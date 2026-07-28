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
our $PARSER_NAME = 'TOML::Tiny::Parser';
our $PARSER_ERROR;
our $PARSER_LOADED;

sub resolve_request {
  my ($class, %arg) = @_;
  my $plan = $arg{plan} // die "missing CLI plan";
  my $start = $arg{start_dir} // getcwd();
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

  if ($located->{kind} eq 'none') {
    return {
      request => \%request,
      configuration => {
        kind   => 'none',
        parser => $class->parser_info,
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
  my $root = dirname($located->{path});
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
        $definitions->{targets}{$target}{unit_profiles},
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
      profile => $manifest->{profile},
      definitions => $definitions,
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
    my %job;
    for my $spec (@specs) {
      die "build matrix produces duplicate job id '$spec->{job_id}'"
        if $job{$spec->{job_id}}++;
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

sub _unit_allows_target {
  my ($directory, $profiles) = @_;
  my $name = File::Basename::basename(File::Spec->rel2abs($directory));
  return 1 if $name !~ /\A\d{3}([a-z]{1,2})-/;
  my $profile = $1;
  return scalar grep { $_ eq $profile } @{ $profiles // [] };
}

sub find_manifest {
  my ($class, %arg) = @_;
  my $start = _absolute_directory($arg{start_dir} // getcwd(), 'start directory');

  if (defined $arg{config}) {
    my $path = File::Spec->rel2abs($arg{config}, $start);
    die "configuration file not found: $path" if !-f $path;
    die "--config accepts only a TOML manifest, not '$path'"
      if $path !~ /\.toml\z/i;
    return { kind => 'toml', path => abs_path($path) };
  }

  if (defined $arg{project_root}) {
    my $root = _absolute_directory(
      File::Spec->rel2abs($arg{project_root}, $start),
      'project root',
    );
    return _manifest_in($root, 1);
  }

  my $directory = $start;
  while (1) {
    my $found = _manifest_in($directory, 0);
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
  _known_keys($manifest, [qw(schema profile project languages targets security latex)],
    $path, $lines, '');
  if (!defined $manifest->{schema} || ref $manifest->{schema}
      || $manifest->{schema} != $MANIFEST_SCHEMA) {
    my $actual = defined($manifest->{schema}) && !ref($manifest->{schema})
      ? $manifest->{schema} : '<missing or non-scalar>';
    _fail_at($path, $lines, 'schema',
      "unsupported project-manifest schema $actual; "
      . "this OLLM supports project-manifest schema $MANIFEST_SCHEMA");
  }
  _require_string($manifest, 'profile', $path);

  _require_table($manifest, 'project', $path);
  _known_keys($manifest->{project}, [qw(id title)], $path, $lines, 'project');
  _require_string($manifest->{project}, 'id', "$path: project");
  _require_string($manifest->{project}, 'title', "$path: project")
    if exists $manifest->{project}{title};

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
    _known_keys($manifest->{security}, [qw(shell_escape)],
      $path, $lines, 'security');
    if (exists $manifest->{security}{shell_escape}) {
      my $policy = _require_string(
        $manifest->{security}, 'shell_escape', "$path: security",
      );
      die "$path: invalid security.shell_escape '$policy'"
        if $policy !~ /\A(?:off|restricted|full)\z/;
    }
  }
  if (exists $manifest->{latex}) {
    die "$path: latex must be a table" if ref $manifest->{latex} ne 'HASH';
    _known_keys($manifest->{latex}, [qw(defaults enforce)],
      $path, $lines, 'latex');
    for my $level (qw(defaults enforce)) {
      next if !exists $manifest->{latex}{$level};
      my $values = $manifest->{latex}{$level};
      die "$path: latex.$level must be a table" if ref $values ne 'HASH';
      _known_keys(
        $values,
        [qw(theme numbering references presentation_backend identity_profile)],
        $path, $lines, "latex.$level",
      );
      _require_string($values, $_, "$path: latex.$level")
        for keys %$values;
    }
  }
  return 1;
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

  my (%profile, %target);
  for my $path (@paths) {
    die "definition search path not found: $path" if !-d $path;
    my @files;
    find(
      sub { push @files, $File::Find::name if -f $_ && /\.toml\z/i },
      $path,
    );
    for my $file (sort @files) {
      my $definition = $class->_load_definition($file);
      my $index = $definition->{kind} eq 'profile' ? \%profile : \%target;
      my $reference = $definition->{kind} eq 'profile'
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

  my $profile_name = $manifest->{profile};
  if (!exists $profile{$profile_name}) {
    my $available = keys(%profile)
      ? join(', ', map { "'$_'" } sort keys %profile)
      : '<none>';
    _fail_at($manifest_path, $manifest_lines, 'profile',
      "requested profile '$profile_name' was not found; "
      . "available profiles: $available; searched: " . join(', ', @paths));
  }

  my %selected_targets;
  my %selected_target_data;
  for my $name (sort keys %{ $manifest->{targets} }) {
    _fail_at($manifest_path, $manifest_lines, "targets.$name",
      "target '$name' was not found; searched: " . join(', ', @paths))
      if !exists $target{$name};
    $selected_targets{$name} = {
      doctype => $target{$name}{data}{doctype},
      family  => $target{$name}{data}{family},
      path    => $target{$name}{path},
      signature => sha256_hex(
        JSON::PP->new->canonical->encode($target{$name}{data}),
      ),
      version => $target{$name}{data}{version},
      unit_profiles => $target{$name}{data}{unit_profiles} // [],
    };
    $selected_target_data{$name} = $target{$name}{data};
  }
  my $signature = sha256_hex(
    JSON::PP->new->canonical->encode({
      manifest => $manifest,
      profile  => $profile{$profile_name}{data},
      targets  => \%selected_target_data,
    }),
  );
  return {
    definition_signature => $signature,
    local_config => -f $local_path ? abs_path($local_path) : undef,
    profile => {
      name    => $profile{$profile_name}{data}{name},
      path    => $profile{$profile_name}{path},
      reference => $profile_name,
      version => $profile{$profile_name}{data}{version},
      latex   => $profile{$profile_name}{data}{latex} // {},
      signature => sha256_hex(
        JSON::PP->new->canonical->encode($profile{$profile_name}{data}),
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
    [qw(schema kind name version latex doctype family unit_profiles)],
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
    if $kind !~ /\A(?:profile|target)\z/;
  _require_string($data, 'name', $path);
  _require_string($data, 'version', $path);
  if ($kind eq 'profile') {
    _fail_at($path, $lines, 'doctype', "profile must not define 'doctype'")
      if exists $data->{doctype};
    _fail_at($path, $lines, 'family', "profile must not define 'family'")
      if exists $data->{family};
    _fail_at($path, $lines, 'unit_profiles',
      "profile must not define 'unit_profiles'")
      if exists $data->{unit_profiles};
  } else {
    _require_string($data, 'doctype', $path);
    _require_string($data, 'family', $path);
    if (exists $data->{unit_profiles}) {
      my $profiles = _require_string_array($data, 'unit_profiles', $path);
      for my $profile (@$profiles) {
        _fail_at($path, $lines, 'unit_profiles',
          "invalid target unit profile '$profile'")
          if $profile !~ /\A[a-z]{1,2}\z/;
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
        [qw(theme numbering references presentation_backend identity_profile)],
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
  my ($directory, $required) = @_;
  my $toml = File::Spec->catfile($directory, 'ollmconfig.toml');
  my $perl = File::Spec->catfile($directory, 'ollmconfig.pl');
  die "both ollmconfig.toml and ollmconfig.pl exist in $directory"
    if -f $toml && -f $perl;
  return { kind => 'toml', path => abs_path($toml) } if -f $toml;
  die "no ollmconfig.toml found in project root $directory"
    if $required;
  return { kind => 'legacy', path => abs_path($perl) } if -f $perl;
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
