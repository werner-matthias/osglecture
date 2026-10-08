= Helper Tool

* `update-bundle-manifest.lua`: check and update package versions in the README
* `bundle-versions.lua`: library reading the module versions from the sources; used by
  `update-bundle-manifest.lua` and by `l3build gittag`
* `legacy-osglecture-rewrites.lua`: rewrites osgbeamer-era lecture sources to the
  osglecture interfaces and reports what still needs a manual decision
* `legacy-osglecture-rewrites.sh`: earlier, purely textual helper for the same
  import (superseded by the Lua tool)

== legacy-osglecture-rewrites.lua

----
texlua tools/legacy-osglecture-rewrites.lua [--check] [--rules=LIST] INPUT.tex [OUTPUT.tex]
----

The legacy source is never overwritten; `OUTPUT.tex` must not exist. `--check`
only prints the report. Comments and verbatim material are passed through
untouched, arguments are matched with balanced delimiters, and the run aborts
without writing if the brace balance of the result differs from the input.

Rule groups (`--rules=modes,figures,...`; default: all):

[cols="1,4"]
|===
|`modes` |`\only<article>{..}` -> `\lecturemode<longform>{..}`, `\alt<mode>{a}{b}` ->
`\IfLectureModeTF`, `\medskip<mode>`/`\small<mode>`/`\vspace<mode>{..}`/`\footnote<mode>{..}`
-> guarded by `\lecturemode`, size pairs -> `\ModeValue`, `\mode<mode>{..}` blocks,
`\pipar` -> `\prespar`
|`sections` |`\section<mode>..` -> `\lecturemode<mode>{\section..}`
|`frames` |`[t]`/`[c]`/`[b]` -> `vertical-alignment=...`
|`columns` |`twocolumns`: `T` -> `t`, mode specification before the options
|`figures` |`\centerpic` -> `\centering\includegraphics` with `\ModeValue` widths;
`artfigure`/`arttable` -> `figure`/`table` with `\caption`/`\label`
|`semcat` |`catbar` -> `SemCatMark`, `catbox` -> `SemCatExplain`, `\qr` -> `\SemCatQR`,
`\OsgDefineCategory` -> `\SemCatDefine`
|`listings` |`\rusteditor`, `\inputminted` -> `\osglistinginput`; a `tearout` around a
single listing -> `style=paper`
|`terminals` |`terminal` -> `ansiterm`, `termexec` -> `ansitermexec`
|`references` |`\xref` -> `\olref`, `\xarticleref`/`\xpresentationref` -> `\olref[type=..]`
|`class` |`\documentclass[..]{osgbeamer}` -> `\documentclass{osglecture}`; after `\lecture` a
title page (`\maketitle`, at the top level). The unit
number is continued from the previous unit of the series; `--chapter=N` forces one
(`\OsgLectureDeploymentChapter{N}`), which only the first unit of a series that does
not start at 1 needs
|===

Mode-qualified overlay specifications such as `<+|handout:0>` are kept:
`osglecture-modes` evaluates them. Styling commands that carried a mode
(`\textbf<presentation>{..}`) are kept as well; the report prints the
`\MakeOverlayAwareCommand` declarations the project setup needs for them.
Everything without a single counterpart (`\xrefsmart`, `\pipar`, `columns`,
`tearout` around arbitrary content, project boxes, ...) is listed with line
numbers under "Manual candidates".
