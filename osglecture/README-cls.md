# osglecture

`osglecture` is a LuaLaTeX document class for creating several kinds of
teaching material from one shared source. The same content can become slides,
lecture notes, scripts, handouts, or assembled course documents without
maintaining a separate source tree for every format.

The class separates logical content from presentation through document modes
and interchangeable profiles. Built-in profiles cover presentation and
long-form classes, while projects can provide their own. Shared authoring
components adapt to the selected output, and metadata or setup can vary by
mode.

For larger courses, `osglecture` supports multilingual variants, references
and continuous numbering across independently maintained units, and assembly
of complete documents. The class and its companion packages are designed for
accessible, tagged-PDF output. OLLM, the bundle's build front end, coordinates
the variants of a complete project; the class can also be used directly.

The bundle contains two end-to-end examples:

- [`series-classic`](../examples/series-classic/) combines Beamer and
  `scrbook` output.
- [`series-modern`](../examples/series-modern/) demonstrates multilingual,
  tagged output, cross-unit references, and document integration.

See `osglecture-manual-en.pdf` or `osglecture-manual-de.pdf` for the full user
documentation. The package is under active development and requires LuaLaTeX.

Released under the LaTeX Project Public License v1.3c or later.
