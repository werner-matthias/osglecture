# tagpax 0.3.3-dev

Experimental LuaLaTeX package for preserving tagged-PDF structure when complete
contribution PDFs are assembled with `pdfpages`.

## Build

```sh
l3build unpack
l3build check
l3build doc
```

The standard fixtures use automatic tagging through
`\DocumentMetadata{tagging=on}` on current LaTeX formats. A compatibility branch
is retained only inside fixtures for older formats.

## Test configurations

The normal regression suite has no dependency on external PDF tools:

```sh
l3build check
```

Additional structural checks are enabled through standard l3build configurations:

```sh
l3build check -c structure
```

This compiles `testfiles/support/headings.tex` and runs qpdf, mutool and pdfcpu when available. A known pdfcpu limitation for PDF 2.0 `/AF` is reported as `UNSUPPORTED` and does not fail the test; all other validation errors do.

For the same checks plus veraPDF:

```sh
l3build check -c verapdf
```

The veraPDF report is written to `build/validate/headings-verapdf.txt`. Optional tools that are not installed are reported as skipped.
