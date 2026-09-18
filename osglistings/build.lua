bundle = "osglecture"
module = "osglistings"

maindir = "../"

textfiles = { "README-osglistings.md" }
installfiles = { "osglistings.sty", "osglistings.lua", "osglistings-check-updates.lua" }
sourcefiles = { "osglistings.dtx", "osglistings.lua", "osglistings-check-updates.lua" }
unpackfiles = { "osglistings.dtx" }
typesetfiles = { "osglistings.dtx" }

dofile("../build.lua")

checkengines = { "luatex" }
checkopts = (checkopts or "-interaction=nonstopmode") .. " --shell-escape"

-- tagging.lvt needs \DocumentMetadata{tagging=on} and the pdfmanagement/
-- latex-lab testphase stack it pulls in -- newer than the rest of this
-- module's dependencies, so it stays excluded from the default "l3build
-- check" run and is exercised on demand, the same way ansiterm keeps its
-- own tagging test opt-in. remote.lvt exercises gist:/github: locators,
-- which need live network access, so it stays opt-in the same way.
-- package-options-cacheignoresfilecontents.lvt exercises a minted option
-- that only exists from a minted version newer than the one bundled with
-- older TeX Live releases, so it lives in its own "cacheopt" config (see
-- cacheopt.lua) instead of the default run.
excludetests = { "tagging", "remote", "package-options-cacheignoresfilecontents" }
