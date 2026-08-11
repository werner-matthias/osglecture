package OLLM::Inspection;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;

use OLLM::State;
use OLLM::Version qw($VERSION);
use OLLM::BuildFile;
use OLLM::Path;

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
  my ($relative, $outside) = OLLM::Path::classify($cwd, $root);
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
    manifest => $manifest, manifest_path => $arg{manifest_path},
    definitions => $arg{definitions},
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
  my %structure = map { $_->{physical_unit} => $_ }
    @{ $request->{structure}{units} };
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
    my $unit = $structure{$result->{physical_unit} // ''};
    if ($unit) {
      for my $field (qw(unit_role unit_scope)) {
        next if !defined $result->{$field};
        push @issues, {
          severity => 'error', code => "$field-mismatch",
          message => "promoted $field does not match the current unit structure",
          identity => _identity($result), stored => $result->{$field},
          current => $unit->{$field},
        } if ($result->{$field} // '') ne ($unit->{$field} // '');
      }
    }
    my $target_name = $result->{target} // $result->{doctype};
    my $target = $request->{manifest}{targets}{$target_name};
    if (!$target) {
      push @issues, { severity => 'error', code => 'target-unconfigured',
        message => "promoted target '$target_name' is no longer configured",
        identity => _identity($result), target => $target_name };
    } elsif (!grep { $_ eq ($result->{language} // '') }
        @{ $target->{languages} // [] }) {
      push @issues, { severity => 'error', code => 'language-unconfigured',
        message => "promoted language '$result->{language}' is no longer configured for target '$target_name'",
        identity => _identity($result), target => $target_name,
        language => $result->{language} };
    }
    _validate_current_contract($request, $result, \@issues)
      if $request->{definitions} && $unit && $target;
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
      my $dependency_status = OLLM::State->dependency_status(
        $spec, $dependency, $target,
      );
      if ($dependency_status eq 'stale') {
        push @issues, {
          severity => 'error', code => 'dependency-stale',
          message => "consumer used an older target generation",
          consumer => $consumer_identity, target => $identity,
          used_generation => $dependency->{target_generation},
          current_generation => $target->{generation_id},
        };
      }
      if ($dependency_status eq 'label-missing') {
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
    my $generation = OLLM::State->_generation_directory($spec, $_);
    +{
      identity => $identity,
      required => $required{_key($_)} ? 1 : 0,
      status => 'available',
      unit_id => $_->{unit_id}, physical_unit => $_->{physical_unit},
      unit_role => $_->{unit_role}, doctype => $_->{doctype},
      language => $_->{language}, generation_id => $_->{generation_id},
      job_id => $_->{job_id}, dependencies => $_->{dependencies} // [],
      target => $_->{target} // $_->{doctype}, chapter => $_->{chapter} // '',
      ordinal => $_->{ordinal} // '', unit_scope => $_->{unit_scope},
      config_signature => $_->{config_signature},
      current_config_signature => $_->{current_config_signature},
      shell_escape => $_->{shell_escape}, bundle_preset => $_->{bundle_preset},
      structure_signature => $_->{structure_signature},
      project_config_signature => $_->{project_config_signature},
      artifact => File::Spec->catfile($generation, 'document.pdf'),
      reference_export => ($_->{unit_role} // '') eq 'i' ? undef
        : File::Spec->catfile($generation, 'reference.osgref.aux'),
    }
  } @report_results;
  return {
    scope => $request->{scope}, units => \@unit_report,
    projections => \@projection_report, issues => \@issues,
    configuration => {
      manifest => $request->{manifest_path},
      bundle_preset => $request->{manifest}{bundle_preset},
      structure_signature => $request->{structure}{signature},
      effective_tex => {
        available => 0,
        reason => 'effective/enforced TeX values are not exported yet',
      },
    },
    ok => scalar(grep { ($_->{severity} // '') eq 'error' } @issues) ? 0 : 1,
  };
}

sub _validate_current_contract {
  my ($request, $result, $issues) = @_;
  my $target_name = $result->{target} // $result->{doctype};
  my $resolved = {
    request => {
      action => 'build', context => 'series', project_root => $request->{project_root},
      series_id => $request->{series_id}, target => $target_name,
      language => $result->{language}, source => 'main.tex',
    },
    configuration => {
      kind => 'toml', path => $request->{manifest_path},
      definitions => $request->{definitions}, structure => $request->{structure},
    },
  };
  my $directory = File::Spec->catdir(
    $request->{project_root}, $result->{physical_unit},
  );
  my $expected = eval {
    OLLM::BuildFile->build_spec(
      resolved => $resolved, manifest => $request->{manifest},
      unit_directory => $directory, target => $target_name,
      language => $result->{language},
    )
  };
  if (!$expected) {
    my $error = $@ || 'cannot reconstruct current build contract'; chomp $error;
    push @$issues, { severity => 'error', code => 'contract-unavailable',
      message => $error, identity => _identity($result) };
    return;
  }
  push @$issues, { severity => 'error', code => 'job-id-mismatch',
    message => 'promoted job id does not match the current build contract',
    identity => _identity($result), stored => $result->{job_id},
    current => $expected->{job_id} }
    if ($result->{job_id} // '') ne $expected->{job_id};
  push @$issues, { severity => 'error', code => 'ordinal-mismatch',
    message => 'promoted ordinal does not match the current unit structure',
    identity => _identity($result), stored => $result->{ordinal},
    current => $expected->{logical_ordinal} }
    if ($result->{ordinal} // '') ne $expected->{logical_ordinal};
  push @$issues, { severity => 'error', code => 'shell-escape-mismatch',
    message => 'promoted shell-escape policy differs from the current policy',
    identity => _identity($result), stored => $result->{shell_escape},
    current => $expected->{shell_escape} }
    if defined($result->{shell_escape})
      && $result->{shell_escape} ne $expected->{shell_escape};
  $result->{current_config_signature} = $expected->{config_signature};
  push @$issues, { severity => 'warning', code => 'configuration-changed',
    message => 'the aggregate build configuration has changed; a rebuild is recommended',
    identity => _identity($result), stored => $result->{config_signature},
    current => $expected->{config_signature} }
    if ($result->{config_signature} // '') ne $expected->{config_signature};
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
