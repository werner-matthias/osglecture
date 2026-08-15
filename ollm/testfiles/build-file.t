use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Spec;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Test::More;

use lib 'scripts/vendor/TOML-Tiny-0.22/lib';
use lib 'scripts/lib';

use OLLM::BuildFile;
use OLLM::Config;

my $fixture = abs_path('testfiles/fixtures/project');
my $chapter = File::Spec->catdir($fixture, '020-processes');
my $manifest_path = File::Spec->catfile($fixture, 'ollmconfig.toml');
my $manifest = OLLM::Config->load_manifest($manifest_path);
my $resolved = OLLM::Config->resolve_request(
  start_dir       => $chapter,
  definitions_dir => abs_path('scripts/definitions'),
  plan => {
    action          => 'build',
    all             => 0,
    dry_run         => 1,
    latexmk_args    => [],
    legacy_args     => [],
    non_interactive => 1,
    rebuild         => 0,
    resolve         => 0,
    source          => 'main.tex',
    target          => 'script',
  },
);

my $spec = OLLM::BuildFile->build_spec(
  resolved       => $resolved,
  manifest       => $manifest,
  unit_directory => $chapter,
);
is $spec->{job_id}, 'bs-020-script-de-processes',
  'job id follows the series identity grammar';
is $spec->{unit_role}, 'content', 'omitted role becomes content';
like $spec->{config_signature}, qr/\A[0-9a-f]{64}\z/,
  'build specification carries a deterministic configuration signature';
like $spec->{structure_signature}, qr/\A[0-9a-f]{64}\z/,
  'build specification carries the canonical project-structure signature';
is $spec->{shell_escape}, 'restricted',
  'manifest shell-escape policy reaches the build specification';
is $spec->{profile_class}, 'longform',
  'target profile class reaches the build specification';
is $spec->{document_metadata_policy}, 'required',
  'project target overrides the definition metadata policy';
is $spec->{shared_tex_directory},
  abs_path(File::Spec->catdir($fixture, 'Include')),
  'shared TeX directory is resolved from the project manifest';
is $spec->{project_config_file}, 'projectconfig.tex',
  'project configuration filename reaches the build specification';
like $spec->{project_config_signature}, qr/\A[0-9a-f]{64}\z/,
  'project configuration contents are signed into the build contract';
like $spec->{build_directory},
  qr{[.]osglecture[\\/]build[\\/]020-processes[\\/]script[\\/]de\z},
  'build directory is isolated by unit, target, and language';
is $spec->{aux_directory}, $spec->{build_directory},
  'auxiliary state stays inside the isolated build directory';
is $spec->{artifact},
  File::Spec->catfile($spec->{build_directory}, "$spec->{job_id}.pdf"),
  'artifact path is explicit';

my $ordinal_units = [
  { physical_unit => '010-first', unit_scope => '', unit_role => 'content' },
  { physical_unit => '011-e-first', unit_scope => '', unit_role => 'e' },
  { physical_unit => '012-e-second', unit_scope => '', unit_role => 'e' },
  { physical_unit => '020-second', unit_scope => '', unit_role => 'content' },
  { physical_unit => '090-a-one', unit_scope => '', unit_role => 'a' },
  { physical_unit => '091-a-two', unit_scope => '', unit_role => 'a' },
  { physical_unit => '099-i-all', unit_scope => '', unit_role => 'i' },
];
is(OLLM::BuildFile::_logical_ordinal($ordinal_units, '010-first', []), 1,
  'content receives the next regular ordinal');
is(OLLM::BuildFile::_logical_ordinal($ordinal_units, '011-e-first', []), '1e1',
  'first excursus is attached to its preceding content ordinal');
is(OLLM::BuildFile::_logical_ordinal($ordinal_units, '012-e-second', []), '1e2',
  'excursuses have a local sequence');
is(OLLM::BuildFile::_logical_ordinal($ordinal_units, '090-a-one', []), '3ap1',
  'first appendix continues the regular ordinal and adds its local sequence');
is(OLLM::BuildFile::_logical_ordinal($ordinal_units, '091-a-two', []), '4ap2',
  'later appendices continue both sequences');
is(OLLM::BuildFile::_logical_ordinal($ordinal_units, '099-i-all', []), '',
  'integration has no ordinal');

is $spec->{document_metadata}{path},
  abs_path(File::Spec->catfile(
    $fixture, 'Include', 'documentmetadata.tex',
  )),
  'conventional document metadata file is discovered in shared TeX';
like $spec->{document_metadata}{signature}, qr/\A[0-9a-f]{64}\z/,
  'document metadata contents are signed into the build contract';

my $slides_resolved = OLLM::Config->resolve_request(
  start_dir       => $chapter,
  definitions_dir => abs_path('scripts/definitions'),
  plan => {
    action => 'build', all => 0, dry_run => 1, latexmk_args => [],
    legacy_args => [], non_interactive => 1, rebuild => 0, resolve => 0,
    source => 'main.tex', target => 'slides',
  },
);
is $slides_resolved->{build_spec}{document_metadata_policy}, 'disabled',
  'target-definition metadata policy applies without a project override';
ok !defined($slides_resolved->{build_spec}{document_metadata}),
  'disabled policy does not preload an existing project metadata file';

my @moved_specs;
for (1 .. 2) {
  my $moved_root = tempdir(CLEANUP => 1);
  my $moved_unit = File::Spec->catdir($moved_root, '020-processes');
  my $moved_shared = File::Spec->catdir($moved_root, 'Include');
  make_path($moved_unit, $moved_shared);
  open my $moved_source, '>',
    File::Spec->catfile($moved_unit, 'main.tex') or die $!;
  print {$moved_source} "\\documentclass{article}\n";
  close $moved_source;
  open my $moved_metadata, '>',
    File::Spec->catfile($moved_shared, 'documentmetadata.tex') or die $!;
  print {$moved_metadata}
    "\\DocumentMetadata{lang=\\OsgLectureRequestedLanguage}\n";
  close $moved_metadata;
  open my $moved_config, '>',
    File::Spec->catfile($moved_shared, 'projectconfig.tex') or die $!;
  print {$moved_config}
    "\\author<presentation>[M.~Mustermann]{Max Mustermann}\n";
  close $moved_config;

  my %moved_request = (
    %{ $resolved->{request} },
    project_root => $moved_root,
  );
  my %moved_configuration = (
    %{ $resolved->{configuration} },
    structure => OLLM::Config->structure_snapshot(
      project_root => $moved_root,
    ),
  );
  my %moved_resolved = (
    %$resolved,
    request       => \%moved_request,
    configuration => \%moved_configuration,
  );
  push @moved_specs, OLLM::BuildFile->build_spec(
    resolved       => \%moved_resolved,
    manifest       => $manifest,
    unit_directory => $moved_unit,
  );
}
is $moved_specs[0]{config_signature}, $moved_specs[1]{config_signature},
  'moving an otherwise identical project does not change its build contract';

my $content = OLLM::BuildFile->render($spec);
like $content, qr/job-id=\{bs-020-script-de-processes\}/,
  'rendered build file binds itself to the job id';
like $content, qr/profile-class=\{longform\}/,
  'rendered build file contains only the target profile class';
like $content, qr/document-metadata-policy=\{required\}/,
  'rendered build file contains the effective early metadata policy';
like $content, qr/shared-tex-directory=\{[^}]*Include\}/,
  'rendered build file contains the absolute shared TeX directory';
like $content, qr/project-config-file=\{projectconfig[.]tex\}/,
  'rendered build file contains the project configuration filename';
like $content, qr/bundle-preset=\{OSG lecture\/1\}/,
  'rendered build file contains the resolved bundle preset';
like $content, qr/shell-escape=\{restricted\}/,
  'rendered build file records the shell-escape policy';
like $content, qr/structure-signature=\{[0-9a-f]{64}\}/,
  'rendered build file makes directory-structure changes visible to TeX';

my $outside = tempdir(CLEANUP => 1);
my $outside_unit = File::Spec->catdir($outside, '020-outside');
mkdir $outside_unit or die $!;
open my $outside_source, '>',
  File::Spec->catfile($outside_unit, 'main.tex') or die $!;
print {$outside_source} "\\documentclass{article}\n";
close $outside_source;
eval {
  OLLM::BuildFile->build_spec(
    resolved       => $resolved,
    manifest       => $manifest,
    unit_directory => $outside_unit,
  );
};
like $@, qr/series unit directory .* is outside project root/,
  'series build rejects a unit outside its canonical project root';

my $temporary = tempdir(CLEANUP => 1);
my $build_file = File::Spec->catfile(
  $temporary, "$spec->{job_id}.osgbuild.tex",
);
is(OLLM::BuildFile->write_atomic($build_file, $content), 1,
  'first build-file write replaces the target');
is(OLLM::BuildFile->write_atomic($build_file, $content), 0,
  'unchanged build file is not replaced');

my $document = File::Spec->catfile($temporary, 'integration.tex');
open my $document_handle, '>', $document or die $!;
my $manifest_file = $spec->{project_manifest};
$manifest_file =~ s{\\}{/}g;
my $job_file = $build_file;
$job_file =~ s{\\}{/}g;
print {$document_handle}
  "\\edef\\OSGLectureProjectManifestFile{\\detokenize{$manifest_file}}\n",
  "\\edef\\OSGLectureJobFile{\\detokenize{$job_file}}\n";
print {$document_handle} <<'TEX';
\documentclass{article}
\usepackage{osglecture-config}
\OsgLectureLoadBuildFileForJob
\begin{document}
\typeout{OSGTEST:doctype=\OsgLectureBuildValue{doctype}}
\typeout{OSGTEST:profile-class=\OsgLectureBuildValue{profile-class}}
\typeout{OSGTEST:language=\OsgLectureBuildValue{language}}
Configuration bridge.
\end{document}
TEX
close $document_handle;

my $old_directory = getcwd();
chdir $temporary or die "cannot enter $temporary: $!";
local $ENV{TEXINPUTS} = abs_path(File::Spec->catdir($old_directory, '..', 'osglecture')) . ':';
local $ENV{TEXMFVAR} = $ENV{TEXMFVAR} // '/tmp/osglecture-texmfvar.RxNSOL';
open my $tex_output, '>', File::Spec->catfile($temporary, 'lualatex.out')
  or die $!;
my $status;
{
  local *STDOUT;
  local *STDERR;
  open STDOUT, '>&', $tex_output or die $!;
  open STDERR, '>&', $tex_output or die $!;
  $status = system(
    'lualatex',
    '-interaction=nonstopmode',
    '-halt-on-error',
    "-jobname=$spec->{job_id}",
    'integration.tex',
  );
}
close $tex_output;
chdir $old_directory or die "cannot return to $old_directory: $!";
is $status, 0, 'LuaLaTeX reads the generated build file';

open my $log_handle, '<',
  File::Spec->catfile($temporary, "$spec->{job_id}.log")
  or die $!;
local $/;
my $log = <$log_handle>;
close $log_handle;
like $log, qr/OSGTEST:doctype=script/, 'LaTeX receives the document type';
like $log, qr/OSGTEST:profile-class=longform/,
  'LaTeX receives the target profile class';
like $log, qr/OSGTEST:language=de/, 'LaTeX receives the language';

done_testing;
