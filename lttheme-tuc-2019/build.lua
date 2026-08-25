bundle = "osglecture"
module = "lttheme-tuc-2019"
maindir = ".."

-- The external TUC theme is implemented on top of the core theme engine.
-- lttheme itself now requires osgstyler, so it must be listed here too
-- (checkdeps/typesetdeps are not transitive).
checkdeps = { "../lttheme", "../osgstyler" }
typesetdeps = { "../lttheme", "../osgstyler" }

-- Make the logos selected automatically by the theme available in l3build's
-- isolated test directory.  A developer installation may provide these via a
-- local TEXMF tree, but a clean CI installation deliberately does not.
supportdir = maindir .. "/images/logos"
checksuppfiles = {
    "osg.png",
    "tuc_white.pdf",
    "tuckhs_white.pdf",
    "tuckhseng_white.pdf",
}


sourcefiles = {
    "example-tuc-2019.tex",
    "lttheme-tuc-2019.dtx"
}

unpackfiles = {
    "lttheme-tuc-2019.dtx"
}

typesetfiles = {
    "example-tuc-2019.tex",
    "lttheme-tuc-2019.dtx"
}


-- ltx-talk removes a temporary final page on the second LaTeX run.
checkruns = 2

installfiles = {
    "ltxtalk-theme-tuc-2019.sty",
}

dofile("../build.lua")
