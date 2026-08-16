use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'scripts/vendor/TOML-Tiny-0.22/lib';
use lib 'scripts/lib';

use OLLM::Config;
use OLLM::CLI;
use OLLM::Executor;
use OLLM::Resolver;
use OLLM::State;

sub _execute_and_preserve_log {
  my ($resolved, $latexmk_rc, $label) = @_;
  my $status = OLLM::Executor->execute(
    resolved => $resolved,
    latexmk_rc => $latexmk_rc,
  );
  if ($status) {
    my $spec = $resolved->{build_spec};
    my $source = File::Spec->catfile(
      $spec->{build_directory}, "$spec->{job_id}.log",
    );
    if (-f $source) {
      my $destination = File::Spec->catdir('..', 'build', 'test');
      make_path($destination);
      copy($source, File::Spec->catfile(
        $destination, "ollm-reference-lifecycle-$label.log",
      )) or warn "cannot preserve failed lifecycle log '$source': $!\n";
    }
  }
  return $status;
}

my $latexmk = OLLM::CLI::_find_program('latexmk');
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
my $shared = File::Spec->catdir($root, 'Include');
make_path($unit, $shared);
copy(
  'testfiles/fixtures/project/Include/projectconfig.tex',
  File::Spec->catfile($shared, 'projectconfig.tex'),
) or die $!;
copy(
  'testfiles/fixtures/project/ollmconfig.toml',
  File::Spec->catfile($root, 'ollmconfig.toml'),
) or die $!;
my $lifecycle_manifest = File::Spec->catfile($root, 'ollmconfig.toml');
open my $manifest_in, '<:raw', $lifecycle_manifest or die $!;
my $manifest_text = do { local $/; <$manifest_in> };
close $manifest_in;
$manifest_text =~ s/document_metadata = "required"/document_metadata = "disabled"/;
open my $manifest_out, '>:raw', $lifecycle_manifest or die $!;
print {$manifest_out} $manifest_text;
close $manifest_out;
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
  definitions_dir => abs_path('scripts/definitions'),
  plan => {
    action => 'build', all => 0, dry_run => 0, latexmk_args => ['-silent'],
    legacy_args => [], non_interactive => 1, rebuild => 0, resolve => 0,
    source => 'main.tex', target => 'script',
  },
);
ok !defined($resolved->{build_spec}{unit_id}),
  'first concrete BuildSpec has no slug-derived logical unit-id';

my $separator = $^O eq 'MSWin32' ? ';' : ':';
my $osglecture_path = abs_path('../osglecture');
$osglecture_path =~ s{\\}{/}g;
my $texinputs_path = $texinputs;
$texinputs_path =~ s{\\}{/}g;
local $ENV{TEXINPUTS} = $texinputs_path . $separator
  . $osglecture_path . $separator
  . ($ENV{TEXINPUTS} // '');
local $ENV{LUAINPUTS} = $osglecture_path . $separator
  . ($ENV{LUAINPUTS} // '');
local $ENV{TEXMFVAR} = $ENV{TEXMFVAR}
  // File::Spec->catdir($root, 'texmf-var');
my $status = _execute_and_preserve_log(
  $resolved, abs_path('scripts/ollm-latexmk.rc'), 'producer-initial',
);
is $status, 0, 'a real LuaLaTeX build completes and promotes its state';
is(
  OLLM::State->known_unit_id($resolved->{build_spec}),
  'processes',
  'the promoted mapping comes from the explicit lecture declaration',
);
my ($initial_producer) = grep {
  $_->{physical_unit} eq '020-processes'
} OLLM::State->_current_results($resolved->{build_spec});
my $producer_export = File::Spec->catfile(
  OLLM::State->_generation_directory($resolved->{build_spec}, $initial_producer),
  'reference.osgref.aux',
);
open my $continuation_export, '<:raw', $producer_export or die $!;
my $continuation_export_text = do { local $/; <$continuation_export> };
close $continuation_export;
like $continuation_export_text,
  qr/\\OsgLectureContinuationCounter\{section\}\{1\}/,
  'the promoted reference export contains the final section counter';
like $continuation_export_text,
  qr/\\OsgLectureContinuationCounter\{page\}\{2\}/,
  'the promoted reference export contains the next physical page number';

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
\typeout{CONTINUATION-PAGE=\arabic{page}}
\typeout{CONTINUATION-BEFORE=\arabic{section}}
\section{Continued section}
\typeout{CONTINUATION-AFTER=\arabic{section}}
See \olref[processes]{sec:scheduling}.
\end{document}
TEX
close $consumer_source;
my $consumer_resolved = OLLM::Config->resolve_request(
  start_dir       => $consumer,
  definitions_dir => abs_path('scripts/definitions'),
  plan => {
    action => 'build', all => 0, dry_run => 0, latexmk_args => ['-silent'],
    legacy_args => [], non_interactive => 1, rebuild => 0, resolve => 0,
    source => 'main.tex', target => 'script',
  },
);
my $consumer_status = _execute_and_preserve_log(
  $consumer_resolved, abs_path('scripts/ollm-latexmk.rc'), 'consumer',
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
like $consumer_log_text, qr/CONTINUATION-PAGE=2/,
  'the consumer starts with the physical page after its predecessor';
like $consumer_log_text, qr/CONTINUATION-BEFORE=1/,
  'the consumer imports the previous unit section counter';
like $consumer_log_text, qr/CONTINUATION-AFTER=2/,
  'the next section continues the imported numbering';
my ($consumer_result) = grep {
  $_->{physical_unit} eq '030-consumer'
} OLLM::State->_current_results($consumer_spec);
is_deeply $consumer_result->{dependencies}, [{
  kind => 'external-reference', unit_id => 'processes',
  doctype => 'script', language => 'de', property => 'ref',
  label => 'sec:scheduling',
  target_generation => $resolved->{build_spec}{generation_id},
}], 'the promoted consumer records its actual external document dependency';

my $unknown_consumer = File::Spec->catdir($root, '040-unknown-consumer');
make_path($unknown_consumer);
open my $unknown_source, '>:raw',
  File::Spec->catfile($unknown_consumer, 'main.tex') or die $!;
print {$unknown_source} <<'TEX';
\documentclass[doctype=script]{osglecture}
\begin{document}
\lecture{Unknown consumer}{unknown-consumer}
See \olref[never-built]{missing-label}.
\end{document}
TEX
close $unknown_source;
my $unknown_resolved = OLLM::Config->resolve_request(
  start_dir       => $unknown_consumer,
  definitions_dir => abs_path('scripts/definitions'),
  plan => {
    action => 'build', all => 0, dry_run => 0, latexmk_args => ['-silent'],
    legacy_args => [], non_interactive => 1, rebuild => 0, resolve => 0,
    source => 'main.tex', target => 'script',
  },
);
is(
  _execute_and_preserve_log(
    $unknown_resolved, abs_path('scripts/ollm-latexmk.rc'),
    'unknown-consumer',
  ),
  0,
  'an unresolved logical unit remains a normal LaTeX build result',
);
my $unknown_spec = $unknown_resolved->{build_spec};
open my $unknown_log, '<:raw', File::Spec->catfile(
  $unknown_spec->{build_directory}, "$unknown_spec->{job_id}.log",
) or die $!;
my $unknown_log_text = do { local $/; <$unknown_log> };
close $unknown_log;
like $unknown_log_text,
  qr/Logical unit 'never-built' is not known.*in this series/s,
  'LaTeX explains that an unknown logical unit must first be built';
eval {
  OLLM::Resolver->execute(
    resolved => $unknown_resolved,
    latexmk_rc => abs_path('scripts/ollm-latexmk.rc'),
  );
};
like $@,
  qr/physical unit is unknown; build that unit once before resolving references/,
  '--resolve reports the unknown mapping instead of searching every unit';

open $source, '>:raw', File::Spec->catfile($unit, 'main.tex') or die $!;
print {$source} <<'TEX';
\documentclass[doctype=script]{osglecture}
\begin{document}
\lecture[Processes]{Processes and scheduling}{processes}
\section{Earlier material}
\section{Scheduling}\label{sec:scheduling}
Lifecycle fixture.
\end{document}
TEX
close $source;
my $producer_status = _execute_and_preserve_log(
  $resolved, abs_path('scripts/ollm-latexmk.rc'), 'producer-changed',
);
is $producer_status, 0, 'the producer can publish a changed label generation';
my ($changed_producer) = grep {
  $_->{physical_unit} eq '020-processes'
} OLLM::State->_current_results($consumer_spec);
isnt $changed_producer->{generation_id}, $consumer_result->{dependencies}[0]{target_generation},
  'the consumer is stale before reference resolution';
my $resolve_status = OLLM::Resolver->execute(
  resolved => $consumer_resolved,
  latexmk_rc => abs_path('scripts/ollm-latexmk.rc'),
);
is $resolve_status, 0, '--resolve rebuilds the stale consumer to a fixpoint';
my ($resolved_consumer) = grep {
  $_->{physical_unit} eq '030-consumer'
} OLLM::State->_current_results($consumer_spec);
is $resolved_consumer->{dependencies}[0]{target_generation},
  $changed_producer->{generation_id},
  'the resolved consumer records the current producer generation';

done_testing;
