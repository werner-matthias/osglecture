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
  "osglecture-integration.sty",
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
  "osglecture-toml.lua",
  "osglecture-manifest.lua",
  "osglecture-manifest-cli.lua",
  "osglecture-integration.lua",
}
sourcefiles = {
  "osglecture.cls",
  "osglecture-config.sty",
  "osglecture-project.sty",
  "osglecture-preamble-*.tex",
  "osglecture-metadata.sty",
  "osglecture-references.sty",
  "osglecture-continuation.sty",
  "osglecture-integration.sty",
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
  "osglecture-toml.lua",
  "osglecture-manifest.lua",
  "osglecture-manifest-cli.lua",
  "osglecture-integration.lua",
}
typesetfiles = { }
checksuppfiles = {
  "reference-source.osgref.aux",
}

dofile("../build.lua")
