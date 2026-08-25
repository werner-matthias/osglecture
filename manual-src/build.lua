bundle = "osglecture"
module = "osglecture-manual"
maindir = ".."

sourcefiles = {
  "osglecture-manual-en.tex",
  "osglecture-manual-de.tex",
  "osglecture-manual.tex",
  "polymorphy-*.tex",
  "styler-*.tex",
}

local manual_example_files = {
  "polymorphy-slides-en.tex",
  "polymorphy-slides-de.tex",
  "polymorphy-script-de.tex",
  "styler-screen.tex",
  "styler-print.tex",
}

typesetfiles = {
  "osglecture-manual-en.tex",
  "osglecture-manual-de.tex",
}

docfiles = {
  "osglecture-manual-en.pdf",
  "osglecture-manual-de.pdf",
}

installfiles = { }

typesetdeps = {
  "../osglecture-modes",
  "../osglecture",
  "../osgstyler",
}

dofile("../build.lua")

-- The manual includes PDFs generated from the example sources above.  They are
-- build prerequisites rather than independently selected documentation files:
-- a targeted build such as
--
--   l3build doc osglecture-manual-de
--
-- must therefore typeset them before it typesets the selected manual.  The
-- l3build demo hook runs after all sources have been copied to typesetdir and
-- before the main documentation loop starts.
function typeset_demo_tasks()
  local command = typesetexe .. " " .. typesetopts
  for _, file in ipairs(manual_example_files) do
    local errorlevel = typeset(file, typesetdir, command)
    if errorlevel ~= 0 then
      return errorlevel
    end
  end
  return 0
end
