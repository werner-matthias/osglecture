# osglecture-modes — Portable document modes for LaTeX

Use Beamer/ltx-talk-style document modes with ordinary LaTeX classes,
define custom modes with multiple parents, and share source between slides,
handouts, and long-form documents.

```latex
\documentclass{article}
\usepackage[mode=script]{osglecture-modes}
\begin{document}
Common text.
\lecturemode<print>{Text for printed documents.}
\lecturemode<presentation>{Text for presentations.}
\end{document}
```

Here `script` activates `article`, `longform`, and `print`, so presentation
text is omitted. The mode selection does not change the document class.

The package provides mode queries, expandable mode-dependent values,
overlay integration, and definitions of mode-dependent commands. Optional
text filtering outside registered environments requires LuaLaTeX, except
when delegating to Beamer's native `\mode*`.

Read the [German manual](../doc/osglecture-modes-de.pdf) or
[English manual](../doc/osglecture-modes-en.pdf) for the quick start,
built-in mode graph, command and option reference, overlays, filters, and
custom document types. The bilingual source is
[osglecture-modes.dtx](osglecture-modes.dtx).

Build both manuals with `l3build doc` in this directory.

This package is part of the osglecture bundle and can also be used independently.
Released under the LaTeX Project Public License v1.3c or later.
See <https://www.latex-project.org/lppl.txt>.
