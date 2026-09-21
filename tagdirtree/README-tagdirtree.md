# tagdirtree 

This package is part of the `osglecture` bundle, purely for shared
maintenance/build/release infrastructure — like `semcat` and
`osglistings`, it does not require `osglecture` and works in any
document. For user documentation, run `texdoc tagdirtree`.

## What this is

A directory-tree listing package, like `dirtree` and `dirtreex`, but
built accessibility-first.
The tree *is* a nested list from the start, not a graphic that
subsequently needs an alt-text description bolted on.

## Why not just fix `dirtree` or `dirtreex`

Both packages are well-suited for the purpose of drawing directory trees.
However, under `\DocumentMetadata{tagging=on}` both produce a
warning flood scaling with tree size. 
`dirtree` is listed as 
"[currently-incompatible](https://latex3.github.io/tagging-project/tagging-status/#dirtree)".
In turn, `dirtreex` is not listed at all.
It draws one `tikzpicture` per node. 
Trying to apply the approach used in `tagbridge` crashes tagpdf.

## Directory as nested list

A directory tree's content is already fully structured data (name, kind,
note, parent) before any drawing happens — going through a graphic
representation at all, just to describe it again afterwards in one alt
string, throws that structure away and then tries to rebuild a worse
version of it in prose. Setting it directly as a tagged nested list skips
that detour entirely.

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

```latex
\RenewDocumentCommand \tagdirtreedirectoryicon { }
  { \textcolor{\OsgColorName{accent}}{[D]} }
```

Released under the LaTeX Project Public License v1.3c or later.
See <https://www.latex-project.org/lppl.txt>.
