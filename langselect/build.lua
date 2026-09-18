bundle = "osglecture"
module = "langselect"

maindir="../"

textfiles = {
    "README-langselect.md"
}

installfiles = { "langselect.sty" }

dofile("../build.lua")

-- bcp47-autoselect exercises Babel's own autoload.bcp47 tag resolution
-- (not langselect's ini-derived mapping) -- older Babel releases resolve an
-- unmapped BCP-47 tag to a synthetic "bcp47-<code>" placeholder language
-- instead of the expected name, a limitation of that Babel release, not of
-- langselect. Isolated into its own "bcp47" config (see bcp47.lua) so that
-- doesn't fail the always-compatible default run.
excludetests = { "bcp47-autoselect" }
