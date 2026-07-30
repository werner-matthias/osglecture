use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON::PP;
use Test::More;

use lib 'vendor/TOML-Tiny-0.22/lib';
use lib 'lib';

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
  "\\OsgLectureReferenceUse{$generation}{other}{script}{de}{document}\n";
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
  doctype => 'script', language => 'de', property => 'document',
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

done_testing;
