module = "tagpax"
ctanpkg = "tagpax"

sourcefiledir = "source"
sourcefiles = { "*.dtx", "*.ins", "*.lua" }
unpackfiles = { "*.ins" }
installfiles = { "*.sty", "*.lua" }
typesetfiles = { "tagpax.dtx" }
textfiles = {
  "README.md",
  "CHANGELOG.md",
  "doc/*.md",
  "structure.lua", "verapdf.lua",
  "build-support/*.lua",
}

checkengines = { "luatex" }
stdengine = "luatex"
checkruns = 1
checksuppfiles = { "testfiles/support/*" }

-- The standard test run deliberately has no dependency on external PDF tools.
-- Optional checks are enabled with:
--   l3build check -c structure
--   l3build check -c verapdf
function checkinit_hook()
  local cmd = "lualatex -interaction=nonstopmode -halt-on-error subdocument.tex"
  return runcmd(cmd, testdir, { "TEXINPUTS", "LUAINPUTS" })
end
