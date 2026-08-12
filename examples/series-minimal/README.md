# Vertical series example

This example is a small end-to-end case study for the current OLLM and
`osglecture` contracts. It contains two logical units and builds each unit as
as a Beamer presentation (`slides`), an extended `ltx-talk` presentation
(`talk`), and a
long-form report (`script`). The second unit refers to a labelled section in
the first one.

## Structure

```text
series-minimal/
├── .ollmconfig.local.toml
├── ollmconfig.toml
├── Definitions/targets/talk.toml
├── Include/
│   ├── documentmetadata.tex
│   ├── osglecture-profile-series-ltx-talk.def
│   ├── projectconfig.tex
│   └── seriesexample-talk-modes.tex
├── 010-introduction/main.tex
└── 020-application/main.tex
```

OLLM discovers `ollmconfig.toml` from either unit directory. Shared TeX files
live in `Include`; there is deliberately no TeX material in the project root.
The manifest uses the default directory and configuration filenames
explicitly, so the relevant build contract remains visible in this example.

`.ollmconfig.local.toml` registers the project-local target definition for the
new `talk` doctype. `projectconfig.tex` contains mode-specific series metadata
and selects concrete profiles per target: `slides` uses `beamer`, while `talk`
uses the project-local `series-ltx-talk` profile. That profile selects the
`ltx-talk` base class and declares `talk` as a presentation mode through its
early `mode-setup-file`. The `lttheme` and `lttheme-tuc-2019` regression suites
can be run independently of this deliberately unthemed structural example.
The long-form `script` target uses the built-in standard `book` default.
All osglecture metadata remains available semantically. Until the planned
bundle-owned title page is implemented, the native Book title machinery only
renders its standard fields; additional values such as `course`, `event`, and
`institute` are intentionally not mapped by this profile.

The target-specific `document_metadata` policy in `ollmconfig.toml` disables
the early file for Beamer, but requires it for `ltx-talk` and `book`. OLLM
therefore inputs the user-owned `documentmetadata.tex` for `talk` and `script`.
The file enables tagging. osglecture validates the resulting kernel state against the selected
profile's `required`, `supported`, or `forbidden` capability.

The unit sources use the profile-independent `section`, `frame`, and
`frametitle` interfaces directly. ltx-talk and Beamer retain their native
normal-frame scanners, while the long-form adapter treats a frame as a content
container and suppresses its frame title by default. No project-local
`seriessection` bridge is needed anymore.

The sources additionally exercise:

- logical unit declarations with stable IDs;
- `presitemize` as list versus connected prose;
- presentation-default `twocolumns` behaviour;
- project-local profiles and mode setup from the shared TeX directory;
- a cross-unit `\olref` resolved through OLLM's promoted reference state.

## Build sequence

Run the following commands from the named unit directories. The producing unit
must be built before the consuming unit so that OLLM can register its promoted
reference export.

```sh
cd 010-introduction
ollm build slides
ollm build --target=talk
ollm build script

cd ../020-application
ollm build slides
ollm build --target=talk
ollm build script
```

The second unit then links to the matching `introduction` projection: slides,
talk, and script each refer to the same target and language in the first
unit. Rebuilding the second unit may be necessary after changing a label in
the first unit. Automated dependency-fixpoint builds are available through
`ollm build --resolve`; the explicit order above remains useful for showing
the initial bootstrap in which the producing unit's logical ID is not yet
known to OLLM.

To inspect all six BuildSpecs without invoking LaTeX, run `ollm build --all
--dry-run` once in each unit directory.

## Expected defaults

| Target | Profile class | Concrete default profile | Behaviour |
|---|---|---|---|
| `slides` | `presentation` | `beamer` | frames, itemized presentation lists, real columns |
| `talk` | `presentation` | `series-ltx-talk` → `ltx-talk` | extended presentation mode with required document metadata |
| `script` | `longform` | `book` | sections, connected prose, column contents in sequence |

The target-specific selection is expressed in `projectconfig.tex` as:

```tex
\LectureTargetSetup{slides}{profile=beamer}
\LectureTargetSetup{talk}{profile=series-ltx-talk}
```
