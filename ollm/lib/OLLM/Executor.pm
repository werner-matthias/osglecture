package OLLM::Executor;

use v5.30;
use strict;
use warnings;

use File::Spec;
use OLLM::BuildFile;

our $VERSION = '0.1.0';

sub execute {
  my ($class, %arg) = @_;
  my $resolved = $arg{resolved} // die "missing resolved build request";
  my $latexmk_rc = $arg{latexmk_rc};
  die "latexmk configuration not found: $latexmk_rc"
    if defined($latexmk_rc) && !-f $latexmk_rc;
  my $request = $resolved->{request};
  my @specs = $resolved->{build_specs}
    ? @{ $resolved->{build_specs} }
    : $resolved->{build_spec}
      ? ($resolved->{build_spec})
      : die "resolved request contains no concrete build specifications";
  _validate_latexmk_args($request->{latexmk_args});

  for my $spec (@specs) {
    die "source file not found: $spec->{source}" if !-f $spec->{source};
    OLLM::BuildFile->write_for_spec($spec);
    my @command = $class->command_for_spec($spec, $request, $latexmk_rc);
    my $status;
    if ($arg{runner}) {
      $status = $arg{runner}->(\@command, $spec);
    } else {
      my $separator = $^O eq 'MSWin32' ? ';' : ':';
      local $ENV{TEXINPUTS} = $spec->{build_directory} . $separator
        . ($ENV{TEXINPUTS} // '');
      $status = system { $command[0] } @command;
    }
    return 69 if $status == -1;
    return $status >> 8 if $status != 0;
    die "latexmk reported success but artifact is missing: $spec->{artifact}"
      if !$arg{runner} && !-f $spec->{artifact};
  }
  return 0;
}

sub command_for_spec {
  my ($class, $spec, $request, $latexmk_rc) = @_;
  my %shell_option = (
    off        => '--no-shell-escape',
    restricted => '--shell-restricted',
    full       => '--shell-escape',
  );
  my $shell = $shell_option{$spec->{shell_escape}}
    // die "unknown shell-escape policy '$spec->{shell_escape}'";
  my $engine = join ' ',
    'lualatex',
    $shell,
    '--synctex=1',
    '--interaction=nonstopmode',
    '--halt-on-error',
    '%O',
    '%S';
  return (
    'latexmk',
    '-norc',
    (defined($latexmk_rc) ? ('-r', $latexmk_rc) : ()),
    '-lualatex',
    '-recorder',
    '-cd',
    "-jobname=$spec->{job_id}",
    "-outdir=$spec->{build_directory}",
    "-auxdir=$spec->{aux_directory}",
    "-pdflualatex=$engine",
    ($request->{rebuild} ? ('-gg') : ()),
    @{ $request->{latexmk_args} // [] },
    $spec->{source},
  );
}

sub _validate_latexmk_args {
  my ($arguments) = @_;
  for my $argument (@{ $arguments // [] }) {
    die "latexmk option '$argument' conflicts with the controlled build contract"
      if $argument =~ /\A--?(?:
        auxdir | aux-directory |
        outdir | output-directory |
        jobname |
        (?:pdf)?lualatex |
        recorder |
        cd |
        e
      )(?:=|\z)/x;
    die "latexmk option '$argument' may not override shell-escape policy"
      if $argument =~ /shell-(?:escape|restricted)/;
  }
}

1;
