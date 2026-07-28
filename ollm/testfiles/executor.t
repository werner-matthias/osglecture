use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'vendor/TOML-Tiny-0.22/lib';
use lib 'lib';

use OLLM::Config;
use OLLM::Executor;

my $fixture = abs_path('testfiles/fixtures/project');
my $temporary = tempdir(CLEANUP => 1);
my $chapter = File::Spec->catdir($temporary, '020-processes');
make_path($chapter);
copy(
  File::Spec->catfile($fixture, 'ollmconfig.toml'),
  File::Spec->catfile($temporary, 'ollmconfig.toml'),
) or die $!;
copy(
  File::Spec->catfile($fixture, '020-processes', 'main.tex'),
  File::Spec->catfile($chapter, 'main.tex'),
) or die $!;
my $resolved = OLLM::Config->resolve_request(
  start_dir       => $chapter,
  definitions_dir => abs_path('definitions'),
  plan => {
    action          => 'build',
    all             => 0,
    dry_run         => 0,
    latexmk_args    => ['-silent'],
    legacy_args     => [],
    non_interactive => 1,
    rebuild         => 1,
    resolve         => 0,
    source          => 'main.tex',
    target          => 'script',
  },
);

my @calls;
my $status = OLLM::Executor->execute(
  resolved => $resolved,
  latexmk_rc => abs_path('ollm-latexmk.rc'),
  runner => sub {
    my ($command, $spec) = @_;
    push @calls, {
      command => [@$command],
      job_id  => $spec->{job_id},
    };
    return 0;
  },
);
is $status, 0, 'executor reports a successful runner';
is scalar @calls, 1, 'executor starts one process for one BuildSpec';
is $calls[0]{command}[0], 'latexmk', 'executor invokes latexmk directly';
ok grep($_ eq abs_path('ollm-latexmk.rc'), @{ $calls[0]{command} }),
  'executor loads only its explicit latexmk configuration';
ok grep($_ eq '-recorder', @{ $calls[0]{command} }),
  'recorder mode is explicit';
ok grep($_ eq '-gg', @{ $calls[0]{command} }),
  'rebuild maps to latexmk full rebuild';
ok grep($_ eq '-silent', @{ $calls[0]{command} }),
  'compatible latexmk arguments are preserved';
ok grep($_ =~ /--shell-restricted/, @{ $calls[0]{command} }),
  'restricted shell escape is part of the controlled LuaLaTeX command';
for my $policy (
  [off  => '--no-shell-escape'],
  [full => '--shell-escape'],
) {
  my %variant = (%{ $resolved->{build_spec} }, shell_escape => $policy->[0]);
  my $option = $policy->[1];
  my @command = OLLM::Executor->command_for_spec(
    \%variant, $resolved->{request},
  );
  ok grep($_ =~ /\Q$option\E/, @command),
    "$policy->[0] shell-escape policy maps to LuaLaTeX";
}

my $spec = $resolved->{build_spec};
my $build_file = File::Spec->catfile(
  $spec->{build_directory}, "$spec->{job_id}.osgbuild.tex",
);
ok -f $build_file, 'executor writes the job-bound build file';

$resolved->{request}{latexmk_args} = ['-outdir=elsewhere'];
eval {
  OLLM::Executor->execute(
    resolved => $resolved,
    runner   => sub { return 0 },
  );
};
like $@, qr/conflicts with the controlled build contract/,
  'user arguments cannot replace the isolated output directory';

$resolved->{request}{rebuild} = 0;
$resolved->{request}{latexmk_args} = ['-pvc'];
eval {
  OLLM::Executor::_validate_latexmk_args($resolved->{request}, 2);
};
like $@,
  qr/--all cannot be combined.*first build would keep running.*never start/,
  '--all conflict explains why continuous mode cannot execute a build matrix';

eval {
  OLLM::Executor::_validate_latexmk_args($resolved->{request}, 1);
};
like $@,
  qr/--non-interactive cannot start.*viewer.*-view=none/,
  'non-interactive viewer conflict explains the headless alternative';

$resolved->{request}{latexmk_args} = ['-pvc', '-view=none'];
eval {
  OLLM::Executor::_validate_latexmk_args($resolved->{request}, 1);
};
is $@, '', 'non-interactive continuous compilation without a viewer is valid';

$resolved->{request}{latexmk_args} = ['-cc'];
eval {
  OLLM::Executor::_validate_latexmk_args($resolved->{request}, 1);
};
is $@, '', 'latexmk continuous-compile mode is valid for one build';

$resolved->{request}{rebuild} = 1;
eval {
  OLLM::Executor::_validate_latexmk_args($resolved->{request}, 1);
};
like $@, qr/--rebuild cannot be combined.*disables force mode/,
  'continuous mode explains its conflict with an OLLM rebuild';

$resolved->{request}{latexmk_args} = ['-g-'];
eval {
  OLLM::Executor::_validate_latexmk_args($resolved->{request}, 1);
};
like $@, qr/-g-.*turns off the rebuild mode/,
  'latexmk force-mode negation cannot cancel an OLLM rebuild';

$resolved->{request}{latexmk_args} = [];
$resolved->{request}{rebuild} = 0;
$status = OLLM::Executor->execute(
  resolved => $resolved,
  runner   => sub { return 2 },
);
is $status, 130, 'SIGINT wait status becomes the conventional abort exit code';

for my $conflict (
  ['-r=other.rc', qr/additional rc files or startup Perl code/],
  ['-pdfxe', qr/non-LuaLaTeX engine/],
  ['-output-format=dvi', qr/LuaLaTeX-to-PDF only/],
  ['-out2dir=artifacts', qr/outside the BuildSpec path/],
  ['-use-make', qr/OLLM.*owns orchestration/],
  ['-latexoption=--jobname=other', qr/unvalidated options/],
  ['-cd-', qr/required source working directory/],
  ['-recorder-', qr/required recorder dependency data/],
) {
  $resolved->{request}{latexmk_args} = [$conflict->[0]];
  eval { OLLM::Executor->validate_request($resolved) };
  like $@, $conflict->[1], "$conflict->[0] conflict explains the violated contract";
}

$resolved->{request}{latexmk_args} = ['-c'];
$resolved->{request}{rebuild} = 1;
eval { OLLM::Executor->validate_request($resolved) };
like $@, qr/--rebuild requests a document build.*requests clean instead/,
  'clean action rejects contradictory OLLM rebuild request';

$resolved->{request}{rebuild} = 0;
unlink $build_file or die "cannot remove temporary build file: $!";
$status = OLLM::Executor->execute(
  resolved => $resolved,
  runner   => sub {
    my ($command) = @_;
    return grep($_ eq '-c', @$command) ? 0 : 256;
  },
);
is $status, 0, 'latexmk clean action is passed through';
ok !-e $build_file, 'clean action does not create a new build-request file';

$resolved->{request}{latexmk_args} = ['-version'];
eval { OLLM::Executor::_validate_latexmk_args($resolved->{request}, 2) };
like $@, qr/--all requests multiple.*only reports information/,
  'information action rejects a misleading OLLM build matrix';

$resolved->{request}{target_explicit} = 1;
eval { OLLM::Executor::_validate_latexmk_args($resolved->{request}, 1) };
like $@, qr/explicit OLLM target selection would not describe a build/,
  'information action reports an irrelevant explicit OLLM selection';

done_testing;
