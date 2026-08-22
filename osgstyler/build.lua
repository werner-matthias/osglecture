bundle = "osglecture"
module = "osgstyler"
maindir = ".."

textfiles = {
    "README-osgstyler.md"
}

installfiles = {
    "osgstyler.sty",
}

sourcefiles = {
    "osgstyler.dtx",
}

unpackfiles = {
    "osgstyler.dtx",
}

typesetfiles = {
    "osgstyler.dtx",
}

dofile("../build.lua")
