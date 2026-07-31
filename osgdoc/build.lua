bundle = "osglecture"
module = "osgdoc"

maindir=".."

textfiles = {
    "README-osgdoc.md"
}

installfiles = { 
    "osgdoc.cls", 
    "osgdoc.sty" 
}

dofile("../build.lua")
