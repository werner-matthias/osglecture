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

my $fixture = abs_path('testfiles/fixtures/project');
my $chapter = File::Spec->catdir($fixture, '020-processes');
my $manifest_path = File::Spec->catfile($fixture, 'ollmconfig.toml');
my $definitions = abs_path('scripts/definitions');

my $located = OLLM::Config->find_manifest(start_dir => $chapter);
is $located->{kind}, 'toml', 'manifest found by upward search';
is $located->{path}, $manifest_path, 'manifest path is canonical';

my $manifest = OLLM::Config->load_manifest($manifest_path);
is $manifest->{schema}, 1, 'schema parsed';
is $manifest->{project}{id}, 'bs', 'project id parsed';
is $manifest->{project}{tex}{directory}, 'Include',
  'shared TeX directory parsed';
is $manifest->{project}{tex}{config}, 'projectconfig.tex',
  'project configuration filename parsed';
is_deeply $manifest->{languages}{available}, ['de', 'en'],
  'language list parsed';

my $obsolete_title = File::Spec->catfile(tempdir(CLEANUP => 1), 'ollmconfig.toml');
open my $obsolete_title_handle, '>:raw', $obsolete_title or die $!;
print {$obsolete_title_handle} <<'TOML';
schema = 1
[project]
id = "test"
title = "TeX metadata"
[languages]
available = ["de"]
default = "de"
[targets.slides]
languages = ["de"]
TOML
close $obsolete_title_handle;
eval { OLLM::Config->load_manifest($obsolete_title) };
like $@, qr/unknown key 'project\.title'/,
  'project title is rejected as a TeX-side property';

my $obsolete_map = File::Spec->catfile(tempdir(CLEANUP => 1), 'ollmconfig.toml');
open my $obsolete_map_handle, '>:raw', $obsolete_map or die $!;
print {$obsolete_map_handle} <<'TOML';
schema = 1
[project]
id = "test"
[languages]
available = ["de"]
default = "de"
[languages.map]
de = "ngerman"
[targets.slides]
languages = ["de"]
TOML
close $obsolete_map_handle;
eval { OLLM::Config->load_manifest($obsolete_map) };
like $@, qr/unknown key 'languages\.map'/,
  'language mapping is rejected as a langselect-side property';

my $resolved = OLLM::Config->resolve_request(
  start_dir => $chapter,
  definitions_dir => $definitions,
  plan => {
    action => 'build',
    all => 0,
    dry_run => 1,
    latexmk_args => [],
    legacy_args => [],
    non_interactive => 0,
    rebuild => 0,
    resolve => 0,
    source => 'main.tex',
    target => 'script',
  },
);
is $resolved->{request}{context}, 'series', 'manifest selects series context';
is $resolved->{request}{language}, 'de', 'project default language selected';
is $resolved->{request}{series_id}, 'bs', 'series id enters BuildRequest';
is $resolved->{configuration}{parser}{version}, '0.22',
  'parser version is reported';
is $resolved->{configuration}{definitions}{bundle_preset}{version}, '1',
  'selected bundle-preset definition is resolved';
is $resolved->{configuration}{definitions}{targets}{script}{version}, '1.0',
  'configured target definition is resolved';
like $resolved->{configuration}{structure}{signature},
  qr/\A[0-9a-f]{64}\z/,
  'series discovery produces a canonical structure signature';
is_deeply(
  $resolved->{configuration}{structure}{units},
  [{
    physical_unit   => '020-processes',
    physical_number => '020',
    unit_scope      => '',
    unit_role       => 'content',
    slug            => 'processes',
  }],
  'structure snapshot records the physical ordering metadata only',
);

my $structure_root_a = tempdir(CLEANUP => 1);
my $structure_root_b = tempdir(CLEANUP => 1);
for my $root ($structure_root_a, $structure_root_b) {
  make_path(
    File::Spec->catdir($root, '020-introduction'),
    File::Spec->catdir($root, '090a-a-posix'),
    File::Spec->catdir($root, 'notes'),
  );
}
my $structure_a = OLLM::Config->structure_snapshot(
  project_root => $structure_root_a,
);
my $structure_b = OLLM::Config->structure_snapshot(
  project_root => $structure_root_b,
);
is $structure_a->{signature}, $structure_b->{signature},
  'structure signature is independent of the absolute project path';
rename(
  File::Spec->catdir($structure_root_b, '020-introduction'),
  File::Spec->catdir($structure_root_b, '040-introduction'),
) or die "cannot rename structure fixture: $!";
my $renamed_structure = OLLM::Config->structure_snapshot(
  project_root => $structure_root_b,
);
isnt $renamed_structure->{signature}, $structure_a->{signature},
  'renaming or reordering a unit changes the structure signature';
make_path(File::Spec->catdir($structure_root_b, 'unrelated-directory'));
is(
  OLLM::Config->structure_snapshot(
    project_root => $structure_root_b,
  )->{signature},
  $renamed_structure->{signature},
  'unmarked unrelated directories do not invalidate the series structure',
);

$resolved = OLLM::Config->resolve_request(
  start_dir => $chapter,
  definitions_dir => $definitions,
  plan => {
    action => 'build',
    all => 1,
    dry_run => 1,
    latexmk_args => [],
    legacy_args => [],
    non_interactive => 0,
    rebuild => 0,
    resolve => 0,
    source => 'main.tex',
    target => 'slides',
  },
);
is scalar @{ $resolved->{request}{builds} }, 4,
  '--all expands only configured target/language pairs';
is scalar @{ $resolved->{build_specs} }, 4,
  '--all resolves every configured pair to a concrete BuildSpec';
is_deeply(
  [map { $_->{job_id} } @{ $resolved->{build_specs} }],
  [
    'bs-020-handout-de-processes',
    'bs-020-script-de-processes',
    'bs-020-script-en-processes',
    'bs-020-slides-de-processes',
  ],
  '--all produces deterministic job identities',
);

my $scoped_root = tempdir(CLEANUP => 1);
my $scoped_unit = File::Spec->catdir($scoped_root, '020as-processes');
my $scoped_shared = File::Spec->catdir($scoped_root, 'Include');
make_path($scoped_unit, $scoped_shared);
for my $file (qw(projectconfig.tex documentmetadata.tex)) {
  copy(
    File::Spec->catfile($fixture, 'Include', $file),
    File::Spec->catfile($scoped_shared, $file),
  ) or die $!;
}
open my $scoped_manifest, '>',
  File::Spec->catfile($scoped_root, 'ollmconfig.toml') or die $!;
open my $fixture_manifest, '<', $manifest_path or die $!;
print {$scoped_manifest} $_ while <$fixture_manifest>;
close $fixture_manifest;
close $scoped_manifest;
open my $scoped_source, '>',
  File::Spec->catfile($scoped_unit, 'main.tex') or die $!;
print {$scoped_source} "\\documentclass{article}\n";
close $scoped_source;
my $scoped = OLLM::Config->resolve_request(
  start_dir       => $scoped_unit,
  definitions_dir => $definitions,
  plan => {
    action => 'build',
    all => 1,
    dry_run => 1,
    latexmk_args => [],
    legacy_args => [],
    non_interactive => 0,
    rebuild => 0,
    resolve => 0,
    source => 'main.tex',
    target => 'slides',
  },
);
is_deeply(
  [map { $_->{target} } @{ $scoped->{build_specs} }],
  ['script', 'script'],
  '--all filters target/language pairs through target unit scopes',
);

my $standalone = OLLM::Config->resolve_request(
  plan => {
    action          => 'build',
    all             => 0,
    dry_run         => 1,
    latexmk_args    => [],
    legacy_args     => ['+standalone'],
    non_interactive => 0,
    rebuild         => 0,
    resolve         => 0,
  },
  start_dir => $chapter,
);
is $standalone->{request}{context}, 'standalone',
  'standalone context is selected explicitly';
is $standalone->{configuration}{kind}, 'none',
  'standalone does not discover a surrounding series manifest implicitly';
is $standalone->{standalone_spec}{context}, 'standalone',
  'standalone resolution produces a new-executor specification';
is $standalone->{standalone_spec}{job_id}, 'main',
  'standalone job name follows the source without imposing a series name';
ok(File::Spec->file_name_is_absolute($standalone->{request}{source}),
  'standalone source is normalized independently of a project manifest');

eval {
  OLLM::Config->resolve_request(
    start_dir       => File::Spec->catdir($fixture, '020-processes'),
    definitions_dir => abs_path('definitions'),
    plan => {
      action => 'build', all => 0, dry_run => 0, latexmk_args => [],
      legacy_args => ['+standalone'], non_interactive => 0, rebuild => 0,
      resolve => 0, source => 'main.tex', target => 'script',
      target_explicit => 1,
    },
  );
};
like $@, qr/document type and language from osglecture class options/,
  'standalone rejects misleading OLLM document selection';

my $invalid = tempdir(CLEANUP => 1);
my $invalid_manifest = File::Spec->catfile($invalid, 'ollmconfig.toml');
open my $invalid_handle, '>', $invalid_manifest or die $!;
print {$invalid_handle} <<'TOML';
schema = 1
bundle_presett = "OSG lecture/1"
bundle_preset = "OSG lecture/1"

[project]
id = "bad"

[languages]
available = ["de"]
default = "de"

[targets.slides]
languages = ["de"]
TOML
close $invalid_handle;
eval { OLLM::Config->load_manifest($invalid_manifest) };
like $@, qr/\Q$invalid_manifest\E:2: unknown key 'bundle_presett'/,
  'semantic manifest errors report their source line';

open my $schema_handle, '>', $invalid_manifest or die $!;
print {$schema_handle} "schema = 9\n";
close $schema_handle;
eval { OLLM::Config->load_manifest($invalid_manifest) };
like $@, qr/:1: unsupported project-manifest schema 9; .* schema 1/,
  'schema mismatch states actual and supported schema';

open my $tex_path_handle, '>', $invalid_manifest or die $!;
print {$tex_path_handle} <<'TOML';
schema = 1
bundle_preset = "OSG lecture/1"

[project]
id = "bad-tex-path"

[project.tex]
directory = "Include"
config = "../projectconfig.tex"

[languages]
available = ["de"]
default = "de"

[targets.slides]
languages = ["de"]
TOML
close $tex_path_handle;
eval { OLLM::Config->load_manifest($invalid_manifest) };
like $@, qr/project[.]tex[.]config must be a filename/,
  'project configuration filename cannot escape the shared TeX directory';

open my $case_handle, '>', $invalid_manifest or die $!;
print {$case_handle} <<'TOML';
schema = 1
bundle_preset = "OSG lecture/1"

[project]
id = "case"

[languages]
available = ["de", "DE"]
default = "de"

[targets.slides]
languages = ["de"]
TOML
close $case_handle;
eval { OLLM::Config->load_manifest($invalid_manifest) };
like $@, qr/languages\.available contains values that collide on case-insensitive/,
  'language identities are portable to case-insensitive filesystems';

open my $missing_handle, '>', $invalid_manifest or die $!;
print {$missing_handle} <<'TOML';
schema = 1
bundle_preset = "OSG lecture/1"

[project]
id = "missing"

[languages]
available = ["de"]
default = "de"

[targets.ghost]
languages = ["de"]
TOML
close $missing_handle;
my $missing_data = OLLM::Config->load_manifest($invalid_manifest);
eval {
  OLLM::Config->resolve_definitions(
    manifest      => $missing_data,
    manifest_path => $invalid_manifest,
    project_root  => $invalid,
    bundle_path   => $definitions,
  );
};
like $@, qr/\Q$invalid_manifest\E:11: target 'ghost' was not found/,
  'unresolved target reports its declaration line';

my $local_root = tempdir(CLEANUP => 1);
my $local_definitions = File::Spec->catdir($local_root, 'project-definitions');
make_path(File::Spec->catdir($local_definitions, 'bundle-presets'));
open my $preset_handle, '>',
  File::Spec->catfile($local_definitions, 'bundle-presets', 'custom.toml')
  or die $!;
print {$preset_handle} <<'TOML';
schema = 1
kind = "bundle-preset"
name = "Descriptive bundle preset"
version = "1"
TOML
close $preset_handle;
open my $local_handle, '>',
  File::Spec->catfile($local_root, '.ollmconfig.local.toml')
  or die $!;
print {$local_handle} <<'TOML';
schema = 1

[definitions]
paths = ["project-definitions"]
TOML
close $local_handle;
my $local_resolution = OLLM::Config->resolve_definitions(
  manifest => {
    bundle_preset => 'Descriptive bundle preset/1',
    targets => { slides => { languages => ['de'] } },
  },
  manifest_path => File::Spec->catfile($local_root, 'ollmconfig.toml'),
  project_root  => $local_root,
  bundle_path   => $definitions,
);
is $local_resolution->{bundle_preset}{reference},
  'Descriptive bundle preset/1',
  'project-relative local definition path resolves a descriptive bundle preset';

my $extended_root = tempdir(CLEANUP => 1);
my $extended_definitions = File::Spec->catdir($extended_root, 'definitions');
my $extended_targets = File::Spec->catdir($extended_definitions, 'targets');
my $extended_unit = File::Spec->catdir($extended_root, '010-opening');
make_path($extended_targets, $extended_unit);
open my $extended_target, '>',
  File::Spec->catfile($extended_targets, 'keynote.toml') or die $!;
print {$extended_target} <<'TOML';
schema = 1
kind = "target"
name = "keynote"
version = "1.0"
doctype = "keynote"
profile_class = "presentation"
document_metadata = "disabled"
TOML
close $extended_target;
open my $extended_local, '>',
  File::Spec->catfile($extended_root, '.ollmconfig.local.toml') or die $!;
print {$extended_local} <<'TOML';
schema = 1

[definitions]
paths = ["definitions"]
TOML
close $extended_local;
open my $extended_manifest, '>',
  File::Spec->catfile($extended_root, 'ollmconfig.toml') or die $!;
print {$extended_manifest} <<'TOML';
schema = 1
bundle_preset = "OSG lecture/1"

[project]
id = "ext"

[languages]
available = ["en"]
default = "en"

[targets.keynote]
languages = ["en"]
TOML
close $extended_manifest;
open my $extended_source, '>',
  File::Spec->catfile($extended_unit, 'main.tex') or die $!;
print {$extended_source} "\\documentclass{osglecture}\n";
close $extended_source;
my $extended = OLLM::Config->resolve_request(
  start_dir       => $extended_unit,
  definitions_dir => $definitions,
  plan => {
    action => 'build', all => 0, dry_run => 1, latexmk_args => [],
    legacy_args => [], non_interactive => 0, rebuild => 0, resolve => 0,
    source => 'main.tex', target => 'keynote', target_explicit => 1,
  },
);
is $extended->{build_spec}{target}, 'keynote',
  'a project-provided target reaches the BuildSpec';
is $extended->{build_spec}{doctype}, 'keynote',
  'an extended target supplies its matching document type';
is $extended->{build_spec}{profile_class}, 'presentation',
  'extended target profile class remains available in the BuildSpec';

open my $mismatched_target, '>',
  File::Spec->catfile($extended_targets, 'mismatch.toml') or die $!;
print {$mismatched_target} <<'TOML';
schema = 1
kind = "target"
name = "mismatch"
version = "1.0"
doctype = "different"
profile_class = "longform"
document_metadata = "disabled"
TOML
close $mismatched_target;
eval {
  OLLM::Config->_load_definition(
    File::Spec->catfile($extended_targets, 'mismatch.toml'),
  );
};
like $@, qr/name 'mismatch' and doctype 'different' differ/,
  'schema 1 rejects a silent target/doctype mismatch';

my $bundle_example = abs_path('../examples/series-minimal');
my $bundle_chapter = File::Spec->catdir($bundle_example, '010-introduction');
my $bundle_manifest = OLLM::Config->find_manifest(start_dir => $bundle_chapter);
is $bundle_manifest->{path},
  File::Spec->catfile($bundle_example, 'ollmconfig.toml'),
  'bundle-level example discovers its project manifest';
my $bundle_data = OLLM::Config->load_manifest($bundle_manifest->{path});
my $bundle_definitions = OLLM::Config->resolve_definitions(
  manifest      => $bundle_data,
  manifest_path => $bundle_manifest->{path},
  project_root  => $bundle_example,
  bundle_path   => $definitions,
);
is $bundle_definitions->{bundle_preset}{reference}, 'OSG lecture/1',
  'bundle-level example resolves its bundled preset';
is $bundle_definitions->{targets}{slides}{document_metadata}, 'disabled',
  'example retains the Beamer target metadata default';
is $bundle_definitions->{targets}{talk}{document_metadata}, 'required',
  'example overrides metadata policy for its ltx-talk target';
my %resolve_manifest = (%$bundle_data,
  build => { resolve => { max_rounds => 3 } },
);
ok(OLLM::Config->validate_manifest(\%resolve_manifest, '<resolve-test>', {}),
  'a positive reference-resolution round limit is accepted');
$resolve_manifest{build}{resolve}{max_rounds} = 0;
eval { OLLM::Config->validate_manifest(\%resolve_manifest, '<resolve-test>', {}) };
like $@, qr/max_rounds must be a positive integer/,
  'a non-positive reference-resolution round limit is rejected';

my $temporary = tempdir(CLEANUP => 1);
open my $toml, '>', File::Spec->catfile($temporary, 'ollmconfig.toml')
  or die $!;
print {$toml} "schema = 1\n";
close $toml;
open my $legacy, '>', File::Spec->catfile($temporary, 'ollmconfig.pl')
  or die $!;
close $legacy;

my $mixed = OLLM::Config->find_manifest(start_dir => $temporary);
is $mixed->{kind}, 'toml', 'TOML wins when both manifest formats exist';
$mixed = OLLM::Config->find_manifest(start_dir => $temporary, legacy => 1);
is $mixed->{kind}, 'legacy', '--legacy explicitly selects the Perl manifest';

my $user_root = tempdir(CLEANUP => 1);
my $user_config = File::Spec->catfile($user_root, 'config.toml');
open my $user_handle, '>', $user_config or die $!;
print {$user_handle} <<'TOML';
schema = 1
bundle_preset = "OSG lecture/1"
TOML
close $user_handle;
{
  local $ENV{OLLM_USER_CONFIG} = $user_config;
  my $user_resolved = OLLM::Config->resolve_request(
    start_dir       => $chapter,
    definitions_dir => $definitions,
    plan => {
      action => 'build',
      all => 0,
      dry_run => 1,
      latexmk_args => [],
      legacy_args => [],
      non_interactive => 0,
      rebuild => 0,
      resolve => 0,
      source => 'main.tex',
      target => 'slides',
    },
  );
  is $user_resolved->{build_spec}{profile_class}, 'presentation',
    'user configuration does not own the TeX document profile';
}

done_testing;
