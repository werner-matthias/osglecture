bundle = "osglecture"
module = "osgdoc"

maindir=".."

textfiles = {
    "README-osgdoc.md"
}

installfiles = {
    "osgdoc.cls",
    "osgdoc.sty"
}

-- osgdoc.cls exists to patch cnltx-doc; testing it necessarily loads
-- cnltx, but this stays a coarse compile-succeeds/fails smoke test on
-- purpose, not a .tlg content comparison. A content diff would freeze in
-- part cnltx's own typeset output, which osgdoc does not control and
-- could shift on a cnltx update unrelated to any osgdoc change. The
-- Lua-only logic behind osgdoc.sty (fileinfo.*, autodoc.*) is covered by
-- the normal .lvt tests instead, which load only osgdoc.sty under plain
-- article and never touch cnltx.
function checkinit_hook()
  local source = assert(io.open(testdir .. "/class-smoke.tex", "w"))
  source:write(table.concat({
    "\\documentclass{osgdoc}",
    "\\begin{document}",
    "Class smoke test.",
    "\\end{document}",
  }, "\n"))
  source:close()
  return runcmd(
    "lualatex -interaction=nonstopmode -halt-on-error class-smoke.tex",
    testdir, { "TEXINPUTS", "LUAINPUTS" })
end

dofile("../build.lua")
