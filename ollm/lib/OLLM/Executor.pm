package OLLM::Executor;

use v5.30;
use strict;
use warnings;

use File::Path qw(make_path);
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
  $class->validate_request($resolved);
  my $action = _latexmk_action($request->{latexmk_args});
  @specs = ($specs[0]) if $action eq 'information';

  for my $spec (@specs) {
    die "source file not found: $spec->{source}" if !-f $spec->{source};
    OLLM::BuildFile->write_for_spec($spec) if $action eq 'build';
    make_path($spec->{build_directory}) if $action eq 'clean';
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
    if ($status == -1) {
      print STDERR "ollm: cannot start latexmk: $!\n" if !$arg{runner};
      return 69;
    }
    my $signal = $status & 127;
    if ($signal) {
      print STDERR "ollm: latexmk terminated by signal $signal\n"
        if !$arg{runner} && $signal != 2;
      return 128 + $signal;
    }
    my $exit_code = $status >> 8;
    return $exit_code if $exit_code != 0;
    die "latexmk reported success but artifact is missing: $spec->{artifact}"
      if $action eq 'build' && !$arg{runner} && !-f $spec->{artifact};
  }
  return 0;
}

sub validate_request {
  my ($class, $resolved) = @_;
  my $request = $resolved->{request}
    // die "resolved build request has no request data";
  my $build_count = $resolved->{build_specs}
    ? scalar @{ $resolved->{build_specs} }
    : $resolved->{build_spec} ? 1 : 0;
  die "resolved request contains no concrete build specifications"
    if !$build_count;
  _validate_latexmk_args($request, $build_count);
  return 1;
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
  my ($request, $build_count) = @_;
  my $arguments = $request->{latexmk_args} // [];
  my $action = _latexmk_action($arguments);
  my ($continuous, $continuous_option, $preview, $preview_option, $print);
  my $view = 'default';
  for my $argument (@{ $arguments // [] }) {
    my $option = $argument;
    $option =~ s/\A--/-/;
    die "latexmk option '$argument' is not allowed because additional rc "
      . "files or startup Perl code could override OLLM's engine, paths, "
      . "and security policy\n"
      if $argument =~ /\A--?(?:r|e)(?:=|\z)/;
    die "latexmk option '$argument' selects a non-LuaLaTeX engine or output "
      . "mode; osglecture builds are LuaLaTeX-to-PDF only\n"
      if $argument =~ /\A--?(?:
          dvi(?:lua)?-? | hnt | pdf(?:dvi|ps|xe)?-? |
          ps-? | xdv-? | xelatex
        )\z/x
        || $argument =~ /\A--?(?:
          dvilualatex | latex | output-format | pdflatex | pdfxelatex
        )=/x;
    die "latexmk option '$argument' is not allowed yet because '-out2dir' "
      . "would move the final artifact outside the BuildSpec path; a future "
      . "multi-artifact contract may add explicit support\n"
      if $argument =~ /\A--?out2dir(?:=|\z)/;
    die "latexmk option '$argument' is not allowed because OLLM, rather than "
      . "latexmk's use-make fallback, owns orchestration of missing inputs "
      . "and dependent builds\n"
      if $argument =~ /\A--?use-?make\z/;
    die "latexmk option '$argument' is not allowed because it can inject "
      . "unvalidated options into the controlled LuaLaTeX command\n"
      if $argument =~ /\A--?latexoption(?:=|\z)/;
    die "latexmk option '$argument' conflicts with OLLM's required source "
      . "working directory\n"
      if $argument =~ /\A--?cd-\z/;
    die "latexmk option '$argument' conflicts with OLLM's required recorder "
      . "dependency data\n"
      if $argument =~ /\A--?recorder-\z/;
    die "latexmk option '$argument' conflicts with the controlled build contract\n"
      if $argument =~ /\A--?(?:
        auxdir | aux-directory |
        outdir | output-directory |
        jobname |
        (?:pdf)?lualatex |
        recorder |
        cd |
        e
      )(?:=|\z)/x;
    die "latexmk option '$argument' may not override shell-escape policy\n"
      if $argument =~ /shell-(?:escape|restricted)/;
    if ($option eq '-cc') {
      ($continuous, $continuous_option, $preview, $view)
        = (1, $argument, 0, 'none');
    } elsif ($option eq '-pvc') {
      ($continuous, $continuous_option, $preview, $preview_option)
        = (1, $argument, 1, $argument);
    } elsif ($option eq '-pvc-') {
      $continuous = 0;
    } elsif ($option eq '-pv') {
      ($continuous, $preview, $preview_option) = (0, 1, $argument);
    } elsif ($option eq '-pv-') {
      $preview = 0;
    } elsif ($option =~ /\A-view=(default|dvi|hnt|none|ps|pdf)\z/) {
      $view = $1;
    } elsif ($option eq '-p') {
      $print = 1;
    }
  }
  if ($action ne 'build' && $request->{rebuild}) {
    die "--rebuild requests a document build, but latexmk option "
      . "'" . _action_option($arguments) . "' requests $action instead; "
      . "remove one of the conflicting options\n";
  }
  if ($action eq 'build' && $request->{rebuild} && $continuous) {
    die "--rebuild cannot be combined with latexmk continuous mode "
      . "'$continuous_option' because latexmk disables force mode when "
      . "continuous preview starts; run one rebuild first, then restart "
      . "OLLM in continuous mode\n";
  }
  if ($action eq 'build' && $request->{rebuild}
      && grep { /\A--?g-\z/ } @$arguments) {
    die "--rebuild cannot be combined with latexmk option '-g-', which "
      . "turns off the rebuild mode requested by OLLM\n";
  }
  if ($action eq 'information' && $build_count > 1) {
    die "--all requests multiple target/language builds, but latexmk option "
      . "'" . _action_option($arguments) . "' only reports information; "
      . "run the latexmk information command without --all\n";
  }
  if ($action eq 'information') {
    my @selection = grep { $request->{"${_}_explicit"} }
      qw(target language source);
    if (@selection) {
      die "latexmk option '" . _action_option($arguments) . "' only reports "
        . "information, so the explicit OLLM "
        . join('/', @selection)
        . " selection would not describe a build; remove that selection or "
        . "run latexmk directly\n";
    }
  }
  if ($action ne 'build' && ($continuous || $preview || $print)) {
    die "latexmk option '" . _action_option($arguments) . "' requests "
      . "$action instead of a build and cannot be combined with watch, "
      . "viewer, or print options\n";
  }
  if ($build_count > 1 && $continuous) {
    die "--all cannot be combined with latexmk continuous mode "
      . "'$continuous_option': the first build would keep running and later "
      . "target/language builds would never start; select one build or omit "
      . "$continuous_option\n";
  }
  if ($request->{non_interactive} && $preview && $view ne 'none') {
    die "--non-interactive cannot start the latexmk viewer requested by "
      . "'$preview_option'; use '-view=none' for continuous compilation "
      . "without a viewer, or omit $preview_option\n";
  }
  if ($request->{non_interactive} && $print) {
    die "--non-interactive cannot be combined with latexmk option '-p', "
      . "which starts an external print action\n";
  }
}

sub _latexmk_action {
  my ($arguments) = @_;
  my ($clean, $information);
  for my $argument (@{ $arguments // [] }) {
    $clean = 1 if $argument =~ /\A--?(?:c|C|CA)\z/;
    $information = 1
      if $argument =~ /\A--?(?:commands|dir-report-only|h|help|v|version)\z/;
  }
  return 'information' if $information;
  return 'clean' if $clean;
  return 'build';
}

sub _action_option {
  my ($arguments) = @_;
  my @action = grep {
    /\A--?(?:c|C|CA|commands|dir-report-only|h|help|v|version)\z/
  } @{ $arguments // [] };
  return $action[-1] // '<unknown>';
}

1;
