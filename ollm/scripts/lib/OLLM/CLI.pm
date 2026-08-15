package OLLM::CLI;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON::PP;
use OLLM::Config;
use OLLM::Path;
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
my $DOCTOR_TEXMF_DIRECTORY;

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

  if ($plan->{action} ne 'deploy' && $plan->{overwrite}) {
    print STDERR "ollm: deployment options are only valid for deploy\n";
    return 2;
  }
  if ($plan->{action} ne 'deploy' && $plan->{action} ne 'build'
      && ($plan->{scope} // '') eq 'collection') {
    print STDERR "ollm: --scope=collection is only valid for build or deploy\n";
    return 2;
  }

  if ($plan->{action} eq 'convertconfig' || $plan->{action} eq 'newtoml') {
    return $class->_migration($plan);
  }

  if ($plan->{action} eq 'deploy') {
    return $class->_deployment($plan);
  }

  if ($plan->{action} eq 'doctor') {
    return $class->_doctor($plan, %arg);
  }

  if ($plan->{action} eq 'clean' || $plan->{action} eq 'prune') {
    return $class->_maintenance($plan);
  }

  if ($plan->{action} eq 'report' || $plan->{action} eq 'check') {
    return $class->_inspection($plan, %arg);
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

  if ($resolved->{configuration}{kind} eq 'none'
      && $resolved->{request}{context} ne 'standalone') {
    print STDERR "ollm: no ollmconfig.toml project found; run the command "
      . "inside a project, select one with --project-root/--config, or use "
      . "standalone explicitly\n";
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

sub _locate_project {
  my ($class, $plan, $default_error) = @_;
  my $cwd = getcwd();
  my $located = eval {
    OLLM::Config->find_manifest(
      start_dir => $cwd, config => $plan->{config},
      project_root => $plan->{project_root},
    );
  };
  if (!$located || $located->{kind} ne 'toml') {
    my $error = $@ || $default_error;
    chomp $error;
    print STDERR "ollm: $error\n";
    return;
  }
  my $manifest = eval { OLLM::Config->load_manifest($located->{path}) };
  if (!$manifest) {
    my $error = $@ || 'cannot load project manifest';
    chomp $error;
    print STDERR "ollm: $error\n";
    return;
  }
  return {
    cwd => $cwd, located => $located, manifest => $manifest,
    root => dirname($located->{path}),
  };
}

# A project selected explicitly (--project-root/--config) may point at a
# manifest above the current directory; commands that otherwise operate on
# the unit under the cwd then fall back to running from the project root.
sub _start_dir {
  my ($class, $plan, $cwd, $root) = @_;
  return $cwd
    if !(defined($plan->{project_root}) || defined($plan->{config}));
  return OLLM::Path::is_outside($cwd, $root) ? $root : $cwd;
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
  my $project = $class->_locate_project(
    $plan, 'deploy requires an ollmconfig.toml project',
  ) or return 2;
  my ($cwd, $manifest, $root) = @{$project}{qw(cwd manifest root)};
  my $start = $class->_start_dir($plan, $cwd, $root);
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
  my $project = $class->_locate_project(
    $plan, 'clean and prune require an ollmconfig.toml project',
  ) or return 2;
  my ($cwd, $manifest, $root) = @{$project}{qw(cwd manifest root)};
  my $start = $class->_start_dir($plan, $cwd, $root);
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
  my ($class, $plan, %arg) = @_;
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
  my $project = $class->_locate_project(
    $plan, 'report and check require an ollmconfig.toml project',
  ) or return 2;
  my ($cwd, $located, $manifest, $root) =
    @{$project}{qw(cwd located manifest root)};
  my $definitions = eval {
    OLLM::Config->resolve_definitions(
      manifest => $manifest, manifest_path => $located->{path},
      project_root => $root,
      bundle_path => $arg{definitions_dir}
        // File::Spec->catdir($arg{script_dir}, 'definitions'),
    )
  };
  if (!$definitions) {
    my $error = $@ || 'cannot resolve project definitions';
    chomp $error;
    print STDERR "ollm: $error\n";
    return 2;
  }
  my $start = $class->_start_dir($plan, $cwd, $root);
  require OLLM::Inspection;
  my $request = eval {
    OLLM::Inspection->prepare(
      plan => $plan, project_root => $root, start_dir => $start,
      manifest => $manifest,
      manifest_path => $located->{path}, definitions => $definitions,
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
  print "Config: $report->{configuration}{manifest}\n"
    if defined $report->{configuration}{manifest};
  print "Bundle: $report->{configuration}{bundle_preset}\n"
    if defined $report->{configuration}{bundle_preset};
  print "TeX configuration: not exported (effective/enforced values unavailable)\n"
    if !$report->{configuration}{effective_tex}{available};
  for my $unit (@{ $report->{units} }) {
    print "Unit:  $unit->{physical_unit} [$unit->{status}]\n";
  }
  for my $projection (@{ $report->{projections} }) {
    print "Build: $projection->{identity} [$projection->{status}]",
      $projection->{required} ? " required\n" : "\n";
    print "        job=$projection->{job_id} ordinal=$projection->{ordinal}",
      " chapter=$projection->{chapter}\n";
    print "        artifact=$projection->{artifact}\n";
    print "        reference-export=$projection->{reference_export}\n"
      if defined $projection->{reference_export};
    print "        config-signature=$projection->{config_signature}\n"
      if defined $projection->{config_signature};
    for my $dependency (@{ $projection->{dependencies} // [] }) {
      print "        depends=$dependency->{kind} ",
        join('/', map { $dependency->{$_} // '' } qw(unit_id doctype language)),
        defined($dependency->{label}) ? " label=$dependency->{label}" : '',
        "\n";
    }
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
  print "Scope:    $request->{scope}\n" if defined $request->{scope};
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
  my ($class, $plan, %arg) = @_;
  for my $option (qw(all dry_run level overwrite rebuild resolve scope stale_units)) {
    if ($plan->{$option}) {
      print STDERR "ollm: --$option is not valid for doctor\n";
      return 2;
    }
  }
  if ($plan->{source_explicit} || $plan->{target_explicit}
      || $plan->{language_explicit} || @{ $plan->{latexmk_args} }) {
    print STDERR "ollm: doctor does not accept build targets, sources, or latexmk options\n";
    return 2;
  }
  my @checks = map { _program_doctor_check($_) }
    qw(perl latexmk lualatex kpsewhich);
  my $ok = !grep { !$_->{ok} } @checks;
  my $parser = OLLM::Config->parser_info;
  $ok = 0 if !$parser->{available};

  my ($kpsewhich_check) = grep { $_->{program} eq 'kpsewhich' } @checks;
  my $kpsewhich = $kpsewhich_check->{found};
  my @tex_files = (
    map({ _kpsewhich_check($_, 1, $kpsewhich, 'osglecture') } qw(
      osglecture.cls osglecture-project.sty osglecture-structure.sty
    )),
    _kpsewhich_check('hyperref.sty', 1, $kpsewhich, 'hyperref'),
    map({ _kpsewhich_check($_, 0, $kpsewhich, $_ eq 'varioref.sty' ? 'tools' : $_ =~ /tagpax/ ? 'tagpax' : 'latex-lab') }
      qw(varioref.sty tagpdf.sty tagpax.sty)),
  );
  $ok = 0 if grep { $_->{required} && !$_->{ok} } @tex_files;

  my ($lualatex_check) = grep { $_->{program} eq 'lualatex' } @checks;
  my $runtime = _lualatex_doctor_probe($lualatex_check->{found}, 'article');
  $ok = 0 if !$runtime->{ok};
  my @ltxtalk_checks = (
    _kpsewhich_check('ltx-talk.cls', 0, $kpsewhich, 'ltx-talk'),
    _kpsewhich_check('NewCMSans10-Regular.otf', 0, $kpsewhich, 'newcomputermodern'),
    _kpsewhich_check('NewCMSansMath-Regular.otf', 0, $kpsewhich, 'newcomputermodern'),
  );
  my $ltxtalk_files_ok = !grep { !$_->{ok} } @ltxtalk_checks;
  my $ltxtalk_runtime = $ltxtalk_files_ok
    ? _lualatex_doctor_probe($lualatex_check->{found}, 'ltx-talk')
    : { ok => JSON::PP::false, skipped => JSON::PP::true,
        message => 'required ltx-talk files are unavailable' };
  my $ltxtalk_ok = $ltxtalk_files_ok && $ltxtalk_runtime->{ok};
  my @capabilities = ({
    name => 'ltx-talk-adapter', required => JSON::PP::false,
    ok => $ltxtalk_ok ? JSON::PP::true : JSON::PP::false,
    checks => \@ltxtalk_checks, runtime => $ltxtalk_runtime,
    (!$ltxtalk_ok ? (remediation =>
      'Update/install the TeX Live packages ltx-talk and newcomputermodern (tlmgr install ltx-talk newcomputermodern).') : ()),
  });

  my $project;
  my $located = eval {
    OLLM::Config->find_manifest(
      start_dir => getcwd(), config => $plan->{config},
      project_root => $plan->{project_root},
    )
  };
  if (!$located) {
    my $error = $@ || 'cannot inspect project configuration'; chomp $error;
    $project = { present => JSON::PP::false, ok => JSON::PP::false,
      error => $error };
    $ok = 0;
  } elsif ($located->{kind} eq 'toml') {
    my $manifest = eval { OLLM::Config->load_manifest($located->{path}) };
    if (!$manifest) {
      my $error = $@ || 'cannot load project manifest'; chomp $error;
      $project = { present => JSON::PP::true, ok => JSON::PP::false,
        path => $located->{path}, error => $error };
      $ok = 0;
    } else {
      my $root = dirname($located->{path});
      my $definitions = eval {
        OLLM::Config->resolve_definitions(
          manifest => $manifest, manifest_path => $located->{path},
          project_root => $root,
          bundle_path => $arg{definitions_dir}
            // File::Spec->catdir($arg{script_dir}, 'definitions'),
        )
      };
      my @project_checks;
      if (!$definitions) {
        my $error = $@ || 'cannot resolve project definitions'; chomp $error;
        push @project_checks, { name => 'definitions', ok => JSON::PP::false,
          message => $error };
      } else {
        push @project_checks, { name => 'definitions', ok => JSON::PP::true,
          bundle_preset => $definitions->{bundle_preset}{reference} };
      }
      my $tex = $manifest->{project}{tex} // {};
      my $shared = File::Spec->catdir($root, $tex->{directory} // 'Include');
      my $config = File::Spec->catfile($shared, $tex->{config} // 'projectconfig.tex');
      push @project_checks,
        { name => 'project-root-writable', ok => (-w $root ? JSON::PP::true : JSON::PP::false), path => $root },
        { name => 'project-config', ok => (-f $config ? JSON::PP::true : JSON::PP::false), path => $config };
      my $needs_metadata = $definitions && grep {
        (($manifest->{targets}{$_}{document_metadata}
          // $definitions->{targets}{$_}{document_metadata} // 'disabled') eq 'required')
      } keys %{ $manifest->{targets} };
      if ($needs_metadata) {
        my $metadata = File::Spec->catfile($shared, 'documentmetadata.tex');
        push @project_checks, { name => 'document-metadata',
          ok => (-f $metadata ? JSON::PP::true : JSON::PP::false), path => $metadata };
      }
      my $state_directory = File::Spec->catdir($root, '.osglecture', 'state');
      if (-e $state_directory) {
        require OLLM::State;
        my $readable = eval {
          my @results = OLLM::State->_current_results({
            project_root => $root, series_id => $manifest->{project}{id},
          });
          scalar @results;
          1;
        };
        my $error = $@; chomp $error;
        push @project_checks, { name => 'state',
          ok => $readable ? JSON::PP::true : JSON::PP::false,
          path => $state_directory,
          (!$readable ? (message => $error) : ()) };
      } else {
        push @project_checks, { name => 'state', ok => JSON::PP::true,
          status => 'not-initialized', path => $state_directory };
      }
      my $project_ok = !grep { !$_->{ok} } @project_checks;
      $project = { present => JSON::PP::true,
        ok => $project_ok ? JSON::PP::true : JSON::PP::false,
        path => $located->{path}, root => $root,
        shell_escape => $manifest->{security}{shell_escape} // 'restricted',
        checks => \@project_checks };
      $ok = 0 if !$project_ok;
    }
  } else {
    $project = { present => JSON::PP::false, ok => JSON::PP::true };
  }

  if ($plan->{format} eq 'json') {
    print JSON::PP->new->canonical->pretty->encode({
      schema  => 'org.osglecture.ollm.doctor',
      version => 1,
      ok      => $ok ? JSON::PP::true : JSON::PP::false,
      checks  => \@checks,
      tex_files => \@tex_files,
      runtime => $runtime,
      capabilities => \@capabilities,
      toml_parser => $parser,
      project => $project,
    });
  } else {
    for my $check (@checks) {
      printf "%-10s %s%s\n", $check->{program},
        defined $check->{found} ? $check->{found} : 'NOT FOUND',
        defined($check->{version}) && $check->{version} ne ''
          ? " -- $check->{version}" : '';
    }
    for my $file (@tex_files) {
      printf "%-10s %s\n", $file->{name},
        $file->{ok} ? $file->{path} : 'NOT FOUND';
    }
    printf "%-10s %s%s\n", 'LuaTeX', $runtime->{ok} ? 'OK' : 'FAILED',
      $runtime->{format_date} ? " (LaTeX $runtime->{format_date})" : '';
    for my $capability (@capabilities) {
      printf "Capability %-20s %s%s\n", $capability->{name},
        $capability->{ok} ? 'OK' : 'UNAVAILABLE',
        $capability->{required} ? '' : ' (optional)';
      print "  Repair: $capability->{remediation}\n"
        if !$capability->{ok} && $capability->{remediation};
    }
    if ($parser->{available}) {
      printf "%-10s %s %s (%s)\n", 'TOML',
        $parser->{name}, $parser->{version}, $parser->{source};
    } else {
      printf "%-10s NOT FOUND: %s\n", 'TOML', $parser->{error};
    }
    if ($project->{present}) {
      print "Project:   $project->{path}\n";
      print "Shell:     $project->{shell_escape}\n";
      for my $check (@{ $project->{checks} // [] }) {
        print "Project:   $check->{name} ", $check->{ok} ? 'OK' : 'FAILED',
          defined($check->{path}) ? " ($check->{path})" : '', "\n";
      }
    } else {
      print "Project:   none (global checks only)\n";
    }
  }
  return $ok ? 0 : 69;
}

sub _program_doctor_check {
  my ($program) = @_;
  my $found = _find_program($program);
  my $version;
  if ($found) {
    my @command = $program eq 'perl' ? ($found, '-v') : ($found, '--version');
    $version = _capture_first_line(@command);
  }
  my $ok = defined($found) && defined($version) && $version ne '';
  return { program => $program, found => $found, version => $version,
    ok => $ok ? JSON::PP::true : JSON::PP::false,
    (!$ok ? (remediation => "Install $program and ensure it is available on PATH.") : ()) };
}

sub _kpsewhich_check {
  my ($name, $required, $kpsewhich, $package) = @_;
  return { name => $name, required => $required ? JSON::PP::true : JSON::PP::false,
    package => $package, ok => JSON::PP::false,
    remediation => "Install the TeX Live package $package (tlmgr install $package)." }
      if !$kpsewhich;
  my $path = _capture_first_line($kpsewhich, $name);
  return { name => $name,
    required => $required ? JSON::PP::true : JSON::PP::false,
    package => $package,
    ok => $path ? JSON::PP::true : JSON::PP::false,
    ($path ? (path => $path) : (remediation =>
      "Install the TeX Live package $package (tlmgr install $package).")) };
}

sub _lualatex_doctor_probe {
  my ($lualatex, $document_class) = @_;
  return { ok => JSON::PP::false, message => 'lualatex is unavailable' }
    if !$lualatex;
  $DOCTOR_TEXMF_DIRECTORY //=
    tempdir('ollm-doctor-XXXXXX', TMPDIR => 1, CLEANUP => 1);
  my $directory = $DOCTOR_TEXMF_DIRECTORY;
  my $source = join '',
    ($document_class eq 'ltx-talk' ? "\\DocumentMetadata{}" : ''),
    "\\documentclass{$document_class}",
    "\\makeatletter\\typeout{OLLM-DOCTOR-FORMAT:\\fmtversion}\\makeatother",
    "\\begin{document}doctor\\end{document}";
  my @command = ($lualatex, '-interaction=nonstopmode', '-halt-on-error',
    "-output-directory=$directory", $source);
  my ($closed, $exit_code, $output) = _capture_doctor_command(@command);
  if (!$closed && $output =~ /no writeable cache path/) {
    my $cache = File::Spec->catdir($directory, 'texmf-cache');
    make_path($cache);
    local $ENV{TEXMFVAR} = $cache;
    local $ENV{TEXMFCACHE} = $cache;
    ($closed, $exit_code, $output) = _capture_doctor_command(@command);
  }
  my ($format_date) = $output =~ /OLLM-DOCTOR-FORMAT:(\d{4}-\d{2}-\d{2})/;
  my $diagnostic = $output;
  $diagnostic =~ s/\A.*?(![^\n]*(?:\n|\z))/$1/s if $diagnostic =~ /!/;
  $diagnostic = substr($diagnostic, -800) if length($diagnostic) > 800;
  $diagnostic =~ s/\s+\z//;
  return {
    ok => $closed ? JSON::PP::true : JSON::PP::false,
    exit_code => $exit_code,
    document_class => $document_class,
    (defined($format_date) ? (format_date => $format_date) : ()),
    (!$closed ? (message => 'LuaLaTeX could not compile the runtime probe',
      diagnostic => $diagnostic) : ()),
  };
}

sub _capture_doctor_command {
  my (@command) = @_;
  open my $handle, '-|', @command or return (0, 127, "cannot start command: $!");
  my $output = do { local $/; <$handle> // '' };
  my $closed = close $handle;
  return ($closed, $? >> 8, $output);
}

sub _capture_first_line {
  my (@command) = @_;
  open my $handle, '-|', @command or return;
  my $line;
  while (defined(my $candidate = <$handle>)) {
    next if $candidate =~ /\A\s*\z/;
    $line = $candidate;
    last;
  }
  close $handle;
  return if !defined $line;
  $line =~ s/[\r\n]+\z//;
  return $line;
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
  ollm [global options] [[+]build] [[+]target| | --target=<target>] [build options] [latexmk options]
  ollm [global options] [+]<report|check|clean|prune|doctor|deploy|convertconfig|newtoml>

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
  +enforce+|--enforce+  require '+' on command and target words
  --overwrite           permit replacement when project policy is explicit
  --legacy              explicitly build with ollmconfig.pl

Build options:
  --target=TARGET       select a registered project target
  --language=LANG | [+]lang=LANG
                        select a language
  --source=FILE         select the main TeX source
  --all
  --resolve
  --rebuild
  --dry-run.            print the normalized request without building
  --level=aux|build|state|all
  --scope=current|unit|series|collection
                        select build, inspection, maintenance, or deploy scope
  --stale-units         let prune remove states for missing physical units
  --debug=tex|ollm|tex+ollm
  --warnings=all|important|none
  --config=FILE
  --project-root=DIR

  Compatible unknown minus options are passed to latexmk.
HELP
}

1;
