use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'vendor/TOML-Tiny-0.22/lib';
use lib 'lib';

use OLLM::Config;

my $fixture = abs_path('testfiles/fixtures/project');
my $chapter = File::Spec->catdir($fixture, '020-processes');
my $manifest_path = File::Spec->catfile($fixture, 'ollmconfig.toml');
my $definitions = abs_path('definitions');

my $located = OLLM::Config->find_manifest(start_dir => $chapter);
is $located->{kind}, 'toml', 'manifest found by upward search';
is $located->{path}, $manifest_path, 'manifest path is canonical';

my $manifest = OLLM::Config->load_manifest($manifest_path);
is $manifest->{schema}, 1, 'schema parsed';
is $manifest->{project}{id}, 'bs', 'project id parsed';
is_deeply $manifest->{languages}{available}, ['de', 'en'],
  'language list parsed';

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
make_path($scoped_unit);
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

my $temporary = tempdir(CLEANUP => 1);
open my $toml, '>', File::Spec->catfile($temporary, 'ollmconfig.toml')
  or die $!;
print {$toml} "schema = 1\n";
close $toml;
open my $legacy, '>', File::Spec->catfile($temporary, 'ollmconfig.pl')
  or die $!;
close $legacy;

eval { OLLM::Config->find_manifest(start_dir => $temporary) };
like $@, qr/both ollmconfig\.toml and ollmconfig\.pl/,
  'mixed legacy and TOML manifests are rejected';

my $user_root = tempdir(CLEANUP => 1);
my $user_config = File::Spec->catfile($user_root, 'config.toml');
open my $user_handle, '>', $user_config or die $!;
print {$user_handle} <<'TOML';
schema = 1
bundle_preset = "OSG lecture/1"

[latex.defaults]
presentation_profile = "ltx-talk"
script_profile = "scrbook"
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
  is $user_resolved->{build_spec}{document_profile}, 'ltx-talk',
    'user defaults select the presentation document profile';
}

done_testing;
