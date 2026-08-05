package OLLM::Config;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use Digest::SHA qw(sha256_hex);
use File::Basename qw(dirname);
use File::Find qw(find);
use File::Spec;
use JSON::PP;

our $VERSION = '0.1.0';
our $MANIFEST_SCHEMA = 1;
our $DEFINITION_SCHEMA = 1;
our $LOCAL_SCHEMA = 1;
our $USER_SCHEMA = 1;
our $PARSER_NAME = 'TOML::Tiny::Parser';
our $PARSER_ERROR;
our $PARSER_LOADED;

sub resolve_request {
  my ($class, %arg) = @_;
  my $plan = $arg{plan} // die "missing CLI plan";
  my $start = _absolute_directory(
    $arg{start_dir} // getcwd(), 'request start directory',
  );
  my $standalone = _has_legacy_arg($plan, '+standalone');
  my $located =
      $standalone
      && !defined $plan->{config}
      && !defined $plan->{project_root}
    ? { kind => 'none' }
    : $class->find_manifest(
        start_dir    => $start,
        config       => $plan->{config},
        project_root => $plan->{project_root},
        legacy       => $plan->{legacy},
      );

  my %request = (
    action          => $plan->{action},
    all             => $plan->{all} ? 1 : 0,
    context         => $standalone
      ? 'standalone'
      : $located->{kind} eq 'toml' ? 'series' : 'legacy',
    dry_run         => $plan->{dry_run} ? 1 : 0,
    latexmk_args    => [@{ $plan->{latexmk_args} }],
    non_interactive => $plan->{non_interactive} ? 1 : 0,
    rebuild         => $plan->{rebuild} ? 1 : 0,
    resolve         => $plan->{resolve} ? 1 : 0,
    source          => $plan->{source} // 'main.tex',
    target          => $plan->{target},
    target_explicit => $plan->{target_explicit} ? 1 : 0,
    language_explicit => $plan->{language_explicit} ? 1 : 0,
    source_explicit => $plan->{source_explicit} ? 1 : 0,
  );
  $request{language} = $plan->{language} if defined $plan->{language};
  $request{debug} = $plan->{debug} if defined $plan->{debug};

  die "--legacy was requested, but no ollmconfig.pl was found"
    if $plan->{legacy} && !$standalone && $located->{kind} eq 'none';
  die "legacy manifest found at $located->{path}; use --legacy to build it "
    . "or run 'ollm convertconfig' to create ollmconfig.toml"
    if $located->{kind} eq 'legacy-unselected';

  if ($located->{kind} eq 'none') {
    if (!$standalone) {
      return {
        request => \%request,
        configuration => {
          kind   => 'none',
          parser => $class->parser_info,
        },
      };
    }
    die "standalone builds take document type and language from "
      . "osglecture class options; remove the explicit OLLM target/language"
      if $request{target_explicit} || $request{language_explicit};
    die "--all requires a series manifest and is not available in standalone mode"
      if $request{all};
    my $source_candidate = File::Spec->rel2abs($request{source}, $start);
    my $source = abs_path($source_candidate)
      // die "source file not found: $source_candidate";
    die "source is not a regular file: $source" if !-f $source;
    my ($volume, $directories, $filename) = File::Spec->splitpath($source);
    (my $job_id = $filename) =~ s/\.[^.]+\z//;
    die "cannot derive a job name from standalone source '$source'"
      if $job_id eq '';
    $request{source} = $source;
    return {
      request => \%request,
      configuration => {
        kind   => 'none',
        parser => $class->parser_info,
      },
      standalone_spec => {
        context          => 'standalone',
        source           => $source,
        source_directory => dirname($source),
        job_id           => $job_id,
        shell_escape     => 'restricted',
      },
    };
  }

  if ($located->{kind} eq 'legacy') {
    return {
      request => \%request,
      configuration => {
        kind => 'legacy',
        path => $located->{path},
      },
    };
  }

  my $manifest = $class->load_manifest($located->{path});
  my $user_defaults = $class->load_user_defaults;
  $manifest->{bundle_preset} //=
    $user_defaults->{bundle_preset} // 'OSG lecture/1';
  my $root = dirname($located->{path});
  my $structure = $class->structure_snapshot(project_root => $root);
  my $definitions = $class->resolve_definitions(
    manifest       => $manifest,
    manifest_path  => $located->{path},
    project_root   => $root,
    bundle_path    => $arg{definitions_dir},
  );
  $request{project_root} = $root;
  $request{series_id} = $manifest->{project}{id};

  my $targets = $manifest->{targets};
  if ($request{all}) {
    delete $request{target};
    delete $request{language};
    my @builds;
    for my $target (sort keys %$targets) {
      next if !_unit_allows_target(
        $start,
        $definitions->{targets}{$target}{unit_scopes},
      );
      for my $language (@{ $targets->{$target}{languages} }) {
        push @builds, {
          target   => $target,
          language => $language,
          source   => $request{source},
        };
      }
    }
    die "no configured target/language combination applies to unit "
      . File::Basename::basename($start)
      if !@builds;
    $request{builds} = \@builds;
  } else {
    my $target = $request{target};
    die "target '$target' is not configured in $located->{path}"
      if !exists $targets->{$target};

    my @target_languages = @{ $targets->{$target}{languages} };
    my %target_language = map { $_ => 1 } @target_languages;
    if (defined $request{language}) {
      die "language '$request{language}' is not configured for target '$target'"
        if !$target_language{$request{language}};
    } else {
      my $default = $manifest->{languages}{default};
      $request{language} = $target_language{$default}
        ? $default
        : $target_languages[0];
    }
  }

  my $resolved = {
    request => \%request,
    configuration => {
      kind    => 'toml',
      path    => $located->{path},
      bundle_preset => $manifest->{bundle_preset},
      definitions => $definitions,
      structure => $structure,
      user_defaults => $user_defaults,
      schema  => $manifest->{schema},
      parser  => $class->parser_info,
    },
  };
  require OLLM::BuildFile;
  if ($request{all}) {
    my @specs = map {
      OLLM::BuildFile->build_spec(
        resolved       => $resolved,
        manifest       => $manifest,
        unit_directory => $start,
        target          => $_->{target},
        language        => $_->{language},
      )
    } @{ $request{builds} };
    my (%job, %directory);
    for my $spec (@specs) {
      my $job_key = lc $spec->{job_id};
      die "build matrix produces job ids that collide on "
        . "case-insensitive filesystems: '$job{$job_key}' and "
        . "'$spec->{job_id}'"
        if exists $job{$job_key};
      $job{$job_key} = $spec->{job_id};
      my $directory_key = lc $spec->{build_directory};
      die "build matrix assigns more than one build to directory "
        . "'$spec->{build_directory}'"
        if $directory{$directory_key}++;
    }
    $resolved->{build_specs} = \@specs;
  } else {
    $resolved->{build_spec} = OLLM::BuildFile->build_spec(
      resolved       => $resolved,
      manifest       => $manifest,
      unit_directory => $start,
    );
  }
  return $resolved;
}

sub structure_snapshot {
  my ($class, %arg) = @_;
  my $root = _absolute_directory(
    $arg{project_root} // die("missing project root"),
    'project root',
  );
  opendir my $directory, $root
    or die "cannot read project root '$root': $!";
  my @names = sort grep {
    $_ ne '.' && $_ ne '..'
      && -d File::Spec->catdir($root, $_)
      && /\A\d{3}[a-z]{0,2}-(?:(?:a|e|i)-)?.+\z/
  } readdir $directory;
  closedir $directory
    or die "cannot close project root '$root': $!";

  my @units = map {
    /\A(\d{3})([a-z]{0,2})-(?:(a|e|i)-)?(.+)\z/
      or die "internal error while parsing series unit directory '$_'";
    {
      physical_unit   => $_,
      physical_number => $1,
      unit_scope      => $2,
      unit_role       => $3 // 'content',
      slug            => $4,
    }
  } @names;
  my $canonical = JSON::PP->new->canonical->encode({
    schema => 1,
    units  => \@units,
  });
  return {
    schema    => 1,
    units     => \@units,
    signature => sha256_hex($canonical),
  };
}

sub _unit_allows_target {
  my ($directory, $unit_scopes) = @_;
  my $name = File::Basename::basename(File::Spec->rel2abs($directory));
  return 1 if $name !~ /\A\d{3}([a-z]{1,2})-/;
  my $unit_scope = $1;
  return scalar grep { $_ eq $unit_scope } @{ $unit_scopes // [] };
}

sub find_manifest {
  my ($class, %arg) = @_;
  my $start = _absolute_directory($arg{start_dir} // getcwd(), 'start directory');

  if (defined $arg{config}) {
    my $path = File::Spec->rel2abs($arg{config}, $start);
    die "configuration file not found: $path" if !-f $path;
    if ($arg{legacy}) {
      die "--legacy --config requires a Perl manifest, not '$path'"
        if $path !~ /\.pl\z/i;
      return { kind => 'legacy', path => abs_path($path) };
    }
    die "--config accepts only a TOML manifest; use --legacy for '$path'"
      if $path !~ /\.toml\z/i;
    return { kind => 'toml', path => abs_path($path) };
  }

  if (defined $arg{project_root}) {
    my $root = _absolute_directory(
      File::Spec->rel2abs($arg{project_root}, $start),
      'project root',
    );
    return _manifest_in($root, 1, $arg{legacy});
  }

  my $directory = $start;
  while (1) {
    my $found = _manifest_in($directory, 0, $arg{legacy});
    return $found if $found->{kind} ne 'none';
    my $parent = dirname($directory);
    last if $parent eq $directory;
    $directory = $parent;
  }
  return { kind => 'none' };
}

sub load_manifest {
  my ($class, $path) = @_;
  $class->_load_parser or die
    "TOML parser unavailable: $PARSER_ERROR; reinstall OLLM or install "
    . "TOML::Tiny with 'cpan TOML::Tiny'";
  open my $handle, '<:raw', $path
    or die "cannot read configuration '$path': $!";
  local $/;
  my $source = <$handle>;
  close $handle or die "cannot close configuration '$path': $!";

  my $manifest = eval {
    TOML::Tiny::Parser->new(strict => 1)->parse($source);
  };
  if (!$manifest) {
    my $error = $@ || 'unknown TOML parser error';
    chomp $error;
    die "cannot parse configuration '$path': $error";
  }
  $class->validate_manifest($manifest, $path, _source_map($source));
  return $manifest;
}

sub validate_manifest {
  my ($class, $manifest, $path, $lines) = @_;
  $path //= '<manifest>';
  $lines //= {};
  die "$path: manifest root must be a table" if ref $manifest ne 'HASH';
  _known_keys($manifest,
    [qw(schema bundle_preset project languages targets security latex deployment)],
    $path, $lines, '');
  if (!defined $manifest->{schema} || ref $manifest->{schema}
      || $manifest->{schema} != $MANIFEST_SCHEMA) {
    my $actual = defined($manifest->{schema}) && !ref($manifest->{schema})
      ? $manifest->{schema} : '<missing or non-scalar>';
    _fail_at($path, $lines, 'schema',
      "unsupported project-manifest schema $actual; "
      . "this OLLM supports project-manifest schema $MANIFEST_SCHEMA");
  }
  _require_string($manifest, 'bundle_preset', $path)
    if exists $manifest->{bundle_preset};

  _require_table($manifest, 'project', $path);
  _known_keys($manifest->{project}, [qw(id title tex)], $path, $lines, 'project');
  _require_string($manifest->{project}, 'id', "$path: project");
  _require_string($manifest->{project}, 'title', "$path: project")
    if exists $manifest->{project}{title};
  if (exists $manifest->{project}{tex}) {
    my $tex = $manifest->{project}{tex};
    die "$path: project.tex must be a table" if ref $tex ne 'HASH';
    _known_keys($tex, [qw(directory config)], $path, $lines, 'project.tex');
    _require_string($tex, $_, "$path: project.tex") for keys %$tex;
    if (exists $tex->{directory}) {
      _fail_at($path, $lines, 'project.tex.directory',
        'project.tex.directory must be project-root-relative')
        if File::Spec->file_name_is_absolute($tex->{directory});
      _fail_at($path, $lines, 'project.tex.directory',
        'project.tex.directory must not be empty')
        if $tex->{directory} eq '';
    }
    if (exists $tex->{config}) {
      _fail_at($path, $lines, 'project.tex.config',
        'project.tex.config must be a filename without directory components')
        if $tex->{config} eq ''
          || File::Spec->file_name_is_absolute($tex->{config})
          || $tex->{config} =~ m{[\\/]};
    }
  }

  _require_table($manifest, 'languages', $path);
  _known_keys($manifest->{languages}, [qw(available default map)],
    $path, $lines, 'languages');
  my $available = _require_string_array(
    $manifest->{languages}, 'available', "$path: languages",
  );
  die "$path: languages.available must not be empty" if !@$available;
  my %available = map { $_ => 1 } @$available;
  die "$path: languages.available contains duplicates"
    if keys(%available) != @$available;
  my %available_folded = map { lc($_) => 1 } @$available;
  die "$path: languages.available contains values that collide on "
    . "case-insensitive filesystems"
    if keys(%available_folded) != @$available;
  my $default = _require_string(
    $manifest->{languages}, 'default', "$path: languages",
  );
  die "$path: default language '$default' is not listed in languages.available"
    if !$available{$default};
  if (exists $manifest->{languages}{map}) {
    my $map = $manifest->{languages}{map};
    die "$path: languages.map must be a table" if ref $map ne 'HASH';
    for my $language (sort keys %$map) {
      _require_string($map, $language, "$path: languages.map");
      _fail_at($path, $lines, "languages.map.$language",
        "language map uses unavailable language '$language'")
        if !$available{$language};
    }
  }

  _require_table($manifest, 'targets', $path);
  die "$path: targets must not be empty" if !keys %{ $manifest->{targets} };
  my %target_folded;
  for my $target (sort keys %{ $manifest->{targets} }) {
    my $folded = lc $target;
    die "$path: target names '$target_folded{$folded}' and '$target' "
      . "collide on case-insensitive filesystems"
      if exists $target_folded{$folded};
    $target_folded{$folded} = $target;
  }
  for my $target (sort keys %{ $manifest->{targets} }) {
    my $definition = $manifest->{targets}{$target};
    die "$path: targets.$target must be a table"
      if ref $definition ne 'HASH';
    _known_keys($definition, [qw(languages)], $path, $lines, "targets.$target");
    my $languages = _require_string_array(
      $definition, 'languages', "$path: targets.$target",
    );
    die "$path: targets.$target.languages must not be empty" if !@$languages;
    my %target_languages = map { $_ => 1 } @$languages;
    die "$path: targets.$target.languages contains duplicates"
      if keys(%target_languages) != @$languages;
    for my $language (@$languages) {
      die "$path: target '$target' uses unavailable language '$language'"
        if !$available{$language};
    }
  }

  if (exists $manifest->{security}) {
    die "$path: security must be a table"
      if ref $manifest->{security} ne 'HASH';
    _known_keys($manifest->{security}, [qw(shell_escape deployment)],
      $path, $lines, 'security');
    if (exists $manifest->{security}{shell_escape}) {
      my $policy = _require_string(
        $manifest->{security}, 'shell_escape', "$path: security",
      );
      die "$path: invalid security.shell_escape '$policy'"
        if $policy !~ /\A(?:off|restricted|full)\z/;
    }
    if (exists $manifest->{security}{deployment}) {
      my $security = $manifest->{security}{deployment};
      die "$path: security.deployment must be a table"
        if ref $security ne 'HASH';
      _known_keys($security, [qw(overwrite)], $path, $lines,
        'security.deployment');
      my $overwrite = _require_string(
        $security, 'overwrite', "$path: security.deployment",
      );
      die "$path: invalid security.deployment.overwrite '$overwrite'"
        if $overwrite !~ /\A(?:explicit|automatic)\z/;
    }
  }
  if (exists $manifest->{latex}) {
    die "$path: latex must be a table" if ref $manifest->{latex} ne 'HASH';
    _known_keys($manifest->{latex}, [qw(defaults enforce document_metadata)],
      $path, $lines, 'latex');
    for my $level (qw(defaults enforce)) {
      next if !exists $manifest->{latex}{$level};
      my $values = $manifest->{latex}{$level};
      die "$path: latex.$level must be a table" if ref $values ne 'HASH';
      _known_keys(
        $values,
        [qw(theme numbering references presentation_backend identity_profile
            presentation_profile script_profile)],
        $path, $lines, "latex.$level",
      );
      _require_string($values, $_, "$path: latex.$level")
        for keys %$values;
    }
    if (exists $manifest->{latex}{document_metadata}) {
      my $metadata = $manifest->{latex}{document_metadata};
      die "$path: latex.document_metadata must be a table"
        if ref $metadata ne 'HASH';
      _known_keys($metadata, [qw(policy file)], $path, $lines,
        'latex.document_metadata');
      my $policy = _require_string(
        $metadata, 'policy', "$path: latex.document_metadata",
      );
      die "$path: invalid latex.document_metadata.policy '$policy'"
        if $policy !~ /\A(?:author|enforce)\z/;
      _require_string($metadata, 'file', "$path: latex.document_metadata")
        if $policy eq 'enforce' || exists $metadata->{file};
    }
  }
  _validate_deployment($manifest, $path, $lines) if exists $manifest->{deployment};
  return 1;
}

sub _validate_deployment {
  my ($manifest, $path, $lines) = @_;
  my $deployment = $manifest->{deployment};
  die "$path: deployment must be a table" if ref $deployment ne 'HASH';
  _known_keys($deployment, [qw(series roles types)], $path, $lines, 'deployment');
  if (exists $deployment->{series}) {
    my $series = _require_string($deployment, 'series', "$path: deployment");
    die "$path: invalid deployment.series '$series'"
      if $series !~ /\A(?:units|collection|both)\z/;
  }
  if (exists $deployment->{roles}) {
    my $roles = $deployment->{roles};
    die "$path: deployment.roles must be a table" if ref $roles ne 'HASH';
    for my $role (keys %$roles) {
      die "$path: deployment.roles.$role must be a string"
        if !defined($roles->{$role}) || ref($roles->{$role});
    }
  }
  my $types = _require_table($deployment, 'types', "$path: deployment");
  for my $doctype (sort keys %$types) {
    die "$path: invalid deployment document type '$doctype'"
      if $doctype !~ /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/;
    my $rule = $types->{$doctype};
    die "$path: deployment.types.$doctype must be a table"
      if ref $rule ne 'HASH';
    _known_keys($rule, [qw(paths filename collection_filename series units)], $path, $lines,
      "deployment.types.$doctype");
    my $paths = _require_string_array(
      $rule, 'paths', "$path: deployment.types.$doctype",
    );
    die "$path: deployment.types.$doctype.paths must not be empty" if !@$paths;
    _require_string($rule, 'filename', "$path: deployment.types.$doctype");
    _require_string($rule, 'collection_filename',
      "$path: deployment.types.$doctype")
      if exists $rule->{collection_filename};
    if (exists $rule->{series}) {
      my $series = _require_string(
        $rule, 'series', "$path: deployment.types.$doctype",
      );
      die "$path: invalid deployment.types.$doctype.series '$series'"
        if $series !~ /\A(?:units|collection|both)\z/;
    }
    next if !exists $rule->{units};
    my $units = $rule->{units};
    die "$path: deployment.types.$doctype.units must be a table"
      if ref $units ne 'HASH';
    for my $unit (sort keys %$units) {
      die "$path: invalid deployment unit-id '$unit'"
        if $unit !~ /\A[^\s,=]+\z/ || index($unit, '...') >= 0;
      my $override = $units->{$unit};
      die "$path: deployment.types.$doctype.units.$unit must be a table"
        if ref $override ne 'HASH';
      _known_keys($override, [qw(filename)], $path, $lines,
        "deployment.types.$doctype.units.$unit");
      _require_string($override, 'filename',
        "$path: deployment.types.$doctype.units.$unit");
    }
  }
}

sub load_user_defaults {
  my ($class) = @_;
  my $path;
  if (defined $ENV{OLLM_USER_CONFIG} && $ENV{OLLM_USER_CONFIG} ne '') {
    $path = File::Spec->rel2abs($ENV{OLLM_USER_CONFIG});
    die "OLLM user configuration not found: $path" if !-f $path;
  } elsif ($^O eq 'MSWin32' && defined $ENV{APPDATA}) {
    $path = File::Spec->catfile($ENV{APPDATA}, 'ollm', 'config.toml');
  } elsif (defined $ENV{XDG_CONFIG_HOME} && $ENV{XDG_CONFIG_HOME} ne '') {
    $path = File::Spec->catfile($ENV{XDG_CONFIG_HOME}, 'ollm', 'config.toml');
  } elsif (defined $ENV{HOME} && $ENV{HOME} ne '') {
    $path = File::Spec->catfile($ENV{HOME}, '.config', 'ollm', 'config.toml');
  }
  return {} if !defined $path || !-f $path;
  my ($data, $lines) = $class->_load_toml($path);
  _known_keys($data, [qw(schema bundle_preset latex)], $path, $lines, '');
  if (!defined $data->{schema} || ref $data->{schema}
      || $data->{schema} != $USER_SCHEMA) {
    my $actual = defined($data->{schema}) && !ref($data->{schema})
      ? $data->{schema} : '<missing or non-scalar>';
    _fail_at($path, $lines, 'schema',
      "unsupported user-configuration schema $actual; "
      . "this OLLM supports user-configuration schema $USER_SCHEMA");
  }
  _require_string($data, 'bundle_preset', $path)
    if exists $data->{bundle_preset};
  if (exists $data->{latex}) {
    die "$path: latex must be a table" if ref $data->{latex} ne 'HASH';
    _known_keys($data->{latex}, [qw(defaults)], $path, $lines, 'latex');
    if (exists $data->{latex}{defaults}) {
      my $values = $data->{latex}{defaults};
      die "$path: latex.defaults must be a table" if ref $values ne 'HASH';
      _known_keys($values,
        [qw(theme numbering references presentation_backend identity_profile
            presentation_profile script_profile)],
        $path, $lines, 'latex.defaults');
      _require_string($values, $_, "$path: latex.defaults") for keys %$values;
    }
  }
  $data->{path} = $path;
  return $data;
}

sub resolve_definitions {
  my ($class, %arg) = @_;
  my $manifest = $arg{manifest} // die "missing manifest";
  my $manifest_path = $arg{manifest_path} // '<manifest>';
  my $root = $arg{project_root} // die "missing project root";
  my $manifest_lines = -f $manifest_path
    ? _source_map_from_file($manifest_path)
    : {};
  my @paths;

  my $local_path = File::Spec->catfile($root, '.ollmconfig.local.toml');
  if (-f $local_path) {
    my $local = $class->_load_local_config($local_path);
    for my $path (@{ $local->{definitions}{paths} // [] }) {
      push @paths, File::Spec->file_name_is_absolute($path)
        ? $path
        : File::Spec->catdir($root, $path);
    }
  }
  push @paths, $arg{bundle_path} if defined $arg{bundle_path};

  my (%preset, %target);
  for my $path (@paths) {
    die "definition search path not found: $path" if !-d $path;
    my @files;
    find(
      sub { push @files, $File::Find::name if -f $_ && /\.toml\z/i },
      $path,
    );
    for my $file (sort @files) {
      my $definition = $class->_load_definition($file);
      my $index = $definition->{kind} eq 'bundle-preset' ? \%preset : \%target;
      my $reference = $definition->{kind} eq 'bundle-preset'
        ? "$definition->{name}/$definition->{version}"
        : $definition->{name};
      if (exists $index->{$reference}) {
        die "duplicate $definition->{kind} definition '$reference': "
          . "$index->{$reference}{path} and $file";
      }
      $index->{$reference} = {
        path => abs_path($file),
        data => $definition,
      };
    }
  }

  my $preset_name = $manifest->{bundle_preset};
  if (!exists $preset{$preset_name}) {
    my $available = keys(%preset)
      ? join(', ', map { "'$_'" } sort keys %preset)
      : '<none>';
    _fail_at($manifest_path, $manifest_lines, 'bundle_preset',
      "requested bundle preset '$preset_name' was not found; "
      . "available bundle presets: $available; searched: " . join(', ', @paths));
  }

  my %selected_targets;
  my %selected_target_data;
  for my $name (sort keys %{ $manifest->{targets} }) {
    _fail_at($manifest_path, $manifest_lines, "targets.$name",
      "target '$name' was not found; searched: " . join(', ', @paths))
      if !exists $target{$name};
    $selected_targets{$name} = {
      doctype       => $target{$name}{data}{doctype},
      profile_class => $target{$name}{data}{profile_class},
      path    => $target{$name}{path},
      signature => sha256_hex(
        JSON::PP->new->canonical->encode($target{$name}{data}),
      ),
      version => $target{$name}{data}{version},
      unit_scopes => $target{$name}{data}{unit_scopes} // [],
    };
    $selected_target_data{$name} = $target{$name}{data};
  }
  my $signature = sha256_hex(
    JSON::PP->new->canonical->encode({
      manifest => $manifest,
      bundle_preset => $preset{$preset_name}{data},
      targets  => \%selected_target_data,
    }),
  );
  return {
    definition_signature => $signature,
    local_config => -f $local_path ? abs_path($local_path) : undef,
    bundle_preset => {
      name    => $preset{$preset_name}{data}{name},
      path    => $preset{$preset_name}{path},
      reference => $preset_name,
      version => $preset{$preset_name}{data}{version},
      latex   => $preset{$preset_name}{data}{latex} // {},
      signature => sha256_hex(
        JSON::PP->new->canonical->encode($preset{$preset_name}{data}),
      ),
    },
    search_paths => [map { abs_path($_) // $_ } @paths],
    targets      => \%selected_targets,
  };
}

sub _load_local_config {
  my ($class, $path) = @_;
  my ($data, $lines) = $class->_load_toml($path);
  _known_keys($data, [qw(schema definitions)], $path, $lines, '');
  if (!defined $data->{schema} || ref $data->{schema}
      || $data->{schema} != $LOCAL_SCHEMA) {
    my $actual = defined($data->{schema}) && !ref($data->{schema})
      ? $data->{schema} : '<missing or non-scalar>';
    _fail_at($path, $lines, 'schema',
      "unsupported local-configuration schema $actual; "
      . "this OLLM supports local-configuration schema $LOCAL_SCHEMA");
  }
  _require_table($data, 'definitions', $path);
  _known_keys($data->{definitions}, [qw(paths)], $path, $lines, 'definitions');
  _require_string_array($data->{definitions}, 'paths', "$path: definitions");
  return $data;
}

sub _load_definition {
  my ($class, $path) = @_;
  my ($data, $lines) = $class->_load_toml($path);
  _known_keys($data,
    [qw(schema kind name version latex doctype profile_class unit_scopes)],
    $path, $lines, '');
  if (!defined $data->{schema} || ref $data->{schema}
      || $data->{schema} != $DEFINITION_SCHEMA) {
    my $actual = defined($data->{schema}) && !ref($data->{schema})
      ? $data->{schema} : '<missing or non-scalar>';
    _fail_at($path, $lines, 'schema',
      "unsupported definition schema $actual; "
      . "this OLLM supports definition schema $DEFINITION_SCHEMA");
  }
  my $kind = _require_string($data, 'kind', $path);
  _fail_at($path, $lines, 'kind', "unknown definition kind '$kind'")
    if $kind !~ /\A(?:bundle-preset|target)\z/;
  _require_string($data, 'name', $path);
  _require_string($data, 'version', $path);
  if ($kind eq 'bundle-preset') {
    _fail_at($path, $lines, 'doctype',
      "bundle preset must not define 'doctype'")
      if exists $data->{doctype};
    _fail_at($path, $lines, 'profile_class',
      "bundle preset must not define 'profile_class'")
      if exists $data->{profile_class};
    _fail_at($path, $lines, 'unit_scopes',
      "bundle preset must not define 'unit_scopes'")
      if exists $data->{unit_scopes};
  } else {
    _require_string($data, 'doctype', $path);
    my $profile_class = _require_string($data, 'profile_class', $path);
    _fail_at($path, $lines, 'profile_class',
      "invalid target profile_class '$profile_class'; "
      . "expected 'presentation' or 'longform'")
      if $profile_class !~ /\A(?:presentation|longform)\z/;
    _fail_at($path, $lines, 'doctype',
      "target name '$data->{name}' and doctype '$data->{doctype}' differ; "
      . "schema 1 has no versioned target/doctype adapter contract")
      if $data->{name} ne $data->{doctype};
    if (exists $data->{unit_scopes}) {
      my $unit_scopes = _require_string_array(
        $data, 'unit_scopes', $path,
      );
      for my $unit_scope (@$unit_scopes) {
        _fail_at($path, $lines, 'unit_scopes',
          "invalid target unit scope '$unit_scope'")
          if $unit_scope !~ /\A[a-z]{1,2}\z/;
      }
    }
    _fail_at($path, $lines, 'latex', "target must not define 'latex'")
      if exists $data->{latex};
  }
  if (exists $data->{latex}) {
    die "$path: latex must be a table" if ref $data->{latex} ne 'HASH';
    _known_keys($data->{latex}, [qw(defaults enforce)], $path, $lines, 'latex');
    for my $level (keys %{ $data->{latex} }) {
      my $values = $data->{latex}{$level};
      die "$path: latex.$level must be a table" if ref $values ne 'HASH';
      _known_keys($values,
        [qw(theme numbering references presentation_backend identity_profile
            presentation_profile script_profile)],
        $path, $lines, "latex.$level");
      _require_string($values, $_, "$path: latex.$level") for keys %$values;
    }
  }
  return $data;
}

sub _load_toml {
  my ($class, $path) = @_;
  $class->_load_parser or die "TOML parser unavailable: $PARSER_ERROR";
  open my $handle, '<:raw', $path or die "cannot read configuration '$path': $!";
  local $/;
  my $source = <$handle>;
  close $handle;
  my $data = eval { TOML::Tiny::Parser->new(strict => 1)->parse($source) };
  if (!$data) {
    my $error = $@ || 'unknown TOML parser error';
    chomp $error;
    die "cannot parse configuration '$path': $error";
  }
  return ($data, _source_map($source));
}

sub parser_info {
  my ($class) = @_;
  my $available = $class->_load_parser;
  my $loaded_from = $INC{'TOML/Tiny/Parser.pm'};
  my $source = $available && defined $loaded_from
    && $loaded_from =~ m{(?:^|/)vendor/TOML-Tiny-0[.]22/}
      ? 'bundled'
      : $available ? 'system' : 'missing';
  return {
    available => $available ? 1 : 0,
    error    => $PARSER_ERROR,
    name     => $PARSER_NAME,
    version  => $available ? $TOML::Tiny::Parser::VERSION : undef,
    source   => $source,
    standard => 'TOML 1.0',
  };
}

sub _load_parser {
  return 1 if $PARSER_LOADED;
  my $loaded = eval {
    require TOML::Tiny::Parser;
    1;
  };
  if (!$loaded) {
    $PARSER_ERROR = $@ || 'unknown loader error';
    chomp $PARSER_ERROR;
    return 0;
  }
  $PARSER_LOADED = 1;
  $PARSER_ERROR = undef;
  return 1;
}

sub _manifest_in {
  my ($directory, $required, $legacy) = @_;
  my $toml = File::Spec->catfile($directory, 'ollmconfig.toml');
  my $perl = File::Spec->catfile($directory, 'ollmconfig.pl');
  if ($legacy) {
    return { kind => 'legacy', path => abs_path($perl) } if -f $perl;
    die "no ollmconfig.pl found in project root $directory" if $required;
    return { kind => 'none' };
  }
  return { kind => 'toml', path => abs_path($toml) } if -f $toml;
  die "no ollmconfig.toml found in project root $directory"
    if $required;
  return { kind => 'legacy-unselected', path => abs_path($perl) } if -f $perl;
  return { kind => 'none' };
}

sub _absolute_directory {
  my ($path, $label) = @_;
  my $absolute = abs_path($path);
  die "$label not found: $path" if !defined $absolute;
  die "$label is not a directory: $absolute" if !-d $absolute;
  return $absolute;
}

sub _source_map {
  my ($source) = @_;
  my %lines;
  my $table = '';
  my @source_lines = split /\n/, $source, -1;
  for my $index (0 .. $#source_lines) {
    my $line = $source_lines[$index];
    if ($line =~ /^\s*\[\s*([A-Za-z0-9_.-]+)\s*\]\s*(?:#.*)?$/) {
      $table = $1;
      $lines{$table} //= $index + 1;
      next;
    }
    next if $line !~ /^\s*([A-Za-z0-9_-]+)\s*=/;
    my $key = $1;
    my $path = length($table) ? "$table.$key" : $key;
    $lines{$path} //= $index + 1;
  }
  return \%lines;
}

sub _source_map_from_file {
  my ($path) = @_;
  open my $handle, '<:raw', $path
    or die "cannot read configuration '$path': $!";
  local $/;
  my $source = <$handle>;
  close $handle;
  return _source_map($source);
}

sub _known_keys {
  my ($table, $allowed, $file, $lines, $prefix) = @_;
  my %allowed = map { $_ => 1 } @$allowed;
  for my $key (sort keys %$table) {
    next if $allowed{$key};
    my $path = length($prefix) ? "$prefix.$key" : $key;
    _fail_at($file, $lines, $path, "unknown key '$path'");
  }
}

sub _fail_at {
  my ($file, $lines, $path, $message) = @_;
  my $line = $lines->{$path};
  die defined($line) ? "$file:$line: $message" : "$file: $message";
}

sub _require_table {
  my ($table, $key, $where) = @_;
  die "$where: missing table '$key'" if !exists $table->{$key};
  die "$where: '$key' must be a table" if ref $table->{$key} ne 'HASH';
  return $table->{$key};
}

sub _require_string {
  my ($table, $key, $where) = @_;
  die "$where: missing '$key'" if !exists $table->{$key};
  my $value = $table->{$key};
  die "$where: '$key' must be a non-empty string"
    if ref $value || !defined $value || $value eq '';
  return $value;
}

sub _require_string_array {
  my ($table, $key, $where) = @_;
  die "$where: missing '$key'" if !exists $table->{$key};
  my $values = $table->{$key};
  die "$where: '$key' must be an array" if ref $values ne 'ARRAY';
  for my $value (@$values) {
    die "$where: '$key' entries must be non-empty strings"
      if ref $value || !defined $value || $value eq '';
  }
  return $values;
}

sub _has_legacy_arg {
  my ($plan, $wanted) = @_;
  return scalar grep { $_ eq $wanted } @{ $plan->{legacy_args} };
}

1;
