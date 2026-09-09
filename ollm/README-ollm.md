# OLLM

OLLM (OSG LaTeX Lecture Maker) is the build frontend of the `osglecture`
bundle. It selects document and language variants and delegates individual
LaTeX builds to `latexmk`.

## For Users of OSGBeamer

There are a few conceptual differences between the OSGLecture and OSGBeamer
build models from a user's perspective:

- The configuration format has changed from Perl to TOML. Accordingly, the
  configuration file is no longer `ollmconfig.pl`, but `ollmconfig.toml`. In
  addition, settings can be configured in more places. Old Perl-based
  configurations can be converted with `ollm convertproject`; however, a
  follow-up check is recommended.
- Resulting artifacts (PDFs) are no longer stored in the unit directories, but
  in subdirectories of `.osglecture/build` in the project root. This has two
  advantages:
  - Input materials are clearly separated from output materials, improving
    overall clarity.
  - If the build reaches an invalid state, entire output directories can be
    deleted as a last resort without risking the removal of input files.

## Installation

Run these commands from this directory:

```sh
l3build check
l3build -full install
```

## Documentation

Please read `ollm-en.pdf` or `ollm-de.pdf` for documentation in English or German.

## TL;DR: A Few Examples

### Build the Script Chapter in English

```sh
ollm build script --language=en
```

or

```sh
ollm script lang=en
```

### Check Installation and Environment

```sh
ollm doctor
```

### Getting Help

```sh
ollm --help
```
