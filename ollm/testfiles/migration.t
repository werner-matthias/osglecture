use v5.30;
use strict;
use warnings;

use Cwd ();
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;
use lib 'scripts/vendor/TOML-Tiny-0.22/lib';
use lib 'scripts/lib';

use OLLM::Config;
use OLLM::Migration;

my $root = tempdir(CLEANUP => 1);
my $legacy = File::Spec->catfile($root, 'ollmconfig.pl');
my $include = File::Spec->catdir($root, 'Include');
mkdir $include or die $!;
open my $dates, '>:raw', File::Spec->catfile($include, 'lectdates.tex') or die $!;
print {$dates} <<'TEX';
% Legacy project metadata
\title{Operating {Systems}}
% \author{Commented Example}
\author [Example] {Nora Example}
\date{\ldeenr{Wintersemester}{Winter term}}
\tucurl[https://example.org]{https://example.org}
\SetGlobalClassOptions{aspectratio=169}
\input{lectspecial}
TEX
close $dates;
open my $old, '>:raw', $legacy or die $!;
print {$old} <<'PL';
$defaultlanguage = 'en';
$shell_escape = 1;
$shared_source_dir = '../Include';
$deploy_path{'handout'} = ['../Deployment/', '../Archive/'];
$deploy_file{'handout'} = '${prefix}-${num}-${lang}';
PL
close $old;

my $result = OLLM::Migration->execute(
  action => 'convertproject', start_dir => $root,
);
ok $result->{converted}, 'convertproject reports a legacy conversion';
ok -f $result->{path}, 'convertproject creates ollmconfig.toml';
ok -f $result->{project_config_path},
  'convertproject creates Include/projectconfig.tex';
open my $converted_tex, '<:raw', $result->{project_config_path} or die $!;
my $converted_source = do { local $/; <$converted_tex> };
close $converted_tex;
like $converted_source, qr/\\title\{Operating \{Systems\}\}/,
  'convertproject preserves nested metadata arguments from lectdates.tex';
like $converted_source, qr/\\author \[Example\] \{Nora Example\}/,
  'convertproject preserves optional metadata arguments from lectdates.tex';
unlike $converted_source, qr/Commented Example/,
  'convertproject does not activate commented legacy metadata';
unlike $converted_source, qr/SetGlobalClassOptions/,
  'convertproject omits unsupported legacy class settings';
unlike $converted_source, qr/^\\tucurl/m,
  'convertproject does not emit \tucurl as an active command';
like $converted_source, qr/^% \\tucurl\[https:/m,
  'convertproject keeps the \tucurl text, commented out';
like $converted_source, qr/\\date\{\\ldeen\{Wintersemester\}\{Winter term\}\}/,
  'convertproject normalizes \ldeenr to \ldeen';
like $converted_source, qr/^\\IncludeOsgLecturePreamble\{lectspecial\}$/m,
  'convertproject converts \input fragments to \IncludeOsgLecturePreamble';
like $converted_source, qr/selectable=\{en,de\}/,
  'convertproject mirrors the manifest language order into projectconfig.tex';
my $converted_warnings = join "\n", @{ $result->{warnings} };
like $converted_warnings, qr/require manual conversion/,
  'convertproject warns about unsupported legacy class settings';
like $converted_warnings, qr/commented out in the converted configuration: \\tucurl/,
  'convertproject reports the commented-out legacy metadata commands';
like $converted_warnings, qr/'\\ldeenr' in .* was rewritten to '\\ldeen'/,
  'convertproject reports the \ldeenr rewrite';
like $converted_warnings, qr/language order does not generate that macro/,
  'convertproject warns that \ldeen is undefined without a de,en language order';
like $converted_warnings, qr/became '\\IncludeOsgLecturePreamble\{lectspecial\}'/,
  'convertproject reports the \input conversion and its timing change';
like $converted_source, qr/presentation-profile=beamer/,
  'converted project configuration selects the default presentation profile';
like $converted_source, qr/% presentation-profile=ltx-talk/,
  'converted project configuration documents the presentation alternative';
my $manifest = OLLM::Config->load_manifest($result->{path});
is $manifest->{languages}{default}, 'en', 'legacy default language is converted';
ok !exists $manifest->{languages}{map},
  'conversion leaves language-variant mapping to TeX';
is $manifest->{security}{shell_escape}, 'full', 'legacy shell escape is converted';
is $manifest->{project}{tex_directory}, 'Include',
  'legacy shared source directory becomes the shared TeX directory';
is_deeply $manifest->{deployment}{types}{handout}{paths},
  ['Deployment/', 'Archive/'], 'legacy destination lists are converted';
is $manifest->{deployment}{types}{handout}{filename},
  '{series}-{chapter}-{lang}.pdf', 'legacy filename variables are converted';

eval { OLLM::Migration->execute(action => 'newproject', start_dir => $root) };
like $@, qr/already exists/, 'newproject does not overwrite an existing manifest';

my $generic = tempdir(CLEANUP => 1);
$result = OLLM::Migration->execute(action => 'newproject', start_dir => $generic);
ok !$result->{converted}, 'newproject reports generic generation';
$manifest = OLLM::Config->load_manifest($result->{path});
is $manifest->{languages}{default}, 'de', 'generic manifest has portable defaults';
is $manifest->{project}{tex_config}, 'projectconfig.tex',
  'generic manifest declares the standard project configuration';
ok -d File::Spec->catdir($generic, 'Include'),
  'newproject creates the shared Include directory';
ok -f $result->{project_config_path},
  'newproject creates the standard project configuration';
open my $generic_tex, '<:raw', $result->{project_config_path} or die $!;
my $generic_source = do { local $/; <$generic_tex> };
close $generic_tex;
like $generic_source, qr/\\title\{\\ldeen\{Kurstitel\}\{Course title\}\}/,
  'newproject supplies bilingual dummy metadata for a de,en manifest';
like $generic_source, qr/\\LectureProjectSetup\{languages=\{selectable=\{de,en\}\}\}/,
  'newproject declares the selectable languages from the manifest';
like $generic_source, qr/longform-profile=scrbook/,
  'newproject selects the default long-form profile';
like $generic_source, qr/% longform-profile=book/,
  'newproject documents the long-form alternative';

my $nested = tempdir(CLEANUP => 1);
open $old, '>:raw', File::Spec->catfile($nested, 'ollmconfig.pl') or die $!;
print {$old} "\$defaultlanguage = 'de';\n";
close $old;
my $unit = File::Spec->catdir($nested, '010-introduction');
mkdir $unit or die $!;
$result = OLLM::Migration->execute(action => 'newproject', start_dir => $unit);
is $result->{path}, File::Spec->catfile(Cwd::abs_path($nested), 'ollmconfig.toml'),
  'newproject discovers a legacy project from a unit directory';

# A shared_source_dir that TeX/Windows cannot handle falls back to Include.
my $awkward = tempdir(CLEANUP => 1);
open $old, '>:raw', File::Spec->catfile($awkward, 'ollmconfig.pl') or die $!;
print {$old} "\$shared_source_dir = 'My Includes';\n";
close $old;
$result = OLLM::Migration->execute(action => 'convertproject', start_dir => $awkward);
my $awkward_manifest = OLLM::Config->load_manifest($result->{path});
is $awkward_manifest->{project}{tex_directory}, 'Include',
  'a non-portable shared_source_dir becomes Include';
like join("\n", @{ $result->{warnings} }), qr/not a portable relative path/,
  'convertproject warns when the legacy source directory is dropped';

# A complete manifest without a projectconfig.tex: keep the manifest, add only
# the missing project configuration.
my $resume = tempdir(CLEANUP => 1);
open my $kept, '>:raw', File::Spec->catfile($resume, 'ollmconfig.toml') or die $!;
print {$kept} <<'TOML';
schema = 2

[project]
id = "resume-me"
tex_directory = "Include"
tex_config = "projectconfig.tex"

[targets.defaults]
languages = ["en", "de"]
default_language = "en"

[targets.slides]
[targets.handout]
[targets.script]
TOML
close $kept;
my $before = do {
  open my $fh, '<:raw', File::Spec->catfile($resume, 'ollmconfig.toml') or die $!;
  local $/; <$fh>;
};
$result = OLLM::Migration->execute(action => 'newproject', start_dir => $resume);
ok $result->{manifest_kept}, 'an intact manifest is reported as kept';
ok !$result->{converted}, 'a kept manifest is not a conversion';
is do {
  open my $fh, '<:raw', $result->{path} or die $!;
  local $/; <$fh>;
}, $before, 'newproject leaves an intact manifest byte-for-byte unchanged';
ok -f $result->{project_config_path},
  'newproject creates the missing projectconfig.tex next to a kept manifest';
open my $resume_tex, '<:raw', $result->{project_config_path} or die $!;
my $resume_source = do { local $/; <$resume_tex> };
close $resume_tex;
like $resume_source, qr/selectable=\{en,de\}/,
  'the added projectconfig.tex mirrors the kept manifest language order';
like join("\n", @{ $result->{warnings} }), qr/kept the existing ollmconfig\.toml/,
  'newproject warns that the manifest was kept';

eval { OLLM::Migration->execute(action => 'newproject', start_dir => $resume) };
like $@, qr/already exists/,
  'newproject still refuses when both files are present';

# A truncated manifest left by an aborted run is replaced.
my $broken = tempdir(CLEANUP => 1);
open my $stub, '>:raw', File::Spec->catfile($broken, 'ollmconfig.toml') or die $!;
print {$stub} "schema = 1\n[project]\nid = \"x\"\n[unterminated\n";
close $stub;
$result = OLLM::Migration->execute(action => 'newproject', start_dir => $broken);
ok !$result->{manifest_kept}, 'a truncated manifest is not kept';
my $repaired = OLLM::Config->load_manifest($result->{path});
is $repaired->{languages}{default}, 'de',
  'the replacement manifest is a valid generic one';
like join("\n", @{ $result->{warnings} }), qr/replaced an incomplete ollmconfig\.toml/,
  'newproject warns that an incomplete manifest was replaced';

done_testing;
