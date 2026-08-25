bundle = "osglecture"
module = "osglecture-manual"
maindir = ".."

sourcefiles = {
  "osglecture-manual-en.tex",
  "osglecture-manual-de.tex",
  "osglecture-manual.tex",
  "polymorphy-*.tex",
  "styler-*.tex",
}

typesetfiles = {
  "polymorphy-slides-en.tex",
  "polymorphy-slides-de.tex",
  "polymorphy-script-de.tex",
  "styler-screen.tex",
  "styler-print.tex",
  "osglecture-manual-en.tex",
  "osglecture-manual-de.tex",
}

docfiles = {
  "osglecture-manual-en.pdf",
  "osglecture-manual-de.pdf",
}

installfiles = { }

typesetdeps = {
  "../osglecture-modes",
  "../osglecture",
  "../osgstyler",
}

dofile("../build.lua")
