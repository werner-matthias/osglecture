bundle = "osglecture"
module = "lttheme"
maindir = ".."

-- ltx-talk removes a temporary final page on the second LaTeX run.
-- PDF-based visual tests must therefore compare the settled output.
checkruns = 2

installfiles = {
    "ltxtalk-theme-core.sty",
    "ltxtalk-theme-academic.sty",
    "ltxtalk-theme-minimal.sty",
    "ltxtalk-theme-modern.sty",
    "ltxtalk-theme-corporate.sty",
}

dofile("../build.lua")
