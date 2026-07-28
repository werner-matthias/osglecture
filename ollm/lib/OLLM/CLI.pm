package OLLM::CLI;

use v5.30;
use strict;
use warnings;

use Cwd qw(getcwd);
use File::Basename qw(dirname);
use File::Spec;
use JSON::PP;
use OLLM::Config;

our $VERSION = '0.12.0-dev';

my %ACTION = map { $_ => 1 } qw(build report check clean prune doctor);
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

  if ($plan->{action} eq 'doctor') {
    return $class->_doctor($plan);
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

  if ($plan->{dry_run}) {
    $class->_print_plan($plan, $resolved);
    return 0;
  }

  if ($resolved->{configuration}{kind} eq 'toml') {
    if ($plan->{resolve}) {
      print STDERR
        "ollm: --resolve is not implemented by the new build executor yet\n";
      return 69;
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

  my @command = $class->_legacy_command($plan, $rc);
  {
    no warnings 'exec';
    exec { $command[0] } @command;
  }
  print STDERR "ollm: cannot execute latexmk: $!\n";
  return 69;
}

sub _legacy_command {
  my ($class, $plan, $rc) = @_;
  my @legacy;
  push @legacy, '+' . $plan->{target} if defined $plan->{target};
  push @legacy, '+lang=' . $plan->{language} if defined $plan->{language};
  push @legacy, '+debug' if defined $plan->{debug};
  push @legacy, '-gg' if $plan->{rebuild};
  push @legacy, @{ $plan->{legacy_args} };
  push @legacy, @{ $plan->{latexmk_args} };
  push @legacy, $plan->{source} if defined $plan->{source};
  return ('latexmk', '-norc', '-r', $rc, @legacy);
}

sub parse {
  my ($class, @argv) = @_;
  my %plan = (
    action       => 'build',
    color        => 'auto',
    format       => 'text',
    legacy_args  => [],
    latexmk_args => [],
    operands     => [],
    warnings     => 'important',
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

    if ($arg eq '--help' || $arg eq '-h' || $arg eq '+help' || $arg eq '+h') {
      $plan{help} = 1;
      next;
    }
    if ($arg eq '--version' || $arg eq '+version') {
      $plan{version} = 1;
      next;
    }

    if ($ACTION{$arg}) {
      die "more than one action specified" if $action_seen;
      $plan{action} = $arg;
      $action_seen = 1;
      next;
    }

    my $compat = $arg;
    $compat =~ s/^\+//;
    if (exists $TARGET_ALIAS{$compat}) {
      die "more than one document target specified" if defined $plan{target};
      $plan{target} = $TARGET_ALIAS{$compat};
      next;
    }

    if ($compat =~ /^(?:standalone|publish|verbose|nosocket)$/) {
      push @{ $plan{legacy_args} }, '+' . $compat;
      next;
    }
    if ($arg eq '+force+') {
      push @{ $plan{legacy_args} }, $arg;
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

    if ($arg =~ /^(?:--language=|\+?lang=)(.+)$/) {
      $plan{language} = $1;
      next;
    }
    if ($arg eq '--language') {
      $plan{language} = _take_value($arg, \@argv);
      next;
    }
    if ($arg =~ /^--source=(.+)$/) {
      $plan{source} = $1;
      next;
    }
    if ($arg eq '--source') {
      $plan{source} = _take_value($arg, \@argv);
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
  }

  $plan{target} //= 'slides' if $plan{action} eq 'build';
  return \%plan;
}

sub _take_value {
  my ($option, $argv) = @_;
  die "$option requires a value" if !@$argv;
  return shift @$argv;
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
  return $ok ? 0 : 1;
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
  ollm [global options] [build] [target] [build options] [latexmk options]
  ollm [global options] <report|check|clean|prune|doctor>

Targets:
  slides (aliases: beamer, presentation)
  handout
  script (alias: article)

Implemented new commands:
  build --dry-run       print the normalized request without building
  doctor                inspect the local Perl and TeX toolchain

General options:
  --help                show this help
  --version             show the OLLM version
  --format=text|json    select human- or machine-readable output
  --color=auto|always|never
  --non-interactive

Build options:
  --language=LANG       select a language
  --source=FILE         select the main TeX source
  --all
  --resolve
  --rebuild
  --dry-run
  --debug=tex|ollm|tex+ollm
  --warnings=all|important|none
  --config=FILE
  --project-root=DIR

Compatibility:
  Bare targets, lang=en, +lang=en, +script, and debug remain accepted.
  Unknown minus options are passed to latexmk for legacy builds.
HELP
}

1;
