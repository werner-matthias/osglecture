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

  return runcmd(command, testdir, { "TEXINPUTS", "LUAINPUTS" })
end

dofile("../build.lua")
