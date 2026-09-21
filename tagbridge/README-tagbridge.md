# tagbridge — developer notes

This package is part of the `osglecture` bundle. For user
documentation, run `texdoc tagbridge`.

## What this is

This package ist amied a collection of tagging-compatibility hooks for 
third-party packages that predate LaTeX's tagged-PDF support and therefore 
either flood `\DocumentMetadata{tagging=on}` documents with warnings, or produce
anonymous/meaningless tags. 

However, since some of the intended patches ended up becoming separate packages
(`osglistings`, `tagdirtree`, `ansiterm`, `semcat`), 
this package currently contains only patches for two cases: 
* qrcode
* self-contained tikz graphic (here, it basically loads `latex-lab-testphase-tikz`)

## Expected lifecycle

Like `lttheme`, this is meant to be a interim solution. 
As the LaTeX Project's own `latex-lab` work (or its eventual non-testphase 
successor) grows native support for more of what's hooked here, the 
corresponding block in `tagbridge.dtx` becomes dead weight and should be 
deleted rather than kept
"just in case" — check LaTeX-lab's changelog before adding anything new
here, in case it already ships upstream.

## To Do
- `proof`
- `rail` 
- `menukeys`
- `chessboard`/`xskak`
- `tabularray`

## Build & test

Standard bundle module layout — `l3build check`/`install` from this
directory or the bundle root, same as `langselect`, `osgstyler`, etc.

Released under the LaTeX Project Public License v1.3c or later.
See <https://www.latex-project.org/lppl.txt>.
