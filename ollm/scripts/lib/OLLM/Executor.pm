package OLLM::Executor;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use Errno qw(EAGAIN EWOULDBLOCK);
use Fcntl qw(:flock);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use OLLM::BuildFile;
use OLLM::State;
use OLLM::Version qw($VERSION);

sub execute {
  my ($class, %arg) = @_;
  my $resolved = $arg{resolved} // die "missing resolved build request";
  my $latexmk_rc = $arg{latexmk_rc};
  die "latexmk configuration not found: $latexmk_rc"
    if defined($latexmk_rc) && !-f $latexmk_rc;
  my $request = $resolved->{request};
  if ($request->{context} eq 'standalone') {
    return $class->_execute_standalone(
      $resolved, $latexmk_rc, $arg{runner},
    );
  }
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
    my $lock;
    if ($action ne 'information') {
      _prepare_build_directory($spec);
      $lock = _acquire_lock($spec);
      if (!$lock) {
        print STDERR "ollm: build '$spec->{job_id}' is already active in "
          . "$spec->{build_directory}\n";
        return 1;
      }
    }
    if ($action eq 'build') {
      OLLM::State->start_attempt($spec);
      OLLM::BuildFile->write_for_spec($spec);
    }
    my @command = $class->command_for_spec($spec, $request, $latexmk_rc);
    my $separator = $^O eq 'MSWin32' ? ';' : ':';
    local $ENV{TEXINPUTS} = join $separator,
      $spec->{build_directory},
      $spec->{shared_tex_directory},
      ($ENV{TEXINPUTS} // '');
    my $status;
    if ($arg{runner}) {
      $status = $arg{runner}->(\@command, $spec);
    } else {
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
    return 1 if $exit_code != 0;
    die "latexmk reported success but artifact is missing: $spec->{artifact}"
      if $action eq 'build' && !$arg{runner}
        && (!-f $spec->{artifact} || !-s _);
    OLLM::State->promote($spec)
      if $action eq 'build' && !$arg{runner};
  }
  return 0;
}

sub validate_request {
  my ($class, $resolved) = @_;
  my $request = $resolved->{request}
    // die "resolved build request has no request data";
  my $build_count = $request->{context} eq 'standalone' ? 1
    : $resolved->{build_specs}
    ? scalar @{ $resolved->{build_specs} }
    : $resolved->{build_spec} ? 1 : 0;
  die "resolved request contains no concrete build specifications"
    if !$build_count;
  if ($request->{context} eq 'standalone') {
    die "resolved standalone request has no execution specification"
      if !$resolved->{standalone_spec};
    _validate_latexmk_args($request, 1, standalone => 1);
    return 1;
  }
  my $path_separator = $^O eq 'MSWin32' ? ';' : ':';
  my @specs = $resolved->{build_specs}
    ? @{ $resolved->{build_specs} }
    : ($resolved->{build_spec});
  for my $spec (@specs) {
    for my $field (qw(source shared_tex_directory build_directory
                      aux_directory artifact)) {
      my $path = $spec->{$field};
      die "BuildSpec $field path contains a line break: $path\n"
        if $path =~ /[\r\n]/;
    }
    die "build directory '$spec->{build_directory}' contains the TEXINPUTS "
      . "path separator '$path_separator' and cannot be represented safely\n"
      if index($spec->{build_directory}, $path_separator) >= 0;
    die "shared TeX directory '$spec->{shared_tex_directory}' contains the "
      . "TEXINPUTS path separator '$path_separator' and cannot be represented "
      . "safely\n"
      if index($spec->{shared_tex_directory}, $path_separator) >= 0;
  }
  _validate_latexmk_args($request, $build_count);
  return 1;
}

sub _acquire_lock {
  my ($spec) = @_;
  my $path = File::Spec->catfile($spec->{build_directory}, '.ollm.lock');
  open my $handle, '>>', $path
    or die "cannot open build lock '$path': $!\n";
  if (!flock($handle, LOCK_EX | LOCK_NB)) {
    return if $! == EAGAIN || $! == EWOULDBLOCK;
    die "cannot lock build state '$path' on this platform: $!\n";
  }
  seek $handle, 0, 0;
  truncate $handle, 0
    or die "cannot update build lock '$path': $!\n";
  print {$handle} "$$\n"
    or die "cannot write build lock '$path': $!\n";
  return $handle;
}

sub _prepare_build_directory {
  my ($spec) = @_;
  my $root = abs_path($spec->{project_root})
    // die "project root not found: $spec->{project_root}\n";
  my $ancestor = $spec->{build_directory};
  while (!-e $ancestor) {
    my $parent = dirname($ancestor);
    die "cannot find an existing ancestor for build directory "
      . "'$spec->{build_directory}'\n"
      if $parent eq $ancestor;
    $ancestor = $parent;
  }
  my $canonical_ancestor = abs_path($ancestor)
    // die "cannot resolve build-directory ancestor '$ancestor'\n";
  _require_within(
    $canonical_ancestor, $root, 'existing build-directory ancestor',
  );
  make_path($spec->{build_directory});
  my $canonical_build = abs_path($spec->{build_directory})
    // die "cannot resolve build directory '$spec->{build_directory}'\n";
  _require_within($canonical_build, $root, 'build directory');
}

sub _require_within {
  my ($path, $root, $label) = @_;
  my $relative = File::Spec->abs2rel($path, $root);
  die "$label '$path' resolves outside project root '$root'\n"
    if File::Spec->file_name_is_absolute($relative)
      || $relative =~ /\A\.\.(?:[\\\/]|\z)/;
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
  my $build_file = File::Spec->catfile(
    $spec->{build_directory}, "$spec->{job_id}.osgbuild.tex",
  );
  my $manifest = $spec->{project_manifest}
    // die "BuildSpec has no project manifest";
  for my $entry (
    ['build-file', $build_file], ['project-manifest', $manifest],
  ) {
    die "$entry->[0] path contains unsafe TeX filename characters: $entry->[1]"
      if $entry->[1] =~ /[{}%#\r\n]/;
  }
  $build_file =~ s{\\}{/}g;
  $manifest =~ s{\\}{/}g;
  my $pretex = "\\edef\\OSGLectureProjectManifestFile"
    . "{\\detokenize{$manifest}}"
    . "\\edef\\OSGLectureJobFile{\\detokenize{$build_file}}";
  for my $symbol (
    ['RequestedTarget', $spec->{target}],
    ['RequestedDoctype', $spec->{doctype}],
    ['RequestedProfileClass', $spec->{profile_class}],
    ['RequestedDocumentMetadataPolicy', $spec->{document_metadata_policy}],
    ['RequestedLanguage', $spec->{language}],
  ) {
    my ($name, $value) = @$symbol;
    die "build value '$value' cannot be represented safely in metadata pre-TeX"
      if !defined($value) || $value !~ /\A[A-Za-z0-9._+-]+\z/;
    $pretex .= "\\def\\OsgLecture$name\{$value}";
  }
  if ($spec->{document_metadata}) {
    my $path = $spec->{document_metadata}{path};
    die "document metadata path contains unsafe TeX filename characters: $path"
      if $path =~ /[{}%#\r\n]/;
    $path =~ s{\\}{/}g;
    $pretex .= "\\input{\"$path\"}";
  }
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
    "-usepretex=$pretex",
    ($request->{rebuild} ? ('-gg') : ()),
    @{ $request->{latexmk_args} // [] },
    $spec->{source},
  );
}

sub _validate_latexmk_args {
  my ($request, $build_count, %arg) = @_;
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
      if !$arg{standalone} && $argument =~ /\A--?out2dir(?:=|\z)/;
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
          jobname | (?:pdf)?lualatex | recorder | cd | e
        )(?:=|\z)/x
      || !$arg{standalone} && $argument =~ /\A--?(?:
          auxdir | aux-directory | outdir | output-directory
        )(?:=|\z)/x;
    die "latexmk option '$argument' is not allowed because OLLM owns the "
      . "pre-TeX hook used for project metadata\n"
      if $argument =~ /\A--?(?:pretex|usepretex)(?:=|\z)/;
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

sub _execute_standalone {
  my ($class, $resolved, $latexmk_rc, $runner) = @_;
  $class->validate_request($resolved);
  my $request = $resolved->{request};
  my $spec = $resolved->{standalone_spec};
  my %shell_option = (
    off        => '--no-shell-escape',
    restricted => '--shell-restricted',
    full       => '--shell-escape',
  );
  my $engine = join ' ',
    'lualatex', $shell_option{$spec->{shell_escape}},
    '--synctex=1', '--interaction=nonstopmode', '--halt-on-error', '%O', '%S';
  my @command = (
    'latexmk', '-norc',
    (defined($latexmk_rc) ? ('-r', $latexmk_rc) : ()),
    '-lualatex', '-recorder', '-cd', "-pdflualatex=$engine",
    ($request->{rebuild} ? ('-gg') : ()),
    @{ $request->{latexmk_args} // [] },
    $spec->{source},
  );
  my $status = $runner
    ? $runner->(\@command, $spec)
    : system { $command[0] } @command;
  if ($status == -1) {
    print STDERR "ollm: cannot start latexmk: $!\n" if !$runner;
    return 69;
  }
  my $signal = $status & 127;
  if ($signal) {
    print STDERR "ollm: latexmk terminated by signal $signal\n"
      if !$runner && $signal != 2;
    return 128 + $signal;
  }
  return ($status >> 8) == 0 ? 0 : 1;
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
