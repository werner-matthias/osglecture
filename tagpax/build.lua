bundle = "osglecture"
module = "tagpax"
maindir = ".."

sourcefiledir = "source"

sourcefiles = {
  "*.dtx",
  "*.ins",
  "*.lua"
}

unpackfiles = { "*.ins" }

installfiles = {
  "*.sty",
  "*.lua"
}

typesetfiles = { "tagpax.dtx" }

textfiles = {
  "README.md",
  "CHANGELOG.md",
  "doc/*.md"
}

docfiles = {
  "README.md",
  "CHANGELOG.md",
  "doc/*.md"
}

checkruns = 1
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

  return runcmd(command, testdir, { "TEXINPUTS", "LUAINPUTS" })
end

dofile("../build.lua")
