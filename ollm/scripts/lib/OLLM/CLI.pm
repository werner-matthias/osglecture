package OLLM::CLI;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Basename qw(dirname);
use File::Spec;
use JSON::PP;
use OLLM::Config;
use OLLM::Version qw($VERSION);

my %ACTION = map { $_ => 1 }
  qw(build report check clean prune doctor convertconfig newtoml);
  $ACTION{deploy} = 1;
my %TARGET_ALIAS = (
  article      => 'script',
  beamer       => 'slides',
  handout      => 'handout',
  presentation => 'slides',
  script       => 'script',
  slides       => 'slides',
);

sub run {
  my ($class, %arg) = @_;
  my $plan;

  eval {
    $plan = $class->parse(@{ $arg{argv} // [] });
    1;
  } or do {
    my $error = $@ || 'unknown command-line error';
    chomp $error;
    print STDERR "ollm: $error\n";
    print STDERR "Try 'ollm --help' for usage.\n";
    return 2;
  };

  if ($plan->{help}) {
    print _help();
    return 0;
  }

  if ($plan->{version}) {
    print "ollm $VERSION\n";
    return 0;
  }

  if ($plan->{action} ne 'deploy'
      && ($plan->{overwrite} || ($plan->{scope} // '') eq 'collection')) {
    print STDERR "ollm: deployment options are only valid for deploy\n";
    return 2;
  }

  if ($plan->{action} eq 'convertconfig' || $plan->{action} eq 'newtoml') {
    return $class->_migration($plan);
  }

  if ($plan->{action} eq 'deploy') {
    return $class->_deployment($plan);
  }

  if ($plan->{action} eq 'doctor') {
    return $class->_doctor($plan);
  }

  if ($plan->{action} eq 'clean' || $plan->{action} eq 'prune') {
    return $class->_maintenance($plan);
  }

  if ($plan->{action} eq 'report' || $plan->{action} eq 'check') {
    return $class->_inspection($plan);
  }

  if ($plan->{action} ne 'build') {
    return $class->_unavailable($plan);
  }

  my $resolved = eval {
    OLLM::Config->resolve_request(
      plan            => $plan,
      definitions_dir => $arg{definitions_dir}
        // File::Spec->catdir($arg{script_dir}, 'definitions'),
      start_dir       => _source_directory($plan->{source}),
    );
  };
  if (!$resolved) {
    my $error = $@ || 'unknown configuration error';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 2;
  }

  if ($resolved->{configuration}{kind} eq 'toml'
      || $resolved->{request}{context} eq 'standalone') {
    my $valid = eval {
      require OLLM::Executor;
      OLLM::Executor->validate_request($resolved);
    };
    if (!$valid) {
      my $error = $@ || 'invalid build option combination';
      chomp $error;
      print STDERR "ollm: $error\n";
      return 2;
    }
  }

  if ($plan->{dry_run}) {
    $class->_print_plan($plan, $resolved);
    return 0;
  }

  if ($resolved->{configuration}{kind} eq 'toml'
      || $resolved->{request}{context} eq 'standalone') {
    if ($plan->{resolve}) {
      require OLLM::Resolver;
      my $status = eval {
        OLLM::Resolver->execute(
          resolved => $resolved,
          latexmk_rc => File::Spec->catfile(
            $arg{script_dir}, 'ollm-latexmk.rc',
          ),
        )
      };
      if (!defined $status) {
        my $error = $@ || 'unknown reference-resolution error';
        chomp $error;
        print STDERR "ollm: $error\n";
        return 1;
      }
      return $status;
    }
    require OLLM::Executor;
    my $status = eval {
      OLLM::Executor->execute(
        resolved => $resolved,
        latexmk_rc => File::Spec->catfile(
          $arg{script_dir}, 'ollm-latexmk.rc',
        ),
      )
    };
    if (!defined $status) {
      my $error = $@ || 'unknown build-executor error';
      chomp $error;
      print STDERR "ollm: $error\n";
      return 2;
    }
    return $status;
  }

  my @unsupported = grep { $plan->{$_} } qw(all resolve);
  if (@unsupported) {
    print STDERR
      "ollm: this build requires the new build engine; use --dry-run to inspect it\n";
    return 69;
  }

  my $rc = File::Spec->catfile($arg{script_dir}, 'ollm-legacy.rc');
  if (!-f $rc) {
    print STDERR "ollm: legacy latexmk configuration not found: $rc\n";
    return 69;
  }

  my @command = $class->_legacy_command(
    $plan, $rc, $resolved->{configuration}{path},
  );
  {
    no warnings 'exec';
    local $ENV{OLLM_VERSION} = $VERSION;
    exec { $command[0] } @command;
  }
  print STDERR "ollm: cannot execute latexmk: $!\n";
  return 69;
}

sub _legacy_command {
  my ($class, $plan, $rc, $config_path) = @_;
  my @legacy;
  push @legacy, '+' . $plan->{target} if defined $plan->{target};
  push @legacy, '+lang=' . $plan->{language} if defined $plan->{language};
  push @legacy, '+debug' if defined $plan->{debug};
  push @legacy, '+ollmconfig=' . ($config_path // $plan->{config})
    if defined($config_path) || defined($plan->{config});
  push @legacy, '+enforce+' if $plan->{enforce_plus};
  push @legacy, '-gg' if $plan->{rebuild};
  push @legacy, @{ $plan->{legacy_args} };
  push @legacy, @{ $plan->{latexmk_args} };
  push @legacy, $plan->{source} if defined $plan->{source};
  return ('latexmk', '-norc', '-r', $rc, @legacy);
}

sub parse {
  my ($class, @argv) = @_;
  my $enforce_plus = 0;
  for my $arg (@argv) {
    last if $arg eq '--';
    $enforce_plus = 1
      if $arg eq '+enforce+' || $arg eq '--enforce+' || $arg eq '+force+';
  }
  my %plan = (
    action       => 'build',
    color        => 'auto',
    format       => 'text',
    legacy_args  => [],
    latexmk_args => [],
    operands     => [],
    warnings     => 'important',
    enforce_plus => $enforce_plus,
  );
  my $options = 1;
  my $action_seen = 0;

  while (@argv) {
    my $arg = shift @argv;

    if ($options && $arg eq '--') {
      $options = 0;
      next;
    }

    if (!$options) {
      push @{ $plan{operands} }, $arg;
      next;
    }

    if ($arg eq '+enforce+' || $arg eq '--enforce+' || $arg eq '+force+') {
      $plan{deprecated_force} = 1 if $arg eq '+force+';
      next;
    }

    if ($arg eq '--help' || $arg eq '-h' || $arg eq '+help' || $arg eq '+h') {
      $plan{help} = 1;
      next;
    }
    if ($arg eq '--version' || $arg eq '+version') {
      $plan{version} = 1;
      next;
    }

    my $prefixed = $arg =~ /^\+(.+)\z/ ? 1 : 0;
    my $word = $prefixed ? $1 : $arg;
    if ($ACTION{$word} && (!$enforce_plus || $prefixed)) {
      die "more than one action specified" if $action_seen;
      $plan{action} = $word;
      $action_seen = 1;
      next;
    }

    my $compat = $arg;
    $compat =~ s/^\+//;
    if (exists $TARGET_ALIAS{$compat} && (!$enforce_plus || $prefixed)) {
      die "more than one document target specified" if defined $plan{target};
      $plan{target} = $TARGET_ALIAS{$compat};
      $plan{target_explicit} = 1;
      next;
    }

    if ($compat =~ /^(?:standalone|publish|verbose|nosocket)$/) {
      push @{ $plan{legacy_args} }, '+' . $compat;
      next;
    }
    if ($arg eq '--legacy') {
      $plan{legacy} = 1;
      next;
    }
    if ($compat =~ /^classpath=(.+)$/) {
      push @{ $plan{legacy_args} }, '+classpath=' . $1;
      next;
    }

    if ($arg eq '--all') {
      $plan{all} = 1;
      next;
    }
    if ($arg =~ /^--target=(.+)$/) {
      _set_target(\%plan, $1);
      next;
    }
    if ($arg eq '--target') {
      _set_target(\%plan, _take_value($arg, \@argv));
      next;
    }
    if ($arg eq '--resolve') {
      $plan{resolve} = 1;
      next;
    }
    if ($arg eq '--rebuild') {
      $plan{rebuild} = 1;
      next;
    }
    if ($arg eq '--dry-run') {
      $plan{dry_run} = 1;
      next;
    }
    if ($arg eq '--non-interactive') {
      $plan{non_interactive} = 1;
      next;
    }
    if ($arg =~ /^--level=(.+)$/) {
      $plan{level} = _enum('level', $1, qw(aux build state all));
      next;
    }
    if ($arg eq '--level') {
      $plan{level} = _enum(
        'level', _take_value($arg, \@argv), qw(aux build state all),
      );
      next;
    }
    if ($arg =~ /^--scope=(.+)$/) {
      $plan{scope} = _enum('scope', $1, qw(current unit series collection));
      next;
    }
    if ($arg eq '--scope') {
      $plan{scope} = _enum(
        'scope', _take_value($arg, \@argv), qw(current unit series collection),
      );
      next;
    }
    if ($arg eq '--stale-units') {
      $plan{stale_units} = 1;
      next;
    }
    if ($arg eq '--overwrite') {
      $plan{overwrite} = 1;
      next;
    }

    if ($arg =~ /^(?:--language=|\+?lang=)(.+)$/) {
      $plan{language} = $1;
      $plan{language_explicit} = 1;
      next;
    }
    if ($arg eq '--language') {
      $plan{language} = _take_value($arg, \@argv);
      $plan{language_explicit} = 1;
      next;
    }
    if ($arg =~ /^--source=(.+)$/) {
      $plan{source} = $1;
      $plan{source_explicit} = 1;
      next;
    }
    if ($arg eq '--source') {
      $plan{source} = _take_value($arg, \@argv);
      $plan{source_explicit} = 1;
      next;
    }
    if ($arg =~ /^--config=(.+)$/) {
      $plan{config} = $1;
      next;
    }
    if ($arg eq '--config') {
      $plan{config} = _take_value($arg, \@argv);
      next;
    }
    if ($arg =~ /^--project-root=(.+)$/) {
      $plan{project_root} = $1;
      next;
    }
    if ($arg eq '--project-root') {
      $plan{project_root} = _take_value($arg, \@argv);
      next;
    }

    if ($arg eq 'debug' || $arg eq '+debug' || $arg eq '--debug') {
      $plan{debug} = 'tex';
      next;
    }
    if ($arg =~ /^(?:--debug=|\+?debug=)(.+)$/) {
      $plan{debug} = _enum('debug', $1, qw(tex ollm tex+ollm));
      next;
    }
    if ($arg =~ /^--warnings=(.+)$/) {
      $plan{warnings} = _enum('warnings', $1, qw(all important none));
      next;
    }
    if ($arg =~ /^--color=(.+)$/) {
      $plan{color} = _enum('color', $1, qw(auto always never));
      next;
    }
    if ($arg =~ /^--format=(.+)$/) {
      $plan{format} = _enum('format', $1, qw(text json));
      next;
    }

    if ($arg =~ /\A--?(?:e|r)\z/) {
      die "latexmk option '$arg' is not accepted by OLLM because additional "
        . "rc files or startup Perl code could override OLLM's controlled "
        . "build configuration\n";
    }

    if ($arg =~ /^-/) {
      push @{ $plan{latexmk_args} }, $arg;
      next;
    }

    push @{ $plan{operands} }, $arg;
  }

  if (@{ $plan{operands} }) {
    die "too many operands" if @{ $plan{operands} } > 1;
    die "source specified twice" if defined $plan{source};
    $plan{source} = $plan{operands}[0];
    $plan{source_explicit} = 1;
  }

  $plan{target} //= 'slides' if $plan{action} eq 'build';
  return \%plan;
}

sub _migration {
  my ($class, $plan) = @_;
  for my $option (qw(all dry_run legacy level rebuild resolve scope stale_units)) {
    if ($plan->{$option}) {
      print STDERR "ollm: --$option is not valid for $plan->{action}\n";
      return 2;
    }
  }
  if ($plan->{source_explicit} || defined $plan->{target_explicit}
      || defined $plan->{language} || @{ $plan->{latexmk_args} }) {
    print STDERR "ollm: $plan->{action} accepts only --config and --project-root\n";
    return 2;
  }
  require OLLM::Migration;
  my $result = eval {
    OLLM::Migration->execute(
      action => $plan->{action}, start_dir => getcwd(),
      config => $plan->{config}, project_root => $plan->{project_root},
    );
  };
  if (!$result) {
    my $error = $@ || 'configuration migration failed';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 2;
  }
  print "Created $result->{path}",
    $result->{converted} ? " from legacy configuration\n" : "\n";
  print STDERR "ollm: conversion warning: $_\n" for @{ $result->{warnings} };
  return 0;
}

sub _deployment {
  my ($class, $plan) = @_;
  for my $option (qw(dry_run legacy level rebuild resolve stale_units)) {
    if ($plan->{$option}) {
      print STDERR "ollm: --$option is not valid for deploy\n";
      return 2;
    }
  }
  if ($plan->{source_explicit} || @{ $plan->{latexmk_args} }) {
    print STDERR "ollm: deploy does not accept a source or latexmk options\n";
    return 2;
  }
  my $cwd = getcwd();
  my $located = eval {
    OLLM::Config->find_manifest(
      start_dir => $cwd, config => $plan->{config},
      project_root => $plan->{project_root},
    );
  };
  if (!$located || $located->{kind} ne 'toml') {
    my $error = $@ || 'deploy requires an ollmconfig.toml project';
    chomp $error; print STDERR "ollm: $error\n"; return 2;
  }
  my $manifest = eval { OLLM::Config->load_manifest($located->{path}) };
  if (!$manifest) {
    my $error = $@ || 'cannot load project manifest'; chomp $error;
    print STDERR "ollm: $error\n"; return 2;
  }
  my $root = dirname($located->{path});
  my $start = $cwd;
  my $relative = File::Spec->abs2rel($cwd, $root);
  if ((defined($plan->{project_root}) || defined($plan->{config}))
      && (File::Spec->file_name_is_absolute($relative)
        || $relative =~ /\A\.\.(?:[\\\/]|\z)/)) {
    $start = $root;
  }
  require OLLM::Deployment;
  my $request = eval {
    OLLM::Deployment->prepare(
      plan => $plan, project_root => $root, start_dir => $start,
      manifest => $manifest,
      structure => OLLM::Config->structure_snapshot(project_root => $root),
    );
  };
  if (!$request) {
    my $error = $@ || 'invalid deployment request'; chomp $error;
    print STDERR "ollm: $error\n"; return 2;
  }
  my $report = eval { OLLM::Deployment->execute($request) };
  if (!$report) {
    my $error = $@ || 'deployment failed'; chomp $error;
    print STDERR "ollm: $error\n"; return 1;
  }
  if ($plan->{format} eq 'json') {
    print JSON::PP->new->canonical->pretty->encode({
      schema => 'org.osglecture.ollm.deployment', version => 1,
      ok => $report->{ok} ? JSON::PP::true : JSON::PP::false,
      scope => $request->{scope}, items => $report->{items},
    });
  } else {
    for my $item (@{ $report->{items} }) {
      my $message = defined $item->{message} ? ": $item->{message}" : '';
      print uc($item->{status}), " ", ($item->{path} // $item->{source}),
        "$message\n";
    }
  }
  return $report->{ok} ? 0 : 1;
}

sub _maintenance {
  my ($class, $plan) = @_;
  my $cwd = getcwd();
  my $located = eval {
    OLLM::Config->find_manifest(
      start_dir => $cwd, config => $plan->{config},
      project_root => $plan->{project_root},
    );
  };
  if (!$located || $located->{kind} ne 'toml') {
    my $error = $@ || 'clean and prune require an ollmconfig.toml project';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 2;
  }
  my $manifest = eval { OLLM::Config->load_manifest($located->{path}) };
  if (!$manifest) {
    my $error = $@ || 'cannot load project manifest';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 2;
  }
  my $root = dirname($located->{path});
  my $start = $cwd;
  my $relative = File::Spec->abs2rel($cwd, $root);
  if ((defined($plan->{project_root}) || defined($plan->{config}))
      && (File::Spec->file_name_is_absolute($relative)
        || $relative =~ /\A\.\.(?:[\\\/]|\z)/)) {
    $start = $root;
  }
  require OLLM::Maintenance;
  my $request = eval {
    OLLM::Maintenance->prepare(
      plan => $plan, project_root => $root, start_dir => $start,
      manifest => $manifest,
      structure => OLLM::Config->structure_snapshot(project_root => $root),
      default_language => $manifest->{languages}{default},
    );
  };
  if (!$request) {
    my $error = $@ || 'invalid maintenance request';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 2;
  }
  if ($request->{confirm_series}) {
    if ($plan->{non_interactive} || !-t STDIN) {
      print STDERR "ollm: --scope=series from inside a unit requires "
        . "interactive confirmation; run it from the project root instead\n";
      return 2;
    }
    print STDERR "Clean the entire series although the command was started "
      . "inside unit '$request->{physical_unit}'? [y/j/N] ";
    my $answer = <STDIN> // '';
    if ($answer !~ /\A\s*(?:y|yes|j|ja)\s*\z/i) {
      print STDERR "ollm: clean cancelled\n";
      return 1;
    }
  }
  my $report = eval { OLLM::Maintenance->execute($request) };
  if (!$report) {
    my $error = $@ || 'maintenance action failed';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 1;
  }
  _print_maintenance($plan, $report);
  return 0;
}

sub _inspection {
  my ($class, $plan) = @_;
  for my $option (qw(all dry_run level rebuild resolve stale_units)) {
    if ($plan->{$option}) {
      print STDERR "ollm: --$option is not valid for $plan->{action}\n";
      return 2;
    }
  }
  if ($plan->{source_explicit} || @{ $plan->{latexmk_args} }) {
    print STDERR "ollm: $plan->{action} does not accept a source or latexmk options\n";
    return 2;
  }
  my $cwd = getcwd();
  my $located = eval {
    OLLM::Config->find_manifest(
      start_dir => $cwd, config => $plan->{config},
      project_root => $plan->{project_root},
    );
  };
  if (!$located || $located->{kind} ne 'toml') {
    my $error = $@ || 'report and check require an ollmconfig.toml project';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 2;
  }
  my $manifest = eval { OLLM::Config->load_manifest($located->{path}) };
  if (!$manifest) {
    my $error = $@ || 'cannot load project manifest';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 2;
  }
  my $root = dirname($located->{path});
  my $start = $cwd;
  my $relative = File::Spec->abs2rel($cwd, $root);
  if ((defined($plan->{project_root}) || defined($plan->{config}))
      && (File::Spec->file_name_is_absolute($relative)
        || $relative =~ /\A\.\.(?:[\\\/]|\z)/)) {
    $start = $root;
  }
  require OLLM::Inspection;
  my $request = eval {
    OLLM::Inspection->prepare(
      plan => $plan, project_root => $root, start_dir => $start,
      manifest => $manifest,
      structure => OLLM::Config->structure_snapshot(project_root => $root),
    );
  };
  if (!$request) {
    my $error = $@ || 'invalid inspection request';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 2;
  }
  my $report = eval { OLLM::Inspection->analyze($request) };
  if (!$report) {
    my $error = $@ || 'cannot inspect OLLM state';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 1;
  }
  _print_inspection($plan, $report);
  return 3 if $plan->{action} eq 'check' && !$report->{ok};
  return 0;
}

sub _print_inspection {
  my ($plan, $report) = @_;
  if ($plan->{format} eq 'json') {
    print JSON::PP->new->canonical->pretty->encode({
      schema => 'org.osglecture.ollm.' . $plan->{action},
      version => 1, %$report,
      ok => $report->{ok} ? JSON::PP::true : JSON::PP::false,
    });
    return;
  }
  print "Scope: $report->{scope}\n";
  for my $unit (@{ $report->{units} }) {
    print "Unit:  $unit->{physical_unit} [$unit->{status}]\n";
  }
  for my $projection (@{ $report->{projections} }) {
    print "Build: $projection->{identity} [$projection->{status}]",
      $projection->{required} ? " required\n" : "\n";
  }
  for my $issue (@{ $report->{issues} }) {
    print uc($issue->{severity}), " [$issue->{code}] $issue->{message}\n";
  }
  print $report->{ok} ? "Status: OK\n" : "Status: INCONSISTENT\n";
}

sub _print_maintenance {
  my ($plan, $report) = @_;
  if ($plan->{format} eq 'json') {
    print JSON::PP->new->canonical->pretty->encode({
      schema => 'org.osglecture.ollm.maintenance',
      version => 1, action => $report->{action},
      dry_run => $plan->{dry_run} ? JSON::PP::true : JSON::PP::false,
      items => $report->{items},
    });
    return;
  }
  my $verb = $plan->{dry_run} ? 'would remove' : 'removed';
  for my $item (@{ $report->{items} }) {
    if ($item->{operation} eq 'report') {
      print "stale unit: $item->{path}\n";
    } else {
      print "$verb [$item->{kind}] $item->{path}\n";
    }
  }
  print "nothing to do\n" if !@{ $report->{items} };
}

sub _take_value {
  my ($option, $argv) = @_;
  die "$option requires a value" if !@$argv;
  return shift @$argv;
}

sub _set_target {
  my ($plan, $target) = @_;
  die "more than one document target specified" if defined $plan->{target};
  die "invalid target '$target'; expected a portable target identifier"
    if $target !~ /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/;
  $plan->{target} = $TARGET_ALIAS{$target} // $target;
  $plan->{target_explicit} = 1;
}

sub _enum {
  my ($name, $value, @allowed) = @_;
  my %allowed = map { $_ => 1 } @allowed;
  die "invalid --$name value '$value'" if !$allowed{$value};
  return $value;
}

sub _source_directory {
  my ($source) = @_;
  return getcwd() if !defined $source;
  my $absolute = File::Spec->rel2abs($source, getcwd());
  return -f $absolute ? dirname($absolute) : getcwd();
}

sub _print_plan {
  my ($class, $plan, $resolved) = @_;
  if ($plan->{format} eq 'json') {
    my $output = {
      schema        => 'org.osglecture.ollm.build-request',
      version       => 1,
      configuration => $resolved->{configuration},
      request       => $resolved->{request},
    };
    $output->{build_spec} = $resolved->{build_spec}
      if $resolved->{build_spec};
    $output->{build_specs} = $resolved->{build_specs}
      if $resolved->{build_specs};
    print JSON::PP->new->canonical->pretty->encode($output);
    return;
  }

  my $request = $resolved->{request};
  my $configuration = $resolved->{configuration};
  print "Action:   $request->{action}\n";
  print "Context:  $request->{context}\n";
  print "Target:   $request->{target}\n" if defined $request->{target};
  print "Language: $request->{language}\n" if defined $request->{language};
  print "Source:   $request->{source}\n";
  print "Config:   ",
    ($configuration->{path} // $configuration->{kind}), "\n";
  if ($resolved->{build_specs}) {
    print "Builds:   ", scalar(@{ $resolved->{build_specs} }), "\n";
    print "Job:      $_->{job_id}\n" for @{ $resolved->{build_specs} };
  } elsif ($resolved->{build_spec}) {
    print "Job:      $resolved->{build_spec}{job_id}\n";
  }
  print "Mode:     dry-run\n";
}

sub _doctor {
  my ($class, $plan) = @_;
  my @checks = map {
    +{ program => $_, found => _find_program($_) }
  } qw(perl latexmk lualatex);
  my $ok = !grep { !defined $_->{found} } @checks;
  my $parser = OLLM::Config->parser_info;
  $ok = 0 if !$parser->{available};

  if ($plan->{format} eq 'json') {
    print JSON::PP->new->canonical->pretty->encode({
      schema  => 'org.osglecture.ollm.doctor',
      version => 1,
      ok      => $ok ? JSON::PP::true : JSON::PP::false,
      checks  => \@checks,
      toml_parser => $parser,
    });
  } else {
    for my $check (@checks) {
      printf "%-10s %s\n", $check->{program},
        defined $check->{found} ? $check->{found} : 'NOT FOUND';
    }
    if ($parser->{available}) {
      printf "%-10s %s %s (%s)\n", 'TOML',
        $parser->{name}, $parser->{version}, $parser->{source};
    } else {
      printf "%-10s NOT FOUND: %s\n", 'TOML', $parser->{error};
    }
  }
  return $ok ? 0 : 69;
}

sub _find_program {
  my ($program) = @_;
  my @suffixes = $^O eq 'MSWin32' ? ('', '.exe', '.bat', '.cmd') : ('');
  for my $directory (File::Spec->path) {
    for my $suffix (@suffixes) {
      my $candidate = File::Spec->catfile($directory, $program . $suffix);
      return File::Spec->rel2abs($candidate) if -f $candidate && -x _;
    }
  }
  return;
}

sub _unavailable {
  my ($class, $plan) = @_;
  my $message = "action '$plan->{action}' is specified but not implemented yet";
  if ($plan->{format} eq 'json') {
    print JSON::PP->new->canonical->encode({
      schema  => 'org.osglecture.ollm.error',
      version => 1,
      error   => 'unavailable',
      message => $message,
    }), "\n";
  } else {
    print STDERR "ollm: $message\n";
  }
  return 69;
}

sub _help {
  return <<'HELP';
Usage:
  ollm [global options] [build] [[+]target| | --target=<target>] [build options] [latexmk options]
  ollm [global options] <report|check|clean|prune|doctor|deploy|convertconfig|newtoml>

Targets:
  slides (aliases: beamer, presentation)
  handout
  script (alias: article)
  Registered project targets can be selected with --target=NAME.

Implemented commands:
  build                 execute a series build
  standalone            execute a manifest-free build
  report                describe discovered units and promoted projections
  check                 validate required projection dependencies
  clean                 remove selected OLLM build or state data
  prune                 remove superseded OLLM state generations
  doctor                inspect the local Perl and TeX toolchain
  deploy                copy promoted PDF artifacts to configured targets
  convertconfig         convert a legacy ollmconfig.pl to TOML where possible
  newtoml               create TOML, converting ollmconfig.pl when present

General options:
  --help                show this help
  --version             show the OLLM version
  --format=text|json    select human- or machine-readable output
  --color=auto|always|never
  --non-interactive
  --legacy              explicitly build with ollmconfig.pl
  +enforce+|--enforce+  require '+' on command and target words
  --overwrite           permit replacement when project policy is explicit

Build options:
  --target=TARGET       select a registered project target
  --language=LANG       select a language
  --source=FILE         select the main TeX source
  --all
  --resolve
  --rebuild
  --dry-run.            print the normalized request without building
  --level=aux|build|state|all
  --scope=current|unit|series|collection
  --stale-units         let prune remove states for missing physical units
  --debug=tex|ollm|tex+ollm
  --warnings=all|important|none
  --config=FILE
  --project-root=DIR

Compatibility:
  Bare targets, lang=en, +lang=en, +script, and debug remain accepted.
  Commands may also use '+'. The deprecated +force+ aliases +enforce+.
  Compatible unknown minus options are passed to latexmk.
HELP
}

1;
