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

  -- Untagged counterpart of subdocument.tex, used to test the fallback
  -- decision in osglecture-integration (tagpax.is_tagged), which must
  -- distinguish a tagged from an untagged source PDF without invoking
  -- tagpax's own strict extraction. Written directly into testdir instead
  -- of living as its own testfiles/*.tex source, because plain support
  -- .tex files placed next to subdocument.tex are not reliably copied into
  -- testdir by the surrounding checksuppfiles machinery.
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
