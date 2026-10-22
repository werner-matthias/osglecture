bundle = "osglecture"
module = "osglecture"

maindir=".."

checkdeps = { "../osglecture-modes", "../tagpax", "../langselect", "../tagbridge" }

textfiles = {
  "README-cls.md",
  "THIRD_PARTY-osglecture-cls.md",
}

installfiles = {
  "osglecture.cls",
  "osglecture-config.sty",
  "osglecture-project.sty",
  "osglecture-preamble-*.tex",
  "osglecture-metadata.sty",
  "osglecture-references.sty",
  "osglecture-continuation.sty",
  "osglecture-integration.sty",
  "osglecture-structure.sty",
  "osglecture-adapters.sty",
  "osglecture-adapter-*.def",
  "osglecture-profiles.sty",
  "osglecture-profile-*.def",
  "osglecture-presitemize.sty",
  "osglecture-twocolumns.sty",
  "osglecture-annotations.sty",
  "osglecture-presenter.sty",
  "osglecture-presenter.lua",
  "osglecture-series-index.lua",
  "osglecture-series.sty",
  "osglecture-bibliography.sty",
  "osglecture-toml.lua",
  "osglecture-manifest.lua",
  "osglecture-manifest-cli.lua",
  "osglecture-integration.lua",
}
sourcefiles = {
  "osglecture.dtx",
  "osglecture-adapters.dtx",
  "osglecture-profiles.dtx",
  "osglecture-preamble-*.tex",
  "osglecture-series-index.lua",
  "osglecture-toml.lua",
  "osglecture-manifest.lua",
  "osglecture-manifest-cli.lua",
  "osglecture-integration.lua",
  "osglecture-presenter.lua",
}
-- Only osglecture.dtx is self-extracting. It also unpacks
-- the adapter.dtx and profile dtx.
unpackfiles = { "osglecture.dtx" }

typesetfiles = {
  "osglecture.dtx"
}
checksuppfiles = {
  "reference-source.osgref.aux.in",
}

-- Untagged PDF fixture for the osglecture-integration fallback path.
-- Copying plain support .tex files seems not to be 
-- reliable, thus write directly to testdir.
function checkinit_hook()
  -- Reference fixtures are kept as *.osgref.aux.in: CTAN rejects .aux files
  -- as leftovers of a build.
  for _, name in ipairs(filelist(testdir, "*.osgref.aux.in")) do
    local input = assert(io.open(testdir .. "/" .. name, "rb"))
    local output = assert(io.open(testdir .. "/" .. name:gsub("%.in$", ""), "wb"))
    output:write(input:read("a"))
    input:close()
    output:close()
  end

  local source = assert(io.open(testdir .. "/untagged-unit.tex", "w"))
  source:write(table.concat({
    "\\documentclass{article}",
    "\\usepackage{hyperref}",
    "\\begin{document}",
    "\\section*{Untagged unit}",
    "An ordinary, untagged paragraph.\\label{untagged-label}",
    "\\end{document}",
  }, "\n"))
  source:close()
  return runcmd(
    "lualatex -interaction=nonstopmode -halt-on-error untagged-unit.tex",
    testdir, { "TEXINPUTS", "LUAINPUTS" })
end

-- Bibliography tests run biber between LaTeX runs; see config-bibliography.lua.
checkconfigs = { "build", "config-bibliography" }

dofile("../build.lua")
