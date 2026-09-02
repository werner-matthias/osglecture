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

`\osglistinginput`'s file argument also accepts a `gist:owner/gist-id/file`
or `github:owner/repo@ref/path` locator instead of a local path; the source
is fetched once and cached under `\jobname.osglistings-cache/`, and an
editor link is derived automatically when none is given explicitly. This
requires LuaLaTeX and `--shell-escape`, and — since it invokes `curl` with
the compiling process's own permissions — should only be used with
trusted documents/locators. `texlua osglistings-check-updates.lua
[--refresh] <cache-dir>` checks a cache for staleness outside LaTeX;
`remote-check=compile` does the same automatically at the end of a
compile run.

`\osglistingsmark{name}` drops a named, invisible `tikz` node at an exact
character position in inline source (needs `escapeinside` on); a later
`tikzpicture[remember picture, overlay]` can then draw to or from it,
resolving after a second compile run like any such overlay. The `marks`
key on `\osglistinginput` does the same for external sources, addressing
positions either by `name at line:col` or by a literal text search
(`name after/before "text" [occurrence=n]`) — no manual `escapeinside`
needed there. `link-display=qrcode` renders the link as a QR code below
the box instead of a titlebar icon or text label.

## Build

```sh
l3build check
l3build install
```
