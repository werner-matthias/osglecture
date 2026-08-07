package OLLM::Deployment;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use File::Basename qw(basename dirname);
use File::Copy qw(copy);
use File::Spec;
use File::Temp qw(tempfile);

use OLLM::State;

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
  my $relative = File::Spec->abs2rel($cwd, $root);
  my $physical;
  if ($relative ne '.' && !File::Spec->file_name_is_absolute($relative)
      && $relative !~ /\A\.\.(?:[\\\/] |\z)/x) {
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
    die "more than one integration unit is promoted for $doctype"
      if keys(%{ $collections{$doctype} }) > 1;
  }
  die "no promoted artifact matches deployment scope '$scope'"
    if !@results;
  return {
    project_root => $root, series_id => $manifest->{project}{id},
    scope => $scope, deployment => $deployment,
    overwrite_policy => $manifest->{security}{deployment}{overwrite}
      // 'explicit',
    overwrite => $plan->{overwrite} ? 1 : 0,
    results => [sort {
         $a->{physical_unit} cmp $b->{physical_unit}
      || $a->{doctype} cmp $b->{doctype}
      || $a->{language} cmp $b->{language}
    } @results],
  };
}

sub execute {
  my ($class, $request) = @_;
  my (@items, %unavailable);
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
        message => 'promoted PDF artifact is missing or empty' };
      next;
    }
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
        _copy_one($source, $destination, $request->{overwrite_policy},
          $request->{overwrite});
      };
      if (!defined $status) {
        my $error = $@ || 'unknown copy error'; chomp $error;
        push @items, { status => 'failed', path => $destination,
          message => $error };
      } else {
        push @items, { status => $status, path => $destination,
          source => $source };
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
  my %value = (
    series => $request->{series_id}, unit => $result->{unit_id},
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
  my ($source, $destination, $policy, $overwrite) = @_;
  if (-f $destination) {
    return 'unchanged' if _digest($source) eq _digest($destination);
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

sub _digest {
  my ($path) = @_;
  open my $handle, '<:raw', $path or die "cannot read '$path': $!";
  my $sha = Digest::SHA->new(256); $sha->addfile($handle);
  close $handle or die "cannot close '$path': $!";
  return $sha->hexdigest;
}

1;
