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
  action => 'convertconfig', start_dir => $root,
);
ok $result->{converted}, 'convertconfig reports a legacy conversion';
ok -f $result->{path}, 'convertconfig creates ollmconfig.toml';
my $manifest = OLLM::Config->load_manifest($result->{path});
is $manifest->{languages}{default}, 'en', 'legacy default language is converted';
is $manifest->{security}{shell_escape}, 'full', 'legacy shell escape is converted';
is_deeply $manifest->{deployment}{types}{handout}{paths},
  ['Deployment/', 'Archive/'], 'legacy destination lists are converted';
is $manifest->{deployment}{types}{handout}{filename},
  '{series}-{chapter}-{lang}.pdf', 'legacy filename variables are converted';

eval { OLLM::Migration->execute(action => 'newtoml', start_dir => $root) };
like $@, qr/already exists/, 'newtoml does not overwrite an existing manifest';

my $generic = tempdir(CLEANUP => 1);
$result = OLLM::Migration->execute(action => 'newtoml', start_dir => $generic);
ok !$result->{converted}, 'newtoml reports generic generation';
$manifest = OLLM::Config->load_manifest($result->{path});
is $manifest->{languages}{default}, 'de', 'generic manifest has portable defaults';

my $nested = tempdir(CLEANUP => 1);
open $old, '>:raw', File::Spec->catfile($nested, 'ollmconfig.pl') or die $!;
print {$old} "\$defaultlanguage = 'de';\n";
close $old;
my $unit = File::Spec->catdir($nested, '010-introduction');
mkdir $unit or die $!;
$result = OLLM::Migration->execute(action => 'newtoml', start_dir => $unit);
is $result->{path}, File::Spec->catfile(Cwd::abs_path($nested), 'ollmconfig.toml'),
  'newtoml discovers a legacy project from a unit directory';

done_testing;
