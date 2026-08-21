use v5.30;
use strict;
use warnings;

use Cwd ();
use File::Temp ();
use Test::More;

use lib 'scripts/vendor/TOML-Tiny-0.22/lib';
use lib 'scripts/lib';

require OLLM::Version;

my $version = qx{$^X scripts/ollm --version};
is $?, 0, 'version exits successfully';
like $version, qr/^ollm \Q$OLLM::Version::VERSION\E/m, 'version is reported';

my $outside = File::Temp::tempdir(CLEANUP => 1);
my $launcher = Cwd::abs_path('scripts/ollm');
my $previous_directory = Cwd::getcwd();
chdir $outside or die "cannot enter temporary directory $outside: $!";
my $outside_output = qx{$^X "$launcher" 2>&1};
my $outside_status = $? >> 8;
chdir $previous_directory
  or die "cannot restore working directory $previous_directory: $!";
is $outside_status, 2, 'a build outside a project is rejected as a usage error';
like $outside_output, qr/no ollmconfig[.]toml project found/,
  'the diagnostic explains how to select a project or standalone mode';
unlike $outside_output, qr/Legacy Mode/,
  'a missing project never enters legacy mode implicitly';

open my $standalone_source, '>', "$outside/main.tex"
  or die "cannot create standalone test source: $!";
print {$standalone_source} "\\documentclass{article}\n\\begin{document}\n\\end{document}\n";
close $standalone_source;
chdir $outside or die "cannot enter temporary directory $outside: $!";
my $standalone_output = qx{$^X "$launcher" standalone --dry-run main.tex 2>&1};
my $standalone_status = $? >> 8;
chdir $previous_directory
  or die "cannot restore working directory $previous_directory: $!";
is $standalone_status, 0,
  'explicit standalone mode remains available outside a project';
like $standalone_output, qr/^Context:\s+standalone$/m,
  'the explicit standalone invocation has standalone context';
unlike $standalone_output, qr/Legacy Mode/,
  'standalone mode is not reported as legacy mode';

require OLLM::State;
is $OLLM::State::VERSION, $OLLM::Version::VERSION,
  'internal modules use the central OLLM program version';

my $standalone_fixture =
  Cwd::abs_path('testfiles/fixtures/project/020-processes/main.tex');
my $plan = qx{$^X scripts/ollm standalone build --source="$standalone_fixture" --dry-run --format=json};
is $?, 0, 'JSON dry-run exits successfully';
like $plan, qr/"schema"\s*:\s*"org\.osglecture\.ollm\.build-request"/,
  'JSON plan has a versioned schema';
like $plan, qr/"target"\s*:\s*"slides"/, 'JSON plan contains default target';

my $dormant_project = Cwd::abs_path('testfiles/fixtures/project');
my $report = qx{$^X scripts/ollm report --project-root="$dormant_project" --format=json};
is $?, 0, 'report describes a project with dormant units successfully';
like $report, qr/"schema"\s*:\s*"org\.osglecture\.ollm\.report"/,
  'report JSON has a versioned schema';
like $report, qr/"status"\s*:\s*"dormant"/,
  'report exposes an unused unbuilt unit without failing';

my $check = qx{$^X scripts/ollm check --project-root="$dormant_project" --format=json};
is $?, 0, 'series check does not require a dormant unit to be built';
like $check, qr/"schema"\s*:\s*"org\.osglecture\.ollm\.check"/,
  'check JSON has a versioned schema';

my $doctor = qx{$^X scripts/ollm doctor --format=json};
like $doctor, qr/"schema"\s*:\s*"org\.osglecture\.ollm\.doctor"/,
  'doctor always emits its versioned JSON result even when a tool is missing';
like $doctor, qr/"tex_files"\s*:/,
  'doctor reports TeX package discovery';
like $doctor, qr/"runtime"\s*:/,
  'doctor verifies LuaLaTeX by compiling a probe';
like $doctor, qr/"capabilities"\s*:/,
  'doctor reports optional integrations separately';
like $doctor, qr/"name"\s*:\s*"ltx-talk-adapter"/,
  'doctor isolates the optional ltx-talk adapter';
like $doctor, qr/"package"\s*:\s*"newcomputermodern"/,
  'doctor provides TeX Live package names for repair';
like $doctor, qr/"project"\s*:/,
  'doctor distinguishes global and project-aware checks';

open my $cmd, '<', 'scripts/ollm.cmd' or die "cannot read scripts/ollm.cmd: $!";
my $wrapper = do { local $/; <$cmd> };
close $cmd;
like $wrapper, qr/perl "\%~dp0ollm" \%\*/,
  'Windows wrapper delegates to the shared Perl launcher';

open my $legacy, '<', 'scripts/ollm-legacy.rc'
  or die "cannot read scripts/ollm-legacy.rc: $!";
my $legacy_source = do { local $/; <$legacy> };
close $legacy;
like $legacy_source,
  qr/OLLM Version \$ollm_version, Legacy Mode, Version \$VERSION/,
  'legacy greeting distinguishes the OLLM and legacy-engine versions';

done_testing;
