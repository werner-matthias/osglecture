bundle = "osglecture"
module = "ansiterm"

maindir = "../"

textfiles = { "README-ansiterm.md" }
installfiles = { "ansiterm.sty", "ansiterm.lua" }
-- ansiterm.lua isn't docstrip-extracted, so it needs to be named here too:
-- otherwise it never reaches the check sandbox and \directlua's own
-- require("ansiterm") silently fails there -- harmless for the tests that
-- never call it, fatal for exec-tagging, which does.
sourcefiles = { "ansiterm.dtx", "ansiterm.lua" }

dofile("../build.lua")

-- Both environments are checked under LuaTeX, since the package needs it
-- unconditionally for ansitermexec, and the tagging test's structure-tree
-- extraction (via show-pdf-tags) does not correctly attribute text to its
-- structure element under pdfTeX -- the compiled PDF itself is correct,
-- only the extraction used for this comparison is affected.
checkengines = { "luatex" }

-- --shell-escape is only a capability, not an invitation: none of the
-- other tests call out to a shell, and exec-tagging itself additionally
-- requires ANSITERM_RUN_EXEC_TESTS=1 in the environment before it will
-- actually run a command (see that file for why). It stays excluded from
-- plain "l3build check" either way -- run it by name to opt in.
checkopts = (checkopts or "-interaction=nonstopmode") .. " --shell-escape"
excludetests = { "exec-tagging" }
