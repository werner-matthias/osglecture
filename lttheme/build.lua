bundle = "osglecture"
module = "lttheme"
maindir = ".."

sourcefiledir = "source"
sourcefiles = { "lttheme.dtx", "lttheme.ins" }
unpackfiles = { "lttheme.ins" }
installfiles = { "ltxtalk-theme-*.sty" }
typesetfiles = { "lttheme.dtx" }

checkengines = { "luatex" }
stdengine = "luatex"
checkruns = 1

dofile("../build.lua")
