-- build.lua -- l3build configuration for tagpax
module = "tagpax"
ctanpkg = "tagpax"

sourcefiledir = "source"
sourcefiles = { "*.dtx", "*.ins", "*.lua", "tagpax-de.tex", "tagpax-en.tex" }
unpackfiles = { "*.ins" }
installfiles = { "*.sty", "*.lua" }

-- Documentation is generated from the documented source. Keeping this
-- explicit makes `l3build doc` and `l3build ctan` reproducible.
typesetfiles = { "tagpax-de.tex", "tagpax-en.tex" }
supportdir = "support"
typesetsuppfiles = { "osgdoc.cls", "osgdoc.sty", "langselect.sty" }
typesetexe = "lualatex"
typesetruns = 2
typesetopts = "-interaction=nonstopmode -halt-on-error"

textfiles = {
  "README.md",
  "CHANGELOG.md",
  "doc/*.md",
  "support/*.md",
  "roundtrip.lua"
}

docfiles = {
  "README.md",
  "CHANGELOG.md",
  "doc/*.md"
}

checkengines = { "luatex" }
stdengine = "luatex"
checkruns = 1
excludetests = { "roundtrip" }
checksuppfiles = { "*.tagpax", "*.tex" }

-- The source PDF used by the extraction test is generated after l3build has
-- copied test support files into the isolated test directory.
function checkinit_hook()
  local command = table.concat({
    "lualatex",
    "-interaction=nonstopmode",
    "-halt-on-error",
    "subdocument.tex"
  }, " ")

  local errorlevel = runcmd(command, testdir, { "TEXINPUTS", "LUAINPUTS" })
  if errorlevel ~= 0 then
    return errorlevel
  end
  return runcmd(command, testdir, { "TEXINPUTS", "LUAINPUTS" })
end
