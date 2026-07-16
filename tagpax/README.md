# tagpax

Goal: Semantic import of tagged PDFs.

Read this file, doc/ARCHITECTURE.md and doc/STATUS.md before starting development.

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

A restricted compatibility for `pdfpages` frontend is generated as `tagpax-pdfpages.sty`:

```latex
\usepackage{tagpax-pdfpages}
\tagpaxincludepdf[pages=-]{paper.pdf}
```

This accepts only the linear full-document case and routes it through the native
importer. It intentionally does not use `pdfpages` for Form creation.

## Modules

- `tagpax.lua`: extraction facade;
- `tagpax-ir.lua`: IR and deserialization;
- `tagpax-validate.lua`: semantic validation;
- `tagpax-inspect.lua`: inspection API;
- `tagpax-import.lua`: backend-independent import plan;
- `tagpax-luatex.lua`: controlled page Form import;
- `tagpax-native.lua`: native linear document emitter;
- `tagpax-backend.lua`: TeX backend-plan emission;
- `tagpax-compare.lua`: semantic roundtrip comparison.

## Build

```sh
l3build unpack
l3build check
l3build check -c roundtrip
l3build doc
l3build ctan
```

The roundtrip test compiles a tagged contribution, extracts it, imports it with
the native path, extracts the master PDF, and compares the semantic trees.
