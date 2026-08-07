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

use OLLM::Deployment;

my $root = tempdir(CLEANUP => 1);
my $unit = File::Spec->catdir($root, '010-introduction');
my $integration = File::Spec->catdir($root, '090-i-collection');
my $destination = File::Spec->catdir($root, 'deployed');
mkdir $_ or die $! for ($unit, $integration, $destination);
my $missing = File::Spec->catdir($root, 'not-mounted');
my $manifest = {
  project => { id => 'course' },
  languages => { default => 'de' },
  security => { deployment => { overwrite => 'explicit' } },
  deployment => {
    series => 'both', roles => { content => '', integration => '' },
    types => { script => {
      paths => [$destination, $missing],
      filename => '{ordinal:02}-{unit}-{lang}.pdf',
      collection_filename => '{series}-{doctype}-{lang}.pdf',
      units => { introduction => { filename => 'chapter-{chapter:02}.pdf' } },
    } },
  },
};
my $structure = { units => [
  { physical_unit => '010-introduction', unit_role => 'content' },
  { physical_unit => '090-i-collection', unit_role => 'i' },
] };
_promote(unit_id => 'introduction', physical => '010-introduction',
  role => 'content', chapter => 2, ordinal => 1, content => 'unit');
_promote(unit_id => '', physical => '090-i-collection',
  role => 'i', chapter => '', ordinal => '', content => 'collection');

my $request = OLLM::Deployment->prepare(
  plan => { action => 'deploy', target => 'script', scope => 'series' },
  project_root => $root, start_dir => $root,
  manifest => $manifest, structure => $structure,
);
is scalar(@{ $request->{results} }), 2,
  'series=both selects unit and collection artifacts';
my $report = OLLM::Deployment->execute($request);
ok !$report->{ok}, 'an unavailable destination gives CI a failing result';
ok -f File::Spec->catfile($destination, 'chapter-02.pdf'),
  'unit filename override and zero-padded chapter are applied';
ok -f File::Spec->catfile($destination, 'course-script-de.pdf'),
  'doctype collection filename is applied to the integration artifact';
is scalar(grep { $_->{status} eq 'failed' && ($_->{path} // '') eq $missing }
  @{ $report->{items} }), 1, 'an unavailable path is probed only once';
ok grep($_->{status} eq 'skipped', @{ $report->{items} }),
  'later copies to the unavailable path are skipped';

$request = OLLM::Deployment->prepare(
  plan => { action => 'deploy', target => 'script', scope => 'collection' },
  project_root => $root, start_dir => $unit,
  manifest => $manifest, structure => $structure,
);
is scalar(@{ $request->{results} }), 1,
  'collection scope selects the integration artifact from any directory';

my $collection_name = OLLM::Deployment::_filename(
  '{series}-{doctype}-{lang}.pdf', $request, $request->{results}[0],
);
is $collection_name, 'course-script-de.pdf',
  'collection templates do not require unit, chapter, or ordinal';
my %excursus_result = (%{ $request->{results}[0] },
  unit_id => 'extra', unit_role => 'e', ordinal => '1e2', chapter => '2');
is(OLLM::Deployment::_filename(
  '{ordinal:02}-{unit}.pdf', $request, \%excursus_result,
), '01e2-extra.pdf', 'zero padding preserves an excursus ordinal suffix');
my %appendix_result = (%excursus_result,
  unit_id => 'appendix', unit_role => 'a', ordinal => '2ap1');
is(OLLM::Deployment::_filename(
  '{ordinal:02}-{unit}.pdf', $request, \%appendix_result,
), '02ap1-appendix.pdf', 'zero padding preserves an appendix ordinal suffix');

my $target = File::Spec->catfile($destination, 'course-script-de.pdf');
$request->{deployment}{types}{script}{paths} = [$destination];
open my $existing, '>:raw', $target or die $!;
print {$existing} 'old'; close $existing;
$report = OLLM::Deployment->execute($request);
ok !$report->{ok}, 'explicit overwrite policy rejects a different target';
$request->{overwrite} = 1;
$report = OLLM::Deployment->execute($request);
ok $report->{ok}, '--overwrite permits an atomic-preferred replacement';

done_testing;

sub _promote {
  my (%arg) = @_;
  my $generation = sha256_hex(join ':', %arg);
  my $projection = File::Spec->catdir(
    $root, '.osglecture', 'state', 'course',
    'unit-' . sha256_hex($arg{role} eq 'i'
      ? 'integration:' . $arg{physical} : $arg{unit_id}), 'script', 'de',
  );
  my $directory = File::Spec->catdir($projection, 'generations', $generation);
  make_path($directory);
  open my $current, '>:raw', File::Spec->catfile($projection, 'current.tex')
    or die $!;
  print {$current} "\\OsgLectureCurrent{1}{$generation}\n"; close $current;
  my $record = {
    schema => 1, generation_id => $generation, series_id => 'course',
    job_id => 'job', unit_id => $arg{unit_id}, physical_unit => $arg{physical},
    unit_role => $arg{role}, doctype => 'script', language => 'de',
    chapter => "$arg{chapter}", ordinal => "$arg{ordinal}", dependencies => [],
  };
  open my $json, '>:raw', File::Spec->catfile($directory, 'result.json')
    or die $!;
  print {$json} JSON::PP->new->canonical->encode($record); close $json;
  open my $pdf, '>:raw', File::Spec->catfile($directory, 'document.pdf')
    or die $!;
  print {$pdf} $arg{content}; close $pdf;
}
