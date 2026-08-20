# Vertical series example -- classic variant

This example is a small end-to-end case study for the current OLLM and
`osglecture` contracts, built entirely on document types that do not use
`\DocumentMetadata`. It contains two logical units, no integration unit. Each
logical unit builds as a Beamer presentation (`slides`) and a KOMA-Script
long-form report (`script`, using `scrbook`). The second unit refers to a
labelled section in the first one.

For the newer, `\DocumentMetadata`-based style (`ltx-talk` + `book`, plus a
`tagpax`-tagged integration unit and a worked example of adding a
project-local target), see the sibling example `../series-modern`.

## Structure

```text
series-classic/
├── ollmconfig.toml
├── Include/
│   └── projectconfig.tex
├── 010-introduction/main.tex
└── 020-application/main.tex
```

OLLM discovers `ollmconfig.toml` from either unit directory. Shared TeX files
live in `Include`; there is deliberately no TeX material in the project root.
The manifest uses the default directory and configuration filenames
explicitly, so the relevant build contract remains visible in this example.

`projectconfig.tex` selects a concrete profile per target:
`\LectureTargetSetup{slides}{profile=beamer}` and
`\LectureTargetSetup{script}{profile=scrbook}`. Both `beamer` and `scrbook`
are built-in osglecture profiles, so no project-local profile or target
definition is needed here -- that is the point of this variant: it is the
plain, unextended path through osglecture. Beamer's `document-metadata`
capability is `forbidden`, so `\DocumentMetadata` must stay off for `slides`;
`scrbook` merely `supports` it, and this example simply leaves it off there
too, for a document type pairing that predates the `\DocumentMetadata`
kernel feature entirely.

## Cross-unit references

The unit sources use the profile-independent `section`, `frame`, and
`frametitle` interfaces directly. Beamer retains its native frame scanner,
while the long-form adapter treats a frame as a content container and
suppresses its frame title by default.

The sources additionally exercise:

- logical unit declarations with stable IDs;
- `presitemize` as list versus connected prose;
- presentation-default `twocolumns` behaviour;
- a cross-unit `\olref` resolved through OLLM's promoted reference state,
  rendered as a working external link (`GoToR`) -- without
  `\DocumentMetadata`, `\olref` builds this link itself from the same
  low-level primitives hyperref's own classic backend uses, rather than
  through the newer `l3pdfannot` API, which requires `\DocumentMetadata` to
  be active;
- continuation of page and section counters in the long form.

There is no integration unit in this variant: `tagpax` (used by
`\includeunit` in `series-modern`) needs a document with tagging active and
therefore needs `\DocumentMetadata`, which this example deliberately does not
use.

## Build sequence

Run the following commands from the named unit directories. The producing
unit must be built before the consuming unit so that OLLM can register its
promoted reference export.

```sh
cd 010-introduction
ollm build slides
ollm build script

cd ../020-application
ollm build slides
ollm build script
```

The second unit then links to the matching `introduction` projection: `slides`
and `script` each refer to the same target and language in the first unit.
Rebuilding the second unit may be necessary after changing a label in the
first unit. Automated dependency-fixpoint builds are available through `ollm
build --resolve`; the explicit order above remains useful for showing the
initial bootstrap in which the producing unit's logical ID is not yet known
to OLLM.

To inspect the BuildSpecs without invoking LaTeX, run `ollm build --all
--dry-run` in the project.

## Expected defaults

| Target | Profile class | Concrete profile | Behaviour |
|---|---|---|---|
| `slides` | `presentation` | `beamer` | frames, itemized presentation lists, real columns |
| `script` | `longform` | `scrbook` | sections, connected prose, column contents in sequence |

The target-specific selection is expressed in `projectconfig.tex` as:

```tex
\LectureTargetSetup{slides}{profile=beamer}
\LectureTargetSetup{script}{profile=scrbook}
```
