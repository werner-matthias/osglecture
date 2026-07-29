# OLLM

OLLM (OSG LaTeX Lecture Maker) is the build frontend of the `osglecture`
bundle. It selects document and language variants and delegates individual
LaTeX builds to `latexmk`.

The program in `ollm` is the portable command-line launcher. Builds using
`ollmconfig.toml` are executed by the new build executor. Projects using the
old Perl manifest and explicit standalone invocations continue to be delegated
to the preserved `ollm-legacy.rc`, version 0.11.1, so its command-line
interface remains the compatibility baseline during migration.

- [`DESIGN.md`](DESIGN.md) specifies the target architecture and records its
  rationale.
- [`../GLOSSARY.md`](../GLOSSARY.md) defines the bundle-wide design terms.
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

Bundle presets and targets are resolved from versioned definitions shipped
with the bundle. Additional absolute or project-root-relative search paths can
be put in `.ollmconfig.local.toml`:

```toml
schema = 1

[definitions]
paths = ["configuration", "/opt/osglecture/definitions"]
```

Unknown standard keys, bundle presets, and targets are errors. Semantic
diagnostics include the configuration file and source line whenever the
offending key is present in the TOML source. The bundle-level minimal
configuration example is in
[`../examples/series-minimal`](../examples/series-minimal).

For a concrete series build, the resolved configuration is normalized into a
job-bound `<jobname>.osgbuild.tex`. The reader in
`../osglecture/osglecture-config.sty` validates its schema and requires its
`job-id` to match TeX's current job name. `--dry-run --format=json` exposes the
same normalized `build_spec` without writing or starting LaTeX.

The bundle preset and document-profile defaults may be selected in the
per-user configuration:

```toml
schema = 1
bundle_preset = "OSG lecture/1"

[latex.defaults]
presentation_profile = "beamer"
script_profile = "scrbook"
```

OLLM reads `$XDG_CONFIG_HOME/ollm/config.toml`, or
`$HOME/.config/ollm/config.toml` when `XDG_CONFIG_HOME` is unset. On Windows it
uses `%APPDATA%\ollm\config.toml`. `OLLM_USER_CONFIG` selects an explicit file,
which is also useful for testing. Without a file OLLM uses `OSG lecture/1`,
`beamer`, and `scrbook`.

`ollmconfig.toml` may override these values for one project. The selected
bundle preset remains the `bundle_preset` field; the concrete TeX-side selection
uses `latex.defaults.presentation_profile` and
`latex.defaults.script_profile`. A CLI build request cannot select a document
profile. The resolved `document-profile` is nevertheless recorded in the
BuildSpec and its signed build file.

## Build execution

Each configured target/language pair is normalized to a concrete BuildSpec.
The executor loads only the bundled `ollm-latexmk.rc`; personal and directory
`latexmk` configuration files do not alter the controlled build contract.
Series builds use:

```text
<project-root>/.osglecture/build/<physical-unit>/<target>/<language>/
```

for their PDF, recorder data, `latexmk` state, auxiliary files, and the
job-bound `<jobname>.osgbuild.tex`. OLLM starts `latexmk` with LuaLaTeX,
recorder mode, SyncTeX, an explicit job name, and controlled output paths.

The manifest policy maps directly to the LuaLaTeX engine:

```text
off         --no-shell-escape
restricted  --shell-restricted
full        --shell-escape
```

If `[security].shell_escape` is omitted, the new executor uses `restricted`.
Conflicting user-supplied output, job-name, engine, recorder, working-directory,
or shell-escape options are rejected rather than silently overriding the
BuildSpec.

Additional `latexmk` rc files and startup Perl code (`-r`, `-e`) are rejected,
as are non-LuaLaTeX engines, `-out2dir`, injected `-latexoption` values, and
`-use-make`. OLLM owns the normalized configuration, artifact location, and
orchestration of dependent builds.

Native `latexmk` clean and information actions such as `-c`, `-C`, `-help`,
and `-version` are passed through. OLLM does not require a PDF after such an
action. Options that still request an OLLM build or build matrix, such as
`--rebuild` or `--all`, are rejected when they contradict the selected
`latexmk` action. A future `ollm clean` implementation may expose the
target-scoped `latexmk` cleanup through OLLM's own level and scope model.

`--all` creates one BuildSpec for each configured target/language pair that
applies to the current unit scope. Target definitions declare this
applicability through `unit_scopes`.

## Continuous builds and viewers

OLLM delegates continuous compilation and preview to `latexmk`. Options such
as `-pvc`, `-cc`, `-pv`, and `-view=none` are passed through. Continuous mode
is restricted to one concrete BuildSpec because its `latexmk` process remains
active; combining it with `--all` is therefore an error. Viewer or print
actions are rejected under `--non-interactive`, while `-pvc -view=none` and
`-cc` remain valid headless continuous-build modes.

OLLM normalizes the manifest and writes the build-request file before starting
`latexmk`. Changes to `ollmconfig.toml`, local configuration, bundle presets,
or target definitions therefore require restarting OLLM. LaTeX source changes
continue to be handled normally by `latexmk`.

Interrupting a build is passed through as a conventional signal exit status;
in particular, Ctrl-C results in exit code 130 on platforms using POSIX wait
status.

## Path and process robustness

Series units and project roots are canonicalized before a BuildSpec is
created. A series unit must remain inside its project root. Build-state paths
are checked again before directory creation so that a symlinked
`.osglecture` directory cannot redirect writes outside the project.

Job identities, configured languages, targets, and build directories are
checked for collisions on case-insensitive filesystems even when OLLM runs on
a case-sensitive Unix filesystem. Paths containing spaces remain individual
process arguments. A build directory containing the platform's `TEXINPUTS`
list separator is rejected because kpathsea cannot represent it
unambiguously.

Each concrete BuildSpec owns a `.ollm.lock` in its isolated build directory.
The lock is held for the complete `latexmk` lifetime, including continuous
mode. A second process targeting the same BuildSpec fails before writing or
starting LaTeX. Different BuildSpecs share no writable registry or state file,
so later parallel execution does not require changing this ownership model.

Nonzero `latexmk` exits map to OLLM's build-failure exit code 1; tool-start
failures remain environment error 69, while signal exits retain their
conventional `128 + signal` status. A successful ordinary build additionally
requires a nonempty regular PDF at the exact artifact path.
