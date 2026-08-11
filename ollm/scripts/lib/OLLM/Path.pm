package OLLM::Path;

use v5.30;
use strict;
use warnings;

use File::Spec;

# All of OLLM's project-root containment checks (build directories, state
# directories, deployment/maintenance targets, the CLI's cwd-vs-root check)
# reduce to the same question: does a path, made relative to a root, stay
# inside that root? This module is the single place that answers it, so a
# future correction to the containment rule only has to happen once.

sub classify {
  my ($path, $root) = @_;
  my $relative = File::Spec->abs2rel($path, $root);
  my $outside = File::Spec->file_name_is_absolute($relative)
    || $relative =~ /\A\.\.(?:[\\\/]|\z)/;
  return ($relative, $outside);
}

sub is_outside {
  my ($path, $root) = @_;
  my (undef, $outside) = classify($path, $root);
  return $outside;
}

sub require_within {
  my ($path, $root, $message) = @_;
  my (undef, $outside) = classify($path, $root);
  die "$message\n" if $outside;
  return;
}

1;
