bundle = "osglecture"
module = "osglecture-manual"
maindir = ".."

sourcefiles = {
  "osglecture-manual-en.tex",
  "osglecture-manual-de.tex",
  "osglecture-manual.tex",
}

typesetfiles = {
  "osglecture-manual-en.tex",
  "osglecture-manual-de.tex",
}

docfiles = {
  "osglecture-manual-en.pdf",
  "osglecture-manual-de.pdf",
}

installfiles = { }

dofile("../build.lua")
