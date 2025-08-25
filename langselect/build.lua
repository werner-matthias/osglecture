module = "langselect"

stdengine    = "luatex"
checkengines = {
   "luatex"
}

sourcefiles = {
   "langselect.dtx"
}
dofile("../build.lua")
