#!/usr/bin/env perl
# TEMPORARY diagnostic: dumps the raw argv this script actually receives
# (i.e. after cmd.exe's / the shell's own command-line reconstruction) to
# build/test/argv-dump.log, then re-execs the real lualatex with the same
# arguments so the build continues normally. Not meant to stay in the repo.
use strict;
use warnings;
use FindBin;
use File::Spec;
use File::Path qw(make_path);

my $dump_file = File::Spec->catfile(
  $FindBin::Bin, '..', '..', 'build', 'test', 'argv-dump.log',
);
make_path(File::Spec->catdir($FindBin::Bin, '..', '..', 'build', 'test'));

open(my $fh, '>>', $dump_file) or die "cannot open $dump_file: $!";
print {$fh} "ARGC=" . scalar(@ARGV) . "\n";
my $i = 0;
for my $arg (@ARGV) {
  print {$fh} "ARG[$i]=<<<$arg>>>\n";
  $i++;
}
print {$fh} "---END---\n";
close $fh;

exec('lualatex', @ARGV) or die "exec failed: $!";
