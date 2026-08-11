package OLLM::Maintenance;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use Errno qw(EAGAIN EWOULDBLOCK);
use Fcntl qw(:flock);
use File::Basename qw(basename dirname);
use File::Find qw(find);
use File::Path qw(make_path remove_tree);
use File::Spec;
use JSON::PP;
use OLLM::Path;
use OLLM::StateLock;
use OLLM::Version qw($VERSION);

sub prepare {
  my ($class, %arg) = @_;
  my $plan = $arg{plan} // die "missing maintenance plan";
  my $root = abs_path($arg{project_root})
    // die "project root not found: $arg{project_root}";
  my $cwd = abs_path($arg{start_dir})
    // die "working directory not found: $arg{start_dir}";
  my $structure = $arg{structure} // die "missing project structure";
  my $manifest = $arg{manifest} // die "missing project manifest";
  my %unit = map { $_->{physical_unit} => $_ } @{ $structure->{units} };
  OLLM::Path::require_within(
    $cwd, $root, "working directory '$cwd' is outside project root '$root'",
  );
  my $relative = File::Spec->abs2rel($cwd, $root);
  my ($physical) = File::Spec->splitdir($relative);
  $physical = undef if !defined($physical) || $physical eq '.'
    || !exists $unit{$physical};

  if ($plan->{action} eq 'clean') {
    my $scope = $plan->{scope} // 'current';
    die "clean --scope=$scope must be run inside a series unit\n"
      if $scope ne 'series' && !defined $physical;
    my $target = $plan->{target} // 'slides';
    my $language = $plan->{language} // $arg{default_language};
    die "target '$target' is not configured for this project\n"
      if !exists $manifest->{targets}{$target};
    my %language = map { $_ => 1 }
      @{ $manifest->{targets}{$target}{languages} // [] };
    die "language '$language' is not configured for target '$target'\n"
      if defined($language) && !$language{$language};
    die "clean --scope=current requires a language\n"
      if $scope eq 'current' && !defined $language;
    return {
      action       => 'clean',
      dry_run      => $plan->{dry_run} ? 1 : 0,
      level        => $plan->{level} // 'aux',
      scope        => $scope,
      project_root => $root,
      physical_unit => $physical,
      target       => $target,
      language     => $language,
      confirm_series => $scope eq 'series' && $cwd ne $root
        && !$plan->{dry_run} ? 1 : 0,
    };
  }

  die "prune does not accept --level or --scope\n"
    if defined($plan->{level}) || defined($plan->{scope});
  return {
    action       => 'prune',
    dry_run      => $plan->{dry_run} ? 1 : 0,
    stale_units  => $plan->{stale_units} ? 1 : 0,
    project_root => $root,
    current_units => { map { $_ => 1 } keys %unit },
  };
}

sub execute {
  my ($class, $request) = @_;
  my $lock = $request->{dry_run}
    ? undef : _maintenance_lock($request->{project_root});
  my $report = $request->{action} eq 'clean'
    ? _clean_plan($request) : _prune_plan($request);
  if (!$request->{dry_run}) {
    _assert_builds_idle($report)
      if $request->{action} eq 'clean';
    _remove_path($_->{path}, $request->{project_root})
      for grep { $_->{operation} eq 'remove' } @{ $report->{items} };
  }
  return $report;
}

sub _assert_builds_idle {
  my ($report) = @_;
  my %lock;
  for my $item (@{ $report->{items} }) {
    my $path = $item->{path};
    my $directory = -d $path ? $path : dirname($path);
    while (1) {
      my $candidate = File::Spec->catfile($directory, '.ollm.lock');
      $lock{$candidate} = 1 if -f $candidate;
      my $parent = dirname($directory);
      last if $parent eq $directory
        || $directory =~ /(?:\A|[\\\/])build\z/;
      $directory = $parent;
    }
    if (-d $path) {
      find({
        no_chdir => 1,
        wanted => sub {
          $lock{$File::Find::name} = 1
            if -f $File::Find::name
              && $File::Find::name =~ /(?:\A|[\\\/])[.]ollm[.]lock\z/;
        },
      }, $path);
    }
  }
  for my $path (sort keys %lock) {
    open my $handle, '>>', $path
      or die "cannot inspect build lock '$path': $!\n";
    if (!flock($handle, LOCK_EX | LOCK_NB)) {
      die "refusing to clean an active build protected by '$path'\n"
        if $! == EAGAIN || $! == EWOULDBLOCK;
      die "cannot inspect build lock '$path': $!\n";
    }
    close $handle;
  }
}

sub _maintenance_lock {
  my ($root) = @_;
  return OLLM::StateLock::acquire($root);
}

sub _clean_plan {
  my ($request) = @_;
  my $root = $request->{project_root};
  my $build_root = File::Spec->catdir($root, '.osglecture', 'build');
  my $state_root = File::Spec->catdir($root, '.osglecture', 'state');
  my @items;
  if ($request->{level} eq 'aux') {
    my @builds = _leaf_build_projections($request, $build_root);
    for my $directory (@builds) {
      next if !-d $directory;
      opendir my $handle, $directory
        or die "cannot read build directory '$directory': $!\n";
      my @entries = sort grep {
        $_ ne '.' && $_ ne '..' && $_ ne '.ollm.lock' && $_ !~ /[.]pdf\z/i
      }
        readdir $handle;
      closedir $handle;
      push @items, map {
        +{ operation => 'remove', kind => 'aux',
           path => File::Spec->catfile($directory, $_) }
      } @entries;
    }
  } elsif ($request->{level} eq 'build' || $request->{level} eq 'all') {
    my @builds = _build_roots($request, $build_root);
    push @items, map {
      +{ operation => 'remove', kind => 'build', path => $_ }
    } grep { -e $_ || -l $_ } @builds;
  }
  if ($request->{level} eq 'state' || $request->{level} eq 'all') {
    push @items, _state_projection_items($request, $state_root);
  }
  return { action => 'clean', items => \@items };
}

sub _build_roots {
  my ($request, $build_root) = @_;
  return () if !-d $build_root;
  if ($request->{scope} eq 'series') {
    opendir my $handle, $build_root or die "cannot read '$build_root': $!\n";
    my @paths = map { File::Spec->catdir($build_root, $_) }
      sort grep { $_ ne '.' && $_ ne '..' } readdir $handle;
    closedir $handle;
    return @paths;
  }
  my $unit = File::Spec->catdir($build_root, $request->{physical_unit});
  return ($unit) if $request->{scope} eq 'unit';
  return (File::Spec->catdir(
    $unit, $request->{target}, $request->{language},
  ));
}

sub _leaf_build_projections {
  my ($request, $build_root) = @_;
  return () if !-d $build_root;
  return _build_roots($request, $build_root)
    if $request->{scope} eq 'current';
  my @units = $request->{scope} eq 'unit'
    ? (File::Spec->catdir($build_root, $request->{physical_unit}))
    : _build_roots($request, $build_root);
  my @leaves;
  for my $unit (@units) {
    next if !-d $unit;
    opendir my $target_handle, $unit or die "cannot read '$unit': $!\n";
    my @targets = map { File::Spec->catdir($unit, $_) }
      sort grep { $_ ne '.' && $_ ne '..' } readdir $target_handle;
    closedir $target_handle;
    for my $target (@targets) {
      next if !-d $target;
      opendir my $language_handle, $target
        or die "cannot read '$target': $!\n";
      push @leaves, map { File::Spec->catdir($target, $_) }
        sort grep { $_ ne '.' && $_ ne '..' } readdir $language_handle;
      closedir $language_handle;
    }
  }
  return grep { -d $_ } @leaves;
}

sub _state_projection_items {
  my ($request, $state_root) = @_;
  return () if !-d $state_root;
  my @items;
  for my $current (_current_files($state_root)) {
    my ($record, $projection) = _current_record($current);
    next if $request->{scope} ne 'series'
      && ($record->{physical_unit} // '') ne $request->{physical_unit};
    next if $request->{scope} eq 'current'
      && (($record->{doctype} // '') ne $request->{target}
        || ($record->{language} // '') ne $request->{language});
    push @items, {
      operation => 'remove', kind => 'state', path => $projection,
      unit_id => $record->{unit_id}, doctype => $record->{doctype},
      language => $record->{language},
    };
  }
  return @items;
}

sub _prune_plan {
  my ($request) = @_;
  my $state_root = File::Spec->catdir(
    $request->{project_root}, '.osglecture', 'state',
  );
  my (@items, %current_generation);
  for my $current (_current_files($state_root)) {
    my ($record, $projection, $generation) = _current_record($current);
    $current_generation{$projection}{$generation} = 1;
    if (!$request->{current_units}{$record->{physical_unit} // ''}) {
      push @items, {
        operation => $request->{stale_units} ? 'remove' : 'report',
        kind => 'stale-unit', path => $projection,
        unit_id => $record->{unit_id},
        physical_unit => $record->{physical_unit},
      };
    }
  }
  return { action => 'prune', items => \@items } if !-d $state_root;
  find({
    no_chdir => 1,
    wanted => sub {
      return if !-d $File::Find::name;
      my $name = basename($File::Find::name);
      if ($name =~ /\A[.]pending-/) {
        push @items, {
          operation => 'remove', kind => 'pending',
          path => $File::Find::name,
        };
        $File::Find::prune = 1;
        return;
      }
      my $parent = dirname($File::Find::name);
      return if $parent !~ /(?:\A|[\\\/])generations\z/;
      my $projection = dirname($parent);
      return if $current_generation{$projection}{$name};
      push @items, {
        operation => 'remove', kind => 'generation',
        path => $File::Find::name,
      };
      $File::Find::prune = 1;
    },
  }, $state_root);
  return { action => 'prune', items => \@items };
}

sub _current_files {
  my ($root) = @_;
  return () if !-d $root;
  my @files;
  find({
    no_chdir => 1,
    wanted => sub {
      push @files, $File::Find::name
        if -f $File::Find::name
          && $File::Find::name =~ /(?:\A|[\\\/])current[.]tex\z/;
    },
  }, $root);
  return sort @files;
}

sub _current_record {
  my ($current) = @_;
  open my $handle, '<:raw', $current
    or die "cannot read state pointer '$current': $!\n";
  my $content = do { local $/; <$handle> };
  close $handle;
  $content =~ /\\OsgLectureCurrent\{1\}\{([0-9a-f]{64})\}/
    or die "invalid state pointer '$current'\n";
  my $generation = $1;
  my $projection = dirname($current);
  my $result = File::Spec->catfile(
    $projection, 'generations', $generation, 'result.json',
  );
  open my $result_handle, '<:raw', $result
    or die "cannot read promoted result '$result': $!\n";
  my $record = eval {
    JSON::PP->new->decode(do { local $/; <$result_handle> })
  };
  close $result_handle;
  die "invalid promoted result '$result': $@\n" if !$record;
  return ($record, $projection, $generation);
}

sub _remove_path {
  my ($path, $root) = @_;
  my $maintenance_root = File::Spec->catdir($root, '.osglecture');
  my ($relative, $outside) = OLLM::Path::classify($path, $maintenance_root);
  die "refusing to remove path outside OLLM state: '$path'\n"
    if $outside || $relative eq '.';
  if (-d $path && !-l $path) {
    remove_tree($path, {error => \my $errors});
    die "cannot remove '$path'\n" if @$errors;
  } elsif (-e $path || -l $path) {
    unlink $path or die "cannot remove '$path': $!\n";
  }
}

1;
