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
excludetests = { "tagging", "remote" }

-- Avoid l3build's io.popen() extraction path, which returns no output on
-- the GitHub macOS runner (and, it turns out, sometimes locally too). A
-- regular test task extracts the same XML and places it in a minimal
-- test-log section before l3build normalizes the raw log -- same fix as
-- ansiterm/lttheme/osgstyler's own tagging tests.
function runtest_tasks(name, run)
  if name == "tagging" then
    return "show-pdf-tags --xml " .. name .. ".pdf > " .. name .. ".tags"
      .. os_concat
      .. "texlua insert-pdf-tags.lua " .. name .. ".log " .. name .. ".tags"
  end
  return ""
end
