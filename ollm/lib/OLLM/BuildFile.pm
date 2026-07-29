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

our $VERSION = '0.1.0';
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
  _validate_job_atom('unit id', $slug, 1);
  my $job_id = join '-',
    $request->{series_id}, $number, $doctype, $language, $slug;
  my $project_root = abs_path($request->{project_root})
    // die "project root not found: $request->{project_root}";
  _require_within($unit_directory, $project_root, 'series unit directory');
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
  my $latex = _effective_latex(
    $configuration->{definitions}{bundle_preset}{latex} // {},
    $configuration->{user_defaults}{latex} // {},
    $arg{manifest}{latex} // {},
  );
  my $profile_key = $doctype =~ /\A(?:slides|handout)\z/
    ? 'presentation_profile' : 'script_profile';
  my $document_profile =
       $latex->{enforce}{$profile_key}
    // $latex->{defaults}{$profile_key}
    // ($doctype =~ /\A(?:slides|handout)\z/ ? 'beamer' : 'scrbook');
  die "invalid document profile '$document_profile'; expected a portable "
    . "profile identifier"
    if $document_profile !~ /\A[A-Za-z0-9][A-Za-z0-9.-]*\z/;
  my $shell_escape = $arg{manifest}{security}{shell_escape} // 'restricted';

  my $config_signature = sha256_hex(
    JSON::PP->new->canonical->encode({
      manifest    => {
        schema    => $arg{manifest}{schema},
        bundle_preset => $arg{manifest}{bundle_preset},
        project   => $arg{manifest}{project},
        languages => $arg{manifest}{languages},
        target    => $arg{manifest}{targets}{$target_name},
        security  => $arg{manifest}{security} // {},
        latex     => $arg{manifest}{latex} // {},
      },
      bundle_preset =>
        $configuration->{definitions}{bundle_preset}{signature},
      target_definition => $target->{signature},
      target      => $target_name,
      doctype     => $doctype,
      language    => $language,
      physical_unit => $physical_unit,
      latex       => $latex,
      document_profile => $document_profile,
      shell_escape => $shell_escape,
    }),
  );
  return {
    schema              => $SCHEMA,
    job_id              => $job_id,
    context             => 'series',
    series_id           => $request->{series_id},
    physical_unit       => $physical_unit,
    physical_number     => $number,
    unit_scope          => $unit_scope,
    unit_role           => $role,
    unit_id             => $slug,
    target              => $target_name,
    doctype             => $doctype,
    language            => $language,
    available_languages => $arg{manifest}{languages}{available},
    language_map        => $arg{manifest}{languages}{map} // {},
    bundle_preset       =>
      $configuration->{definitions}{bundle_preset}{reference},
    document_profile    => $document_profile,
    project_root        => $project_root,
    source              => $source,
    source_directory    => dirname($source),
    build_directory     => $build_directory,
    aux_directory       => $build_directory,
    artifact            => $artifact,
    latex               => $latex->{defaults},
    latex_enforce       => $latex->{enforce},
    shell_escape        => $shell_escape,
    config_signature    => $config_signature,
  };
}

sub render {
  my ($class, $spec) = @_;
  my @languages = map { _tex_atom($_) } @{ $spec->{available_languages} };
  my @map = map {
    _tex_atom($_) . '=' . _tex_atom($spec->{language_map}{$_})
  } sort keys %{ $spec->{language_map} };
  my %latex_key = (
    identity_profile     => 'identity-profile',
    numbering            => 'numbering',
    presentation_backend => 'presentation-backend',
    presentation_profile => 'presentation-profile',
    references           => 'references',
    script_profile       => 'script-profile',
    theme                => 'theme',
  );
  my @latex = map {
    "  $latex_key{$_}={" . _tex_atom($spec->{latex}{$_}) . "},"
  } sort keys %{ $spec->{latex} };
  my @enforce = map {
    "  $latex_key{$_}={" . _tex_atom($spec->{latex_enforce}{$_}) . "},"
  } sort keys %{ $spec->{latex_enforce} };
  $enforce[-1] =~ s/,\z// if @enforce;
  my @lines = (
    '% Generated by OLLM. Do not edit.',
    "\\OsgLectureBuildSetup{",
    "  schema={" . $spec->{schema} . "},",
    "  job-id={" . _tex_atom($spec->{job_id}) . "},",
    "  context={" . _tex_atom($spec->{context}) . "},",
    "  series-id={" . _tex_atom($spec->{series_id}) . "},",
    "  physical-unit={" . _tex_atom($spec->{physical_unit}) . "},",
    "  physical-number={" . _tex_atom($spec->{physical_number}) . "},",
    "  unit-scope={" . _tex_atom($spec->{unit_scope}) . "},",
    "  unit-role={" . _tex_atom($spec->{unit_role}) . "},",
    "  unit-id={" . _tex_atom($spec->{unit_id}) . "},",
    "  target={" . _tex_atom($spec->{target}) . "},",
    "  doctype={" . _tex_atom($spec->{doctype}) . "},",
    "  language={" . _tex_atom($spec->{language}) . "},",
    "  available-languages={" . join(',', @languages) . "},",
    "  language-map={" . join(',', @map) . "},",
    "  bundle-preset={" . _tex_atom($spec->{bundle_preset}) . "},",
    "  document-profile={" . _tex_atom($spec->{document_profile}) . "},",
    @latex,
    "  shell-escape={" . _tex_atom($spec->{shell_escape}) . "},",
    "  config-signature={" . _tex_atom($spec->{config_signature}) . "}",
    "}",
    (@enforce
      ? ("\\OsgLectureEnforceSetup{", @enforce, "}")
      : ()),
    '',
  );
  return join "\n", @lines;
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

sub _effective_latex {
  my ($preset, $user, $project) = @_;
  my %defaults = (
    %{ $preset->{defaults} // {} },
    %{ $user->{defaults} // {} },
    %{ $project->{defaults} // {} },
  );
  my %enforce = (
    %{ $preset->{enforce} // {} },
    %{ $project->{enforce} // {} },
  );
  return {
    defaults => \%defaults,
    enforce  => \%enforce,
  };
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
  my $relative = File::Spec->abs2rel($path, $root);
  die "$label '$path' is outside project root '$root'"
    if File::Spec->file_name_is_absolute($relative)
      || $relative =~ /\A\.\.(?:[\\\/]|\z)/;
}

sub _tex_atom {
  my ($value) = @_;
  $value //= '';
  die "value '$value' cannot be represented safely in a TeX build file"
    if $value !~ /\A[A-Za-z0-9 ._+\/=-]*\z/;
  return $value;
}

1;
