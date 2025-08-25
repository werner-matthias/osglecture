bundle   = "osglecture"
ctanpkg  = bundle

modules = {
  { name = "osglecture" },
  { name = "langselect" },
  { name = "osgterminal" },
  { name = "osgbib" },
  { name = "osgcombine" },
  { name = "osglisting" },
}

textfiles = { "README.md", "CHANGES.md", "LICENSE" }

-- Script-Auslieferung (landet in TEXMF/scripts/osglecture/)
scriptfiles = {
  "scripts/ollm",
  "scripts/ollm.bat",   -- optional; für Windows bequem
}

-- Globale Defaults (pro Modul überschreibbar)
sourcefiles  = { "*.dtx", "*.ins", "doc/*.tex" }
typesetfiles = { "doc/*-doc.tex" }

-- Tests: Standard-Lauf (Unit je Modul) + Integrations-Lauf (siehe config-integ.lua)
-- checkconfigs = { "build", "config-integ" }
checkconfigs = { "build"}

-- Integration hängt von allen Modulen ab (sorgt für Entpacken/Build vor dem Test)
checkdeps = {
  --"./osglecture",
  "./multibabel",
  --"./osgterminal",
  --"./osgbib",
  --"./osgcombine",
  --"./osglisting",
}

unpackfiles = {
   "*.dtx"
}

-- Engines global (Integration nutzt lualatex + pdflatex; Unit-Tests pro Modul können enger sein)
stdengine    = "lualatex"
checkengines = { "luatex" }

-- Doku
typesetexe = "lualatex"
maxruns    = 3

-- Tagging (optional)
tagfiles = {
  "osglecture/osglecture.dtx",
  "multibabel/multibabel.dtx",
  "osgterminal/osgterminal.dtx",
  "osgbib/osgbib.dtx",
  "osgcombine/osgcombine.dtx",
  "osglisting/osglisting.dtx",
  "scripts/ollm",
}
tagfmt = "v%Y-%m-%d"
