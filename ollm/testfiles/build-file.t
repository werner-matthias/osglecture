use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'vendor/TOML-Tiny-0.22/lib';
use lib 'lib';

use OLLM::BuildFile;
use OLLM::Config;

my $fixture = abs_path('testfiles/fixtures/project');
my $chapter = File::Spec->catdir($fixture, '020-processes');
my $manifest_path = File::Spec->catfile($fixture, 'ollmconfig.toml');
my $manifest = OLLM::Config->load_manifest($manifest_path);
my $resolved = OLLM::Config->resolve_request(
  start_dir       => $chapter,
  definitions_dir => abs_path('definitions'),
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
is_deeply $spec->{language_map}, { de => 'ngerman', en => 'british' },
  'language mapping reaches the build specification';
like $spec->{config_signature}, qr/\A[0-9a-f]{64}\z/,
  'build specification carries a deterministic configuration signature';
is $spec->{shell_escape}, 'restricted',
  'manifest shell-escape policy reaches the build specification';
is $spec->{latex}{theme}, 'osg',
  'bundle-preset LaTeX defaults reach the build specification';
is $spec->{document_profile}, 'scrbook',
  'doctype-specific document profile reaches the build specification';
like $spec->{build_directory},
  qr{[.]osglecture/build/020-processes/script/de\z},
  'build directory is isolated by unit, target, and language';
is $spec->{aux_directory}, $spec->{build_directory},
  'auxiliary state stays inside the isolated build directory';
is $spec->{artifact},
  File::Spec->catfile($spec->{build_directory}, "$spec->{job_id}.pdf"),
  'artifact path is explicit';

my $content = OLLM::BuildFile->render($spec);
like $content, qr/job-id=\{bs-020-script-de-processes\}/,
  'rendered build file binds itself to the job id';
like $content, qr/theme=\{osg\}/,
  'rendered build file contains effective LaTeX defaults';
like $content, qr/document-profile=\{scrbook\}/,
  'rendered build file contains the resolved document profile';
like $content, qr/bundle-preset=\{OSG lecture\/1\}/,
  'rendered build file contains the resolved bundle preset';
like $content, qr/shell-escape=\{restricted\}/,
  'rendered build file records the shell-escape policy';

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
print {$document_handle} <<'TEX';
\documentclass{article}
\usepackage{osglecture-config}
\OsgLectureLoadBuildFileForJob
\begin{document}
\typeout{OSGTEST:doctype=\OsgLectureBuildValue{doctype}}
\typeout{OSGTEST:document-profile=\OsgLectureBuildValue{document-profile}}
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
like $log, qr/OSGTEST:document-profile=scrbook/,
  'LaTeX receives the resolved document profile';
like $log, qr/OSGTEST:language=de/, 'LaTeX receives the language';

done_testing;
