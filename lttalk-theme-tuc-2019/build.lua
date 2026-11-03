bundle = "osglecture"
module = "lttalk-theme-tuc-2019"
maindir = ".."

-- The external TUC theme is implemented on top of the core theme engine.
-- lttalk-themeengine itself requires osgstyler, so it must be listed here
-- too (checkdeps/typesetdeps are not transitive).  The teaching-lecture-
-- number test loads the osglecture class directly, which pulls in
-- osglecture's own checkdeps (osgmodes, tagpax, langselect, tagbridge);
-- those must be listed here too for the same non-transitive reason.
checkdeps = {
    "../lttalk-themeengine", "../osgstyler",
    "../osglecture", "../osgmodes", "../tagpax", "../langselect", "../tagbridge",
}
typesetdeps = { "../lttalk-themeengine", "../osgstyler" }

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
    "lttalk-theme-tuc-2019.dtx"
}

unpackfiles = {
    "lttalk-theme-tuc-2019.dtx"
}

typesetfiles = {
    "example-tuc-2019.tex",
    "lttalk-theme-tuc-2019.dtx"
}


-- ltx-talk removes a temporary final page on the second LaTeX run.
checkruns = 2

installfiles = {
    "lttalk-theme-tuc-2019.sty",
}

dofile("../build.lua")
