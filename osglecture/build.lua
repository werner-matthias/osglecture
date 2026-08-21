bundle = "osglecture"
module = "osglecture"

maindir=".."

checkdeps = { "../osglecture-modes", "../tagpax" }

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
  "osglecture-osgbeamer.code.tex",
  "osglecture-presitemize.sty",
  "osglecture-twocolumns.sty",
  "osglecture-series-index.lua",
  "osglecture-series.sty",
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
}
-- Only osglecture.dtx is self-extracting. It also unpacks
-- the adapter.dtx and profile dtx.
unpackfiles = { "osglecture.dtx" }

typesetfiles = {
  "osglecture.dtx"
}
checksuppfiles = {
  "reference-source.osgref.aux",
}

-- Untagged PDF fixture for the osglecture-integration fallback path.
-- Copying plain support .tex files seems not to be 
-- reliable, thus write directly to testdir.
function checkinit_hook()
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

dofile("../build.lua")
