use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use Test::More;

use lib 'scripts/vendor/TOML-Tiny-0.22/lib';
use lib 'scripts/lib';

use OLLM::Config;
use OLLM::LuaManifest;

if (!OLLM::LuaManifest::available()) {
  plan skip_all => 'shared Lua module is not available: '
    . (OLLM::LuaManifest::error() // 'unknown reason');
}

my $fixture = abs_path('testfiles/fixtures/project');

my $info = OLLM::LuaManifest::toml_info();
ok $info->{available}, 'Lua-side TOML parser reports available';
is $info->{name}, 'osglecture-toml', 'Lua-side TOML parser name';
is $info->{standard}, 'TOML 1.0', 'Lua-side TOML parser standard';
ok defined($info->{version}) && length($info->{version}),
  'Lua-side TOML parser reports a version';

my $units = OLLM::LuaManifest::discover_units($fixture);
is scalar(@$units), 1, 'discover_units finds exactly the one series unit';
is $units->[0]{physical_unit}, '020-processes',
  'discover_units reports the correct physical unit';
is $units->[0]{physical_number}, '020', 'discover_units parses the number';
is $units->[0]{unit_scope}, '', 'discover_units parses an empty scope';
is $units->[0]{unit_role}, 'content', 'discover_units defaults the role';
is $units->[0]{slug}, 'processes', 'discover_units parses the slug';

my $perl_structure = OLLM::Config->structure_snapshot(project_root => $fixture);
is_deeply
  [ sort map { $_->{physical_unit} } @{ $perl_structure->{units} } ],
  [ sort map { $_->{physical_unit} } @$units ],
  'Perl structure_snapshot and the Lua module agree on unit names';
for my $field (qw(physical_number unit_scope unit_role slug)) {
  is $perl_structure->{units}[0]{$field}, $units->[0]{$field},
    "Perl and Lua agree on $field";
}

eval { OLLM::LuaManifest::discover_units('/does/not/exist/osglecture-test') };
like $@, qr/\S/, 'discover_units on a missing directory dies with a message';

done_testing;
