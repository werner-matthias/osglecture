use v5.30;
use strict;
use warnings;

use Test::More;

my $version = qx{$^X ollm --version};
is $?, 0, 'version exits successfully';
like $version, qr/^ollm 0\.12\.0-dev/m, 'version is reported';

my $plan = qx{$^X ollm build script --language=en --source=main.tex --dry-run --format=json};
is $?, 0, 'JSON dry-run exits successfully';
like $plan, qr/"schema"\s*:\s*"org\.osglecture\.ollm\.build-request"/,
  'JSON plan has a versioned schema';
like $plan, qr/"target"\s*:\s*"script"/, 'JSON plan contains target';

open my $cmd, '<', 'ollm.cmd' or die "cannot read ollm.cmd: $!";
my $wrapper = do { local $/; <$cmd> };
close $cmd;
like $wrapper, qr/perl "\%~dp0ollm" \%\*/,
  'Windows wrapper delegates to the shared Perl launcher';

done_testing;
