package OLLM::LuaManifest;

use v5.30;
use strict;
use warnings;

use File::Spec;

# Bridge to the shared Lua module (osglecture-manifest.lua /
# osglecture-series-index.lua, see osglecture/ARCHITECTURE.md section 12):
# reads project content and does directory discovery through the same
# implementation osglecture itself uses at compile time, instead of a
# second, independently maintained Perl parser. Every public function here
# shells out to texlua; none of them re-implement TOML or the series-unit
# directory grammar.

my $CLI_SCRIPT_NAME = 'osglecture-manifest-cli.lua';

my $TEXLUA_PATH;
my $CLI_SCRIPT_PATH;
my $LOOKUP_ERROR;

sub _find_texlua {
  return $TEXLUA_PATH if defined $TEXLUA_PATH;
  require OLLM::CLI;
  $TEXLUA_PATH = OLLM::CLI::_find_program('texlua') // '';
  return $TEXLUA_PATH;
}

sub _find_cli_script {
  return $CLI_SCRIPT_PATH if defined $CLI_SCRIPT_PATH;
  my $kpsewhich = OLLM::CLI::_find_program('kpsewhich');
  if ($kpsewhich) {
    my $path = qx{$kpsewhich $CLI_SCRIPT_NAME 2>/dev/null};
    chomp $path;
    if ($path) {
      $CLI_SCRIPT_PATH = $path;
      return $CLI_SCRIPT_PATH;
    }
  }
  # Development fallback: this file's own bundle ships osglecture as a
  # sibling directory, so the script is reachable without an installed
  # TDS tree. A real installation is expected to resolve via kpsewhich
  # above instead.
  my $sibling = File::Spec->catfile(
    File::Spec->updir, 'osglecture', $CLI_SCRIPT_NAME,
  );
  $CLI_SCRIPT_PATH = -f $sibling ? File::Spec->rel2abs($sibling) : '';
  return $CLI_SCRIPT_PATH;
}

sub available {
  $LOOKUP_ERROR = undef;
  my $texlua = _find_texlua();
  if (!$texlua) {
    $LOOKUP_ERROR = 'texlua was not found on PATH';
    return 0;
  }
  my $script = _find_cli_script();
  if (!$script) {
    $LOOKUP_ERROR = "$CLI_SCRIPT_NAME was not found "
      . '(neither via kpsewhich nor as a sibling of the OLLM installation)';
    return 0;
  }
  return 1;
}

sub error {
  return $LOOKUP_ERROR;
}

# Runs "texlua <cli-script> <command> <args...>" and returns its stdout
# split into lines, each further split on tab (the CLI script's TSV
# convention). Dies with the subprocess's stderr on a non-zero exit.
sub _run {
  my (@args) = @_;
  die "$LOOKUP_ERROR\n" if !available();
  my @command = (_find_texlua(), _find_cli_script(), @args);
  my $output = qx{@{[ join ' ', map { quotemeta } @command ]} 2>&1};
  my $status = $? >> 8;
  if ($status != 0) {
    chomp $output;
    die "osglecture-manifest-cli.lua failed: $output\n";
  }
  my @lines = split /\n/, $output;
  return [ map { [ split /\t/, $_ ] } @lines ];
}

sub toml_info {
  my $rows = eval { _run('toml-info') };
  if (!$rows) {
    my $error = $@ || 'unknown error'; chomp $error;
    return { available => 0, error => $error, name => 'osglecture-toml',
      version => undef, source => undef, standard => 'TOML 1.0' };
  }
  my ($name, $version, $source) = @{ $rows->[0] };
  return { available => 1, error => undef, name => $name,
    version => $version, source => $source, standard => 'TOML 1.0' };
}

# Returns a list of unit hashes shaped like
# OLLM::Config::structure_snapshot's own "units" entries, so callers can
# compare the two directly.
sub discover_units {
  my ($project_root) = @_;
  my $rows = _run('discover-units', $project_root);
  return [ map {
    my ($physical_unit, $physical_number, $unit_scope, $unit_role, $slug) = @$_;
    {
      physical_unit   => $physical_unit,
      physical_number => $physical_number,
      unit_scope      => $unit_scope,
      unit_role       => $unit_role,
      slug            => $slug,
    }
  } @$rows ];
}

1;
