package OLLM::Inspection;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;

use OLLM::State;

our $VERSION = '0.1.0';

sub prepare {
  my ($class, %arg) = @_;
  my $plan = $arg{plan} // die "missing inspection plan";
  my $root = abs_path($arg{project_root})
    // die "project root not found: $arg{project_root}";
  my $cwd = abs_path($arg{start_dir})
    // die "working directory not found: $arg{start_dir}";
  my $manifest = $arg{manifest} // die "missing project manifest";
  my $structure = $arg{structure} // die "missing project structure";
  my %unit = map { $_->{physical_unit} => $_ } @{ $structure->{units} };
  my $relative = File::Spec->abs2rel($cwd, $root);
  my $outside = File::Spec->file_name_is_absolute($relative)
    || $relative =~ /\A\.\.(?:[\\\/]|\z)/;
  my $physical;
  if (!$outside && $relative ne '.') {
    ($physical) = File::Spec->splitdir($relative);
    $physical = undef if !exists $unit{$physical};
  }
  my $scope = $plan->{scope};
  if (!defined $scope) {
    if ($outside && ($plan->{project_root} || $plan->{config})) {
      $scope = 'series';
    } elsif ($cwd eq $root) {
      $scope = 'series';
    } elsif (defined $physical) {
      $scope = 'current';
    } else {
      die "cannot infer report/check scope from '$cwd'; use --scope\n";
    }
  }
  die "$plan->{action} --scope=$scope must be run inside a series unit\n"
    if $scope ne 'series' && !defined $physical;
  my $target = $plan->{target} // 'slides';
  my $language = $plan->{language} // $manifest->{languages}{default};
  if ($scope eq 'current') {
    die "target '$target' is not configured for this project\n"
      if !exists $manifest->{targets}{$target};
    my %language = map { $_ => 1 }
      @{ $manifest->{targets}{$target}{languages} // [] };
    die "language '$language' is not configured for target '$target'\n"
      if !$language{$language};
  }
  return {
    action => $plan->{action}, scope => $scope, project_root => $root,
    series_id => $manifest->{project}{id}, structure => $structure,
    physical_unit => $physical, target => $target, language => $language,
  };
}

sub analyze {
  my ($class, $request) = @_;
  my $spec = {
    project_root => $request->{project_root},
    series_id => $request->{series_id},
  };
  my @all = OLLM::State->_current_results($spec);
  my %by_identity;
  my %physical_ids;
  my %integration;
  for my $result (@all) {
    my $key = _key($result);
    die "duplicate promoted document identity '" . _identity($result) . "'\n"
      if exists $by_identity{$key};
    $by_identity{$key} = $result;
    if (($result->{unit_role} // '') eq 'i') {
      $integration{$result->{doctype}}{$result->{physical_unit}} = 1;
    } else {
      $physical_ids{$result->{unit_id}}{$result->{physical_unit}} = 1;
    }
  }

  my @projections = grep {
    $request->{scope} eq 'series'
      || ($_->{physical_unit} // '') eq $request->{physical_unit}
  } @all;
  if ($request->{scope} eq 'current') {
    @projections = grep {
      ($_->{doctype} // '') eq $request->{target}
        && ($_->{language} // '') eq $request->{language}
    } @projections;
  }
  @projections = sort {
       _physical_number($request, $a) cmp _physical_number($request, $b)
    || $a->{doctype} cmp $b->{doctype}
    || $a->{language} cmp $b->{language}
    || $a->{unit_id} cmp $b->{unit_id}
  } @projections;

  my @issues;
  my %discovered = map { $_->{physical_unit} => 1 }
    @{ $request->{structure}{units} };
  for my $result (@projections) {
    if (!$discovered{$result->{physical_unit} // ''}) {
      push @issues, {
        severity => 'warning', code => 'physical-unit-missing',
        message => "promoted projection belongs to a missing physical unit",
        identity => _identity($result),
        physical_unit => $result->{physical_unit},
      };
    }
  }
  if ($request->{action} eq 'check' && $request->{scope} eq 'current'
      && !@projections) {
    push @issues, {
      severity => 'error', code => 'current-missing',
      message => "required current projection is not promoted",
      physical_unit => $request->{physical_unit},
      doctype => $request->{target}, language => $request->{language},
    };
  }
  for my $unit_id (sort keys %physical_ids) {
    my @physical = sort keys %{ $physical_ids{$unit_id} };
    push @issues, {
      severity => 'error', code => 'unit-id-ambiguous',
      message => "logical unit '$unit_id' maps to multiple physical units",
      unit_id => $unit_id, physical_units => \@physical,
    } if @physical > 1;
  }
  for my $doctype (sort keys %integration) {
    my @physical = sort keys %{ $integration{$doctype} };
    push @issues, {
      severity => 'error', code => 'integration-unit-ambiguous',
      message => "document type '$doctype' has more than one integration unit",
      doctype => $doctype, physical_units => \@physical,
    } if @physical > 1;
  }

  my %required;
  my @queue = @projections;
  while (@queue) {
    my $consumer = shift @queue;
    my $consumer_key = _key($consumer);
    my $consumer_identity = _identity($consumer);
    next if $required{$consumer_key}++;
    _validate_projection($spec, $consumer, \@issues);
    for my $dependency (@{ $consumer->{dependencies} // [] }) {
      next if ($dependency->{kind} // '') ne 'external-reference'
        && ($dependency->{kind} // '') ne 'integration';
      my $key = _key($dependency);
      my $identity = _identity($dependency);
      my $target = $by_identity{$key};
      if (!$target) {
        push @issues, {
          severity => 'error', code => 'dependency-missing',
          message => "required projection '$identity' is not promoted",
          consumer => $consumer_identity, %$dependency,
        };
        next;
      }
      if (($dependency->{target_generation} // '')
          ne ($target->{generation_id} // '')) {
        push @issues, {
          severity => 'error', code => 'dependency-stale',
          message => "consumer used an older target generation",
          consumer => $consumer_identity, target => $identity,
          used_generation => $dependency->{target_generation},
          current_generation => $target->{generation_id},
        };
      }
      if (($dependency->{kind} // '') eq 'external-reference'
          && defined($dependency->{label})
          && !_export_has_label($spec, $target, $dependency->{label})) {
        push @issues, {
          severity => 'error', code => 'label-missing',
          message => "required label '$dependency->{label}' is not exported",
          consumer => $consumer_identity, target => $identity,
          label => $dependency->{label}, property => $dependency->{property},
        };
      }
      push @queue, $target if !$required{$key};
    }
  }

  my %selected_physical = map { ($_->{physical_unit} // '') => 1 } @projections;
  my @units = grep {
    $request->{scope} eq 'series'
      || $_->{physical_unit} eq $request->{physical_unit}
  } @{ $request->{structure}{units} };
  my @unit_report = map {
    +{
      %$_,
      status => $selected_physical{$_->{physical_unit}}
        ? 'available' : 'dormant',
    }
  } @units;
  my @report_results = sort {
       _physical_number($request, $a) cmp _physical_number($request, $b)
    || $a->{doctype} cmp $b->{doctype}
    || $a->{language} cmp $b->{language}
    || $a->{unit_id} cmp $b->{unit_id}
  } grep { $required{_key($_)} } values %by_identity;
  my @projection_report = map {
    my $identity = _identity($_);
    +{
      identity => $identity,
      required => $required{_key($_)} ? 1 : 0,
      status => 'available',
      unit_id => $_->{unit_id}, physical_unit => $_->{physical_unit},
      unit_role => $_->{unit_role}, doctype => $_->{doctype},
      language => $_->{language}, generation_id => $_->{generation_id},
      job_id => $_->{job_id}, dependencies => $_->{dependencies} // [],
    }
  } @report_results;
  return {
    scope => $request->{scope}, units => \@unit_report,
    projections => \@projection_report, issues => \@issues,
    ok => scalar(grep { ($_->{severity} // '') eq 'error' } @issues) ? 0 : 1,
  };
}

sub _validate_projection {
  my ($spec, $result, $issues) = @_;
  my $generation = OLLM::State->_generation_directory($spec, $result);
  my @files = qw(result.json document.pdf);
  push @files, 'reference.osgref.aux'
    if ($result->{unit_role} // '') ne 'i';
  for my $file (@files) {
    my $path = File::Spec->catfile($generation, $file);
    push @$issues, {
      severity => 'error', code => 'artifact-missing',
      message => "promoted file '$file' is missing",
      identity => _identity($result), path => $path,
    } if !-f $path || !-s _;
  }
}

sub _export_has_label {
  my ($spec, $target, $label) = @_;
  my $path = File::Spec->catfile(
    OLLM::State->_generation_directory($spec, $target),
    'reference.osgref.aux',
  );
  return 0 if !-f $path;
  open my $handle, '<:raw', $path or return 0;
  my $content = do { local $/; <$handle> };
  close $handle;
  return $content =~ /\\newlabel\{\Q$label\E\}\{/ ? 1 : 0;
}

sub _identity {
  my ($value) = @_;
  return join '/', map { $value->{$_} // '' }
    qw(unit_id doctype language);
}

sub _key {
  my ($value) = @_;
  return join "\0", map { $value->{$_} // '' }
    qw(unit_id doctype language);
}

sub _physical_number {
  my ($request, $result) = @_;
  for my $unit (@{ $request->{structure}{units} }) {
    return $unit->{physical_number}
      if $unit->{physical_unit} eq ($result->{physical_unit} // '');
  }
  return '999';
}

1;
