bundle = "osglecture"
module = "lttheme"
maindir = ".."

textfiles = {
    "README-lttheme.md"
}

-- ltx-talk removes a temporary final page on the second LaTeX run.
-- PDF-based visual tests must therefore compare the settled output.
checkruns = 2

checkdeps = { "../osgstyler" }

installfiles = {
    "ltxtalk-theme.sty",
    "ltxtalk-theme-minimal.sty",
    "ltxtalk-theme-magpie.sty",
    "ltxtalk-theme-hawk.sty",
    "ltxtalk-theme-sparrow.sty",
    "ltxtalk-theme-bluebird.sty",
    "ltxtalk-theme-goose.sty",
    "ltxtalk-theme-anchovy.sty",
    "ltxtalk-theme-carp.sty",
    "ltxtalk-theme-font-sans.sty",
    "ltxtalk-theme-font-serif.sty",
    "ltxtalk-theme-font-mixed.sty",
    "ltxtalk-theme-font-libertinus.sty",
    "ltxtalk-theme-font-newcm.sty",
    "ltxtalk-theme-font-texgyre.sty",
}

dofile("../build.lua")

-- Avoid l3build's io.popen() extraction path, which returns no output on the
-- GitHub macOS runner. A regular test task extracts the same XML and places
-- it in a minimal test-log section before l3build normalizes the raw log.
function runtest_tasks(name, run)
  if name == "tagging-slots" then
    return "show-pdf-tags --xml " .. name .. ".pdf > " .. name .. ".tags"
      .. os_concat
      .. "texlua insert-pdf-tags.lua " .. name .. ".log " .. name .. ".tags"
  end
  return ""
end
