use v5.30;
use strict;
use warnings;

use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON::PP;
use Test::More;

use lib 'vendor/TOML-Tiny-0.22/lib';
use lib 'lib';

use OLLM::Maintenance;

my $root = tempdir(CLEANUP => 1);
my $unit = File::Spec->catdir($root, '020-processes');
make_path($unit);
my $structure = {
  units => [{
    physical_unit => '020-processes', physical_number => '020',
    unit_scope => '', unit_role => 'content', slug => 'processes',
  }],
};
my $manifest = {
  languages => {default => 'de'},
  targets => {
    slides => {languages => ['de']},
    script => {languages => ['de', 'en']},
  },
};
my $current_build = File::Spec->catdir(
  $root, '.osglecture', 'build', '020-processes', 'slides', 'de',
);
my $other_build = File::Spec->catdir(
  $root, '.osglecture', 'build', '020-processes', 'script', 'en',
);
make_path($current_build, $other_build);
_write(File::Spec->catfile($current_build, 'job.pdf'), '%PDF');
_write(File::Spec->catfile($current_build, 'job.aux'), 'aux');
_write(File::Spec->catfile($other_build, 'other.pdf'), '%PDF');
_write(File::Spec->catfile($other_build, 'other.log'), 'log');

my $clean = OLLM::Maintenance->prepare(
  plan => {action => 'clean', dry_run => 1},
  project_root => $root, start_dir => $unit,
  structure => $structure, manifest => $manifest, default_language => 'de',
);
is $clean->{scope}, 'current', 'clean defaults to current scope';
is $clean->{level}, 'aux', 'clean defaults to auxiliary files';
my $clean_report = OLLM::Maintenance->execute($clean);
is_deeply(
  [map { File::Basename::basename($_->{path}) } @{$clean_report->{items}}],
  ['job.aux'],
  'current aux clean selects neither the PDF nor another projection',
);
ok -f File::Spec->catfile($current_build, 'job.aux'),
  'dry-run preserves the selected auxiliary file';

$clean->{dry_run} = 0;
OLLM::Maintenance->execute($clean);
ok !-e File::Spec->catfile($current_build, 'job.aux'),
  'aux clean removes the selected auxiliary file';
ok -f File::Spec->catfile($current_build, 'job.pdf'),
  'aux clean preserves the local PDF artifact';
ok -f File::Spec->catfile($other_build, 'other.log'),
  'current scope preserves another target/language projection';

my $unit_clean = OLLM::Maintenance->prepare(
  plan => {action => 'clean', scope => 'unit', level => 'aux'},
  project_root => $root, start_dir => $unit,
  structure => $structure, manifest => $manifest, default_language => 'de',
);
OLLM::Maintenance->execute($unit_clean);
ok !-e File::Spec->catfile($other_build, 'other.log'),
  'unit aux clean reaches every target/language projection';
ok -f File::Spec->catfile($other_build, 'other.pdf'),
  'unit aux clean does not remove PDFs with their parent directories';

my $series = OLLM::Maintenance->prepare(
  plan => {action => 'clean', scope => 'series', level => 'build'},
  project_root => $root, start_dir => $unit,
  structure => $structure, manifest => $manifest, default_language => 'de',
);
ok $series->{confirm_series},
  'series clean started in a unit requests confirmation';
my $root_series = OLLM::Maintenance->prepare(
  plan => {action => 'clean', scope => 'series', level => 'build'},
  project_root => $root, start_dir => $root,
  structure => $structure, manifest => $manifest, default_language => 'de',
);
ok !$root_series->{confirm_series},
  'series clean started at project root needs no confirmation';
my $series_dry_run = OLLM::Maintenance->prepare(
  plan => {action => 'clean', scope => 'series', level => 'build', dry_run => 1},
  project_root => $root, start_dir => $unit,
  structure => $structure, manifest => $manifest, default_language => 'de',
);
ok !$series_dry_run->{confirm_series},
  'a non-destructive series dry-run needs no confirmation';

my $state = File::Spec->catdir($root, '.osglecture', 'state', 'bs');
my $current_generation = 'a' x 64;
my $old_generation = 'b' x 64;
my $projection = _projection(
  $state, 'unit-one', '020-processes', $current_generation, $old_generation,
);
my $pending = File::Spec->catdir(
  $projection, 'generations', '.pending-attempt',
);
make_path($pending);
_write(File::Spec->catfile($pending, 'partial'), 'partial');
my $stale_projection = _projection(
  $state, 'renamed', '010-old-name', 'c' x 64,
);

my $prune = OLLM::Maintenance->prepare(
  plan => {action => 'prune', dry_run => 0},
  project_root => $root, start_dir => $unit,
  structure => $structure, manifest => $manifest, default_language => 'de',
);
my $prune_report = OLLM::Maintenance->execute($prune);
ok !-d File::Spec->catdir($projection, 'generations', $old_generation),
  'prune removes an unreferenced immutable generation';
ok !-d $pending, 'prune removes an abandoned pending generation';
ok -d $stale_projection,
  'normal prune preserves a state whose physical unit disappeared';
ok grep(
  $_->{operation} eq 'report' && $_->{kind} eq 'stale-unit',
  @{$prune_report->{items}},
), 'normal prune reports a potentially renamed unit';

my $aggressive = OLLM::Maintenance->prepare(
  plan => {action => 'prune', stale_units => 1},
  project_root => $root, start_dir => $root,
  structure => $structure, manifest => $manifest, default_language => 'de',
);
OLLM::Maintenance->execute($aggressive);
ok !-d $stale_projection,
  '--stale-units explicitly removes the stale physical mapping';

done_testing;

sub _projection {
  my ($state, $unit_id, $physical, $current, $old) = @_;
  my $projection = File::Spec->catdir(
    $state, "unit-$unit_id", 'script', 'de',
  );
  my $generations = File::Spec->catdir($projection, 'generations');
  make_path(File::Spec->catdir($generations, $current));
  _write(File::Spec->catfile($projection, 'current.tex'),
    "\\OsgLectureCurrent{1}{$current}\n");
  _write(File::Spec->catfile(
    $generations, $current, 'result.json',
  ), JSON::PP->new->encode({
    generation_id => $current, unit_id => $unit_id,
    physical_unit => $physical, doctype => 'script', language => 'de',
  }));
  if (defined $old) {
    make_path(File::Spec->catdir($generations, $old));
    _write(File::Spec->catfile($generations, $old, 'result.json'), '{}');
  }
  return $projection;
}

sub _write {
  my ($path, $content) = @_;
  open my $handle, '>:raw', $path or die $!;
  print {$handle} $content;
  close $handle;
}
