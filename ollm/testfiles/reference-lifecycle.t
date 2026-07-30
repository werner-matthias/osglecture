use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'vendor/TOML-Tiny-0.22/lib';
use lib 'lib';

use OLLM::Config;
use OLLM::Executor;
use OLLM::State;

my $latexmk = qx{command -v latexmk 2>/dev/null};
chomp $latexmk;
if (!$latexmk) {
  plan skip_all => 'latexmk is not available';
}

my $root = tempdir(CLEANUP => 1);
my $texinputs = File::Spec->catdir($root, 'texinputs');
make_path($texinputs);
my $modes_dtx = abs_path(
  File::Spec->catfile('..', 'osglecture-modes', 'osglecture-modes.dtx')
);
copy($modes_dtx, File::Spec->catfile($texinputs, 'osglecture-modes.dtx'))
  or die $!;
my $old_directory = getcwd();
chdir $texinputs or die $!;
my $unpack_status = system(
  'tex', '-interaction=batchmode', 'osglecture-modes.dtx',
);
chdir $old_directory or die $!;
if ($unpack_status != 0) {
  BAIL_OUT('cannot unpack osglecture-modes for the lifecycle test');
}
my $unit = File::Spec->catdir($root, '020-processes');
make_path($unit);
copy(
  'testfiles/fixtures/project/ollmconfig.toml',
  File::Spec->catfile($root, 'ollmconfig.toml'),
) or die $!;
open my $source, '>:raw', File::Spec->catfile($unit, 'main.tex')
  or die $!;
print {$source} <<'TEX';
\documentclass[doctype=script]{osglecture}
\begin{document}
\lecture[Processes]{Processes and scheduling}{processes}
\section{Scheduling}\label{sec:scheduling}
Lifecycle fixture.
\end{document}
TEX
close $source;

my $resolved = OLLM::Config->resolve_request(
  start_dir       => $unit,
  definitions_dir => abs_path('definitions'),
  plan => {
    action => 'build', all => 0, dry_run => 0, latexmk_args => ['-silent'],
    legacy_args => [], non_interactive => 1, rebuild => 0, resolve => 0,
    source => 'main.tex', target => 'script',
  },
);
ok !defined($resolved->{build_spec}{unit_id}),
  'first concrete BuildSpec has no slug-derived logical unit-id';

my $separator = $^O eq 'MSWin32' ? ';' : ':';
local $ENV{TEXINPUTS} = $texinputs . $separator
  . abs_path('../osglecture') . $separator
  . ($ENV{TEXINPUTS} // '');
local $ENV{TEXMFVAR} = $ENV{TEXMFVAR} // '/tmp/osglecture-texmf-var';
my $status = OLLM::Executor->execute(
  resolved    => $resolved,
  latexmk_rc  => abs_path('ollm-latexmk.rc'),
);
is $status, 0, 'a real LuaLaTeX build completes and promotes its state';
is(
  OLLM::State->known_unit_id($resolved->{build_spec}),
  'processes',
  'the promoted mapping comes from the explicit lecture declaration',
);

my %next = %{ $resolved->{build_spec} };
delete $next{generation_id};
delete $next{unit_id};
OLLM::State->start_attempt(\%next);
is $next{unit_id}, 'processes',
  'the next BuildSpec can be bound to the validated logical identity';
open my $registry, '<:raw', $next{reference_registry} or die $!;
my $registry_text = do { local $/; <$registry> };
close $registry;
like $registry_text, qr/unit=\{processes\}/,
  'the next job-bound registry contains the promoted projection';
like $registry_text, qr/reference[.]osgref[.]aux/,
  'the registry points at the promoted LaTeX reference export';

my $consumer = File::Spec->catdir($root, '030-consumer');
make_path($consumer);
open my $consumer_source, '>:raw',
  File::Spec->catfile($consumer, 'main.tex') or die $!;
print {$consumer_source} <<'TEX';
\documentclass[doctype=script]{osglecture}
\begin{document}
\lecture{Consumer}{consumer}
See \olref[processes]{sec:scheduling}.
\end{document}
TEX
close $consumer_source;
my $consumer_resolved = OLLM::Config->resolve_request(
  start_dir       => $consumer,
  definitions_dir => abs_path('definitions'),
  plan => {
    action => 'build', all => 0, dry_run => 0, latexmk_args => ['-silent'],
    legacy_args => [], non_interactive => 1, rebuild => 0, resolve => 0,
    source => 'main.tex', target => 'script',
  },
);
my $consumer_status = OLLM::Executor->execute(
  resolved    => $consumer_resolved,
  latexmk_rc  => abs_path('ollm-latexmk.rc'),
);
is $consumer_status, 0,
  'a second unit resolves and promotes an external reference';
my $consumer_spec = $consumer_resolved->{build_spec};
open my $consumer_log, '<:raw', File::Spec->catfile(
  $consumer_spec->{build_directory}, "$consumer_spec->{job_id}.log",
) or die $!;
my $consumer_log_text = do { local $/; <$consumer_log> };
close $consumer_log;
unlike $consumer_log_text, qr/Reference .* undefined/,
  'the external label is resolved through the promoted aux projection';
my ($consumer_result) = grep {
  $_->{physical_unit} eq '030-consumer'
} OLLM::State->_current_results($consumer_spec);
is_deeply $consumer_result->{dependencies}, [{
  kind => 'external-reference', unit_id => 'processes',
  doctype => 'script', language => 'de', property => 'document',
}], 'the promoted consumer records its actual external document dependency';

done_testing;
