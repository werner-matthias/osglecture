bundle = "osglecture"
module = "lttheme-tuc-2019"
maindir = ".."

-- The external TUC theme is implemented on top of the core theme engine.
checkdeps = { "../lttheme" }
typesetdeps = { "../lttheme" }


sourcefiles = {
    "example-tuc-2019.tex",
    "lttheme-tuc-2019.dtx"
}

unpackfiles = {
    "lttheme-tuc-2019.dtx"
}

typesetfiles = {
    "example-tuc-2019.tex"
}


-- ltx-talk removes a temporary final page on the second LaTeX run.
checkruns = 2

installfiles = {
    "ltxtalk-theme-tuc-2019.sty",
}

dofile("../build.lua")
