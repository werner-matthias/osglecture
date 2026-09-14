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

The tagging problems this covers come in (at least) three distinct shapes,
and none of them reduces to the others:

1. **Raw low-level drawing, no tikz involved** (`qrcode`'s per-module
   `\rule`s). Needs a manual wrap around the drawing call:
   `\tagpdfparaOff` + `\tagstructbegin`/`\tagmcbegin` ... `\tagmcend`/
   `\tagstructend`, plus a language-aware `alt=` default and a
   content-based security check (see `__tagbridge_qrcode_*` in
   `tagbridge.dtx`). This is the pattern to copy for any future
   non-tikz raw-drawing package (candidates found in an audit of a real
   lecture project: `rail`, syntax diagrams via the LaTeX `picture`
   environment; `proof`, natural-deduction trees via raw `\hrule`).
2. **tikz-based, but the drawing macro never passes `alt=`/`artifact=`**
   (any bare `\tikz`/`tikzpicture` call). `latex-lab-testphase-tikz`
   already makes tikz itself tag-safe (no crash, sane marked-content
   grouping) regardless of what's drawn — confirmed experimentally, see
   the qrcodetikz spike in this package's originating conversation.
   What's missing is purely the *semantic* label, which has to be
   injected into the specific `\tikz[...]` call site (`menukeys`,
   `chessboard`/`xskak`, `tabularray`'s TikZ-drawn borders all fall
   here). There is no generic fix for this shape beyond loading the
   testphase package and, package by package, patching in the key.
3. **Structural content** (`array`/`longtable` tables). Needs a
   completely different official module,
   `latex-lab-testphase-table`, not a home-grown wrap. Not yet wired up
   here — `tabularray` in particular builds tables from scratch (not
   through `array`) and would likely need its own investigation before
   `latex-lab-testphase-table` helps it at all.

Centralizing shape (1)'s wrap mechanics and the "load the right
`latex-lab-testphase-*` companion" bootstrap for shape (2)/(3) in one
place — outside `osglecture`, so `semcat`, `osglistings`, or any other
project can depend on it directly — is the whole point of this package.

## Expected lifecycle

Like `lttheme`, this is meant to be a stopgap. As the LaTeX Project's own
`latex-lab` work (or its eventual non-testphase successor) grows native
support for more of what's hooked here, the corresponding block in
`tagbridge.dtx` becomes dead weight and should be deleted rather than kept
"just in case" — check LaTeX-lab's changelog before adding anything new
here, in case it already ships upstream.

## Adding a new hook

- Raw-drawing package (shape 1 above): copy the `qrcode` block's
  structure — guard the whole thing in
  `\cs_if_exist:NT \tagstructbegin { ... }`, hook via
  `\AddToHook{package/<name>/after}[tagbridge/<name>-tagging]{...}`,
  patch only the package's actual low-level drawing primitive(s), not a
  higher-level wrapper macro.
- tikz-based package (shape 2): no hook needed in this file for
  "does it crash" — `latex-lab-testphase-tikz` (already required here)
  covers that. What's needed is a small patch at the *call site* of the
  affected package to pass `alt=`/`artifact=` into its `\tikz[...]`
  invocation; document that patch next to whichever package integration
  needs it, not necessarily here.
- Structural/table package (shape 3): investigate whether it routes
  through `array`'s primitives (then `latex-lab-testphase-table` likely
  already helps) before writing anything bespoke.

## Build & test

Standard bundle module layout — `l3build check`/`install` from this
directory or the bundle root, same as `langselect`, `osgstyler`, etc.

Released under the LaTeX Project Public License v1.3c or later.
See <https://www.latex-project.org/lppl.txt>.
