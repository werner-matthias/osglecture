bundle = "osglecture"
module = "osglistings"

maindir = "../"

textfiles = { "README-osglistings.md" }
installfiles = { "osglistings.sty" }
sourcefiles = { "osglistings.dtx" }
unpackfiles = { "osglistings.dtx" }
typesetfiles = { "osglistings.dtx" }

dofile("../build.lua")

checkengines = { "luatex" }
checkopts = (checkopts or "-interaction=nonstopmode") .. " --shell-escape"

-- tagging.lvt needs \DocumentMetadata{tagging=on} and the pdfmanagement/
-- latex-lab testphase stack it pulls in -- newer than the rest of this
-- module's dependencies, so it stays excluded from the default "l3build
-- check" run and is exercised on demand, the same way ansiterm keeps its
-- own tagging test opt-in.
excludetests = { "tagging" }
