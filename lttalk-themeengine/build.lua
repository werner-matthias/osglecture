bundle = "osglecture"
module = "lttalk-themeengine"
maindir = ".."

textfiles = {
    "README-lttheme.md"
}

-- ltx-talk removes a temporary final page on the second LaTeX run.
-- PDF-based visual tests must therefore compare the settled output.
checkruns = 2

checkdeps = { "../osgstyler" }

installfiles = {
    "lttalk-themeengine.sty",
    "lttalk-theme-minimal.sty",
    "lttalk-theme-magpie.sty",
    "lttalk-theme-hawk.sty",
    "lttalk-theme-sparrow.sty",
    "lttalk-theme-bluebird.sty",
    "lttalk-theme-goose.sty",
    "lttalk-theme-anchovy.sty",
    "lttalk-theme-carp.sty",
    "lttalk-theme-font-sans.sty",
    "lttalk-theme-font-serif.sty",
    "lttalk-theme-font-mixed.sty",
    "lttalk-theme-font-libertinus.sty",
    "lttalk-theme-font-newcm.sty",
    "lttalk-theme-font-texgyre.sty",
}

-- Shared helper of the tagging tests, kept once in <maindir>/support.
checksuppfiles = { "insert-pdf-tags.lua" }

dofile("../build.lua")

-- \lttalkversion mirrors the package version as a bare number for messages
-- issued before \ProvidesExplPackage has run; keep it in step when tagging.
local update_bundle_tag = update_tag

function update_tag(file, content, tagname, tagdate)
  local updated = update_bundle_tag(file, content, tagname, tagdate)
  if file == "lttalk-themeengine.dtx" then
    local bare_version = tagname:gsub("^v", "")
    updated = updated:gsub(
      "(\\def\\lttalkversion{)[^}]*(})",
      function(opening, closing)
        return opening .. bare_version .. closing
      end,
      1
    )
  end
  return updated
end

-- Avoid l3build's io.popen() extraction path, which returns no output on the
-- GitHub macOS runner. A regular test task extracts the same XML and places
-- it in a minimal test-log section before l3build normalizes the raw log.
local tagging_tests = {
  ["accessibility-roles"] = true,
  ["auto-section-title"] = true,
  ["framesubtitle-tagging"] = true,
  ["tagging-slots"] = true,
}

function runtest_tasks(name, run)
  if tagging_tests[name] then
    return "show-pdf-tags --xml " .. name .. ".pdf > " .. name .. ".tags"
      .. os_concat
      .. "texlua insert-pdf-tags.lua " .. name .. ".log " .. name .. ".tags"
  end
  return ""
end
