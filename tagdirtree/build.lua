bundle = "osglecture"
module = "tagdirtree"

maindir="../"

textfiles = {
    "README-tagdirtree.md"
}

installfiles = { "tagdirtree.sty" }

dofile("../build.lua")

-- Avoid l3build's io.popen() extraction path, which returns no output on the
-- GitHub macOS runner. A regular test task extracts the same XML and places
-- it in a minimal test-log section before l3build normalizes the raw log.
local tagging_tests = {
  ["structure"] = true,
}

function runtest_tasks(name, run)
  if tagging_tests[name] then
    return "show-pdf-tags --xml " .. name .. ".pdf > " .. name .. ".tags"
      .. os_concat
      .. "texlua insert-pdf-tags.lua " .. name .. ".log " .. name .. ".tags"
  end
  return ""
end
