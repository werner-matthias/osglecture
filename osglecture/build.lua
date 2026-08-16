bundle = "osglecture"
module = "osglecture"

maindir=".."

checkdeps = { "../osglecture-modes" }

installfiles = {
  "osglecture.cls",
  "osglecture-config.sty",
  "osglecture-project.sty",
  "osglecture-preamble-*.tex",
  "osglecture-metadata.sty",
  "osglecture-references.sty",
  "osglecture-continuation.sty",
  "osglecture-structure.sty",
  "osglecture-adapters.sty",
  "osglecture-adapter-*.def",
  "osglecture-profiles.sty",
  "osglecture-profile-*.def",
  "osglecture-osgbeamer.code.tex",
  "osglecture-presitemize.sty",
  "osglecture-twocolumns.sty",
  "osglecture-series-index.lua",
  "osglecture-series.sty",
}
sourcefiles = {
  "osglecture.cls",
  "osglecture-config.sty",
  "osglecture-project.sty",
  "osglecture-preamble-*.tex",
  "osglecture-metadata.sty",
  "osglecture-references.sty",
  "osglecture-continuation.sty",
  "osglecture-structure.sty",
  "osglecture-adapters.sty",
  "osglecture-adapter-*.def",
  "osglecture-profiles.sty",
  "osglecture-profile-*.def",
  "osglecture-osgbeamer.code.tex",
  "osglecture-presitemize.sty",
  "osglecture-twocolumns.sty",
  "osglecture-series-index.lua",
  "osglecture-series.sty",
}
typesetfiles = { }
textfiles = { "README.md", "ARCHITECTURE.md" }
checksuppfiles = {
  "reference-source.osgref.aux",
}

dofile("../build.lua")
