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
-- Only osglecture.dtx carries a self-installing driver; the adapter and
-- profile dtx are pure docstrip sources pulled in via \from{...} from
-- osglecture.dtx's own \generate block, so they must not be unpacked
-- (run through the engine) on their own.
unpackfiles = { "osglecture.dtx" }
typesetfiles = { }
checksuppfiles = {
  "reference-source.osgref.aux",
}

-- Untagged PDF fixture for the osglecture-integration fallback path
-- (integration-untagged.lvt): a plain, ordinary article with no
-- \DocumentMetadata, so tagpax.is_tagged reports it as untagged. Written
-- directly into testdir instead of living as its own testfiles/*.tex
-- source, matching the approach in ../tagpax/build.lua, because plain
-- support .tex files are not reliably copied into testdir by the
-- surrounding checksuppfiles machinery.
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
