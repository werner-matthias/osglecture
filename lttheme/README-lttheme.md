# ltxtalk-themes - Theme Engine for ltx-talk

A flexible, accessible theme system for the ltx-talk presentation class.

## Quick Start

```latex
\DocumentMetadata{}
\documentclass{ltx-talk}
\usepackage{ltxtalk-theme-magpie}
\useltxtalktheme{magpie}

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
with `l3build save visual-magpie`.

The bundled layout themes are `minimal`, `magpie` (inspired by Beamer
Madrid), `hawk` (Hannover), and `sparrow` (Szeged). The colour-only themes
`anchovy` (AnnArbor colours) and `carp` (CambridgeUS colours) are layered on
top of a layout theme with `\addltxtalktheme{anchovy}` or
`\addltxtalktheme{carp}`. They change semantic colours only and leave the
layout and tagged reading order untouched.

The engine also controls the inner theme. `\setltxtalkcolors` accepts the
semantic colours `structure`, `alert`, and `example`; `\styleltxtalkblock`
styles the `block`, `alertblock`, and `exampleblock` template instances; and
`\setltxtalkitemize` selects the marker for each of the four list levels.
The fallback alert/example environments reuse ltx-talk's block implementation,
including its overlay and tagging behaviour, and are only defined when the
class has not supplied environments of the same names.

The `tagging-slots` test additionally compares the XML representation of the
tagged PDF structure. It requires the `show-pdf-tags` program distributed with
TeX Live.
