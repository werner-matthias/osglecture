bundle = "osglecture"
module = "lttheme"
maindir = ".."

textfiles = {
    "README-lttheme.md"
}

-- ltx-talk removes a temporary final page on the second LaTeX run.
-- PDF-based visual tests must therefore compare the settled output.
checkruns = 2

checkdeps = { "../osgstyler" }

installfiles = {
    "ltxtalk-theme.sty",
    "ltxtalk-theme-minimal.sty",
    "ltxtalk-theme-magpie.sty",
    "ltxtalk-theme-hawk.sty",
    "ltxtalk-theme-sparrow.sty",
    "ltxtalk-theme-bluebird.sty",
    "ltxtalk-theme-goose.sty",
    "ltxtalk-theme-anchovy.sty",
    "ltxtalk-theme-carp.sty",
}

dofile("../build.lua")
