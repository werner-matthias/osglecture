use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'scripts/vendor/TOML-Tiny-0.22/lib';
use lib 'scripts/lib';

use OLLM::Config;
use TOML::Tiny::Parser;

# The profile TOMLs under scripts/definitions/profiles are a hand-maintained
# projection of \DeclareOsgLectureProfile in osglecture-profiles.dtx. This test
# is the guard against the two drifting apart.

my $profiles_dir = abs_path('scripts/definitions/profiles');
ok -d $profiles_dir, 'profile definitions directory exists';

my %toml;
for my $file (glob "$profiles_dir/*.toml") {
  open my $fh, '<:raw', $file or die $!;
  local $/;
  my $parsed = TOML::Tiny::Parser->new(strict => 1)->parse(<$fh>);
  close $fh;
  is $parsed->{kind}, 'profile', "$file declares kind = profile";
  $toml{ $parsed->{name} } = $parsed;
}

my $dtx = abs_path('../osglecture/osglecture-profiles.dtx');
ok -f $dtx, 'osglecture-profiles.dtx is reachable from the OLLM module';
open my $dtx_handle, '<:raw', $dtx or die $!;
my $dtx_source = do { local $/; <$dtx_handle> };
close $dtx_handle;

my %def;
while ($dtx_source =~ /\\DeclareOsgLectureProfile\{([^}]+)\}\s*\{(.*?)\n\s*\}/gs) {
  my ($name, $body) = ($1, $2);
  my %field;
  $field{'document-metadata'} = $1
    if $body =~ /document-metadata\s*=\s*([a-z-]+)/;
  $field{doctypes} = [ split /\s*,\s*/, $1 ]
    if $body =~ /doctypes\s*=\s*\{([^}]*)\}/;
  $field{capabilities} = [ split /\s*,\s*/, $1 ]
    if $body =~ /capabilities\s*=\s*\{([^}]*)\}/;
  $def{$name} = \%field;
}

is_deeply [ sort keys %toml ], [ sort keys %def ],
  'every declared profile has a TOML projection and vice versa';

for my $name (sort keys %def) {
  my $t = $toml{$name} or next;
  is $t->{document_metadata}, $def{$name}{'document-metadata'},
    "$name: document_metadata matches the class declaration";
  is_deeply [ sort @{ $t->{doctypes} } ], [ sort @{ $def{$name}{doctypes} } ],
    "$name: doctypes match the class declaration";
  my ($class) = grep { $_ eq 'presentation' || $_ eq 'longform' }
    @{ $def{$name}{capabilities} };
  is $t->{profile_class}, $class,
    "$name: profile_class matches the class capability";
}

# resolve_definitions exposes the projection for later build resolution.
my $fixture = abs_path('testfiles/fixtures/project');
my $manifest = OLLM::Config->load_manifest(
  File::Spec->catfile($fixture, 'ollmconfig.toml'),
);
my $resolved = OLLM::Config->resolve_definitions(
  manifest      => $manifest,
  manifest_path => File::Spec->catfile($fixture, 'ollmconfig.toml'),
  project_root  => $fixture,
  bundle_path   => abs_path('scripts/definitions'),
);
is ref $resolved->{profiles}, 'HASH', 'resolved definitions carry profiles';
is $resolved->{profiles}{'ltx-talk'}{document_metadata}, 'required',
  'ltx-talk profile projection is resolved';
is_deeply $resolved->{profiles}{beamer}{doctypes}, ['slides', 'handout'],
  'beamer profile doctypes are resolved';

done_testing;
