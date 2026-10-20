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

use OLLM::CLI;
use OLLM::Config;
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
  security => { overwrite => 'explicit' },
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

is(OLLM::Deployment::_filename(
  '{slug}-{lang}.pdf', $request, $request->{results}[0],
), 'collection-de.pdf', 'slug omits the number and role of the unit directory');
my %labelled_result = (%excursus_result,
  unit_id => 'un:extra', physical_unit => '020ab-e-extra-topic');
is(OLLM::Deployment::_filename(
  '{ordinal:02}-{slug}.pdf', $request, \%labelled_result,
), '01e2-extra-topic.pdf', 'slug is independent of a label-style unit ID');
ok !eval { OLLM::Deployment::_filename(
  '{slug}.pdf', $request, { %labelled_result, physical_unit => 'odd' }); 1 },
  'slug requires a regular unit directory name';

my $target = File::Spec->catfile($destination, 'course-script-de.pdf');
$request->{deployment}{types}{script}{paths} = [$destination];
open my $existing, '>:raw', $target or die $!;
print {$existing} 'old'; close $existing;
$report = OLLM::Deployment->execute($request);
ok !$report->{ok}, 'explicit overwrite policy rejects a different target';
$request->{overwrite} = 1;
$report = OLLM::Deployment->execute($request);
ok $report->{ok}, '--overwrite permits an atomic-preferred replacement';

# --- PDF permissions ------------------------------------------------------

my $config = File::Spec->catfile($root, 'ollmconfig.toml');
open my $toml, '>:raw', $config or die $!;
print {$toml} <<'TOML';
schema = 2
[project]
id = "course"
[targets.defaults]
languages = ["de"]
default_language = "de"
[targets.script]
[targets.slides]
[deployment]
paths = ["deployed"]
filename = "{unit}.pdf"
[deployment.permissions]
print = "none"
extract = false
modify = true
[deployment.types.script]
[deployment.types.slides.permissions]
print = "low"
TOML
close $toml;
my $configured = OLLM::Config->load_manifest($config);
is_deeply $configured->{deployment}{types}{script}{permissions},
  { print => 'none', extract => 0, modify => 1 },
  'a type without permissions inherits the deployment default';
is_deeply $configured->{deployment}{types}{slides}{permissions},
  { print => 'low' }, 'a type permissions table replaces the default';
is OLLM::Deployment::restrictions(
  $configured->{deployment}{types}{script}{permissions}),
  'print=none,extract=false', 'only withheld permissions are restrictions';
is OLLM::Deployment::restrictions({ print => 'full', modify => 1 }), '',
  'granted permissions need no encryption';

for my $case (
  [ 'print = "never"', qr/invalid deployment\.permissions\.print 'never'/ ],
  [ 'extract = "no"', qr/deployment\.permissions\.extract must be true or false/ ],
  [ 'accessibility = false', qr/unknown key 'deployment\.permissions\.accessibility'/ ],
) {
  my $invalid = File::Spec->catfile(tempdir(CLEANUP => 1), 'ollmconfig.toml');
  open my $handle, '>:raw', $invalid or die $!;
  print {$handle} <<"TOML";
schema = 2
[project]
id = "course"
[targets.defaults]
languages = ["de"]
default_language = "de"
[targets.script]
[deployment]
paths = ["deployed"]
filename = "{unit}.pdf"
[deployment.permissions]
$case->[0]
[deployment.types.script]
TOML
  close $handle;
  eval { OLLM::Config->load_manifest($invalid) };
  like $@, $case->[1], "invalid permissions are rejected: $case->[0]";
}

is_deeply(OLLM::Deployment->parse_permissions('print=none, extract=no'),
  { print => 'none', extract => 0 }, '--permissions accepts KEY=VALUE lists');
is_deeply(OLLM::Deployment->parse_permissions('all'), {},
  '--permissions=all grants every permission');
for my $spec ('', 'print', 'print=never', 'copy=false', 'print=low,print=none') {
  ok !eval { OLLM::Deployment->parse_permissions($spec); 1 },
    "--permissions rejects '$spec'";
}
is_deeply(OLLM::CLI->parse(qw(deploy --permissions print=none))->{permissions},
  { print => 'none' }, 'the CLI parses a separate --permissions value');
is(OLLM::CLI->parse(qw(deploy --owner-password=secret))->{owner_password},
  'secret', 'the CLI accepts an owner password for deploy');
ok !eval { OLLM::CLI->parse('deploy', '--owner-password='); 1 },
  'an empty owner password is rejected';

$request = OLLM::Deployment->prepare(
  plan => { action => 'deploy', target => 'script', scope => 'series' },
  project_root => $root, start_dir => $root,
  manifest => { %$manifest, deployment => {
    %{ $manifest->{deployment} },
    types => { script => { %{ $manifest->{deployment}{types}{script} },
      permissions => { print => 'none' } } },
  } }, structure => $structure,
);
ok(OLLM::Deployment->requires_qpdf($request),
  'configured restrictions require qpdf');
$request->{permissions} = {};
ok(!OLLM::Deployment->requires_qpdf($request),
  'an explicit --permissions=all overrides configured restrictions');
$request->{permissions} = { print => 'none' };
$request->{qpdf} = undef;
$report = OLLM::Deployment->execute($request);
ok !$report->{ok} && $report->{items}[0]{message} =~ /require qpdf/,
  'restricted deployment fails instead of copying an unrestricted PDF';

SKIP: {
  my $qpdf = OLLM::CLI::_find_program('qpdf');
  skip 'qpdf is not installed', 10 if !$qpdf;
  my $restricted = File::Spec->catdir($root, 'restricted');
  mkdir $restricted or die $!;
  _promote(unit_id => 'introduction', physical => '010-introduction',
    role => 'content', chapter => 2, ordinal => 1, content => _pdf());
  $request = OLLM::Deployment->prepare(
    plan => { action => 'deploy', target => 'script', scope => 'unit',
      permissions => { print => 'none', extract => 0 } },
    project_root => $root, start_dir => $unit,
    manifest => $manifest, structure => $structure,
  );
  $request->{deployment}{types}{script}{paths} = [$restricted];
  $request->{qpdf} = $qpdf;
  $report = OLLM::Deployment->execute($request);
  ok $report->{ok}, 'qpdf creates the restricted copy';
  is $report->{items}[0]{restrictions}, 'print=none,extract=false',
    'the report names the applied restrictions';
  my $deployed = File::Spec->catfile($restricted, 'chapter-02.pdf');
  my $encryption = OLLM::Deployment::_encryption($qpdf, $deployed);
  like $encryption, qr/\AR = 6\n/, 'the copy uses AES-256 encryption';
  open my $show, '-|', $qpdf, '--show-encryption', $deployed or die $!;
  my $shown = do { local $/; <$show> }; close $show;
  like $shown, qr/print high resolution: not allowed/,
    'printing is not allowed';
  like $shown, qr/extract for any purpose: not allowed/,
    'extraction is not allowed';
  $report = OLLM::Deployment->execute($request);
  is $report->{items}[0]{status}, 'unchanged',
    'a fresh restricted copy of the same artifact is unchanged';
  $request->{permissions} = { print => 'low' };
  $report = OLLM::Deployment->execute($request);
  ok !$report->{ok}, 'changed permissions make the existing copy different';

  $request->{permissions} = { print => 'none', extract => 0 };
  $request->{owner_password} = 'lift-me';
  $request->{overwrite} = 1;
  $report = OLLM::Deployment->execute($request);
  like OLLM::Deployment::_encryption($qpdf, $deployed, 'lift-me'),
    qr/Supplied password is owner password/,
    '--owner-password sets the password that lifts the restrictions';
  $request->{overwrite} = 0;
  $report = OLLM::Deployment->execute($request);
  is $report->{items}[0]{status}, 'unchanged',
    'a copy with the same owner password is unchanged';
  $request->{owner_password} = 'another';
  $report = OLLM::Deployment->execute($request);
  ok !$report->{ok}, 'a different owner password makes the copy different';
}

done_testing;

# A minimal valid one-page PDF with a correct cross-reference table. Like
# every LuaLaTeX PDF it carries a document ID, which qpdf keeps when it
# encrypts; without one each encryption would invent a different ID.
sub _pdf {
  my $content = "0 0 m 10 10 l S\n";
  my @objects = (
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>',
    "<< /Length " . length($content) . " >>\nstream\n${content}endstream",
  );
  my $pdf = "%PDF-1.7\n";
  my @offsets;
  for my $number (1 .. @objects) {
    push @offsets, length $pdf;
    $pdf .= "$number 0 obj\n$objects[$number - 1]\nendobj\n";
  }
  my $xref = length $pdf;
  $pdf .= "xref\n0 " . (@objects + 1) . "\n0000000000 65535 f \n";
  $pdf .= sprintf "%010d 00000 n \n", $_ for @offsets;
  $pdf .= "trailer\n<< /Size " . (@objects + 1) . " /Root 1 0 R\n"
    . "/ID [<0123456789abcdef0123456789abcdef> <0123456789abcdef0123456789abcdef>] >>\n"
    . "startxref\n$xref\n%%EOF\n";
  return $pdf;
}

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
