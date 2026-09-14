# tagdirtree — developer notes

This package is part of the `osglecture` bundle, purely for shared
maintenance/build/release infrastructure — like `semcat` and
`osglistings`, it does not require `osglecture` and works in any
document. For user-facing documentation, run `texdoc tagdirtree`.

## What this is

A directory-tree listing package, like `dirtree` and `dirtreex`, but
built accessibility-first instead of accessibility-as-an-afterthought:
the tree *is* a nested list from the start, not a graphic that
subsequently needs an alt-text description bolted on.

## Why not just fix `dirtree` or `dirtreex`

See `tagbridge`'s README for the full investigation. Short version: both
existing packages draw the tree as a self-contained graphic (raw
`\hrule`/`\vrule` for `dirtree`, one `tikzpicture` per node for
`dirtreex`), and under `\DocumentMetadata{tagging=on}` both produce a
warning flood scaling with tree size, landing as one anonymous
`/S /Artifact` with no `/Alt` and no per-entry semantics. Wrapping either
after the fact hits real problems: the raw case is (probably) fixable
with `tagbridge`'s `qrcode`-style manual wrap applied to the whole tree,
but the tikz case actively crashes tagpdf if you try (see `tagbridge`'s
README) — there is no known-working retrofit for `dirtreex`.

A directory tree's content is already fully structured data (name, kind,
note, parent) before any drawing happens — going through a graphic
representation at all, just to describe it again afterwards in one alt
string, throws that structure away and then tries to rebuild a worse
version of it in prose. Setting it directly as a tagged nested list skips
that detour entirely.

## How the tagging actually works

This needed real debugging, not just applying the obvious pattern — two
non-obvious things had to be found empirically (verified via the
`\DocumentMetadata{tagging=on}` + `qpdf --qdf` round-trip used throughout
this package's design discussion):

1. **Each entry's manually-opened structure uses role `Span`, not `LI`.**
   The surrounding `\item` is already correctly tagged as a list item by
   the kernel's own `enumitem`/list-tagging integration. Manually opening
   a *second* `LI`-rolled structure at the same point is an illegal
   parent-child relation (`LI` cannot directly contain another `LI`) --
   confirmed by reproducing the exact `tagpdf` error. `Span` nests inside
   the kernel's own list body without conflict.
2. **`\leavevmode` immediately after `\item`, before opening the manual
   tag structure, is required.** Without it, the manual
   `\tagstructbegin` fires before the kernel's own per-item paragraph
   structure has actually opened, and attaches to the wrong (stale)
   parent — same error class as (1), independent of which role is used.
   Confirmed by isolating the difference between "manual tag call right
   after `\item`" (fails) and "manual tag call after some other content
   in the same item" (works) — `\leavevmode` is the standard idiom that
   forces the same paragraph-opening machinery.

With both fixed, a full nested tree (directories, files, an archive,
entries with and without a note) tags with zero `tagpdf` warnings and
correct per-entry `/Alt` text (verified: `/S /Span` per entry, each with
`/Alt` = "Kind: name -- note" or "Kind: name" when the note is empty).

The `/Alt` string, not a custom PDF structure-type name, is deliberately
the primary channel for the kind ("File"/"Directory"/"Archive"): custom
role names (`tagdirtree/file` etc., declared via `\NewStructureName` /
`\AssignStructureRole`, same idiom as `ansiterm`) exist here mainly as a
configurable indirection to the real tag (`Span`), not as something most
screen readers actually vocalize distinctly — see the discussion in this
package's design conversation. Putting the kind word in the `/Alt` text
itself is what reliably reaches a real user.

## Icons instead of connector lines

No connector lines are drawn at all, deliberately — the nested-list
structure already conveys the hierarchy (indentation), so a drawn line
would be purely redundant decoration, not additional information. Each
entry instead gets a kind icon (`\tagdirtreefileicon` /
`\tagdirtreedirectoryicon` / `\tagdirtreearchiveicon`, default plain
placeholders `[F]`/`[D]`/`[A]`), meant to be overridden by the document.

The icon is wrapped in `\tagmcbegin{artifact}...\tagmcend` and inserted
at the *render* step, not passed through the `name`/`note` arguments —
verified why this matters the hard way: stuffing an icon macro into
`\dtdir`'s name argument leaks raw macro tokens into the `/Alt` string
(the alt-text builder does not expect non-expandable content there),
since it isn't expanded the way the visible-render path is. Icons and
alt text are two separate consumers of the same entry data; only the
render path should ever see the icon.

`osgstyler` integration was checked and does *not* go through its
`affix` decoration family — that's bound to `osgstyler-block`'s own
application sites with no public "apply one affix standalone" command,
and its `symbol=` key has no resolving backend yet anyway. The
practical hook is the public, expandable `\OsgColorName`, to pick a
theme color for whatever icon content you use:

```latex
\RenewDocumentCommand \tagdirtreedirectoryicon { }
  { \textcolor{\OsgColorName{accent}}{[D]} }
```

## Scope of v0.1

- No package options (key-value interface) — customization is via
  redefining the icon commands and via `enumitem` on the `tagdirtree`
  environment itself, not a formal options system.
- `\dtdir`'s body argument is `+m` (paragraph-safe) so nested entries can
  be formatted on separate lines as in the examples.

## Build & test

Standard bundle module layout — `l3build check`/`install` from this
directory or the bundle root, same as `langselect`, `tagbridge`, etc.

Released under the LaTeX Project Public License v1.3c or later.
See <https://www.latex-project.org/lppl.txt>.
