#!/usr/bin/env perl

# Flags \directlua{...} bodies that rely on TeX catcodes \directlua does not
# actually give them, based on bugs found and fixed by hand repeatedly
# across this bundle (osglecture-series-index.lua, osglecture-manifest.lua,
# tagpax's \tagpaxextract -- see development-docs/ARCHITECTURE.md and the
# git history around each). Two independent mechanisms are involved:
#
# - A bare "#" (Lua's length operator) is TeX's macro-parameter character
#   (catcode 6) under normal LaTeX2e catcodes, regardless of \ExplSyntaxOn.
#   "#1".."#9" are legitimate TeX parameter references and are not flagged.
# - A bare "--" (Lua line comment) or "%" (TeX's own comment character)
#   inside \directlua swallows more than intended: \directlua flattens
#   multiple physical lines into one Lua chunk via TeX's end-of-line
#   handling, so a "--" comment never finds the real newline it needs to
#   stop at, and "%" is consumed by TeX before Lua ever sees it.
# - \ExplSyntaxOn sets space (catcode 32) to catcode 9 (ignored), not 10.
#   Multi-statement Lua ("local x = 1; local y = 2") relies on spaces to
#   separate tokens; under \ExplSyntaxOn those spaces vanish at
#   tokenization time and the code silently becomes invalid Lua. This only
#   applies where \ExplSyntaxOn is actually active at the \directlua call
#   site, so this check is scoped to that state (tracked per file, in
#   document order, starting from \ProvidesExplPackage/\ProvidesExplClass
#   or an explicit \ExplSyntaxOn, ending at the next \ExplSyntaxOff).
#
# The fix in every case found so far was the same: move the multi-statement
# logic into a real .lua file reachable via require(...), and keep the
# \directlua{...} call site itself a single-line, space-free chained
# expression. See osglecture-series.sty's initialize_tex_csv_if_available
# or tagpax.lua's extract_command for worked examples.
#
# This is a heuristic lint, not a Lua or TeX parser: it does not understand
# string literals, so a flagged pattern occurring only inside a Lua string
# is a false positive. Review each hit; do not assume every hit is a bug.

use v5.30;
use strict;
use warnings;

my @files = @ARGV;
if (!@files) {
  print STDERR "usage: $0 <file>...\n";
  exit 2;
}

my $exit = 0;

for my $file (@files) {
  open my $fh, '<', $file or die "cannot open '$file': $!\n";
  local $/;
  my $text = <$fh>;
  close $fh;

  my $expl_on = 0;
  my $scanned = 0;

  while ($text =~ /\G.*?(\\ProvidesExplPackage|\\ProvidesExplClass|\\ExplSyntaxOn|\\ExplSyntaxOff|\\directlua\s*\{)/gcs) {
    my $marker = $1;
    if ($marker eq '\ProvidesExplPackage' || $marker eq '\ProvidesExplClass'
        || $marker eq '\ExplSyntaxOn') {
      $expl_on = 1;
      next;
    }
    if ($marker eq '\ExplSyntaxOff') {
      $expl_on = 0;
      next;
    }

    # $marker is the opening "\directlua{"; find its matching close brace.
    my $body_start = pos($text);
    my $depth = 1;
    my $p = $body_start;
    my $len = length($text);
    while ($depth > 0 && $p < $len) {
      my $ch = substr($text, $p, 1);
      $depth++ if $ch eq '{';
      $depth-- if $ch eq '}';
      $p++;
    }
    my $body = substr($text, $body_start, $p - $body_start - 1);
    my $line = 1 + (substr($text, 0, $body_start) =~ tr/\n//);

    my @problems;
    push @problems, "bare '#' (Lua length operator collides with TeX's "
      . "macro-parameter character)"
      if $body =~ /(?<!\\)#(?!\d)/;
    push @problems, "'--' (Lua comment swallows the rest of the flattened "
      . "\\directlua body, not just its own line)"
      if $body =~ /--/;
    push @problems, "bare '%' (TeX comment character; Lua never sees the "
      . "rest of the line)"
      if $body =~ /(?<!\\)%/;
    if ($expl_on) {
      push @problems, "'local ' under active \\ExplSyntaxOn (space is "
        . "catcode 9/ignored there; multi-statement Lua loses its "
        . "separating spaces)"
        if $body =~ /\blocal\s/;
      push @problems, "';' under active \\ExplSyntaxOn (statement "
        . "separator; same multi-statement risk as 'local ')"
        if $body =~ /;/;
    }

    if (@problems) {
      $exit = 1;
      print "$file:$line: risky \\directlua body"
        . ($expl_on ? " (\\ExplSyntaxOn active)" : "") . "\n";
      print "  - $_\n" for @problems;
    }
    pos($text) = $p;
  }
}

exit $exit;
