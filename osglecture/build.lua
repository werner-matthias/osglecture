bundle = "osglecture"
module = "osglecture"

maindir=".."

installfiles = { "osglecture.cls", "osglecture-config.sty", "twocolumns.sty" }
sourcefiles = { "osglecture.cls", "osglecture-config.sty", "twocolumns.sty" }
typesetfiles = { }
textfiles = { "README.md", "ARCHITECTURE.md" }

dofile("../build.lua")
