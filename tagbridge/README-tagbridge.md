# tagbridge — developer notes

This package is part of the `osglecture` bundle. For user-facing
documentation, run `texdoc tagbridge`.

## What this is

A collection of tagging-compatibility hooks for third-party packages that
predate LaTeX's tagged-PDF support and therefore either flood
`\DocumentMetadata{tagging=on}` documents with warnings, or produce
anonymous/meaningless tags. Each hook is self-contained, fires only while
`tagpdf` is active (checked via `\cs_if_exist:NT \tagstructbegin`), and is
otherwise a no-op. `tagbridge` has no package options and no public API —
document classes and other packages just `\RequirePackage{tagbridge}` and
get whatever hooks apply.

`pdfpages` import is explicitly out of scope; that's `tagpax`'s job.

## Why a separate package, not inline in `osglecture`

The tagging problems this covers come in (at least) three distinct shapes.
The axis that actually matters is *not* "tikz or not" — it's whether a
package emits **one self-contained graphic** or **many small marks
scattered through running text, each ending a paragraph**. tikz only
changes which of the two failure modes a bad case falls into, it does not
by itself make a package safe.

1. **One self-contained graphic, drawn raw** (`qrcode`'s per-module
   `\rule`s form a single QR code). Needs a manual wrap around the
   drawing call: `\tagpdfparaOff` + `\tagstructbegin`/`\tagmcbegin` ...
   `\tagmcend`/`\tagstructend`, plus a language-aware `alt=` default and
   a content-based security check (see `__tagbridge_qrcode_*` in
   `tagbridge.dtx`). This pattern is proven to work for this shape.
2. **One self-contained graphic, drawn via tikz, but the macro never
   passes `alt=`/`artifact=`** (e.g. `menukeys`' per-key `\tikz[...]`,
   `chessboard`/`xskak`, `tabularray`'s tikz-drawn cell borders).
   `latex-lab-testphase-tikz` — now auto-loaded by the kernel itself
   whenever `\DocumentMetadata{tagging=on}` is set, confirmed identical
   in the CI containers, see this package's originating conversation —
   already makes a single tikz picture tag-safe (no crash, no warnings,
   sane marked-content grouping) regardless of what's drawn inside it.
   What's missing is purely the *semantic* label, which has to be
   injected into the specific `\tikz[...]` call site. There is no
   generic fix beyond patching the key in, package by package.
3. **Many small marks in running text, each ending a paragraph** —
   the shape that actually causes the "Parent-Child relation" warning
   flood, independent of whether the marks are raw or tikz-drawn.
   Confirmed for `dirtree`'s per-line `\hrule`/`\vrule` (raw; test: 5
   tree lines → 8 "Relation is not allowed" warnings, scaling with tree
   size) and — non-obviously — for **`dirtreex`**, a from-scratch tikz
   reimplementation of directory trees: each node is its own
   `\begin{tikzpicture}...\end{tikzpicture}\par`
   (confirmed in `dirtreex.sty` source, and by test: 2 tree lines → 2
   "Relation is not allowed" warnings, tree lands as one anonymous
   `/S /Artifact`, no `/Figure`, no `/Alt`). tikz's auto-tag-safety
   (shape 2) only covers *one* picture; many per-item pictures in
   flowing text hit the same paragraph-tagging conflict as raw marks.
   Worse: naively applying shape (1)'s manual wrap *around* tikz-drawn
   content crashes tagpdf outright (`Package tagpdf Error: there is no
   open structure on the stack` — reproduced with a manually re-wrapped
   `qrcodetikz`) because the manual wrap and tikz's own internal
   auto-tagging both try to manage the marked-content stack. Fixing
   `dirtree` is presumably shape (1)'s recipe applied to the whole tree
   rather than per-line, but untested; fixing `dirtreex` is an open
   problem — likely needs tikz's own auto-tagging disabled or worked
   with (not against) rather than a second manual layer on top of it.

`proof` (raw `\hrule` inference lines) and `rail` (raw `picture`-environment
syntax diagrams, currently unused/commented out in the audited project) are
confirmed raw-drawing but *not yet classified* between shape (1) and (3) —
unlike `qrcode`/`dirtree`, nobody has checked whether they assemble one
diagram per call (shape 1, e.g. `rail`'s source shows one `picture`
environment per diagram inside one `minipage` — suggestive but unverified
by an actual tagging test) or emit one paragraph-ending mark per element
like `dirtree` (shape 3). Test before assuming either.

`array`/`longtable` table tagging is *not* a fourth shape needing
anything here: `latex-lab-testphase-table` is, like `-tikz`, now
auto-loaded by the kernel whenever tagging is on (confirmed both locally
and in CI). `tabularray` is a partial exception — its tikz-drawn borders
get shape (2)'s crash-safety for free, but since it does not route
through `array`'s primitives, whether its actual cell/row structure gets
real `Table`/`TR`/`TD` semantics from `-testphase-table` is unconfirmed.

Centralizing shape (1)'s and (3)'s wrap mechanics, and the general
"load the right `latex-lab-testphase-*` companion" pattern, in one place
— outside `osglecture`, so `semcat`, `osglistings`, or any other project
can depend on it directly — is the whole point of this package.

## Expected lifecycle

Like `lttheme`, this is meant to be a stopgap. As the LaTeX Project's own
`latex-lab` work (or its eventual non-testphase successor) grows native
support for more of what's hooked here, the corresponding block in
`tagbridge.dtx` becomes dead weight and should be deleted rather than kept
"just in case" — check LaTeX-lab's changelog before adding anything new
here, in case it already ships upstream.

## Adding a new hook

- One self-contained graphic, raw-drawn (shape 1): copy the `qrcode`
  block's structure — guard the whole thing in
  `\cs_if_exist:NT \tagstructbegin { ... }`, hook via
  `\AddToHook{package/<name>/after}[tagbridge/<name>-tagging]{...}`,
  patch only the package's actual low-level drawing primitive(s), not a
  higher-level wrapper macro.
- One self-contained graphic, tikz-drawn (shape 2): no hook needed in
  this file for "does it crash" — `latex-lab-testphase-tikz` (loaded
  automatically by the kernel once tagging is on) covers that. What's
  needed is a small patch at the *call site* of the affected package to
  pass `alt=`/`artifact=` into its `\tikz[...]` invocation; document
  that patch next to whichever package integration needs it, not
  necessarily here.
- Many small marks in running text (shape 3): if raw-drawn, shape (1)'s
  recipe applied around the *whole* unit (not per-mark) is the working
  hypothesis — verify it the way `qrcode` was verified (structure-object
  count, no warnings, correct `/Alt`) before trusting it for a new
  package. If tikz-drawn, there is currently no known-working recipe
  here at all — do not just copy shape (1)'s wrap onto tikz content, it
  crashes (see `dirtreex` above); investigate working *with* tikz's own
  auto-tagging (e.g. suppressing/redirecting it per picture) before
  writing anything.
- Table/structural package: investigate whether it routes through
  `array`'s primitives first — if so, `latex-lab-testphase-table`
  (auto-loaded by the kernel) already handles it and nothing belongs
  here.

## Known gaps

- **Directory trees.** Neither `dirtree` (shape 3, raw `\hrule`/`\vrule`
  per line — presumably fixable by applying the `qrcode` recipe to the
  whole tree rather than per-line, but untested) nor `dirtreex` (shape 3
  tikz variant, no known-working recipe yet — see above) has a hook here
  yet. One of the two approaches (or a third option) will be needed for
  a real project; `dirtree` is the lower-risk path to try first since a
  raw-drawing wrap is proven to work elsewhere in this file (for
  `qrcode`), `dirtreex` would be new ground (tikz auto-tagging conflict,
  unsolved).
- `proof` and `rail` — confirmed raw-drawing, not yet classified as
  shape 1 or shape 3 (see above), no hook yet either way.
- `menukeys`, `chessboard`/`xskak` (shape 2) — no `alt=`/`artifact=`
  patch yet.
- `tabularray` cell/row structure — unconfirmed whether
  `latex-lab-testphase-table` helps it at all (see above).

## Build & test

Standard bundle module layout — `l3build check`/`install` from this
directory or the bundle root, same as `langselect`, `osgstyler`, etc.

Released under the LaTeX Project Public License v1.3c or later.
See <https://www.latex-project.org/lppl.txt>.
