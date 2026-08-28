# osglistings

`osglistings` is a `minted`-based code-listing front end for LuaLaTeX: an
`osglisting` environment for inline source and an `\osglistinginput` command
for external files, three selectable box styles, an independent color
palette for syntax highlighting, and optional links into external online
editors.

```tex
\usepackage{osglistings}

\begin{osglisting}[style=editor, title={main.rs}, link=https://...]{rust}
fn main() {
    println!("hi");
}
\end{osglisting}

\osglistinginput[style=paper, firstline=3, lastline=9]{c}{src/foo.c}
```

Box styles (`style=plain|paper|editor`): `plain` is a minimal rule frame,
`paper` is a torn-edge "printer paper" look with no title bar (and no
support for breaking across a page), `editor` is a title-bar "editor
window" with a language badge and, when `link` is set, an edit-link icon.

Any key `osglistings` doesn't recognize (`firstline`, `lastline`,
`breaklines`, ...) is forwarded to `minted` unchanged.

Colors come from a named palette, declared with `\DeclareOsgListingsPalette`
and activated with `\UseOsgListingsPalette` (or per call via the `palette`
key). Slots left unspecified inherit their value from the built-in
`osglistings-default` palette:

```tex
\DeclareOsgListingsPalette{my-theme}{
  keyword = {model=HTML, value=8A2BE2},
  string  = {alias=keyword},
}
\UseOsgListingsPalette{my-theme}
```

Code is set in `DejaVu Sans Mono` (falling back to `\ttfamily` with a
warning if that font isn't installed) rather than `minted`/`fvextra`'s
default Latin Modern Mono, which silently drops any glyph it doesn't
cover — Cyrillic, chess symbols, and most other non-Latin or symbol text
in source comments/strings would otherwise just vanish from the output.

When LaTeX is started with `\DocumentMetadata{tagging=on}`, the source is
tagged as structure `Code` (structure name `osglistings/code`, remappable
with `\NewStructureName`/`\AssignStructureRole`); switch it off per call
with `tag=false`.

This is the Phase 1 slice of a larger design: remote source (gist/repository)
with caching, marker-comment-based semantic range selection, character-level
`tikz` annotation, and a QR-code link display are follow-up phases, not yet
implemented.

## Build

```sh
l3build check
l3build install
```
