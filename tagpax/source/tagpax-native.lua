--[[
  Package: tagpax
  Date:
  2026-07-23
  Version:
  v0.8.5-dev
  Description:
  TeX emission for native linear document import
]]
--<*pkg>
local ir_reader = require("tagpax-ir")
local M = {}
local catlatex = luatexbase.registernumber("catcodetable@latex")

-- \ldeen{Der Orchestrierungsadapter erzeugt \TeX-Operationen, inspiziert aber
-- weder Quellobjekte noch erzeugt er semantische Struktur.}{The orchestration
-- adapter emits \TeX\ operations but neither inspects source objects nor
-- constructs semantic structure.}
--
-- \ldeen*{Escaping stammt aus @1 und wird dort zentral gepflegt.}{Escaping
-- lives in @1 and is maintained there centrally.}{\code{tagpax-ir.lua}}
local tex_escape = ir_reader.tex_escape

function M.emit_page_imports(pdf, irfile, prefix)
  -- \ldeen{Unterstützt wird der lineare Vollimport: Seiten-Forms entstehen in
  -- Quellreihenfolge nach der Reservierung der Struktur-Slots.}{The supported
  -- profile is linear full import: page Forms are created in source order after
  -- structure slots are reserved.}
  local ir=ir_reader.read(irfile)
  local pages=assert(ir.source and tonumber(ir.source.pages), "IR has no source page count")
  for page=1,pages do
    local sid=tostring(prefix or "0")..".p"..page
    tex.sprint(catlatex, string.format(
      "\\TagPaxImportOnePage{%s}{%d}{%s}{%s}{%s}",
      tex_escape(pdf),page,sid,tex_escape(irfile),tex_escape(prefix or "0")
    ))
  end
end

function M.emit_page_navigation(irfile, page, prefix)
  -- \ldeen{Inhaltsverzeichnis und Lesezeichen nutzen stabile Seitenziele;
  -- präzise Quellziele erzeugt der Seitenschreiber separat.}{Contents and
  -- bookmarks use stable page destinations; the page writer emits precise
  -- source destinations separately.}
  local ir = ir_reader.read(irfile)
  local page_destination = string.format("tagpax.%s.page.%d", prefix, page)
  tex.sprint(catlatex, "\\TagPaxPageDestination{" .. tex_escape(page_destination) .. "}{fit}")
  for _, heading in ipairs(ir.headings or {}) do
    if tonumber(heading.page) == tonumber(page) and heading.text and heading.text ~= "" then
      tex.sprint(catlatex, string.format(
        "\\TagPaxNavigationHeading{%s}{%s}{%s}",
        tex_escape(heading.role), tex_escape(heading.text), tex_escape(page_destination)
      ))
    end
  end
end
return M
--</pkg>
