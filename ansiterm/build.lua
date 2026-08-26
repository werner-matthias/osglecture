bundle = "osglecture"
module = "ansiterm"

maindir = "../"

textfiles = { "README-ansiterm.md" }
installfiles = { "ansiterm.sty", "ansiterm.lua" }

dofile("../build.lua")

-- The regression test covers the engine-independent display environment.
-- Live execution is exercised separately with LuaLaTeX and shell escape.
checkengines = { "pdftex" }
