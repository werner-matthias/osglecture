# osglecture

`osglecture` is a LuaLaTeX document class for creating several teaching
materials from one shared source. The same content can become presentation
slides, lecture notes, scripts, handouts, or assembled course documents
without maintaining a separate source tree for each format.

It is the core class of the `osglecture` bundle and works together with OLLM,
the bundle's build front end. The class can also be used directly for simpler
documents.

## Why osglecture?

Teaching materials often repeat the same explanations, examples, figures, and
references across slides and long-form documents. Keeping those variants in
separate files makes corrections easy to miss and encourages them to drift
apart.

`osglecture` separates the logical content from its presentation. Authors can
write a unit once, select which passages belong in each mode, and let profiles
adapt the result to a presentation or long-form base class.

## What it provides

- **Multiple outputs from one source.** Mode expressions select content for
  presentations, long-form documents, print output, or project-defined modes.
- **Interchangeable class profiles.** Built-in profiles support Beamer,
  `ltx-talk`, `book`, and `scrbook`; projects can define their own profiles.
- **Mode-aware metadata and setup.** Titles, authors, class options, and other
  settings can vary by output while remaining in one project configuration.
- **Shared authoring components.** Lists and two-column layouts adapt to their
  target: presentation lists can become connected prose, and columns can
  become sequential content in long-form documents.
- **References across course units.** Logical references can point into other
  independently built units while retaining ordinary local-reference syntax.
- **Continuous documents.** Counters such as pages, sections, figures, and
  equations can continue across separately maintained units.
- **Document assembly.** Integration units can combine tagged PDFs while
  preserving structure, links, destinations, outlines, and table-of-contents
  entries. An untagged fallback is available where necessary.
- **Multilingual projects.** Integration with `langselect` allows language
  variants to share the same document structure and build configuration.
- **Accessible output.** The class and its companion packages are designed to
  work with LaTeX's tagged-PDF infrastructure.

## A small example

```latex
\documentclass[standalone,doctype=slides]{osglecture}

\title{Operating Systems}
\author{Ada Example}

\begin{document}

\lecture{Processes}

\begin{frame}{Why concurrency matters}
  \begin{presitemize}
    \item Programs \finite{share} limited resources
    \anditem the operating system \finite{coordinates} access
    \thereforeitem synchronization \finite{is} essential
  \end{presitemize}
\end{frame}

\end{document}
```

With `doctype=slides`, `presitemize` behaves like a normal list. Changing the
standalone example to `doctype=script` turns the same entries into connected
prose. Frames likewise remain native presentation frames or become ordinary
content containers, depending on the selected profile.

For a complete project, OLLM selects the target, language, and profile from a
TOML manifest. Project-wide TeX configuration can then choose concrete
profiles without changing the shared source:

```latex
\LectureTargetSetup{slides}{profile=beamer}
\LectureTargetSetup{talk}{profile=ltx-talk}
\LectureTargetSetup{script}{profile=scrbook}
```

## Examples and documentation

The bundle contains two end-to-end examples:

- [`series-classic`](../examples/series-classic/) uses Beamer and `scrbook`
  without `\DocumentMetadata`.
- [`series-modern`](../examples/series-modern/) demonstrates multilingual,
  tagged output, a project-defined target, cross-unit references, and document
  integration.

See `osglecture-manual-en.pdf` for the English user manual and
`osglecture-manual-de.pdf` for the German version. 

## Building the package

From this directory, run:

```sh
l3build check
l3build install --full
```

`osglecture` requires LuaLaTeX. Some profiles and tagged-PDF features also
depend on sufficiently recent LaTeX and package versions; the build and class
diagnostics report incompatible combinations explicitly.

## Status

The bundle is under active development. Its architecture already supports
real multi-document lecture projects, but interfaces may continue to evolve
before a stable 1.0 release.

`osglecture` is released under the LaTeX Project Public License, version 1.3c
or later.
