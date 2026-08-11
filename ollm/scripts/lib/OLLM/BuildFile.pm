package OLLM::BuildFile;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use File::Basename qw(basename dirname);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempfile);
use JSON::PP;
use OLLM::Path;
use OLLM::Version qw($VERSION);
our $SCHEMA = 1;

sub build_spec {
  my ($class, %arg) = @_;
  my $resolved = $arg{resolved} // die "missing resolved configuration";
  my $request = $resolved->{request};
  my $configuration = $resolved->{configuration};
  die "build files require series context"
    if $request->{context} ne 'series';
  my $target_name = $arg{target} // $request->{target};
  my $language = $arg{language} // $request->{language};
  die "build files require one concrete target" if !defined $target_name;
  die "build files require one concrete language" if !defined $language;

  my $unit_directory = $arg{unit_directory} // '.';
  $unit_directory = abs_path($unit_directory)
    // die "unit directory not found: $unit_directory";
  my $physical_unit = basename($unit_directory);
  my ($number, $unit_scope, $role, $slug) = _parse_unit($physical_unit);
  my $target = $configuration->{definitions}{targets}{$target_name}
    // die "resolved target '$target_name' has no definition";
  my $doctype = $target->{doctype};
  _validate_job_atom('series id', $request->{series_id});
  _validate_job_atom('document type', $doctype);
  _validate_job_atom('language', $language);
  _validate_job_atom('unit slug', $slug, 1);
  my $job_id = join '-',
    $request->{series_id}, $number, $doctype, $language, $slug;
  my $project_root = abs_path($request->{project_root})
    // die "project root not found: $request->{project_root}";
  _require_within($unit_directory, $project_root, 'series unit directory');
  my $project_tex = $arg{manifest}{project}{tex} // {};
  my $shared_tex_relative = File::Spec->canonpath(
    $project_tex->{directory} // 'Include',
  );
  my $shared_tex_candidate = File::Spec->rel2abs(
    $shared_tex_relative, $project_root,
  );
  _require_within($shared_tex_candidate, $project_root, 'shared TeX directory');
  my $shared_tex_directory = -e $shared_tex_candidate
    ? abs_path($shared_tex_candidate)
      // die "cannot resolve shared TeX directory: $shared_tex_candidate"
    : $shared_tex_candidate;
  _require_within($shared_tex_directory, $project_root, 'shared TeX directory');
  die "shared TeX path is not a directory: $shared_tex_directory"
    if -e $shared_tex_directory && !-d $shared_tex_directory;
  my $project_config_file = $project_tex->{config} // 'projectconfig.tex';
  my $project_config_candidate = File::Spec->catfile(
    $shared_tex_directory, $project_config_file,
  );
  my $project_config_signature;
  if (-e $project_config_candidate) {
    my $canonical = abs_path($project_config_candidate)
      // die "cannot resolve project configuration file: $project_config_candidate";
    _require_within($canonical, $shared_tex_directory,
      'project configuration file');
    die "project configuration path is not a regular file: $canonical"
      if !-f $canonical;
    open my $config_handle, '<:raw', $canonical
      or die "cannot read project configuration file '$canonical': $!";
    local $/;
    my $config_source = <$config_handle>;
    close $config_handle
      or die "cannot close project configuration file '$canonical': $!";
    $project_config_signature = sha256_hex($config_source);
  }
  my $logical_ordinal = _logical_ordinal(
    $configuration->{structure}{units}, $physical_unit,
    $target->{unit_scopes} // [],
  );
  my $source_candidate = File::Spec->rel2abs(
    $request->{source}, $unit_directory,
  );
  my $source = abs_path($source_candidate)
    // die "source file not found: $source_candidate";
  die "source is not a regular file: $source" if !-f $source;
  my $build_directory = File::Spec->catdir(
    $project_root, '.osglecture', 'build', $physical_unit,
    $target_name, $language,
  );
  my $artifact = File::Spec->catfile($build_directory, "$job_id.pdf");
  my $profile_class = $target->{profile_class}
    // die "target '$target_name' has no profile class";
  my $document_metadata_policy = $target->{document_metadata}
    // die "target '$target_name' has no document metadata policy";
  my $shell_escape = $arg{manifest}{security}{shell_escape} // 'restricted';
  my $document_metadata;
  my $document_metadata_contract;
  my $document_metadata_file = 'documentmetadata.tex';
  my $candidate = File::Spec->catfile(
    $shared_tex_directory, $document_metadata_file,
  );
  if ($document_metadata_policy eq 'required') {
    die "document metadata file required for target '$target_name': $candidate"
      if !-e $candidate;
    my $canonical = abs_path($candidate)
      // die "cannot resolve document metadata file: $candidate";
    die "document metadata path is not a regular file: $canonical"
      if !-f $canonical;
    _require_within($canonical, $shared_tex_directory, 'document metadata file');
    open my $metadata_handle, '<:raw', $canonical
      or die "cannot read document metadata file '$canonical': $!";
    local $/;
    my $metadata_source = <$metadata_handle>;
    close $metadata_handle
      or die "cannot close document metadata file '$canonical': $!";
    $document_metadata = {
      path      => $canonical,
      signature => sha256_hex($metadata_source),
    };
    $document_metadata_contract = {
      path      => File::Spec->catfile(
        $shared_tex_relative, $document_metadata_file,
      ),
      signature => $document_metadata->{signature},
    };
  }
  my $structure_signature =
    $configuration->{structure}{signature}
      // die "resolved configuration has no structure signature";

  my $config_signature = sha256_hex(
    JSON::PP->new->canonical->encode({
      manifest    => {
        schema    => $arg{manifest}{schema},
        bundle_preset => $arg{manifest}{bundle_preset},
        project   => $arg{manifest}{project},
        languages => $arg{manifest}{languages},
        target    => $arg{manifest}{targets}{$target_name},
        security  => $arg{manifest}{security} // {},
      },
      bundle_preset =>
        $configuration->{definitions}{bundle_preset}{signature},
      target_definition => $target->{signature},
      target      => $target_name,
      doctype     => $doctype,
      language    => $language,
      physical_unit => $physical_unit,
      structure_signature => $structure_signature,
      shell_escape => $shell_escape,
      document_metadata => $document_metadata_contract,
      document_metadata_policy => $document_metadata_policy,
      project_tex => {
        directory => $shared_tex_relative,
        config    => $project_config_file,
        (defined($project_config_signature)
          ? (signature => $project_config_signature) : ()),
      },
    }),
  );
  return {
    schema              => $SCHEMA,
    job_id              => $job_id,
    context             => 'series',
    series_id           => $request->{series_id},
    physical_unit       => $physical_unit,
    physical_number     => $number,
    logical_ordinal     => $logical_ordinal,
    unit_scope          => $unit_scope,
    unit_role           => $role,
    unit_id             => undef,
    target              => $target_name,
    doctype             => $doctype,
    profile_class       => $profile_class,
    document_metadata_policy => $document_metadata_policy,
    language            => $language,
    available_languages => $arg{manifest}{languages}{available},
    bundle_preset       =>
      $configuration->{definitions}{bundle_preset}{reference},
    project_root        => $project_root,
    project_manifest    => abs_path($arg{resolved}{configuration}{path})
      // die("project manifest not found: "
        . $arg{resolved}{configuration}{path}),
    shared_tex_directory => $shared_tex_directory,
    shared_tex_relative  => $shared_tex_relative,
    project_config_file  => $project_config_file,
    project_config_signature => $project_config_signature,
    source              => $source,
    source_directory    => dirname($source),
    build_directory     => $build_directory,
    aux_directory       => $build_directory,
    artifact            => $artifact,
    shell_escape        => $shell_escape,
    document_metadata   => $document_metadata,
    structure_signature => $structure_signature,
    config_signature    => $config_signature,
  };
}

sub render {
  my ($class, $spec) = @_;
  my @languages = map { _tex_atom($_) } @{ $spec->{available_languages} };
  my @lines = (
    '% Generated by OLLM. Do not edit.',
    "\\OsgLectureBuildSetup{",
    "  schema={" . $spec->{schema} . "},",
    "  job-id={" . _tex_atom($spec->{job_id}) . "},",
    "  context={" . _tex_atom($spec->{context}) . "},",
    "  series-id={" . _tex_atom($spec->{series_id}) . "},",
    "  physical-unit={" . _tex_atom($spec->{physical_unit}) . "},",
    "  physical-number={" . _tex_atom($spec->{physical_number}) . "},",
    "  logical-ordinal={" . _tex_atom($spec->{logical_ordinal}) . "},",
    "  unit-scope={" . _tex_atom($spec->{unit_scope}) . "},",
    "  unit-role={" . _tex_atom($spec->{unit_role}) . "},",
    (defined($spec->{unit_id})
      ? "  unit-id={" . _tex_atom($spec->{unit_id}) . "},"
      : ()),
    (defined($spec->{generation_id})
      ? "  generation-id={" . _tex_atom($spec->{generation_id}) . "},"
      : ()),
    "  target={" . _tex_atom($spec->{target}) . "},",
    "  profile-class={" . _tex_atom($spec->{profile_class}) . "},",
    "  document-metadata-policy={"
      . _tex_atom($spec->{document_metadata_policy}) . "},",
    "  doctype={" . _tex_atom($spec->{doctype}) . "},",
    "  language={" . _tex_atom($spec->{language}) . "},",
    "  available-languages={" . join(',', @languages) . "},",
    "  bundle-preset={" . _tex_atom($spec->{bundle_preset}) . "},",
    "  shared-tex-directory={" . _tex_path($spec->{shared_tex_directory}) . "},",
    "  project-config-file={" . _tex_atom($spec->{project_config_file}) . "},",
    "  shell-escape={" . _tex_atom($spec->{shell_escape}) . "},",
    "  structure-signature={" . _tex_atom($spec->{structure_signature}) . "},",
    "  config-signature={" . _tex_atom($spec->{config_signature}) . "}",
    "}",
    '',
  );
  return join "\n", @lines;
}

sub _logical_ordinal {
  my ($units, $physical, $scopes) = @_;
  my %scope = map { $_ => 1 } @$scopes;
  my ($ordinal, $excursus, $appendix) = (0, 0, 0);
  for my $unit (@$units) {
    my $applies = ($unit->{unit_scope} // '') eq ''
      || $scope{$unit->{unit_scope} // ''};
    next if !$applies;
    return '' if $unit->{physical_unit} eq $physical
      && ($unit->{unit_role} // '') eq 'i';
    next if ($unit->{unit_role} // '') eq 'i';
    my $role = $unit->{unit_role} // 'content';
    my $value;
    if ($role eq 'excursus' || $role eq 'e') {
      die "excursus '$unit->{physical_unit}' has no preceding content unit"
        if !$ordinal;
      $value = $ordinal . 'e' . ++$excursus;
    } elsif ($role eq 'appendix' || $role eq 'a') {
      ++$ordinal;
      $value = $ordinal . 'ap' . ++$appendix;
    } else {
      ++$ordinal;
      ($excursus, $appendix) = (0, 0);
      $value = $ordinal;
    }
    return $value if $unit->{physical_unit} eq $physical;
  }
  die "cannot determine logical ordinal for physical unit '$physical'";
}

sub write_atomic {
  my ($class, $path, $content) = @_;
  my ($volume, $directories, $filename) = File::Spec->splitpath($path);
  $directories = '.' if $directories eq '';
  my ($handle, $temporary) = tempfile('.ollm-build-XXXXXX', DIR => $directories);
  binmode $handle, ':raw';
  print {$handle} $content or die "cannot write '$temporary': $!";
  close $handle or die "cannot close '$temporary': $!";
  if (-f $path) {
    open my $old, '<:raw', $path or die "cannot read '$path': $!";
    local $/;
    my $existing = <$old>;
    close $old;
    if ($existing eq $content) {
      unlink $temporary or die "cannot remove '$temporary': $!";
      return 0;
    }
  }
  if (!rename $temporary, $path) {
    my $rename_error = $!;
    if ($^O eq 'MSWin32' && -f $path) {
      my $backup = "$path.ollm-old-$$";
      rename $path, $backup
        or die "cannot prepare Windows replacement of '$path': $!";
      if (!rename $temporary, $path) {
        my $replacement_error = $!;
        rename $backup, $path
          or die "cannot replace '$path' ($replacement_error) or restore it: $!";
        die "cannot replace '$path' with '$temporary': $replacement_error";
      }
      unlink $backup or die "cannot remove replaced build file '$backup': $!";
    } else {
      die "cannot replace '$path' with '$temporary': $rename_error";
    }
  }
  return 1;
}

sub write_for_spec {
  my ($class, $spec) = @_;
  make_path($spec->{build_directory});
  my $path = File::Spec->catfile(
    $spec->{build_directory}, "$spec->{job_id}.osgbuild.tex",
  );
  $class->write_atomic($path, $class->render($spec));
  return $path;
}

sub _parse_unit {
  my ($name) = @_;
  die "invalid series unit directory '$name'; expected "
    . "<three digits><optional scope code>-<optional role-><slug>"
    if $name !~ /\A(\d{3})([a-z]{0,2})-(?:(a|e|i)-)?(.+)\z/;
  my ($number, $unit_scope, $role, $slug) = ($1, $2, $3 // 'content', $4);
  die "invalid empty unit slug in '$name'" if $slug eq '';
  return ($number, $unit_scope, $role, $slug);
}

sub _validate_job_atom {
  my ($label, $value, $allow_hyphen) = @_;
  die "$label is missing" if !defined $value || $value eq '';
  my $pattern = $allow_hyphen
    ? qr/\A[A-Za-z0-9._]+(?:-[A-Za-z0-9._]+)*\z/
    : qr/\A[A-Za-z0-9._]+\z/;
  die "invalid $label '$value' for a portable job name"
    if $value !~ $pattern;
}

sub _require_within {
  my ($path, $root, $label) = @_;
  OLLM::Path::require_within(
    $path, $root, "$label '$path' is outside project root '$root'",
  );
}

sub _tex_atom {
  my ($value) = @_;
  $value //= '';
  die "value '$value' cannot be represented safely in a TeX build file"
    if $value !~ /\A[A-Za-z0-9 ._+\/=-]*\z/;
  return $value;
}

sub _tex_path {
  my ($value) = @_;
  $value //= '';
  $value =~ s{\\}{/}g;
  die "path '$value' cannot be represented safely in a TeX build file"
    if $value =~ /[{}%#\r\n]/;
  return $value;
}

1;
