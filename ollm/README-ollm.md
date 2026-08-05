# OLLM

OLLM (OSG LaTeX Lecture Maker) is the build frontend of the `osglecture`
bundle. It selects document and language variants and delegates individual
LaTeX builds to `latexmk`.

The program in `ollm` is the portable command-line launcher. Builds using
`ollmconfig.toml` are executed by the new build executor. Old Perl manifests
are delegated to the preserved `ollm-legacy.rc`, version 0.11.1, only when
`--legacy` is explicit. A TOML and Perl manifest may coexist; TOML is the
normal selection.

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
ollm convertconfig
ollm newtoml
```

## Implementation status and TODO

The new executor currently implements ordinary and continuous `build`,
`build --all`, `build --dry-run`, standalone builds, and the basic `doctor`
toolchain check. Native latexmk clean and information actions can be passed
through to one resolved build.

Dependency fixpoint builds with `build --resolve` remain the principal CLI
function accepted but not yet implemented; they return exit code 69.

`report` describes discovered units, promoted projections, their generations,
and semantic dependencies without using findings as a release gate. `check`
uses the same analysis and returns exit code 3 for inconsistent required
dependencies. A discovered but unused and unbuilt unit is reported as
`dormant` and is not a check failure. At the project root both commands default
to `series`; inside a unit they default to `current`. `unit` is always
explicit.

`clean` implements the documented `aux`, `build`, `state`, and `all` levels
with `current`, `unit`, and `series` scopes. `prune` removes abandoned pending
directories and superseded immutable generations. Potentially renamed units
are reported but retained unless `--stale-units` is explicit. Both commands
support `--dry-run`.

`deploy` copies already promoted PDF artifacts; it never starts an implicit
build. Its default scope is `series` at the project root and `current` inside
any unit. `--scope=collection` selects the integration artifact for a document
type. Missing destinations are not created and produce a failing status; later
attempts to the same unavailable path are skipped while other destinations
continue. Existing different files follow
`security.deployment.overwrite = "explicit" | "automatic"`; the explicit
policy requires `--overwrite`. Installation uses a temporary file in the
destination and prefers an atomic rename.

Series builds now assign a generation ID, validate the LaTeX result and
reference envelopes, and atomically promote an immutable generation for each
logical unit/document type/language projection. Before a following build OLLM
writes a job-bound TeX registry of the last valid projections. The logical
unit ID always comes from the explicit `\lecture` declaration; a directory
slug is never promoted as its substitute.

The `.osglecture` tree is OLLM-owned but deliberately inspectable and fully
rebuildable. With no OLLM or latexmk process running, deleting it is a
supported radical recovery procedure; this also discards all promoted logical
mappings, so target units must be built directly again. Reference-index
evaluation by `check`/`report`, dependency fixpoint builds, and the extended
project-aware `doctor` checks remain TODO.

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

For migration, `ollmconfig.pl` may coexist with the TOML manifest. Normal
commands select TOML; `ollm --legacy ...` explicitly selects Perl. If only the
Perl file exists, `ollm convertconfig` creates a conservative TOML translation
without executing arbitrary Perl. `ollm newtoml` creates a generic manifest,
or performs that conversion when it discovers a Perl file. Neither command
overwrites an existing TOML file. Statically recognizable legacy deployment
rules are translated; unsupported dynamic, restriction, path, or computed
settings are reported for manual review.

Commands and built-in targets accept the historical leading `+`. With
`+enforce+` or `--enforce+`, that prefix becomes mandatory for command and
target words, allowing files named for example `slides` to remain operands.
`+force+` is retained as a deprecated compatibility alias.

Deployment rules are optional and apply to generated artifacts only:

```toml
[deployment]
series = "both" # units | collection | both

[deployment.roles]
content = ""
appendix = "A"

[deployment.types.handout]
paths = ["/srv/lecture/handouts", "/srv/lecture/archive"]
filename = "{role}{chapter:02}-{unit}-{lang}.pdf"
collection_filename = "{series}-{lang}.pdf"

[deployment.types.handout.units.introduction]
filename = "{chapter:02}-intro-{lang}.pdf"

[security.deployment]
overwrite = "explicit"
```

Filename templates support `series`, `unit`, `ordinal`, `chapter`, `doctype`,
`lang`, and mapped `role` placeholders. Decimal values accept a minimum width,
for example `{ordinal:02}`. LaTeX reports the actual chapter representation;
`\OsgLectureDeploymentChapter{...}` overrides it explicitly. A generic
`newtoml` file contains commented deployment examples. `convertconfig`
translates statically recognizable legacy `deploy_path` and `deploy_file`
assignments and reports unsupported dynamic or restriction settings.

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

Targets registered by additional definitions can be selected explicitly:

```sh
ollm build --target=studyguide --language=en
```

A schema-1 target definition uses the same `name` and `doctype` and declares
`profile_class = "presentation"` or `profile_class = "longform"`. This value
only selects the corresponding project-wide document profile. Mode parents
and abstract modes belong to that profile's TeX-side `mode-setup-file`; OLLM
does not merge or interpret the mode graph.

Project-wide TeX material lives outside the project root's top level. The
default directory and project configuration are `Include` and
`projectconfig.tex`; both names can be changed in the project manifest:

```toml
[project.tex]
directory = "Include"
config = "projectconfig.tex"
```

The directory is project-root-relative. OLLM adds its resolved absolute path
to `TEXINPUTS`, after the isolated build directory and before inherited search
paths, so it may contain project-local packages as well as configuration
files. If the configured project configuration exists, its contents
participate in the BuildSpec signature. The generated job-bound build file
passes its absolute directory and filename to `osglecture`.

`osglecture` loads that file after the active mode graph and its metadata
interface have been initialized, but before the remaining class services and
profile setup. Mode-specific metadata is therefore valid, for example:

```latex
\author<presentation>[M.~M.]{Max Mustermann}
\author<longform>[Mustermann]{Max Mustermann}
```

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

A project may enforce one shared, project-root-relative metadata file:

```toml
[latex.document_metadata]
policy = "enforce"
file = "Include/document-metadata.tex"
```

OLLM inserts it before the main source through latexmk's controlled pre-TeX
mechanism and first defines `\OsgLectureRequestedLanguage`. The file contents
participate in the configuration signature. OLLM does not inspect or rewrite
`main.tex`; a second `\DocumentMetadata` in the source remains a normal LaTeX
conflict which the author must resolve. User `-pretex` and `-usepretex`
options are reserved and rejected.

OLLM reads `$XDG_CONFIG_HOME/ollm/config.toml`, or
`$HOME/.config/ollm/config.toml` when `XDG_CONFIG_HOME` is unset. On Windows it
uses `%APPDATA%\ollm\config.toml`. `OLLM_USER_CONFIG` selects an explicit file,
which is also useful for testing. Without a file OLLM uses `OSG lecture/1`,
`beamer`, and `scrbook`.

The target's `profile_class` selects `presentation_profile` or
`script_profile`. For that key, the implemented priority is: built-in fallback
below bundle-preset defaults, user defaults, project `latex.defaults`, and
finally effective enforcement (bundle preset followed by project
`latex.enforce`). A CLI build request cannot select a document profile. The
resolved `document-profile` is nevertheless recorded in the BuildSpec and its
signed build file. An explicit TeX class option `profile=...` must match this
resolved value when a build file is loaded.

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

Every series resolution also computes a path-independent signature of the
ordered physical unit structure. The signature is written to the BuildSpec and
its `.osgbuild.tex` file, so a manual unit rename or reordering invalidates
affected builds without guessing a logical identity. Unrelated directories,
timestamps, and the absolute project location do not affect the signature.
Future Cargo-like `ollm init` and `ollm unit ...` commands may make structural
changes more convenient, but ordinary filesystem operations remain supported.

`+standalone` uses the new executor without manifest discovery, a generated
`.osgbuild.tex`, or a series job name. It defaults to `main.tex` in the current
directory and passes normal latexmk output-directory options (`-outdir`,
`-auxdir`, and `-out2dir`). Document type, language, and profile belong in
`osglecture` class options in this mode.

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
as are non-LuaLaTeX engines, injected `-latexoption` values, and `-use-make`.
For series builds, `-out2dir` is also rejected because OLLM owns the artifact
path. It is permitted only for standalone builds, where normal latexmk output
directories remain under user control.

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
