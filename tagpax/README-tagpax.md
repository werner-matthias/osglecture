# tagpax

`tagpax` extracts, reconstructs and reimports the logical structure of fully tagged
PDFs to allow assembled tagged pdf documents.
It is LuaLaTeX-only.

The public commands are:

```latex
\tagpaxextract[paper.tagpax]{paper.pdf}
\tagpaxinclude[ir=paper.tagpax]{paper.pdf}
```

It currently only supports complete linear documents, one fresh Form XObject per
source page, page-content MCIDs, and a new `Part` wrapper. Explicit nested
`/Stm` source Forms remain represented in the IR but are rejected by the native
writer until a reliable nested-XObject mapping is available.

Named destinations and `/Link` annotations with `GoTo`, `URI`, and `GoToR`
actions are imported. Internal destination views and coordinates are
transformed to the scaled whole page; remote named and page targets are
retained.
Extracted headings are added to the master table of contents and, when the
`bookmark` interface is available, to the master PDF outline according to
`toc-depth`, `bookmark-depth`, and `heading-map`.

## Build

```sh
l3build install
```

## Regression Test

```sh
l3build check
l3build check -c roundtrip
```

The roundtrip test compiles a tagged contribution, extracts it, imports it with
the native path, extracts the master PDF, and compares the semantic trees,
including MCR/OBJR order and precise internal destinations.