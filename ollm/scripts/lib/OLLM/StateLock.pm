package OLLM::StateLock;

use v5.30;
use strict;
use warnings;

use Fcntl qw(:flock);
use File::Path qw(make_path);
use File::Spec;

# State.pm and Maintenance.pm both serialize access to a project's
# .osglecture/.state.lock file: State writes/promotes build results while
# Maintenance cleans them, and neither may run while the other holds it.

sub acquire {
  my ($root) = @_;
  my $directory = File::Spec->catdir($root, '.osglecture');
  make_path($directory);
  my $path = File::Spec->catfile($directory, '.state.lock');
  open my $handle, '>>', $path
    or die "cannot open OLLM state lock '$path': $!\n";
  flock($handle, LOCK_EX)
    or die "cannot lock OLLM state '$path': $!\n";
  return $handle;
}

1;
