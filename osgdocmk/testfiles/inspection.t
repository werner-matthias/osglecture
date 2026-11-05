use v5.30;
use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON::PP;
use Test::More;

use lib 'scripts/vendor/TOML-Tiny-0.22/lib';
use lib 'scripts/lib';

use OLLM::Inspection;

my $root = tempdir(CLEANUP => 1);
my $consumer_dir = File::Spec->catdir($root, '020-consumer');
my $dormant_dir = File::Spec->catdir($root, '030-later');
make_path($consumer_dir, $dormant_dir);
my $structure = {
  units => [
    {physical_unit => '010-target', physical_number => '010',
     unit_scope => '', unit_role => 'content', slug => 'target'},
    {physical_unit => '020-consumer', physical_number => '020',
     unit_scope => '', unit_role => 'content', slug => 'consumer'},
    {physical_unit => '030-later', physical_number => '030',
     unit_scope => '', unit_role => 'content', slug => 'later'},
  ],
};
my $manifest = {
  project => {id => 'bs'},
  languages => {default => 'de'},
  targets => {script => {languages => ['de']}, slides => {languages => ['de']}},
};
my $target_generation = 'a' x 64;
my $consumer_generation = 'b' x 64;
_projection(
  unit_id => 'target', physical => '010-target', generation => $target_generation,
  labels => ['sec:present'],
);
_projection(
  unit_id => 'consumer', physical => '020-consumer',
  generation => $consumer_generation,
  dependencies => [{
    kind => 'external-reference', unit_id => 'target',
    doctype => 'script', language => 'de',
    target_generation => $target_generation,
    label => 'sec:present', property => 'ref',
  }],
);

my $series_request = OLLM::Inspection->prepare(
  plan => {action => 'check'}, project_root => $root, start_dir => $root,
  manifest => $manifest, structure => $structure,
);
is $series_request->{scope}, 'series',
  'project-root inspection defaults to series scope';
my $series = OLLM::Inspection->analyze($series_request);
ok $series->{ok}, 'a consistent dependency closure passes check';
is(
  (grep { $_->{physical_unit} eq '030-later' && $_->{status} eq 'dormant' }
    @{$series->{units}}),
  1,
  'an unbuilt and unused discovered unit is dormant, not inconsistent',
);

my $current_request = OLLM::Inspection->prepare(
  plan => {action => 'check', target => 'script', language => 'de'},
  project_root => $root, start_dir => $consumer_dir,
  manifest => $manifest, structure => $structure,
);
is $current_request->{scope}, 'current',
  'inspection within a unit defaults to current scope';
my $current = OLLM::Inspection->analyze($current_request);
is_deeply(
  [map { $_->{unit_id} } @{$current->{projections}}],
  ['target', 'consumer'],
  'current report includes the transitive required dependency',
);
like $current->{projections}[0]{artifact}, qr/document[.]pdf\z/,
  'report exposes the promoted PDF path';
like $current->{projections}[0]{reference_export}, qr/reference[.]osgref[.]aux\z/,
  'report exposes the promoted reference export';
ok !$current->{configuration}{effective_tex}{available},
  'report states that effective and enforced TeX values are not exported yet';

my $missing_current = OLLM::Inspection->prepare(
  plan => {action => 'check', target => 'slides', language => 'de'},
  project_root => $root, start_dir => $consumer_dir,
  manifest => $manifest, structure => $structure,
);
my $missing = OLLM::Inspection->analyze($missing_current);
ok !$missing->{ok}, 'an explicitly selected missing current projection fails';
is $missing->{issues}[0]{code}, 'current-missing',
  'missing current projection has a stable diagnostic code';

my $consumer_result = _result('consumer', 'script', 'de');
$consumer_result->{dependencies}[0]{label} = 'sec:missing';
_rewrite_result($consumer_result);
my $bad_label = OLLM::Inspection->analyze($series_request);
ok !$bad_label->{ok}, 'a required absent exported label fails check';
ok grep($_->{code} eq 'label-missing', @{$bad_label->{issues}}),
  'missing label has a stable diagnostic code';

$consumer_result->{dependencies}[0]{label} = 'sec:present';
$consumer_result->{dependencies}[0]{target_generation} = 'c' x 64;
_rewrite_result($consumer_result);
my $stale = OLLM::Inspection->analyze($series_request);
ok grep($_->{code} eq 'dependency-stale', @{$stale->{issues}}),
  'a consumer bound to an old target generation is detected';

done_testing;

sub _projection {
  my (%arg) = @_;
  my $generation = File::Spec->catdir(
    $root, '.osglecture', 'state', 'bs',
    'unit-' . sha256_hex($arg{unit_id}), 'script', 'de',
    'generations', $arg{generation},
  );
  make_path($generation);
  my $projection = File::Spec->catdir($generation, '..', '..');
  _write(File::Spec->catfile($projection, 'current.tex'),
    "\\OsgLectureCurrent{1}{$arg{generation}}\n");
  my $record = {
    schema => 1, generation_id => $arg{generation}, series_id => 'bs',
    unit_id => $arg{unit_id}, physical_unit => $arg{physical},
    unit_role => 'content', doctype => 'script', language => 'de',
    job_id => "bs-$arg{unit_id}", config_signature => 'f' x 64,
    dependencies => $arg{dependencies} // [],
  };
  _write(File::Spec->catfile($generation, 'result.json'),
    JSON::PP->new->canonical->encode($record));
  _write(File::Spec->catfile($generation, 'document.pdf'), '%PDF');
  my $aux = join '', map { "\\newlabel{$_}{{1}{1}{}{}{}}\n" }
    @{ $arg{labels} // [] };
  _write(File::Spec->catfile($generation, 'reference.osgref.aux'),
    $aux || "% no labels\n");
}

sub _result {
  my ($unit_id, $doctype, $language) = @_;
  my $generation_root = File::Spec->catdir(
    $root, '.osglecture', 'state', 'bs', 'unit-' . sha256_hex($unit_id),
    $doctype, $language, 'generations',
  );
  opendir my $handle, $generation_root or die $!;
  my ($generation) = grep { /\A[0-9a-f]{64}\z/ } readdir $handle;
  closedir $handle;
  open my $json, '<:raw',
    File::Spec->catfile($generation_root, $generation, 'result.json') or die $!;
  my $record = JSON::PP->new->decode(do { local $/; <$json> });
  close $json;
  return $record;
}

sub _rewrite_result {
  my ($record) = @_;
  my $path = File::Spec->catfile(
    $root, '.osglecture', 'state', 'bs',
    'unit-' . sha256_hex($record->{unit_id}), $record->{doctype},
    $record->{language}, 'generations', $record->{generation_id}, 'result.json',
  );
  _write($path, JSON::PP->new->canonical->encode($record));
}

sub _write {
  my ($path, $content) = @_;
  open my $handle, '>:raw', $path or die $!;
  print {$handle} $content;
  close $handle;
}
