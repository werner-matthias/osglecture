bundle = "osglecture"
module = "osglecture"

maindir=".."

installfiles = {
  "osglecture.cls",
  "osglecture-config.sty",
  "osglecture-profiles.sty",
  "osglecture-profile-*.def",
  "osglecture-osgbeamer.code.tex",
  "twocolumns.sty"
}
sourcefiles = {
  "osglecture.cls",
  "osglecture-config.sty",
  "osglecture-profiles.sty",
  "osglecture-profile-*.def",
  "osglecture-osgbeamer.code.tex",
  "twocolumns.sty"
}
typesetfiles = { }
textfiles = { "README.md", "ARCHITECTURE.md" }

dofile("../build.lua")
