use v5.30;
use strict;
use warnings;

use Test::More;

my $version = qx{$^X scripts/ollm --version};
is $?, 0, 'version exits successfully';
like $version, qr/^ollm 0\.12\.0-dev/m, 'version is reported';

my $plan = qx{$^X scripts/ollm build script --language=en --source=main.tex --dry-run --format=json};
is $?, 0, 'JSON dry-run exits successfully';
like $plan, qr/"schema"\s*:\s*"org\.osglecture\.ollm\.build-request"/,
  'JSON plan has a versioned schema';
like $plan, qr/"target"\s*:\s*"script"/, 'JSON plan contains target';

my $report = qx{$^X scripts/ollm report --project-root=../examples/series-minimal --format=json};
is $?, 0, 'report describes a project with dormant units successfully';
like $report, qr/"schema"\s*:\s*"org\.osglecture\.ollm\.report"/,
  'report JSON has a versioned schema';
like $report, qr/"status"\s*:\s*"dormant"/,
  'report exposes an unused unbuilt unit without failing';

my $check = qx{$^X scripts/ollm check --project-root=../examples/series-minimal --format=json};
is $?, 0, 'series check does not require a dormant unit to be built';
like $check, qr/"schema"\s*:\s*"org\.osglecture\.ollm\.check"/,
  'check JSON has a versioned schema';

open my $cmd, '<', 'scripts/ollm.cmd' or die "cannot read scripts/ollm.cmd: $!";
my $wrapper = do { local $/; <$cmd> };
close $cmd;
like $wrapper, qr/perl "\%~dp0ollm" \%\*/,
  'Windows wrapper delegates to the shared Perl launcher';

done_testing;
