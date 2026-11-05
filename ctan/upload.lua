--[[
  CTAN submission data for the osglecture bundle, read by the root build.lua
  and used by l3build's upload target:

    l3build ctan                                  -- build osglecture-ctan.zip
    l3build upload --email=<address> --dry-run    -- let CTAN validate only
    l3build upload --email=<address>              -- validate, then submit

  This file replaces filling in the web form by hand.  The fields come from
  the package register (tools/packages.lua) and the texts in
  ctan/<package>/, composed by tools/ctan-metadata.lua; validate them with
  "texlua tools/make-ctan-metadata.lua --check".  The version of the bundle
  is its release date, maintained by "l3build tag" in README.md; an
  unreleased bundle has none, and l3build then asks for one.  A version
  given on the command line ("l3build upload 2026-11-02") wins.
--]]

local metadata = dofile("tools/ctan-metadata.lua")

-- In a module directory `module` names the package; in the bundle root it
-- is unset and the bundle is submitted.
uploadconfig = metadata.uploadconfig(
  type(module) == "string" and module ~= "" and module or bundle
)
