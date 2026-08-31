bundle = "osglecture"
module = "semcat"
maindir = ".."

checkdeps = { "../osglecture-modes", "../osgstyler" }

textfiles = {
  "README-semcat.md"
}

installfiles = {
  "semcat.sty",
  "semcat.lua",
}

sourcefiles = {
  "semcat.dtx",
  "semcat.lua",
}

unpackfiles = {
  "semcat.dtx",
}

typesetfiles = {
  "semcat.dtx",
}

dofile("../build.lua")

checkengines = { "luatex" }
