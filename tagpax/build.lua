bundle = "osglecture"
module = "tagpax"
maindir = ".."

sourcefiledir = "source"

sourcefiles = {
  "*.dtx",
  "*.ins",
  "*.lua"
}

unpackfiles = { "*.dtx" }

installfiles = {
  "*.sty",
  "*.lua"
}

typesetfiles = { "tagpax.dtx" }

textfiles = {
  "README-tagpax.md",
}

docfiles = {
  "README-tagpax.md",
  "*.tikz"
}

checkruns = 1
checkconfigs = { "build", "roundtrip" }
excludetests = { "roundtrip" }
checksuppfiles = { "*.tagpax", "*.tex" }

function checkinit_hook()
  local command = table.concat({
    "lualatex",
    "-interaction=nonstopmode",
    "-halt-on-error",
    "subdocument.tex"
  }, " ")

  local errorlevel =
    runcmd(command, testdir, { "TEXINPUTS", "LUAINPUTS" })

  if errorlevel ~= 0 then
    return errorlevel
  end

  errorlevel = runcmd(command, testdir, { "TEXINPUTS", "LUAINPUTS" })
  if errorlevel ~= 0 then
    return errorlevel
  end

  -- Deutsch: Ungetaggte Testquelle für die Fallback-Entscheidung von
  -- tagpax.is_tagged. Sie entsteht direkt im Testverzeichnis, da die
  -- checksuppfiles-Verarbeitung benachbarte Hilfsdateien nicht sicher kopiert.
  -- English: Untagged test source for the tagpax.is_tagged fallback decision.
  -- It is created in the test directory because checksuppfiles does not
  -- reliably copy adjacent support files.
  local source = assert(io.open(testdir .. "/untagged-subdocument.tex", "w"))
  source:write(table.concat({
    "\\documentclass{article}",
    "\\usepackage{hyperref}",
    "\\begin{document}",
    "An ordinary, untagged paragraph.",
    "\\end{document}",
  }, "\n"))
  source:close()

  return runcmd(
    "lualatex -interaction=nonstopmode -halt-on-error untagged-subdocument.tex",
    testdir, { "TEXINPUTS", "LUAINPUTS" })
end

dofile("../build.lua")
