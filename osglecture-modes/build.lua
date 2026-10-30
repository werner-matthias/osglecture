bundle = "osglecture"
module = "osglecture-modes"

maindir = ".."

installfiles = {
  "osglecture-modes.sty",
  "osglecture-modes-overlays.code.tex",
  "osglecture-modes-lttalk.sty",
  "osglecture-modes-lttalk.lua",
}

sourcefiles = {
  "osglecture-modes.dtx",
}

typesetfiles = { "osglecture-modes.dtx" }

dofile("../build.lua")
