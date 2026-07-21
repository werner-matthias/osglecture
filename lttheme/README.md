# ltxtalk-themes - Theme Engine for ltx-talk

A flexible, accessible theme system for the ltx-talk presentation class.

## Quick Start

```latex
\DocumentMetadata{}
\documentclass{ltx-talk}
\usepackage{ltxtalk-theme-modern}
\useltxtalktheme{modern}

\title{My Presentation}
\author{John Doe}

\begin{document}
\begin{frame}{First Slide}
  Content here
\end{frame}
\end{document}
```

## Tests

Run the API and PDF-based visual regression tests with `l3build check`.
The `visual-*.pvt` tests contain the same fixed two-slide presentation for
each bundled theme. Their normalized PDF references are stored in the matching
`.tpf` files. After an intentional visual change, inspect the PDFs in
`../build/test/` and update the affected reference explicitly, for example
with `l3build save visual-modern`.

`example/example-tuc-2019.tex` demonstrates the bundled TU Chemnitz 2019
corporate-design theme.  It is available through the short package name
`ltxtalk-tuc-2019` and the regular `ltxtalk-theme-tuc-2019` name.

The `tagging-slots` test additionally compares the XML representation of the
tagged PDF structure. It requires the `show-pdf-tags` program distributed with
TeX Live.
