bundle = "osglecture"
module = "osglecture"

maindir=".."

installfiles = { "osglecture.cls", "osglecture-config.sty" }
sourcefiles = { "osglecture.cls", "osglecture-config.sty" }
typesetfiles = { }
textfiles = { "README.md", "ARCHITECTURE.md" }

dofile("../build.lua")
