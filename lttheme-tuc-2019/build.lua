bundle = "osglecture"
module = "lttheme-tuc-2019"
maindir = ".."

-- The external TUC theme is implemented on top of the core theme engine.
checkdeps = { "../lttheme" }
typesetdeps = { "../lttheme" }

-- ltx-talk removes a temporary final page on the second LaTeX run.
checkruns = 2

installfiles = {
    "ltxtalk-theme-tuc-2019.sty",
}

dofile("../build.lua")
