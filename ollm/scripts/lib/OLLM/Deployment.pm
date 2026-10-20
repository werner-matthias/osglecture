package OLLM::Deployment;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use Digest::SHA ();
use File::Basename qw(basename dirname);
use File::Copy qw(copy);
use File::Spec;
use File::Temp qw(tempdir tempfile);

use OLLM::Config;
use OLLM::Digest;
use OLLM::Path;
use OLLM::State;

# qpdf option for each boolean permission of OLLM::Config::PERMISSION_FLAGS.
# The accessibility bit is missing on purpose: qpdf ignores it for 256-bit
# encryption, so offering it would promise a restriction that is not set.
my %QPDF_OPTION = (
  extract => 'extract', modify => 'modify-other', annotate => 'annotate',
  form => 'form', assemble => 'assemble',
);

sub prepare {
  my ($class, %arg) = @_;
  my $plan = $arg{plan} // die "missing deployment plan";
  my $manifest = $arg{manifest} // die "missing project manifest";
  my $deployment = $manifest->{deployment}
    // die "project has no deployment configuration";
  my $root = abs_path($arg{project_root})
    // die "project root not found: $arg{project_root}";
  my $cwd = abs_path($arg{start_dir})
    // die "working directory not found: $arg{start_dir}";
  my $structure = $arg{structure} // die "missing project structure";
  my %unit = map { $_->{physical_unit} => $_ } @{ $structure->{units} };
  my ($relative, $outside) = OLLM::Path::classify($cwd, $root);
  my $physical;
  if (!$outside && $relative ne '.') {
    ($physical) = File::Spec->splitdir($relative);
    $physical = undef if !exists $unit{$physical};
  }
  my $scope = $plan->{scope};
  $scope //= $cwd eq $root ? 'series' : defined($physical) ? 'current' : undef;
  die "cannot infer deployment scope from '$cwd'; use --scope"
    if !defined $scope;
  die "deploy --scope=$scope must be run inside a series unit"
    if ($scope eq 'current' || $scope eq 'unit') && !defined $physical;

  my $spec = { project_root => $root, series_id => $manifest->{project}{id} };
  my @results = OLLM::State->_current_results($spec);
  my @doctypes = $plan->{all}
    ? sort keys %{ $deployment->{types} }
    : ($plan->{target} // 'slides');
  my %doctype = map { $_ => 1 } @doctypes;
  die "no deployment rule for document type '$_'"
    for grep { !exists $deployment->{types}{$_} } @doctypes;
  @results = grep { $doctype{$_->{doctype} // ''} } @results;
  @results = grep { ($_->{language} // '') eq $plan->{language} } @results
    if defined $plan->{language};

  if ($scope eq 'current') {
    @results = grep { ($_->{physical_unit} // '') eq $physical } @results;
    if (!$plan->{all}) {
      my $language = $plan->{language} // $manifest->{languages}{default};
      @results = grep { ($_->{language} // '') eq $language } @results;
    }
  } elsif ($scope eq 'unit') {
    @results = grep { ($_->{physical_unit} // '') eq $physical } @results;
  } elsif ($scope eq 'collection') {
    @results = grep { ($_->{unit_role} // '') eq 'i' } @results;
  } elsif ($scope eq 'series') {
    @results = grep {
      my $mode = $deployment->{types}{$_->{doctype}}{series}
        // $deployment->{series} // 'both';
      $mode eq 'both'
        || ($mode eq 'units' && ($_->{unit_role} // '') ne 'i')
        || ($mode eq 'collection' && ($_->{unit_role} // '') eq 'i');
    } @results;
  } else {
    die "invalid deployment scope '$scope'";
  }

  my %collections;
  for my $result (grep { ($_->{unit_role} // '') eq 'i' } @results) {
    $collections{$result->{doctype}}{$result->{physical_unit}} = 1;
  }
  for my $doctype (keys %collections) {
    die "more than one integration unit provides a $doctype collection"
      if keys(%{ $collections{$doctype} }) > 1;
  }
  die "no built PDF matches deployment scope '$scope'"
    if !@results;
  return {
    project_root => $root, series_id => $manifest->{project}{id},
    scope => $scope, deployment => $deployment,
    overwrite_policy => $manifest->{security}{overwrite} // 'explicit',
    overwrite => $plan->{overwrite} ? 1 : 0,
    permissions => $plan->{permissions},
    owner_password => $plan->{owner_password},
    results => [sort {
         $a->{physical_unit} cmp $b->{physical_unit}
      || $a->{doctype} cmp $b->{doctype}
      || $a->{language} cmp $b->{language}
    } @results],
  };
}

# --permissions=all grants everything; otherwise a comma-separated list of
# KEY=VALUE entries with the same keys as a manifest permissions table.
sub parse_permissions {
  my ($class, $spec) = @_;
  return {} if $spec eq 'all';
  die "--permissions needs 'all' or KEY=VALUE entries\n" if $spec eq '';
  my %flag = map { $_ => 1 } @OLLM::Config::PERMISSION_FLAGS;
  my %permissions;
  for my $entry (split /,/, $spec, -1) {
    my ($key, $value) = $entry =~ /\A\s*([a-z]+)\s*=\s*([a-z]+)\s*\z/
      or die "invalid --permissions entry '$entry'; expected KEY=VALUE or 'all'\n";
    die "--permissions sets '$key' more than once\n"
      if exists $permissions{$key};
    if ($key eq 'print') {
      die "invalid --permissions value print=$value; expected full, low, or none\n"
        if $value !~ /\A(?:full|low|none)\z/;
      $permissions{print} = $value;
    } elsif ($flag{$key}) {
      die "invalid --permissions value $key=$value; expected true or false\n"
        if $value !~ /\A(?:true|false|yes|no)\z/;
      $permissions{$key} = $value =~ /\A(?:true|yes)\z/ ? 1 : 0;
    } else {
      die "unknown --permissions key '$key'; expected "
        . join(', ', 'print', @OLLM::Config::PERMISSION_FLAGS) . "\n";
    }
  }
  return \%permissions;
}

# An explicit --permissions value replaces the configured permissions of
# every document type for this run.
sub permissions_for {
  my ($class, $request, $result) = @_;
  return $request->{permissions}
    // $request->{deployment}{types}{$result->{doctype}}{permissions} // {};
}

sub requires_qpdf {
  my ($class, $request) = @_;
  return scalar grep {
    restrictions($class->permissions_for($request, $_)) ne ''
  } @{ $request->{results} };
}

sub execute {
  my ($class, $request) = @_;
  my (@items, %unavailable, $workspace);
  for my $result (@{ $request->{results} }) {
    my $rule = $request->{deployment}{types}{$result->{doctype}};
    my $override = ($rule->{units} // {})->{$result->{unit_id}};
    my $template = ($result->{unit_role} // '') eq 'i'
      ? ($rule->{collection_filename} // $rule->{filename})
      : (($override // {})->{filename} // $rule->{filename});
    my $filename = _filename($template, $request, $result);
    my $generation = OLLM::State->_generation_directory($request, $result);
    my $source = File::Spec->catfile($generation, 'document.pdf');
    if (!-f $source || !-s _) {
      push @items, { status => 'failed', source => $source,
        message => 'the built PDF is missing or empty' };
      next;
    }
    my $permissions = $class->permissions_for($request, $result);
    my $restrictions = restrictions($permissions);
    my ($artifact, $same) = ($source, undef);
    if ($restrictions ne '') {
      $workspace //= tempdir('ollm-deploy-XXXXXX', TMPDIR => 1, CLEANUP => 1);
      my $restricted = eval {
        _restrict($request->{qpdf}, $source, $permissions, $workspace,
          $request->{owner_password});
      };
      if (!$restricted) {
        my $error = $@ || 'cannot apply PDF permissions'; chomp $error;
        push @items, { status => 'failed', source => $source,
          restrictions => $restrictions, message => $error };
        next;
      }
      $artifact = $restricted->{path};
      $same = sub { _same_restricted($request->{qpdf}, $restricted, shift) };
    }
    my %restricted = $restrictions ne '' ? (restrictions => $restrictions) : ();
    for my $configured (@{ $rule->{paths} }) {
      my $directory = File::Spec->rel2abs($configured, $request->{project_root});
      my $key = File::Spec->canonpath($directory);
      if ($unavailable{$key}) {
        push @items, { status => 'skipped', path => $directory,
          message => 'destination was already found unavailable' };
        next;
      }
      if (!-d $directory) {
        $unavailable{$key} = 1;
        push @items, { status => 'failed', path => $directory,
          message => 'destination directory does not exist; a volume or network share may not be mounted' };
        next;
      }
      my $destination = File::Spec->catfile($directory, $filename);
      my $status = eval {
        _copy_one($artifact, $destination, $request->{overwrite_policy},
          $request->{overwrite}, $same);
      };
      if (!defined $status) {
        my $error = $@ || 'unknown copy error'; chomp $error;
        push @items, { status => 'failed', path => $destination,
          %restricted, message => $error };
      } else {
        push @items, { status => $status, path => $destination,
          source => $source, %restricted };
      }
    }
  }
  my $failed = grep { $_->{status} eq 'failed' } @items;
  return { ok => $failed ? 0 : 1, items => \@items };
}

sub _filename {
  my ($template, $request, $result) = @_;
  my %role = (content => '', integration => '',
    %{ $request->{deployment}{roles} // {} });
  my $semantic_role = ($result->{unit_role} // '') eq 'a' ? 'appendix'
    : ($result->{unit_role} // '') eq 'e' ? 'excursus'
    : ($result->{unit_role} // '') eq 'i' ? 'integration'
    : ($result->{unit_role} // 'content');
  my ($slug) = ($result->{physical_unit} // '')
    =~ /\A\d{3}[a-z]{0,2}-(?:[aei]-)?(.+)\z/;
  my %value = (
    series => $request->{series_id}, unit => $result->{unit_id},
    slug => $slug,
    ordinal => $result->{ordinal}, chapter => $result->{chapter},
    doctype => $result->{doctype}, lang => $result->{language},
    role => $role{$semantic_role},
  );
  my $output = $template;
  $output =~ s{\{([A-Za-z][A-Za-z0-9_-]*)(?::0([1-9][0-9]*))?\}}
    {_placeholder($1, $2, \%value)}ge;
  die "invalid deployment filename '$output'; paths are not allowed in filename templates"
    if $output eq '' || $output eq '.' || $output eq '..'
      || $output =~ m{[\\/\0\r\n]};
  return $output;
}

sub _placeholder {
  my ($name, $width, $value) = @_;
  die "unknown deployment filename placeholder '{$name}'"
    if !exists $value->{$name};
  die "deployment filename placeholder '{$name}' has no value"
    if !defined($value->{$name})
      || ($value->{$name} eq '' && $name ne 'role');
  my $rendered = $value->{$name} // '';
  if (defined $width) {
    my ($number, $suffix) = $name eq 'ordinal'
      ? ($rendered =~ /\A([0-9]+)((?:e|ap)[0-9]+)?\z/)
      : ($rendered =~ /\A([0-9]+)()\z/);
    die "deployment placeholder '{$name}:0$width}' requires a decimal value"
      if !defined $number;
    $number = ('0' x ($width - length($number))) . $number
      if length($number) < $width;
    $rendered = $number . ($suffix // '');
  }
  return $rendered;
}

sub _copy_one {
  my ($source, $destination, $policy, $overwrite, $same) = @_;
  if (-f $destination) {
    return 'unchanged' if $same ? $same->($destination)
      : _digest($source) eq _digest($destination);
    die "destination exists; use --overwrite"
      if $policy eq 'explicit' && !$overwrite;
  } elsif (-e $destination) {
    die "destination exists and is not a regular file";
  }
  my ($temporary, $tempname) = tempfile('.ollm-deploy-XXXXXX',
    DIR => dirname($destination), UNLINK => 0);
  close $temporary or die "cannot close temporary deployment file: $!";
  eval {
    copy($source, $tempname) or die "cannot copy deployment artifact: $!";
    if (!rename($tempname, $destination)) {
      if (-f $destination && ($policy eq 'automatic' || $overwrite)) {
        unlink $destination or die "cannot replace deployment artifact: $!";
        rename($tempname, $destination)
          or die "cannot install deployment artifact: $!";
      } else {
        die "cannot install deployment artifact: $!";
      }
    }
    1;
  } or do {
    my $error = $@ || 'unknown deployment copy error';
    unlink $tempname if -e $tempname;
    die $error;
  };
  return 'copied';
}

# Canonical text of the permissions that are actually withheld; empty when
# the copy needs no encryption at all.
sub restrictions {
  my ($permissions) = @_;
  my @restricted;
  push @restricted, "print=$permissions->{print}"
    if ($permissions->{print} // 'full') ne 'full';
  push @restricted, map { "$_=false" }
    grep { exists $permissions->{$_} && !$permissions->{$_} }
      @OLLM::Config::PERMISSION_FLAGS;
  return join ',', @restricted;
}

# The deployed copy opens without a password (empty user password). Unless
# --owner-password names one, the owner password is random and discarded: the
# restrictions are a deliberate speed bump for readers, not access control,
# and the unrestricted original stays in the project state.
sub _restrict {
  my ($qpdf, $source, $permissions, $workspace, $password) = @_;
  die "PDF permissions require qpdf, which was not found on PATH\n"
    if !$qpdf;
  my (undef, $path) = tempfile('restricted-XXXXXX', DIR => $workspace,
    SUFFIX => '.pdf', OPEN => 0);
  my $owner = $password // substr(
    Digest::SHA::sha256_hex(join ':', time, $$, rand, $source), 0, 32);
  my @options = ('--print=' . ($permissions->{print} // 'full'),
    map { "--$QPDF_OPTION{$_}=" . (($permissions->{$_} // 1) ? 'y' : 'n') }
      @OLLM::Config::PERMISSION_FLAGS);
  _qpdf($qpdf, '--encrypt', '', $owner, '256', @options, '--',
    $source, $path);
  return { path => $path, workspace => $workspace, password => $password };
}

# Encryption uses random salts and IVs, so two restricted copies of the same
# artifact never agree byte for byte. They are the same deployment when their
# encryption parameters match and their decrypted, qpdf-normalized forms do.
# This relies on qpdf keeping the source's document ID, which LuaLaTeX always
# writes; a source without one is merely reported as different every time.
# With an explicit owner password, a copy locked with another one differs.
sub _same_restricted {
  my ($qpdf, $restricted, $destination) = @_;
  my $password = $restricted->{password};
  $restricted->{encryption} //=
    _encryption($qpdf, $restricted->{path}, $password);
  my $encryption = eval { _encryption($qpdf, $destination, $password) };
  return 0 if !defined($encryption) || $encryption ne $restricted->{encryption};
  $restricted->{normalized} //= _normalized_digest($qpdf, $restricted->{path},
    $restricted->{workspace});
  my $normalized = eval {
    _normalized_digest($qpdf, $destination, $restricted->{workspace});
  };
  return defined($normalized) && $normalized eq $restricted->{normalized};
}

sub _encryption {
  my ($qpdf, $path, $password) = @_;
  open my $handle, '-|', $qpdf,
    (defined $password ? "--password=$password" : ()),
    '--show-encryption', $path
    or die "cannot run qpdf: $!\n";
  my @lines = grep { /\A(?:R = |P = |Supplied password is )/ } <$handle>;
  close $handle;
  _qpdf_status();
  return join '', @lines;
}

sub _normalized_digest {
  my ($qpdf, $path, $workspace) = @_;
  my (undef, $normalized) = tempfile('normalized-XXXXXX', DIR => $workspace,
    SUFFIX => '.pdf', OPEN => 0);
  my $digest = eval {
    _qpdf($qpdf, '--static-id', '--decrypt', $path, $normalized);
    _digest($normalized);
  };
  my $error = $@;
  unlink $normalized;
  die $error if !defined $digest;
  return $digest;
}

sub _qpdf {
  my ($qpdf, @arguments) = @_;
  my $status = system { $qpdf } $qpdf, @arguments;
  die "cannot run qpdf: $!\n" if $status == -1;
  _qpdf_status();
}

# qpdf exits with 3 when it succeeded with warnings.
sub _qpdf_status {
  die "qpdf was terminated by signal " . ($? & 127) . "\n" if $? & 127;
  my $code = $? >> 8;
  die "qpdf failed with exit code $code\n" if $code != 0 && $code != 3;
}

sub _digest {
  my ($path) = @_;
  return OLLM::Digest::sha256_hex_of_file($path);
}

1;
