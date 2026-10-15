# semcat

`semcat` assigns passages to named, visually distinguishable semantic
categories such as “required”, “supplementary”, or “background”. Categories
can mark short inline passages, longer material spanning paragraphs and pages,
or floating explanations outside the main reading flow. They can also point
readers to related material with QR-code annotations.

Category styling can use colour, symbols, boxes, or continuous margin bars,
which keeps distinctions usable in colour-limited output. Optional integration
with `osgstyler` supplies theme-aware colours and decorations, while
`osglecture-modes` can restrict annotations to selected document variants.

The package supports tagged-PDF output and preserves the distinction between
annotations within the reading flow and supplementary floating material. It
can be used independently of the rest of the `osglecture` bundle; continuous
margin bars require LuaLaTeX.

For the complete interface and examples, run `texdoc semcat`.
