bundle = "osglecture"
module = "osgmodes"

maindir = ".."

installfiles = {
  "osgmodes.sty",
  "osgmodes-overlays.code.tex",
  "osgmodes-lttalk.sty",
  "osgmodes-lttalk.lua",
}

sourcefiles = {
  "osgmodes.dtx",
}

typesetfiles = { "osgmodes.dtx" }

dofile("../build.lua")
