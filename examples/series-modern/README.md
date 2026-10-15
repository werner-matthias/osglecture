# Vertical series example -- modern variant

This example is a small end-to-end case study for the current OLLM and
`osglecture` contracts, built entirely on document types that require
`\DocumentMetadata`. It contains two content units, one exercise unit, and one
integration unit. Each content unit builds as an `ltx-talk` presentation
(`slides`) and a long-form report (`script`), both with `\DocumentMetadata`
active, and each in German and English via `langselect`. The exercise unit
builds as an exercise sheet (`script`) and, through a project-local target, as
the same sheet with solutions (`solutions`). The second and third units refer
to a labelled section in the first one; the integration unit combines the
German `script` PDFs with `tagpax`.

Between the profile-driven class selection, the project-local target, the
multilingual source, and the tagged integration, this variant is meant to sketch how far a single
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
├── Definitions/
│   ├── profiles/series-solutions.toml
│   └── targets/solutions.toml
├── Include/
│   ├── documentmetadata.tex
│   ├── osglecture-profile-series-solutions.def
│   ├── projectconfig.tex
│   ├── seriesexample-exercises.tex
│   └── seriesexample-modes.tex
├── 010-introduction/main.tex
├── 020-application/main.tex
├── 030a-exercises/main.tex
└── 900-i-collection/main.tex
```

OLLM discovers `ollmconfig.toml` from either unit directory. Shared TeX files
live in `Include`; there is deliberately no TeX material in the project root.
The manifest uses the default directory and configuration filenames
explicitly, so the relevant build contract remains visible in this example.

## Selecting the classes through profiles

The content units use only OLLM's built-in `slides` and `script` targets. The
choice between `ltx-talk` and
Beamer is made entirely by the profile, here with
`presentation_profile = "ltx-talk"` in `[targets.defaults]` (the bundle preset
would otherwise default to `beamer`). The unit sources stay the same; they
contain nothing specific to either class. `series-classic` builds the same
kind of sources with Beamer just by selecting a different profile.

The long-form `script` target uses the built-in standard `book` profile,
selected with `longform_profile = "book"` in `[targets.defaults]` (the bundle
preset would otherwise default to `scrbook`). No project-local profile is
needed for it.

## A project-local target: exercises with solutions

Built-in targets cover the usual documents; a project-local target is worth
adding when the same source has to yield a document whose *content* differs.
Here that is an exercise sheet with and without solutions. The exercise unit
marks its solutions once:

```tex
\begin{exercise} ... \end{exercise}
\begin{solution} ... \end{solution}
```

`Include/seriesexample-exercises.tex` defines `solution` so that its body is
typeset only under `\mode<solutions>`, and the unit additionally uses
`\IfLectureModeTF{solutions}` for a sentence that differs between the two
versions. `ollm build script` then yields the sheet for students,
`ollm build --target=solutions` the key. Five small pieces make the target
work:

- `.ollmconfig.local.toml` registers `Definitions` as a search path for
  project-local OLLM definitions.
- `Definitions/targets/solutions.toml` declares the target:
  `doctype = "solutions"`, `profile_class = "longform"`, and
  `unit_scopes = ["a", "as"]` like the built-in `script`.
- `Include/osglecture-profile-series-solutions.def` declares the osglecture
  profile `series-solutions`. It is the built-in `book` profile with
  `doctypes = {solutions}`: a profile lists the doctypes it serves, and
  `book` only serves `script` and `article`.
- `Definitions/profiles/series-solutions.toml` is the capability projection
  of that profile which OLLM reads before LaTeX starts. The manifest selects
  the profile with `profile = "series-solutions"` in `[targets.solutions]`.
- `Include/seriesexample-modes.tex` declares the mode `solutions` as a child
  of `script`, so the solutions version contains everything the script does.
  `projectconfig.tex` registers it with
  `\LectureProjectSetup{mode-setup-file = seriesexample-modes.tex}`, which
  reads it in *every* target. That matters: the shared source names
  `solutions` in every build, and an undeclared mode is an error. A profile's
  own `mode-setup-file` is only read for that profile's doctypes, so it is the
  place for modes that nothing outside those doctypes mentions.

The exercise unit lives in `030a-exercises`. The scope code `a` restricts it
to targets whose `unit_scopes` contain `a` -- `script` and `solutions`, but
not `slides` -- so `ollm build slides` is refused there. The content units
carry no scope code and accept every target, including `solutions`.

Cross-unit references and counter continuation are keyed by target, like
everything OLLM promotes. The exercise unit's `\olref` to the first unit
therefore needs a `solutions` projection of that unit; building `solutions`
for all units, as in the build sequence below, yields a complete solutions
edition of the series whose references stay within that edition.

The same mechanism serves other variants, for example a tagged `ltx-talk`
and an untagged Beamer version of the same slides side by side: a target
with its own doctype and a profile that serves it.

## Multilingual content with langselect

Every unit in this example is written once and builds in German and English,
using the independent `langselect` module (also part of this bundle, but not
otherwise coupled to `osglecture`). The selectable languages -- and their
order, which decides `langselect`'s bilingual macro name -- come from the
manifest (`[targets.defaults].languages = ["en", "de"]`). `osglecture` hands
that list to `langselect` from the build file and configures it automatically;
`projectconfig.tex` only supplies the target language and the visible title:

```tex
\OsgLectureBuildLoadedTF
  { \edef\olsTargetLanguage{\OsgLectureBuildValue{language}} }
  { }
\title{\lende{One source, multiple documents}{Eine Quelle, mehrere Dokumente}}
```

`\OsgLectureBuildValue{language}` is used rather than the more familiar
`\OsgLectureLanguage` because this file is read early during class loading,
before the latter's accessor command is defined; the build-spec value it is
built from is already available. Setting `\olsTargetLanguage` before loading
`langselect` takes priority over all of `langselect`'s own target-language
detection (job name, `\DocumentMetadata`, ...), so OLLM's per-language build
directly determines which half of each `\lende{English}{German}` call ends up
in the PDF, with no per-target duplication needed.

A project that also needs the Babel/Polyglossia name mapping still uses
`osglecture`'s own project-setup vocabulary, but only for the sub-keys that
are genuinely LaTeX concerns:
`\LectureProjectSetup{languages={map={de=ngerman,en=british}, load babel}}`.
The `selectable` sub-key is manifest-owned for an OLLM build and is ignored
(with a warning) if written here. `osglecture.cls` issues the resulting
`\usepackage{langselect}` from within its intercept-and-replay queue, so it
lands right after the target's base class -- avoiding a collision between
`langselect`'s `csquotes` integration and `ltx-talk`'s own `quote`
environment, both of which would otherwise define `quote` before `\LoadClass`.

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

All targets in this example end up with `\DocumentMetadata` active. For
`slides` it is forced: the `ltx-talk` profile declares
`document_metadata = "required"`. For `script` it is a choice: the `book`
profile only `supports` metadata, and `[targets.defaults].document_metadata =
"enabled"` in the manifest turns it on; the same holds for `solutions`, whose
profile mirrors `book`. OLLM inputs the user-owned
`Include/documentmetadata.tex` early whenever the derived policy is `enabled`,
which enables tagging. osglecture validates the resulting kernel state against
the profile's capability -- setting `document_metadata = "disabled"` against a
`required` profile, or `"enabled"` against a `forbidden` one, is rejected by
OLLM before the run. Active tagging is also what makes the `tagpax`-based
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
ollm build slides
ollm build script
ollm build --target=solutions

cd ../020-application
ollm build slides
ollm build script
ollm build --target=solutions

cd ../030a-exercises
ollm build script
ollm build --target=solutions

cd ../900-i-collection
ollm build script
```

`solutions` needs the `--target=` form: it is a project-registered target,
and only OLLM's built-in targets can be named positionally.

This builds the default language (German, per
`[targets.defaults].default_language` in `ollmconfig.toml`). Add
`--language=en` to any of the unit
builds above to get the English versions, e.g.
`ollm build slides --language=en`; both
languages can coexist since OLLM keys promoted projections by language along
with target and unit. The integration unit above stays German-only (see
"Multilingual content" and "Document metadata"); building it in English too
would just mean adding `--language=en` there as well, once both source units
have an English `script` projection.

The second and third units then link to the matching `introduction`
projection: `slides`, `script`, and `solutions` each refer to the same target
and language in the first unit.
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
\includeunit{exercises}
```

The exercises therefore enter the collection in their student version; the
solutions edition stays a separate document.

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
| `slides` | `presentation` | `ltx-talk` | presentation mode with required document metadata |
| `script` | `longform` | `book` | sections, connected prose, column contents in sequence |
| `solutions` | `longform` | `series-solutions` (project-local, `book`) | like `script`, plus content marked for `solutions` |

The profile selection lives in the manifest:

```toml
[targets.defaults]
presentation_profile = "ltx-talk"
longform_profile = "book"

[targets.solutions]
profile = "series-solutions"
```
