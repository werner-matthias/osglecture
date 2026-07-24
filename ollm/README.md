# OLLM

OLLM (OSG LaTeX Lecture Maker) is the build frontend of the `osglecture`
bundle. It selects document and language variants and delegates individual
LaTeX builds to `latexmk`.

The program in `ollm` is the new portable command-line launcher. Compatible
builds are currently delegated to the preserved `ollm-legacy.rc`, version
0.11.1. Its command-line interface remains the compatibility baseline while
the build engine is being redesigned.

- [`DESIGN.md`](DESIGN.md) specifies the target architecture and records its
  rationale.
- [`ollm.tex`](ollm.tex) is the source of the typeset user documentation.

## Development commands

Run these commands from this directory:

```sh
l3build check
l3build doc
l3build install
```

The first build stage checks the Perl syntax. Functional CLI and integration
tests are added as the new implementation is introduced.

The first new interfaces can be inspected without starting LaTeX:

```sh
ollm --version
ollm build script --language=en --dry-run
ollm build script --language=en --dry-run --format=json
ollm doctor
```

## TOML parser

OLLM ships the read-only parser from `TOML::Tiny` 0.22. No CPAN module has to
be installed by users. `ollm doctor` reports the parser name, version, and
origin.

The bundled copy is intentional: TeX Live does not guarantee third-party Perl
modules, and its Windows Perl installation is deliberately minimal. Provenance
and licensing are recorded in [`THIRD_PARTY.md`](THIRD_PARTY.md).
Detailed fallback instructions, including the TeX Live setting for an external
Perl on Windows, are in [`DEPENDENCIES.md`](DEPENDENCIES.md).

Developers who want a separate upstream installation for comparison can use:

```sh
cpanm TOML::Tiny
```

or, with the CPAN client included in many Perl installations:

```sh
cpan TOML::Tiny
```

OLLM itself continues to use its tested bundled parser; installing the CPAN
distribution is therefore optional and does not repair or change an OLLM
installation.

## Project manifest

The manifest is named `ollmconfig.toml` and marks the project root. OLLM
searches for it from the working directory upwards. An explicit manifest or
project root can be selected with:

```sh
ollm build script --config=/path/to/ollmconfig.toml --dry-run
ollm build script --project-root=/path/to/project --dry-run
```

If `ollmconfig.toml` and the legacy `ollmconfig.pl` occur in the same
directory, OLLM reports an error instead of choosing one implicitly.

Profiles and targets are resolved from versioned definitions shipped with the
bundle. Additional absolute or project-root-relative search paths can be put
in `.ollmconfig.local.toml`:

```toml
schema = 1

[definitions]
paths = ["configuration", "/opt/osglecture/definitions"]
```

Unknown standard keys, profiles, and targets are errors. Semantic diagnostics
include the configuration file and source line whenever the offending key is
present in the TOML source. The bundle-level minimal configuration example is
in [`../examples/series-minimal`](../examples/series-minimal).

For a concrete series build, the resolved configuration is normalized into a
job-bound `<jobname>.osgbuild.tex`. The reader in
`../osglecture/osglecture-config.sty` validates its schema and requires its
`job-id` to match TeX's current job name. `--dry-run --format=json` exposes the
same normalized `build_spec` without writing or starting LaTeX.
