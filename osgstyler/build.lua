bundle = "osglecture"
module = "osgstyler"
maindir = ".."

checkdeps = { "../osglecture-modes" }

textfiles = {
    "README-osgstyler.md"
}

installfiles = {
    "osgstyler.sty",
    "osgstyler-lua.sty",
    "osgstyler.lua",
}

sourcefiles = {
    "osgstyler.dtx",
    "osgstyler.lua",
}

unpackfiles = {
    "osgstyler.dtx",
}

typesetfiles = {
    "osgstyler.dtx",
}

dofile("../build.lua")
