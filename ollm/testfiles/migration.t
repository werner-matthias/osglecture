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
\date{Winter term}
\SetGlobalClassOptions{aspectratio=169}
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
like join("\n", @{ $result->{warnings} }), qr/require manual conversion/,
  'convertproject warns about unsupported legacy class settings';
like $converted_source, qr/presentation-profile=beamer/,
  'converted project configuration selects the default presentation profile';
like $converted_source, qr/% presentation-profile=ltx-talk/,
  'converted project configuration documents the presentation alternative';
my $manifest = OLLM::Config->load_manifest($result->{path});
is $manifest->{languages}{default}, 'en', 'legacy default language is converted';
ok !exists $manifest->{languages}{map},
  'conversion leaves language-variant mapping to TeX';
is $manifest->{security}{shell_escape}, 'full', 'legacy shell escape is converted';
is $manifest->{project}{tex}{directory}, 'Include',
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
is $manifest->{project}{tex}{config}, 'projectconfig.tex',
  'generic manifest declares the standard project configuration';
ok -d File::Spec->catdir($generic, 'Include'),
  'newproject creates the shared Include directory';
ok -f $result->{project_config_path},
  'newproject creates the standard project configuration';
open my $generic_tex, '<:raw', $result->{project_config_path} or die $!;
my $generic_source = do { local $/; <$generic_tex> };
close $generic_tex;
like $generic_source, qr/\\title\{Course title\}/,
  'newproject supplies dummy project metadata';
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

done_testing;
