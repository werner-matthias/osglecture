# tagpax

`tagpax` extracts and reconstructs the logical structure of fully tagged
contribution PDFs for proceedings assembled with LuaLaTeX.

The public native command is:

```latex
\tagpaxextract[paper.tagpax]{paper.pdf}
\tagpaxinclude[ir=paper.tagpax]{paper.pdf}
```

It currently supports complete linear documents, one fresh Form XObject per
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

For short migrations, package option `pdfpages` provides the familiar command
name with a deliberately restricted option set:

```latex
\usepackage[pdfpages]{tagpax}
\includepdf[pages=-]{paper.pdf}
```

This accepts only the linear full-document case and routes it through the
native importer. It neither loads nor depends on the real `pdfpages` package.
Do not combine the compatibility option with that package. If `tagpax` detects
it, the compatibility command is disabled with a warning; use
`\tagpaxinclude` for semantic imports instead.

## Developer documentation

- [`doc/architecture.md`](doc/architecture.md): data flow, ownership,
  invariants, backend phases and module boundaries;
- [`doc/DESIGN.md`](doc/DESIGN.md): current design decisions and rationale;
- [`doc/FORMATS.md`](doc/FORMATS.md): canonical IR, import-plan and private TeX
  backend formats;
- [`doc/PDF-MODEL.md`](doc/PDF-MODEL.md): PDF object, tagging, navigation and
  coordinate structures used by the implementation;
- [`doc/CONTRIBUTING.md`](doc/CONTRIBUTING.md): maintenance and verification.

## Build

```sh
l3build unpack
l3build check
l3build check -c roundtrip
l3build doc
l3build ctan
```

The roundtrip test compiles a tagged contribution, extracts it, imports it with
the native path, extracts the master PDF, and compares the semantic trees,
including MCR/OBJR order and precise internal destinations.
