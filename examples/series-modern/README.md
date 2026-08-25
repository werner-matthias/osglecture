# Vertical series example -- modern variant

This example is a small end-to-end case study for the current OLLM and
`osglecture` contracts, built entirely on document types that require
`\DocumentMetadata`. It contains two logical units and one integration unit.
Each logical unit builds as an extended `ltx-talk` presentation (`talk`) and a
long-form report (`script`), both with `\DocumentMetadata` active, and each in
German and English via `langselect`. The second unit refers to a labelled
section in the first one; the integration unit combines both German `script`
PDFs with `tagpax`.

Between the project-local target/profile extension, the multilingual source,
and the tagged integration, this variant is meant to sketch how far a single
source tree can go with OLLM and `osglecture` -- not as a complete tour of
every bundle capability, but as a base other examples or real projects can
extend in the same direction.

For the older, `\DocumentMetadata`-free style (Beamer + KOMA-Script `scrbook`,
no tagged integration), see the sibling example `../series-classic`.

## Structure

```text
series-modern/
├── .ollmconfig.local.toml
├── ollmconfig.toml
├── Definitions/targets/talk.toml
├── Include/
│   ├── documentmetadata.tex
│   ├── osglecture-profile-series-ltx-talk.def
│   ├── projectconfig.tex
│   └── seriesexample-talk-modes.tex
├── 010-introduction/main.tex
├── 020-application/main.tex
└── 900-i-collection/main.tex
```

OLLM discovers `ollmconfig.toml` from either unit directory. Shared TeX files
live in `Include`; there is deliberately no TeX material in the project root.
The manifest uses the default directory and configuration filenames
explicitly, so the relevant build contract remains visible in this example.

## Extending OSGLecture: a project-local target and profile

`talk` is not one of OSGLecture's built-in targets -- this example defines it
itself, which is the mechanism to reach for whenever a project needs a
document type the bundle does not ship. Three small, cooperating pieces make
this work:

- `.ollmconfig.local.toml` registers `Definitions` as a search path for
  project-local OLLM definitions.
- `Definitions/targets/talk.toml` declares `talk` as a new target kind:
  `doctype = "talk"`, `profile_class = "presentation"`,
  `document_metadata = "required"`.
- `Include/osglecture-profile-series-ltx-talk.def` declares a project-local
  osglecture profile `series-ltx-talk` that reuses the built-in `ltx-talk`
  backend/adapter/class, but additionally loads
  `seriesexample-talk-modes.tex` as an early `mode-setup-file`, which
  declares `talk` as a presentation mode derived from `presentation`.

`projectconfig.tex` then selects this profile for the `talk` target with
`\LectureTargetSetup{talk}{profile=series-ltx-talk}`. Everything else about
`talk` -- its `frame`/`frametitle` handling, its column and list behaviour --
comes for free from the `presentation` mode it derives from. A project that
only needs a differently named target with the same behaviour as an existing
one can stop here; deeper customization (new layout primitives, a different
title page, additional mode-specific behavior) would extend
`seriesexample-talk-modes.tex` instead of touching the bundle.

The long-form `script` target uses the built-in standard `book` profile, with
no project-local override needed.

## Multilingual content with langselect

Every unit in this example is written once and builds in German and English,
using the independent `langselect` module (also part of this bundle, but not
otherwise coupled to `osglecture`). `projectconfig.tex` wires the two
together in four lines:

```tex
\OsgLectureBuildLoadedTF
  { \edef\olsTargetLanguage{\OsgLectureBuildValue{language}} }
  { }
\LectureProjectSetup{languages={selectable={en,de}}}
\title{\lende{One source, multiple documents}{Eine Quelle, mehrere Dokumente}}
```

`\OsgLectureBuildValue{language}` is used rather than the more familiar
`\OsgLectureLanguage` because this file is read early during class loading,
before the latter's accessor command is defined; the build-spec value it is
built from is already available. Setting `\olsTargetLanguage` before loading
`langselect` takes priority over all of `langselect`'s own target-language
detection (job name, `\DocumentMetadata`, ...), so OLLM's per-language build
directly determines which half of each `\lende{English}{German}` call ends
up in the PDF, with no per-target duplication needed.

`\LectureProjectSetup{languages={selectable={en,de}}}` is `osglecture`'s own
project-setup vocabulary (the same one used elsewhere for `theme`,
`numbering`, and the profile keys); it hides that multilingual support is
technically implemented by `langselect` at all. `languages` takes its own
small keyval, `selectable` being the one most projects need (it maps to
`langselect`'s own `languages` option, just named after what it actually
is -- `langselect` itself calls these "selectable languages" in its
documentation); the rest of `langselect`'s options (`map`, `load babel`,
`load polyglossia`, `prefix`, `targetlang`, `auto`, `trim`, `unified
shorthands`) are reachable the same way, e.g. `languages={selectable={en,
de}, map={de=ngerman,en=british}}` for old/new German spelling or British/
American English. All given sub-keys are collected first and issued in a
single `\usepackage[...]{langselect}` call once `languages` has been fully
processed -- not one call per sub-key -- because `langselect`, once loaded,
silently ignores extra options given on a later, separate load rather than
erroring, so collecting before triggering avoids configuration that looks
accepted but silently never applies. It is not just cosmetic sugar either
way: `osglecture.cls` defers any `\usepackage`/`\RequirePackage` written
directly in `projectconfig.tex` until right after the target's base class
(here `ltx-talk`) has loaded, the same way it already defers `\title` and
the other metadata fields (see `README-cls.md`), and `\LectureProjectSetup`'s
`languages` key rides the very same queue since it is only ever evaluated
from within that reading window. This matters for a reason independent of
`langselect` itself: `projectconfig.tex` is read *before* `osglecture.cls`'s
own `\LoadClass` for the target's base class has run, and a package that
probes "does the base class already define X" at that point can get a false
negative. `langselect`'s default `unified shorthands` option (babel/
polyglossia quote-shorthand integration, harmless to leave on even though
this example loads neither) pulls in `csquotes`, which defines a classic
fallback `quote` environment if it finds none yet -- true before the base
class has loaded. `ltx-talk` then defines its own `quote` via
`\NewDocumentEnvironment`, whose built-in check is unconditional -- it
errors on *any* pre-existing `quote` -- so csquotes' fallback and
`ltx-talk`'s own definition would collide (`Environment 'quote' already
defined`) if both ran before `\LoadClass`. Since the `languages` key's
`\usepackage` call is deferred to right after `\LoadClass` and replayed in
the same queue and order as `\title`, `langselect`/`csquotes` see the base
class's `quote` already in place, and `\lende` is already defined by the
time `\title` runs.

The unit sources then use `\lende{English text}{German text}` wherever the
two versions differ -- titles, headings, list items, running prose -- and
plain text wherever they don't (formulas, code, the `Mode-aware Layout`
heading). See `langselect`'s own documentation
(`langselect/langselect.dtx` in this bundle) for the starred variant, custom
per-project language names, and the Babel/Polyglossia/csquotes integration
this example deliberately leaves aside for simplicity.

`\olref` cross-unit references are unaffected by the language split: since
the cross-unit reference identity includes the language, `application`'s
German build links to `introduction`'s German build, and English to English,
automatically.

## Document metadata

Both targets in this example require `\DocumentMetadata` (see
`document_metadata = "required"` in `ollmconfig.toml` and in `talk.toml`).
OLLM therefore inputs the user-owned `Include/documentmetadata.tex` early,
which enables tagging. osglecture validates the resulting kernel state
against the selected profile's `required`, `supported`, or `forbidden`
document-metadata capability -- `ltx-talk` declares it `required`, `book`
merely `supported`. Active tagging is also what makes the `tagpax`-based
`\includeunit` integration below possible: `tagpax`'s tagging bridge needs a
document with tagging turned on and fails outright otherwise, which is why
the integration unit builds only under `script`, and only in this
`\DocumentMetadata` variant of the example (`series-classic` has no
integration unit for the same reason).

## Cross-unit references

The unit sources use the profile-independent `section`, `frame`, and
`frametitle` interfaces directly. `ltx-talk` retains its native frame
scanner, while the long-form adapter treats a frame as a content container
and suppresses its frame title by default.

The sources additionally exercise:

- logical unit declarations with stable IDs;
- `presitemize` as list versus connected prose;
- presentation-default `twocolumns` behaviour;
- multilingual content from a single source via `langselect` (see below);
- a cross-unit `\olref` resolved through OLLM's promoted reference state,
  rendered as a working link (external `GoToR` when the two units are built
  standalone, rewritten to an internal `GoTo` once both are merged by
  `\includeunit` below);
- continuation of page and section counters in the long form;
- tagged integration through `tagpax` in `\includeunit` command order.

## Build sequence

Run the following commands from the named unit directories. The producing
unit must be built before the consuming unit so that OLLM can register its
promoted reference export.

```sh
cd 010-introduction
ollm build --target=talk
ollm build script

cd ../020-application
ollm build --target=talk
ollm build script

cd ../900-i-collection
ollm build script
```

`talk` needs the `--target=` form (not the bare `ollm build talk` used for
`script`/`slides` above): it is a project-registered target, not one of
OLLM's built-in target aliases, which are the only ones resolvable
positionally. This builds the default language (German, per `[languages]
default` in `ollmconfig.toml`). Add `--language=en` to any of the unit
builds above to get the English versions, e.g.
`ollm build --target=talk --language=en`; both
languages can coexist since OLLM keys promoted projections by language along
with target and unit. The integration unit above stays German-only (see
"Multilingual content" and "Document metadata"); building it in English too
would just mean adding `--language=en` there as well, once both source units
have an English `script` projection.

The second unit then links to the matching `introduction` projection: `talk`
and `script` each refer to the same target and language in the first unit.
Rebuilding the second unit may be necessary after changing a label in the
first unit. Automated dependency-fixpoint builds are available through `ollm
build --resolve`; the explicit order above remains useful for showing the
initial bootstrap in which the producing unit's logical ID is not yet known
to OLLM.

The integration unit deliberately contains no `\lecture` declaration. Its
role comes from the directory name `900-i-collection`. It selects promoted
`script` PDFs by logical Unit ID:

```tex
\includeunit{introduction}
\includeunit{application}
```

Command order is output order. `osglecture-integration` resolves each ID
against the job-bound registry, lets `tagpax` extract and import the tagged
PDF, and records the exact source generation as an integration dependency for
`ollm check` and `ollm build --resolve`. It also records, per logical unit,
which internal `tagpax` prefix that unit was merged under -- this is what
lets `\olref` links between merged units resolve to an internal jump instead
of staying an external file link; a reference to a unit merged later in
document order needs one extra build pass to pick this up, the same way
`\ref` needs a rerun for a forward reference.

To inspect the BuildSpecs without invoking LaTeX, run `ollm build --all
--dry-run` in the project.

## Expected defaults

| Target | Profile class | Concrete profile | Behaviour |
|---|---|---|---|
| `talk` | `presentation` | `series-ltx-talk` → `ltx-talk` | extended presentation mode with required document metadata |
| `script` | `longform` | `book` | sections, connected prose, column contents in sequence |

The target-specific selection is expressed in `projectconfig.tex` as:

```tex
\LectureTargetSetup{talk}{profile=series-ltx-talk}
```
