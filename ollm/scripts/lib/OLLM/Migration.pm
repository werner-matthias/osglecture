package OLLM::Migration;

use v5.30;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(basename dirname);
use File::Path qw(make_path);
use File::Spec;

sub execute {
  my ($class, %arg) = @_;
  my $action = $arg{action} // die "missing migration action";
  my $start = abs_path($arg{start_dir} // '.')
    // die "migration directory not found";
  my $root = defined $arg{project_root}
    ? File::Spec->rel2abs($arg{project_root}, $start) : $start;
  if (!defined $arg{project_root} && !defined $arg{config}) {
    my $candidate = $start;
    while (1) {
      if (-f File::Spec->catfile($candidate, 'ollmconfig.toml')
          || -f File::Spec->catfile($candidate, 'ollmconfig.pl')) {
        $root = $candidate;
        last;
      }
      my $parent = dirname($candidate);
      last if $parent eq $candidate;
      $candidate = $parent;
    }
  }
  $root = abs_path($root) // die "project root not found: $root";
  die "project root is not a directory: $root" if !-d $root;

  my $toml = File::Spec->catfile($root, 'ollmconfig.toml');
  my $perl = defined $arg{config}
    ? File::Spec->rel2abs($arg{config}, $start)
    : File::Spec->catfile($root, 'ollmconfig.pl');
  $root = dirname(abs_path($perl)) if defined $arg{config} && -f $perl;
  $toml = File::Spec->catfile($root, 'ollmconfig.toml');

  my @warnings;
  my ($source, $manifest_kept);
  if (-e $toml) {
    # A readable, structurally complete manifest may have been written by an
    # earlier run or edited by hand; never overwrite it. Only an unusable
    # leftover (truncated write, missing core sections) is replaced.
    if (_toml_looks_complete($toml)) {
      $source = _read_file($toml);
      $manifest_kept = 1;
    }
    else {
      push @warnings, "replaced an incomplete ollmconfig.toml left by an "
        . "earlier migration; review it and re-run if it held manual edits";
    }
  }

  if (!$manifest_kept) {
    if (-f $perl) {
      ($source, my @convert_warnings) = $class->convert_source($perl, $root);
      push @warnings, @convert_warnings;
    }
    elsif ($action eq 'convertproject') {
      die "legacy configuration not found: $perl";
    }
    else {
      $source = $class->generic_source($root);
    }
  }

  my $tex_directory = _manifest_tex_directory($source);
  my $include = File::Spec->catdir($root, $tex_directory);
  my $project_config = File::Spec->catfile($include, 'projectconfig.tex');

  # A kept manifest can name any directory; warn rather than silently write
  # projectconfig.tex somewhere TeX or Windows cannot reliably read back.
  push @warnings, "the shared TeX directory in ollmconfig.toml is '$1'; spaces "
    . "and quotes are unreliable in TeX file lookups and invalid on Windows -- "
    . "prefer a plain relative name"
    if $manifest_kept
    && $source =~ /^\s*tex_directory\s*=\s*["']([^\n]*?[\s"][^\n]*?)["']\s*(?:#.*)?$/m;

  die "ollmconfig.toml already exists: $toml"
    if $manifest_kept && -e $project_config;

  make_path($include) if !-d $include;
  if (!$manifest_kept) {
    open my $handle, '>:raw', $toml
      or die "cannot create '$toml': $!";
    print {$handle} $source or die "cannot write '$toml': $!";
    close $handle or die "cannot close '$toml': $!";
  }
  else {
    push @warnings, "kept the existing ollmconfig.toml; created only "
      . "Include/projectconfig.tex to match it";
  }

  my $languages = _manifest_languages($source);
  my $project_config_created = !-e $project_config;
  if ($project_config_created) {
    my $lectdates = File::Spec->catfile($include, 'lectdates.tex');
    my ($tex_source, @tex_warnings);
    if (-f $lectdates) {
      ($tex_source, @tex_warnings) =
        $class->convert_lectdates($lectdates, $languages);
    }
    else {
      $tex_source = $class->generic_project_config($languages);
      push @tex_warnings, "no lectdates.tex found at '$lectdates'; wrote "
        . "placeholder metadata -- copy it from the legacy file manually if it "
        . "lives elsewhere"
        if -f $perl;
    }
    push @warnings, @tex_warnings;
    open my $tex_handle, '>:raw', $project_config
      or die "cannot create '$project_config': $!";
    print {$tex_handle} $tex_source
      or die "cannot write '$project_config': $!";
    close $tex_handle or die "cannot close '$project_config': $!";
  }

  return {
    path => $toml, project_config_path => $project_config,
    project_config_created => $project_config_created,
    manifest_kept => $manifest_kept ? 1 : 0,
    converted => (!$manifest_kept && -f $perl) ? 1 : 0,
    warnings => \@warnings,
  };
}

sub _read_file {
  my ($path) = @_;
  open my $fh, '<:raw', $path or die "cannot read '$path': $!";
  local $/;
  my $content = <$fh>;
  close $fh or die "cannot close '$path': $!";
  return $content;
}

# A manifest is worth preserving when it parses and carries the sections the
# generator always emits. A truncated write drops trailing tables and fails one
# of these checks; if no TOML parser is available the file is kept untouched.
sub _toml_looks_complete {
  my ($path) = @_;
  my $source = eval { _read_file($path) };
  return 0 if !defined $source || $source !~ /\S/;
  return 1 if !eval { require TOML::Tiny::Parser; 1 };
  my $parsed = eval { TOML::Tiny::Parser->new(strict => 1)->parse($source) };
  return 0 if ref $parsed ne 'HASH';
  return (exists $parsed->{schema}
    && ref $parsed->{project} eq 'HASH'
    && ref $parsed->{targets} eq 'HASH'
    && ref $parsed->{targets}{defaults} eq 'HASH') ? 1 : 0;
}

sub _manifest_languages {
  my ($source) = @_;
  return [] if $source !~ /^languages\s*=\s*\[([^\]]*)\]/m;
  return [ $1 =~ /['"]([^'"]*)['"]/g ];
}

# A pointer, not a setting: the document profiles are chosen in
# ollmconfig.toml ([targets.defaults].presentation_profile / longform_profile,
# or profile on a single target), because the class needs the metadata
# contract before it runs. projectconfig.tex keeps only LaTeX-side semantics.
sub _project_config_profiles {
  return <<'TEX';
% Document profiles (beamer/ltx-talk, book/scrbook) are chosen in
% ollmconfig.toml, not here. The bundle preset defaults to beamer + scrbook;
% to change one, set presentation_profile / longform_profile in
% [targets.defaults], or profile on a single [targets.<name>].
TEX
}

# langselect derives the bilingual helper macro name from the selectable-language
# order: de,en -> \ldeen ; en,de -> \lende. Only two-language projects get one;
# other counts fall through to a plain (or trilingual) configuration.
sub _bilingual_macro {
  my ($languages) = @_;
  return undef if !$languages || @$languages != 2;
  return 'l' . $languages->[0] . $languages->[1];
}

# The selectable languages come from the manifest for an OLLM build; the class
# wires them into langselect from the build file. projectconfig.tex only keeps
# the LaTeX-variant map, so the converter emits a stub, not a selectable list.
sub _language_setup_line {
  my ($languages) = @_;
  return '' if !$languages || @$languages < 2;
  return "% Language selection comes from ollmconfig.toml. Add the langselect\n"
    . "% variant mapping here if needed, e.g.:\n"
    . "% \\LectureProjectSetup{languages={map={"
    . join(',', map { "$_=..." } @$languages) . "}}}\n";
}

sub generic_project_config {
  my ($class, $languages) = @_;
  my $macro = _bilingual_macro($languages);
  my $setup = _language_setup_line($languages);

  my $body = "% Shared metadata for the lecture project. Replace these dummy "
    . "values.\n";
  if (defined $macro) {
    $body .= "% This project builds in several languages; wrap language-"
      . "specific metadata\n% as \\$macro" . '{...}{...} (first argument '
      . "$languages->[0], second $languages->[1]).\n";
  }
  elsif ($setup ne '') {
    $body .= "% This project builds in several languages; wrap language-"
      . "specific metadata\n% in the langselect macro generated for the "
      . "languages below.\n";
  }
  $body .= $setup;
  $body .= defined $macro
    ? "\\title{\\$macro" . '{Kurstitel}{Course title}}' . "\n"
    : "\\title{Course title}\n";
  $body .= "\\author{First name Last name}\n"
    . "\\date{Term and year}\n"
    . "\\institute{Institution}\n\n"
    . _project_config_profiles();
  return $body;
}

sub convert_lectdates {
  my ($class, $path, $languages) = @_;
  open my $handle, '<:raw', $path or die "cannot read '$path': $!";
  local $/;
  my $legacy = <$handle>;
  close $handle or die "cannot close '$path': $!";

  # osglecture provides these directly or as a documented legacy alias.
  my @copy = qw(
    title subtitle author date course event lehrveranstaltung conference institute
  );
  # Accepted by the legacy TUC beamer theme but undefined under osglecture:
  # keep the text, commented out, so nothing vanishes and nothing breaks.
  my @comment = qw(tucurl logo);

  my @found;
  push @found, map { [@$_, 0] } _extract_tex_commands($legacy, $_) for @copy;
  push @found, map { [@$_, 1] } _extract_tex_commands($legacy, $_) for @comment;
  @found = sort { $a->[0] <=> $b->[0] } @found;

  my ($normalized, @lines);
  for my $entry (@found) {
    my (undef, $text, $commented) = @$entry;
    if ($commented) {
      push @lines, "% $text";
      next;
    }
    # \ldeenr was the pre-langselect robust spelling of \ldeen; langselect's
    # \ldeen is robust on its own, so normalize to it.
    $normalized = 1 if $text =~ s/\\ldeenr(?![a-zA-Z])/\\ldeen/g;
    push @lines, $text;
  }
  my $metadata = join("\n", @lines);

  # Comments never carry an active command; strip them before scanning.
  my $active = $legacy =~ s/(?<!\\)%.*//rg;
  my @warnings;
  push @warnings, "no recognizable metadata found in '$path'" if !@found;

  my @present = grep { $active =~ /\\\Q$_\E(?![a-zA-Z])/ } @comment;
  push @warnings, "commands with no osglecture equivalent were commented out in "
    . "the converted configuration: " . join(', ', map { "\\$_" } @present)
    if @present;

  push @warnings, "'\\ldeenr' in '$path' was rewritten to '\\ldeen'"
    if $normalized;

  my $de_en = $languages && @$languages == 2
    && $languages->[0] eq 'de' && $languages->[1] eq 'en';
  push @warnings, "copied metadata in '$path' uses '\\ldeen', but this project's "
    . "language order does not generate that macro; check the argument order "
    . "against '\\" . (_bilingual_macro($languages) // 'lende') . "' or set the "
    . "languages to de, en"
    if $metadata =~ /\\ldeen(?![a-zA-Z])/ && !$de_en;

  my $includes = '';
  for my $name ($active =~ /\\input\s*\{\s*([^}]+?)\s*\}/g) {
    (my $bare = $name) =~ s/\.tex\z//;
    if ($bare =~ m{[\\/]}) {
      $includes .= "% \\IncludeOsgLecturePreamble{$bare} "
        . "% path outside the shared TeX directory -- convert manually\n";
      push @warnings, "'\\input{$name}' in '$path' points outside the shared "
        . "TeX directory; convert it manually";
    }
    else {
      $includes .= "\\IncludeOsgLecturePreamble{$bare}\n";
      push @warnings, "'\\input{$name}' in '$path' became "
        . "'\\IncludeOsgLecturePreamble{$bare}'; the fragment now runs after "
        . "\\LoadClass -- use the starred form if it must run earlier";
    }
  }
  $includes = "\n% '\\input' fragments from the legacy lectdates.tex. Unlike "
    . "\\input, these\n% are replayed only after the document class has loaded; "
    . "use\n% \\IncludeOsgLecturePreamble* for a fragment that must run "
    . "earlier.\n" . $includes
    if $includes ne '';

  push @warnings, "legacy class options in '$path' require manual conversion"
    if $active =~ /\\(?:SetGlobalClassOptions|EnforceGlobalClassOptions)(?![a-zA-Z])/;

  my $body = "% Converted from lectdates.tex; review the copied metadata.\n";
  $body .= _language_setup_line($languages);
  $body .= "$metadata\n" if $metadata ne '';
  $body .= $includes;
  $body .= "\n" . _project_config_profiles();
  return ($body, @warnings);
}

sub _extract_tex_commands {
  my ($source, $name) = @_;
  my @found;
  while ($source =~ /\\\Q$name\E(?=\s*[<\[{])/g) {
    my $start = $-[0];
    my $pos = pos($source);
    my $line_start = rindex($source, "\n", $start - 1) + 1;
    my $prefix = substr($source, $line_start, $start - $line_start);
    $prefix =~ s/\\%//g;
    next if $prefix =~ /%/;
    $pos++ while substr($source, $pos, 1) =~ /\s/;
    for my $pair (['<', '>'], ['[', ']']) {
      while (substr($source, $pos, 1) eq $pair->[0]) {
        $pos = _balanced_end($source, $pos, @$pair);
        return @found if !defined $pos;
        $pos++ while substr($source, $pos, 1) =~ /\s/;
      }
    }
    next if substr($source, $pos, 1) ne '{';
    my $end = _balanced_end($source, $pos, '{', '}');
    next if !defined $end;
    push @found, [$start, substr($source, $start, $end - $start)];
    pos($source) = $end;
  }
  return @found;
}

sub _balanced_end {
  my ($source, $start, $open, $close) = @_;
  my $depth = 0;
  for (my $i = $start; $i < length($source); ++$i) {
    my $char = substr($source, $i, 1);
    next if $i > 0 && substr($source, $i - 1, 1) eq '\\';
    ++$depth if $char eq $open;
    if ($char eq $close) {
      --$depth;
      return $i + 1 if $depth == 0;
    }
  }
  return;
}

# Reads the shared TeX directory ([project].tex_directory) back from a manifest
# -- the freshly generated one, or an existing file that is kept as-is. Accepts
# either quote style; a value with an embedded quote (or none at all) is left
# to the caller's fallback rather than parsed into a broken path.
sub _manifest_tex_directory {
  my ($source) = @_;
  return $1 if $source =~ /^\s*tex_directory\s*=\s*"([^"]+)"\s*(?:#.*)?$/m;
  return $1 if $source =~ /^\s*tex_directory\s*=\s*'([^']+)'\s*(?:#.*)?$/m;
  return 'Include';
}

sub convert_source {
  my ($class, $path, $root) = @_;
  open my $handle, '<:raw', $path or die "cannot read '$path': $!";
  local $/;
  my $perl = <$handle>;
  close $handle or die "cannot close '$path': $!";

  my %scalar;
  while ($perl =~ /^\s*(?:my\s+)?\$(\w+)\s*=\s*(['"])(.*?)\2\s*;/mg) {
    my ($name, $value) = ($1, $3);
    $value =~ s/\\(['"\\])/$1/g;
    $scalar{$name} = $value;
  }
  while ($perl =~ /^\s*(?:my\s+)?\$(\w+)\s*=\s*([01])\s*;/mg) {
    $scalar{$1} = $2;
  }

  my $default = $scalar{defaultlanguage} // 'de';
  my @languages = ($default);
  push @languages, grep { $_ ne $default } qw(de en);
  my $shell = ($scalar{shell_escape} // 0) ? 'full' : 'restricted';
  my @warnings;
  my $tex_directory = $scalar{shared_source_dir} // 'Include';
  $tex_directory =~ s{\A\.\.[\\/]}{};
  # Spaces, quotes, backslashes and the Windows-reserved characters do not
  # survive TeX file lookups (\IncludeOsgLecturePreamble, the class locating
  # projectconfig.tex) reliably and are invalid in Windows path components.
  if (File::Spec->file_name_is_absolute($tex_directory)
      || $tex_directory =~ m{\A\.\.(?:[\\/]|\z)}
      || $tex_directory =~ /["\s\\<>:|?*]/) {
    push @warnings,
      "shared_source_dir '$tex_directory' is not a portable relative path; "
      . "using 'Include'";
    $tex_directory = 'Include';
  }
  my $deployment = _legacy_deployment($perl);
  my $source = _manifest(
    root => $root, default => $default, languages => \@languages,
    shell_escape => $shell, tex_directory => $tex_directory,
    deployment => $deployment,
    overwrite => ($deployment ne '' ? 'explicit' : undef),
  );

  push @warnings, "defaultlanguage could not be read; using 'de'"
    if !exists $scalar{defaultlanguage};
  my @unsupported;
  push @unsupported, 'deployment restrictions/passwords'
    if $perl =~ /\%deploy_restriction\b|\$deploy_pw\b/;
  push @unsupported, 'dynamically assigned deployment settings'
    if $perl =~ /\%(?:deploy_path|deploy_file)\s*=/;
  push @unsupported, 'shared data path'
    if $perl =~ /\$shared_data_dir\b/;
  push @unsupported, 'chapter-number settings'
    if $perl =~ /\$(?:first_chapter_number|lectconfig|lectureprefix)\b|\@first_chapter_number\b/;
  push @warnings, 'not represented in TOML: ' . join(', ', @unsupported)
    if @unsupported;
  push @warnings, 'the Perl file contains executable or unrecognized statements; review the generated manifest'
    if $perl =~ /^\s*(?!#|$|(?:my\s+)?[$@%]\w+\s*=)[^\s]/m;
  return ($source, @warnings);
}

sub generic_source {
  my ($class, $root) = @_;
  return _manifest(
    root => $root, default => 'de', languages => [qw(de en)],
    shell_escape => 'restricted', tex_directory => 'Include',
  ) . <<'TOML';

# Deployment copies promoted PDF artifacts. Enable and adapt these examples;
# OLLM never creates missing destination directories.
# [deployment]
# series = "both" # units | collection | both
# paths = ["deployment"]
# filename = "{role}{chapter:02}-{unit}-{lang}.pdf"
#
# [deployment.types.handout]
# paths = ["deployment/handouts"]
#
# [security]
# overwrite = "explicit" # explicit | automatic
TOML
}

sub _manifest {
  my (%arg) = @_;
  my $id = lc basename($arg{root});
  $id =~ s/[^a-z0-9._-]+/-/g;
  $id =~ s/\A[-._]+|[-._]+\z//g;
  $id = 'lecture-series' if $id eq '';
  my $languages = join(', ', map { _quote($_) } @{ $arg{languages} });
  my $default = _quote($arg{default});
  my $tex_directory = _quote($arg{tex_directory} // 'Include');
  my $security = "[security]\nshell_escape = " . _quote($arg{shell_escape}) . "\n";
  $security .= "overwrite = " . _quote($arg{overwrite}) . "\n"
    if defined $arg{overwrite};
  return "schema = 2\nbundle_preset = \"OSG lecture/1\"\n\n"
    . "[project]\nid = " . _quote($id) . "\n"
    . "tex_directory = $tex_directory\n"
    . "tex_config = \"projectconfig.tex\"\n\n"
    . "[targets.defaults]\nlanguages = [$languages]\n"
    . "default_language = $default\n\n"
    . join('', map { "[targets.$_]\n\n" } qw(slides handout script))
    . "$security\n"
    . ($arg{deployment} // '');
}

sub _legacy_deployment {
  my ($perl) = @_;
  my (%paths, %files);
  while ($perl =~ /\$deploy_path\s*\{\s*['"]?([^}'"\s]+)['"]?\s*\}\s*=\s*([^;]+);/g) {
    my ($key, $value) = ($1, $2);
    my @values = _literal_list($value);
    $paths{_deploy_alias($key)} = \@values if @values;
  }
  while ($perl =~ /\$deploy_file\s*\{\s*['"]?([^}'"\s]+)['"]?\s*\}\s*=\s*(['"])(.*?)\2\s*;/g) {
    $files{_deploy_alias($1)} = $3;
  }
  return '' if !%paths;
  my @types = qw(slides handout script);
  my $output = "[deployment]\nseries = \"both\"\n\n";
  for my $type (@types) {
    my $legacy_paths = $paths{$type} // $paths{all} // next;
    my @converted = map {
      my $path = $_;
      $path =~ s{\A\.\.[\\/]}{};
      $path;
    } @$legacy_paths;
    my $template = $files{$type} // $files{all}
      // '${prefix}-${num}-${doctype}-${lang}-${topic}';
    $template =~ s/\$\{prefix\}/{series}/g;
    $template =~ s/\$\{num\}/{chapter}/g;
    $template =~ s/\$\{doctype\}/{doctype}/g;
    $template =~ s/\$\{lang\}/{lang}/g;
    $template =~ s/\$\{topic\}/{unit}/g;
    $template .= '.pdf' if $template !~ /[.]pdf\z/i;
    $output .= "[deployment.types.$type]\npaths = ["
      . join(', ', map { _quote($_) } @converted) . "]\n"
      . "filename = " . _quote($template) . "\n\n";
  }
  return $output;
}

sub _deploy_alias {
  my ($name) = @_;
  return 'slides' if $name eq 'beamer' || $name eq 'presentation';
  return 'script' if $name eq 'article';
  return $name;
}

sub _literal_list {
  my ($source) = @_;
  $source =~ s/\A\s+|\s+\z//g;
  if ($source =~ /\A(['"])(.*?)\1\z/s) {
    return ($2);
  }
  return () if $source !~ /\A\[(.*)\]\z/s;
  my $inside = $1;
  my @values;
  pos($inside) = 0;
  while ($inside =~ /\G\s*(['"])(.*?)\1\s*(?:,|\z)/gc) {
    push @values, $2;
  }
  return () if (pos($inside) // 0) != length($inside);
  return @values;
}

sub _quote { my ($v) = @_; $v =~ s/([\\"])/\\$1/g; return qq{"$v"}; }

1;
