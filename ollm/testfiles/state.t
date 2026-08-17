use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON::PP;
use Test::More;

use lib 'scripts/vendor/TOML-Tiny-0.22/lib';
use lib 'scripts/lib';

use OLLM::State;

my $root = tempdir(CLEANUP => 1);
my $build = File::Spec->catdir(
  $root, '.osglecture', 'build', '020-processes', 'script', 'de',
);
make_path($build);
my $job = 'bs-020-script-de-processes';
my $spec = {
  schema           => 1,
  job_id           => $job,
  project_root     => $root,
  build_directory  => $build,
  artifact         => File::Spec->catfile($build, "$job.pdf"),
  series_id        => 'bs',
  physical_unit    => '020-processes',
  unit_role        => 'content',
  doctype          => 'script',
  language         => 'de',
  config_signature => 'c' x 64,
};

my $generation = OLLM::State->start_attempt($spec);
like $generation, qr/\A[0-9a-f]{64}\z/,
  'a build attempt receives a portable generation identifier';
ok -f File::Spec->catfile($build, "$job.osgrefs.tex"),
  'an empty job-bound registry is generated before the first build';
ok !defined $spec->{unit_id},
  'the first build does not invent a logical unit-id';

open my $artifact, '>:raw', $spec->{artifact} or die $!;
print {$artifact} "%PDF-test\n";
close $artifact;
open my $result, '>:raw',
  File::Spec->catfile($build, "$job.osgresult.aux") or die $!;
print {$result}
  "\\OsgLectureResult{1}{$generation}{$job}{bs}{processes}"
  . "{020-processes}{content}{script}{de}\n";
close $result;
open my $reference, '>:raw',
  File::Spec->catfile($build, "$job.osgref.aux") or die $!;
print {$reference} "\\newlabel{target}{{42}{7}{Target}{section.1}{}}\n";
print {$reference}
  "\\OsgLectureReferenceExport{1}{$generation}{$job}{bs}"
  . "{processes}{script}{de}\n";
close $reference;
open my $used, '>:raw',
  File::Spec->catfile($build, "$job.osgref-used.aux") or die $!;
print {$used}
  "\\OsgLectureReferenceUse{$generation}{", ('d' x 64),
  "}{other}{script}{de}{sec:other}{page}\n";
print {$used}
  "\\OsgLectureIntegrationUse{$generation}{", ('e' x 64),
  "}{included}{script}{de}\n";
close $used;

my $published = OLLM::State->promote($spec);
ok -d $published, 'a complete generation is published atomically';
ok -f File::Spec->catfile($published, 'reference.osgref.aux'),
  'promoted generation contains the reference export';
ok -f File::Spec->catfile($published, 'document.pdf'),
  'promoted generation contains the matching PDF';
ok -f File::Spec->catfile($published, 'result.json'),
  'promoted generation contains the derived machine-readable result';

open my $json_handle, '<:raw',
  File::Spec->catfile($published, 'result.json') or die $!;
my $record = JSON::PP->new->decode(do { local $/; <$json_handle> });
close $json_handle;
is $record->{unit_id}, 'processes',
  'promoted state uses the explicit LaTeX unit-id';
is_deeply $record->{dependencies}, [{
  kind => 'external-reference', unit_id => 'other',
  doctype => 'script', language => 'de', property => 'page',
  label => 'sec:other', target_generation => 'd' x 64,
}, {
  kind => 'integration', unit_id => 'included',
  doctype => 'script', language => 'de',
  target_generation => 'e' x 64,
}], 'actual external-document use is retained at document granularity';

my %next = %$spec;
delete $next{generation_id};
delete $next{unit_id};
my $next_generation = OLLM::State->start_attempt(\%next);
is $next{unit_id}, 'processes',
  'a later build receives the previously validated logical unit-id';
open my $registry, '<:raw',
  File::Spec->catfile($build, "$job.osgrefs.tex") or die $!;
my $registry_text = do { local $/; <$registry> };
close $registry;
like $registry_text, qr/unit=\{processes\}/,
  'registry exposes the logical unit identity';
like $registry_text,
  qr/\\OsgLectureSeriesUnit\{physical=\{020-processes\},unit=\{processes\}\}/,
  'registry exposes the general physical/logical series-unit mapping';
like $registry_text, qr/reference[.]osgref/,
  'registry points at the promoted reference projection';
like $registry_text, qr/document[.]pdf/,
  'registry points at the PDF from the same generation';

open my $bad_result, '>:raw',
  File::Spec->catfile($build, "$job.osgresult.aux") or die $!;
print {$bad_result}
  "\\OsgLectureResult{1}{", ('0' x 64), "}{$job}{bs}{processes}"
  . "{020-processes}{content}{script}{de}\n";
close $bad_result;
eval { OLLM::State->promote(\%next) };
like $@, qr/generation_id .* does not match BuildSpec/,
  'a mismatched result generation is rejected';
ok -f File::Spec->catfile($published, 'result.json'),
  'failed promotion preserves the last valid generation';

my $integration_build = File::Spec->catdir(
  $root, '.osglecture', 'build', '090-i-collection', 'script', 'de',
);
make_path($integration_build);
my $integration_job = 'bs-090-script-de-collection';
my $integration_spec = {
  %$spec, job_id => $integration_job, build_directory => $integration_build,
  artifact => File::Spec->catfile($integration_build, "$integration_job.pdf"),
  physical_unit => '090-i-collection', unit_role => 'i',
  logical_ordinal => '',
};
delete $integration_spec->{unit_id};
my $integration_generation = OLLM::State->start_attempt($integration_spec);
open my $integration_pdf, '>:raw', $integration_spec->{artifact} or die $!;
print {$integration_pdf} "%PDF-collection\n"; close $integration_pdf;
open my $integration_result, '>:raw', File::Spec->catfile(
  $integration_build, "$integration_job.osgresult.aux",
) or die $!;
print {$integration_result}
  "\\OsgLectureResult{1}{$integration_generation}{$integration_job}{bs}{}"
  . "{090-i-collection}{i}{script}{de}\n"
  . "\\OsgLectureDeploymentResult{}{}\n";
close $integration_result;
my $integration_published = OLLM::State->promote($integration_spec);
ok -f File::Spec->catfile($integration_published, 'document.pdf'),
  'integration PDF is promoted for collection deployment';
ok !-e File::Spec->catfile($integration_published, 'reference.osgref.aux'),
  'integration promotion does not create a reference export';

my %new_target = (%$record, generation_id => 'e' x 64);
my $new_directory = OLLM::State->_generation_directory($spec, \%new_target);
make_path($new_directory);
open my $new_reference, '>:raw',
  File::Spec->catfile($new_directory, 'reference.osgref.aux') or die $!;
print {$new_reference} "\\newlabel{target}{{42}{7}{Target}{section.1}{}}\n";
close $new_reference;
my $dependency = {
  kind => 'external-reference', target_generation => $record->{generation_id},
  unit_id => 'processes', doctype => 'script', language => 'de',
  label => 'target', property => 'ref',
};
is(OLLM::State->dependency_status($spec, $dependency, \%new_target), 'current',
  'an unchanged referenced label remains current across target generations');
open $new_reference, '>:raw',
  File::Spec->catfile($new_directory, 'reference.osgref.aux') or die $!;
print {$new_reference} "\\newlabel{target}{{43}{8}{Target}{section.2}{}}\n";
close $new_reference;
is(OLLM::State->dependency_status($spec, $dependency, \%new_target), 'stale',
  'a changed referenced label makes its consumer stale');

done_testing;
