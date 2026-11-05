package OLLM::Resolver;

use v5.30;
use strict;
use warnings;

use File::Spec;

use OLLM::BuildFile;
use OLLM::Executor;
use OLLM::State;
use OLLM::Version qw($VERSION);

sub execute {
  my ($class, %arg) = @_;
  my $resolved = $arg{resolved} // die "missing resolved build request";
  my $request = $resolved->{request};
  die "--resolve is available only for series builds"
    if ($request->{context} // '') ne 'series';
  die "--resolve requires an ordinary build action"
    if grep { $_ eq '-c' || $_ eq '-C' || $_ eq '-pvc' }
      @{ $request->{latexmk_args} // [] };

  my @roots = $resolved->{build_specs}
    ? @{ $resolved->{build_specs} }
    : ($resolved->{build_spec});
  my @pending = @roots;
  my $maximum = $resolved->{configuration}{resolve_max_rounds} // 8;

  for my $round (1 .. $maximum) {
    my $round_request = {
      %$resolved,
      request => { %$request, resolve => 0 },
      build_specs => \@pending,
    };
    delete $round_request->{build_spec};
    my $status = OLLM::Executor->execute(
      resolved => $round_request,
      latexmk_rc => $arg{latexmk_rc},
      (exists $arg{runner} ? (runner => $arg{runner}) : ()),
    );
    return $status if $status;

    my @current = OLLM::State->_current_results({
      project_root => $request->{project_root}, series_id => $request->{series_id},
    });
    my %identity = map { (_key($_) => $_) } @current;
    my (%physical, %integration);
    for my $result (@current) {
      if (($result->{unit_role} // '') eq 'i') {
        $integration{$result->{doctype}}{$result->{physical_unit}} = 1;
        next;
      }
      $physical{$result->{unit_id}}{$result->{physical_unit}} = 1;
    }
    my @queue;
    for my $root (@roots) {
      my @match = grep {
        ($_->{physical_unit} // '') eq $root->{physical_unit}
          && ($_->{doctype} // '') eq $root->{doctype}
          && ($_->{language} // '') eq $root->{language}
      } @current;
      die "resolved root projection '$root->{job_id}' was not promoted\n"
        if @match != 1;
      push @queue, $match[0];
    }

    my (%visited, %scheduled);
    my @next;
    while (@queue) {
      my $consumer = shift @queue;
      next if $visited{_key($consumer)}++;
      for my $dependency (@{ $consumer->{dependencies} // [] }) {
        next if ($dependency->{kind} // '') ne 'external-reference'
          && ($dependency->{kind} // '') ne 'integration';
        my $target = $identity{_key($dependency)};
        if (!$target) {
          my @directories = sort keys %{
            ($dependency->{kind} // '') eq 'integration'
              ? ($integration{$dependency->{doctype}} // {})
              : ($physical{$dependency->{unit_id}} // {})
          };
          my $description = ($dependency->{kind} // '') eq 'integration'
            ? "integration for document type '$dependency->{doctype}'"
            : "logical unit '$dependency->{unit_id}'";
          die "cannot resolve $description: its physical unit is unknown; "
            . "build that unit once before resolving references to it\n"
            if !@directories;
          die "cannot resolve ambiguous $description\n" if @directories > 1;
          my $spec = $class->_build_spec($resolved, $dependency, $directories[0]);
          push @next, $spec if !$scheduled{$spec->{job_id}}++;
          next;
        }
        my $state = OLLM::State->dependency_status(
          { project_root => $request->{project_root}, series_id => $request->{series_id} },
          $dependency, $target,
        );
        die "required label '$dependency->{label}' is not exported by "
          . "'$dependency->{unit_id}'\n" if $state eq 'label-missing';
        if ($state eq 'stale') {
          my $spec = $class->_build_spec(
            $resolved, $consumer, $consumer->{physical_unit},
          );
          push @next, $spec if !$scheduled{$spec->{job_id}}++;
        }
        push @queue, $target;
      }
    }
    return 0 if !@next;
    @pending = @next;
  }
  die "reference resolution did not converge after $maximum rounds\n";
}

sub _build_spec {
  my ($class, $resolved, $identity, $physical) = @_;
  my @targets = grep {
    ($resolved->{configuration}{definitions}{targets}{$_}{doctype} // '')
      eq ($identity->{doctype} // '')
  } keys %{ $resolved->{configuration}{definitions}{targets} };
  die "cannot map document type '$identity->{doctype}' to a configured target\n"
    if @targets != 1;
  my $directory = File::Spec->catdir(
    $resolved->{request}{project_root}, $physical,
  );
  return OLLM::BuildFile->build_spec(
    resolved => $resolved, manifest => $resolved->{manifest},
    unit_directory => $directory, target => $targets[0],
    language => $identity->{language},
  );
}

sub _key {
  my ($value) = @_;
  return join "\0", map { $value->{$_} // '' } qw(unit_id doctype language);
}

1;
