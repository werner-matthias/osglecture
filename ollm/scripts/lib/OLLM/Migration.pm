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
  die "ollmconfig.toml already exists: $toml" if -e $toml;

  my ($source, @warnings);
  if (-f $perl) {
    ($source, @warnings) = $class->convert_source($perl, $root);
  } elsif ($action eq 'convertproject') {
    die "legacy configuration not found: $perl";
  } else {
    $source = $class->generic_source($root);
  }

  open my $handle, '>:raw', $toml
    or die "cannot create '$toml': $!";
  print {$handle} $source or die "cannot write '$toml': $!";
  close $handle or die "cannot close '$toml': $!";

  my $tex_directory = _manifest_tex_directory($source);
  my $include = File::Spec->catdir($root, $tex_directory);
  make_path($include) if !-d $include;
  my $project_config = File::Spec->catfile($include, 'projectconfig.tex');
  my $project_config_created = !-e $project_config;
  if (!-e $project_config) {
    my $lectdates = File::Spec->catfile($include, 'lectdates.tex');
    my ($tex_source, @tex_warnings) = -f $lectdates
      ? $class->convert_lectdates($lectdates)
      : ($class->generic_project_config(), ());
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
    converted => -f $perl ? 1 : 0, warnings => \@warnings,
  };
}

sub generic_project_config {
  return <<'TEX';
% Shared metadata for the lecture project. Replace these dummy values.
\title{Course title}
\author{First name Last name}
\date{Term and year}
\institute{Institution}

\LectureProjectSetup{
  presentation-profile=beamer,
  longform-profile=scrbook
  % If you want class ltx-talk as the presentation backend, uncomment the
  % following line and comment out presentation-profile=beamer above.
  % presentation-profile=ltx-talk,
  % If you want class book as the long-form backend, uncomment the following
  % line and comment out longform-profile=scrbook above.
  % longform-profile=book
}
TEX
}

sub convert_lectdates {
  my ($class, $path) = @_;
  open my $handle, '<:raw', $path or die "cannot read '$path': $!";
  local $/;
  my $legacy = <$handle>;
  close $handle or die "cannot close '$path': $!";

  my @commands;
  for my $name (qw(title subtitle author date course event lehrveranstaltung institute tucurl logo)) {
    push @commands, _extract_tex_commands($legacy, $name);
  }
  @commands = sort { $a->[0] <=> $b->[0] } @commands;
  my $metadata = join("\n", map { $_->[1] } @commands);
  my @warnings;
  push @warnings, "no recognizable metadata found in '$path'"
    if !@commands;
  push @warnings, "legacy class options in '$path' require manual conversion"
    if $legacy =~ /\\(?:SetGlobalClassOptions|EnforceGlobalClassOptions)\b/;
  return ("% Converted from lectdates.tex; review the copied metadata.\n"
    . ($metadata ne '' ? "$metadata\n\n" : "")
    . $class->generic_project_config_profiles(), @warnings);
}

sub generic_project_config_profiles {
  my ($class) = @_;
  my $source = $class->generic_project_config();
  $source =~ s/\A.*?(?=\\LectureProjectSetup)//s;
  return $source;
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

sub _manifest_tex_directory {
  my ($source) = @_;
  return $1 if $source =~ /^directory\s*=\s*"([^"]+)"/m;
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
  if (File::Spec->file_name_is_absolute($tex_directory)
      || $tex_directory =~ m{\A\.\.(?:[\\/]|\z)}) {
    push @warnings,
      "shared_source_dir could not be converted portably; using 'Include'";
    $tex_directory = 'Include';
  }
  my $source = _manifest(
    root => $root, default => $default, languages => \@languages,
    shell_escape => $shell, tex_directory => $tex_directory,
    deployment => _legacy_deployment($perl),
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
#
# [deployment.types.handout]
# paths = ["deployment/handouts"]
# filename = "{role}{chapter:02}-{unit}-{lang}.pdf"
#
# [security.deployment]
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
  return "schema = 1\nbundle_preset = \"OSG lecture/1\"\n\n"
    . "[project]\nid = " . _quote($id) . "\n\n"
    . "[project.tex]\ndirectory = $tex_directory\n"
    . "config = \"projectconfig.tex\"\n\n"
    . "[languages]\navailable = [$languages]\ndefault = $default\n\n"
    . join('', map { "[targets.$_]\nlanguages = [$languages]\n\n" }
        qw(slides handout script))
    . "[security]\nshell_escape = " . _quote($arg{shell_escape}) . "\n\n"
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
  $output .= "[security.deployment]\noverwrite = \"explicit\"\n\n";
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
