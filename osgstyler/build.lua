bundle = ""
module = "osgstyler"
maindir = ".."

checkdeps = { "../osgmodes" }

textfiles = {
    "README.md"
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

-- The lttheme-* tests need a stand-in for lttalk-themeengine, see the head
-- of testfiles/support/lttalk-themeengine.sty.in.
function checkinit_hook()
  local input = assert(io.open(testdir .. "/lttalk-themeengine.sty.in", "rb"))
  local output = assert(io.open(testdir .. "/lttalk-themeengine.sty", "wb"))
  output:write(input:read("a"))
  input:close()
  output:close()
  return 0
end

-- Shared helper of the tagging tests, kept once in <maindir>/support.
checksuppfiles = { "insert-pdf-tags.lua" }

dofile("../build.lua")

-- Avoid l3build's io.popen() extraction path, which returns no output on the
-- GitHub macOS runner. A regular test task extracts the same XML and places
-- it in a minimal test-log section before l3build normalizes the raw log.
local tagging_tests = {
  ["block-tagging"] = true,
  ["tagging-preservation"] = true,
  ["tagging-semantics"] = true,
}

function runtest_tasks(name, run)
  if tagging_tests[name] then
    return "show-pdf-tags --xml " .. name .. ".pdf > " .. name .. ".tags"
      .. os_concat
      .. "texlua insert-pdf-tags.lua " .. name .. ".log " .. name .. ".tags"
  end
  return ""
end
