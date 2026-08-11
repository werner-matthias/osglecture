package OLLM::Digest;

use v5.30;
use strict;
use warnings;

use Digest::SHA;

sub sha256_hex_of_file {
  my ($path) = @_;
  open my $handle, '<:raw', $path or die "cannot read '$path': $!\n";
  my $digest = Digest::SHA->new(256);
  $digest->addfile($handle);
  close $handle or die "cannot close '$path': $!\n";
  return $digest->hexdigest;
}

1;
