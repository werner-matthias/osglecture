<!-- Generated from README.md by tools/make-ctan-readme.lua; do not edit. -->
# OSG Lecture

This README describes the CTAN release 2026-10-22 of the bundle.
Sources and the current development state are available at
<https://github.com/werner-matthias/osglecture>.

LaTeX bundle for generating lecture materials at the Operating Systems Group at the TU Chemnitz.
The bundle serves two main purposes:
* To support an "one source, many documents" approach
* To support accessibility (tagging)

Currently, the following packages are included:
* The **osglecture** class to generate different materials (slides, script) from a common source
* **OSG LaTeX Lecture Maker** is a latexmk-based build script to support creation and deploying of lecture materials
* **osglecture-modes** provides a generalization of portable document modes in the style of beamer/ltx-talk
* **langselect**: supports the generation of different language versions from a common source
* **tagpax**:  enables the semantic import of tagged PDFs
* **osgstyler** provides a template-based formatting
* **ltxtalk-theme**: is a theme engine to allow easy and flexible design of themes for ltx-talk.
    It also includes a few themes modeled after some Beamer themes
* **ltxtalk-theme-tuc-2019** is (an unofficial version of) the presentation theme of TU Chemnitz for ltx-talk
* **ansiterm**: ANSI-aware executable terminal windows
* **osglistings**: a `minted`-based code-listing front end
* **semcat**: generalized semantic-category markup (inline, margin, box) with optional QR-code annotations
* **tagdirtree**: taggable directory tree
* **tagbridge**: transition package to patch few third party package w/o own native PDF/UA support.
* **osgdoc** is a small wrapper for cnltx and provides some further support for documentation

> **Warning**
> Although the bundle is currently in active use (or perhaps precisely because
> it is—we're dealing with a kind of DevOps scenario here), it is explicitly under active
> development and is not stable.
>
> In other words: APIs are subject to change.

## Modules' version and compatibility
The bundle as a whole is identified by its release date only
(current: 2026-10-22).
Each module keeps its own version and may has its own compatibility dependency.
Whilst in general an up-to-date TeX installation is required, few modules are
working with older distributions.

In addition, OSG Lecture is a LuaLaTeX bundle ( 🌕 ). That said, there are few package that can work without Lua in a
degrated mode ( 🌓 ) or don't require Lua at all ( 🌑 ).

 The following table lists versions and compatibility, the `TL ...` columns show compatibility with
recent TeXLive/MacTeX distributions ("current" = latest available image).

| Module | Version | Date | Files | Lua | TL 2024 | TL 2025 | TL current |
|---|---|---|---|:---:|:---:|:---:|:---:|
| osglecture | v0.6.0 | 2026-10-05 | 24 | 🌕 | 🔴 | 🟢 | 🟢 |
| osglecture-modes | v0.5.1 | 2026-09-27 | 2 | 🌕 | 🔴 | 🟢 | 🟢 |
| ltx-talk support (osglecture + osglecture-modes) | n/a | n/a | n/a | 🌕 | 🔴 | 🔴 | 🟢 |
| ollm | v0.15.0 | n/a | 1 | ⚪ | ⚪ | 🟢 | 🟢 |
| tagpax | v0.8.6 | 2026-10-22 | 2 | 🌕 | 🔴 | 🟢 | 🟢 |
| tagbridge | v0.1.0 | 2026-09-14 | 1 | 🌑 | 🔴 | 🟢 | 🟢 |
| tagdirtree[^1] | v0.1.0 | 2026-09-14 | 1 | 🌑 | 🔴 | 🟢 | 🟢 |
| langselect | v1.1.3 | 2026-09-18 | 1 | 🌕 | 🟢 | 🟢 | 🟢 |
| osgstyler | v0.2.0 | 2026-08-24 | 2 | 🌓 | 🔴 | 🔴 | 🟢 |
| lttheme | v0.5.3 | 2026-10-05 | 15 | 🌑 | 🔴 | 🔴 | 🟢 |
| lttheme-tuc-2019 | v0.5.1 | 2026-08-24 | 1 | 🌑 | 🔴 | 🔴 | 🟢 |
| ansiterm[^2] | v0.2.1 | 2026-08-26 | 1 | 🌕 | 🔴 | 🔴 | 🟢 |
| osglistings | v0.1.0 | 2026-08-28 | 1 | 🌕 | 🟢 | 🟢 | 🟢 |
| semcat | v0.3.0 | 2026-08-31 | 1 | 🌕 | 🟢 | 🟢 | 🟢 |
| osgdoc | v0.5.0 | 2026-09-08 | 2 | 🌓 | 🟢 | 🟢 | 🟢 |
[^1]: The incompatibility for TL 2024 refers to tagging only; the untagged tree is okay.
[^2]: The incompatibility for TL 2025 refers to tagging only; the basis features are okay.

## Installation
Install the bundle with the package manager of your TeX distribution.
The build tool `ollm` is installed as a user command; check the installation with
```
ollm doctor
```

## Documentation
See `osglecture-manual-en.pdf` or `osglecture-manual-de.pdf` for a user documentation
in English, or German, respectively.

Beside, the most packages have their own documentation.

## Bugs and Limitations
Even though the individual packages vary considerably in terms of maturity,
the bundle as a whole should definitely be considered experimental.
As such, it certainly still has lots of bugs.
Please report any bug you find [here](https://github.com/werner-matthias/osglecture/issues).
