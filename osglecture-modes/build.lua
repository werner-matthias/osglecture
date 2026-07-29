bundle = "osglecture"
module = "osglecture-modes"

maindir = ".."

installfiles = {
  "osglecture-modes.sty",
  "osglecture-modes-ltxtalk.sty",
  "osglecture-modes-ltxtalk.lua",
}

sourcefiles = {
  "osglecture-modes.dtx",
}

typesetfiles = { "osglecture-modes.dtx" }

dofile("../build.lua")
