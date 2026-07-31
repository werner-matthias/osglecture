use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'scripts/vendor/TOML-Tiny-0.22/lib';
use lib 'scripts/lib';

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
  definitions_dir => abs_path('scripts/definitions'),
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
  latexmk_rc => abs_path('scripts/ollm-latexmk.rc'),
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
ok grep($_ eq abs_path('scripts/ollm-latexmk.rc'), @{ $calls[0]{command} }),
  'executor loads only its explicit latexmk configuration';
ok grep($_ eq '-recorder', @{ $calls[0]{command} }),
  'recorder mode is explicit';
ok grep($_ eq '-gg', @{ $calls[0]{command} }),
  'rebuild maps to latexmk full rebuild';
ok grep($_ eq '-silent', @{ $calls[0]{command} }),
  'compatible latexmk arguments are preserved';
ok grep($_ =~ /--shell-restricted/, @{ $calls[0]{command} }),
  'restricted shell escape is part of the controlled LuaLaTeX command';
my %metadata_spec = (
  %{ $resolved->{build_spec} },
  document_metadata => {
    path => File::Spec->catfile($temporary, 'shared metadata.tex'),
  },
);
my @metadata_command = OLLM::Executor->command_for_spec(
  \%metadata_spec, $resolved->{request},
);
ok grep(
  $_ =~ /\A-usepretex=\\def\\OsgLectureRequestedLanguage\{de\}/
    && index($_, '\\input{"') >= 0,
  @metadata_command,
), 'enforced metadata uses controlled pre-TeX with the normalized language';
for my $policy (
  [off  => '--no-shell-escape'],
  [full => '--shell-escape'],
) {
  my %policy_spec = (
    %{ $resolved->{build_spec} },
    shell_escape => $policy->[0],
  );
  my $option = $policy->[1];
  my @command = OLLM::Executor->command_for_spec(
    \%policy_spec, $resolved->{request},
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
  ['-usepretex=evil', qr/owns the pre-TeX hook/],
) {
  $resolved->{request}{latexmk_args} = [$conflict->[0]];
  eval { OLLM::Executor->validate_request($resolved) };
  like $@, $conflict->[1], "$conflict->[0] conflict explains the violated contract";
}

my $standalone_source = File::Spec->catfile($temporary, 'standalone.tex');
open my $standalone_handle, '>', $standalone_source or die $!;
print {$standalone_handle} "\\documentclass{article}\\begin{document}x\\end{document}\n";
close $standalone_handle or die $!;
my $standalone_resolved = {
  request => {
    action => 'build', context => 'standalone', latexmk_args => [
      '-outdir=standalone-output', '-auxdir=standalone-aux',
      '-out2dir=standalone-artifacts',
    ],
    non_interactive => 0, rebuild => 0,
  },
  configuration => {kind => 'none'},
  standalone_spec => {
    context => 'standalone', source => $standalone_source,
    source_directory => $temporary, job_id => 'standalone',
    shell_escape => 'restricted',
  },
};
my @standalone_calls;
$status = OLLM::Executor->execute(
  resolved => $standalone_resolved,
  runner => sub {
    my ($command) = @_;
    push @standalone_calls, [@$command];
    return 0;
  },
);
is $status, 0, 'standalone uses the new executor successfully';
ok grep($_ eq '-out2dir=standalone-artifacts', @{ $standalone_calls[0] }),
  'standalone passes normal latexmk artifact directory options through';
ok !grep(/(?:jobname|\\.osgbuild\\.tex)/, @{ $standalone_calls[0] }),
  'standalone imposes neither a series job name nor a build file';

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

$resolved->{request}{target_explicit} = 0;
$resolved->{request}{latexmk_args} = [];
my $runner_calls = 0;
$status = OLLM::Executor->execute(
  resolved => $resolved,
  runner   => sub {
    $runner_calls++;
    return 12 << 8;
  },
);
is $status, 1, 'latexmk failures map to the stable build-failure exit code';

my $first_lock = OLLM::Executor::_acquire_lock($spec);
ok $first_lock, 'first process acquires the per-BuildSpec lock';
my $lock_diagnostic = '';
{
  local *STDERR;
  open STDERR, '>', \$lock_diagnostic or die $!;
  $status = OLLM::Executor->execute(
    resolved => $resolved,
    runner   => sub {
      $runner_calls++;
      return 0;
    },
  );
}
is $status, 1, 'a concurrent build of the same BuildSpec is rejected';
like $lock_diagnostic, qr/build .* is already active/,
  'lock conflict identifies the active build';
is $runner_calls, 1, 'lock conflict occurs before another process is started';
undef $first_lock;

my %space_spec = (
  %$spec,
  build_directory => File::Spec->catdir($temporary, 'build with spaces'),
  aux_directory   => File::Spec->catdir($temporary, 'build with spaces'),
);
my @space_command = OLLM::Executor->command_for_spec(
  \%space_spec, $resolved->{request},
);
ok grep($_ eq "-outdir=$space_spec{build_directory}", @space_command),
  'build directory containing spaces remains one process argument';

if ($^O ne 'MSWin32') {
  my %separator_spec = (
    %$spec,
    build_directory => File::Spec->catdir($temporary, 'bad:path'),
    aux_directory   => File::Spec->catdir($temporary, 'bad:path'),
  );
  my %separator_resolved = (
    %$resolved,
    build_spec => \%separator_spec,
  );
  eval { OLLM::Executor->validate_request(\%separator_resolved) };
  like $@, qr/contains the TEXINPUTS path separator ':'/,
    'unrepresentable TEXINPUTS build path is rejected explicitly';
}

my $symlink_root = tempdir(CLEANUP => 1);
my $symlink_target = tempdir(CLEANUP => 1);
SKIP: {
  skip 'symbolic links are unavailable', 1
    if !symlink($symlink_target, File::Spec->catdir(
      $symlink_root, '.osglecture',
    ));
  my %symlink_spec = (
    %$spec,
    project_root    => $symlink_root,
    build_directory => File::Spec->catdir(
      $symlink_root, '.osglecture', 'build', '020-processes', 'script', 'de',
    ),
    aux_directory => File::Spec->catdir(
      $symlink_root, '.osglecture', 'build', '020-processes', 'script', 'de',
    ),
  );
  eval { OLLM::Executor::_prepare_build_directory(\%symlink_spec) };
  like $@, qr/resolves outside project root/,
    'symlinked build-state directory cannot redirect writes outside project';
}

done_testing;
