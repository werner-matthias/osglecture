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

-- \ldeen{Bildet die Gesamtzahl aus \code{layout} (@1) auf ein Zeilen/Spalten-Raster
-- ab. @2 nimmt nur bei @3 einen von @4 einen Wert an; er verlangt keinen
-- Notizinhalt, sondern reserviert lediglich liniierten Leerraum -- siehe die
-- Design-Notiz zu zurückgestelltem Notizinhalt.}{Maps the total count from
-- \code{layout} (@1) to a rows/columns grid. @2 only ever takes the value
-- @4 among the @3 modes; it requires no note content, only reserving ruled
-- blank space -- see the design note on deferred note content.}
-- {\code{layout}}{\code{mode}}{\code{ruled}/\code{notes}}{\code{ruled}}
local GRID_BY_COUNT = {
  [2] = { rows = 2, cols = 1 },
  [3] = { rows = 3, cols = 1 },
  [4] = { rows = 2, cols = 2 },
  [6] = { rows = 3, cols = 2 },
}

local function parse_layout(layout)
  if not layout or layout == "" then return nil end
  local base, suffix = layout:match("^%s*(.-)%s*|%s*(%a+)%s*$")
  base = base or layout
  local count = tonumber(base:match("^%s*(%d+)%s+on%s+1%s*$"))
  if not count then
    error("tagpax: unrecognized layout '" .. layout ..
      "'; expected e.g. '4 on 1' or '2 on 1|ruled'")
  end
  local template = GRID_BY_COUNT[count]
  if not template then
    error("tagpax: unsupported layout count " .. count .. "; supported: 2, 3, 4, 6")
  end
  local grid = { rows = template.rows, cols = template.cols }
  if suffix then
    if count ~= 2 and count ~= 3 then
      error("tagpax: layout modifier '" .. suffix ..
        "' is only supported for '2 on 1' and '3 on 1'")
    end
    if suffix == "ruled" then
      grid.mode = "ruled"
    elseif suffix == "notes" then
      error("tagpax: layout modifier 'notes' is not implemented yet " ..
        "(see development-docs/tagpax/DESIGN.md); use 'ruled' instead.")
    else
      error("tagpax: unknown layout modifier '" .. suffix .. "'")
    end
  end
  return grid
end

function M.emit_page_imports(pdf, irfile, prefix, layout)
  -- \ldeen{Unterstützt wird der lineare Vollimport: Seiten-Forms entstehen in
  -- Quellreihenfolge nach der Reservierung der Struktur-Slots. @1 gruppiert
  -- diese Reihenfolge zusätzlich zu Blättern fester Größe, ändert aber nicht
  -- die Reihenfolge selbst.}{The supported profile is linear full import:
  -- page Forms are created in source order after structure slots are
  -- reserved. @1 additionally groups that order into fixed-size sheets, but
  -- does not change the order itself.}{\code{layout}}
  local ir=ir_reader.read(irfile)
  local pages=assert(ir.source and tonumber(ir.source.pages), "IR has no source page count")
  local grid = parse_layout(layout)
  if not grid then
    for page=1,pages do
      local sid=tostring(prefix or "0")..".p"..page
      tex.sprint(catlatex, string.format(
        "\\TagPaxImportOnePage{%s}{%d}{%s}{%s}{%s}",
        tex_escape(pdf),page,sid,tex_escape(irfile),tex_escape(prefix or "0")
      ))
    end
    return
  end
  local per_page = grid.rows * grid.cols
  local cellmacro = grid.mode == "ruled"
    and "\\TagPaxImportGridPageRuled" or "\\TagPaxImportGridPage"
  for page=1,pages do
    local sid=tostring(prefix or "0")..".p"..page
    if (page - 1) % per_page == 0 then
      tex.sprint(catlatex, string.format(
        "\\TagPaxGridPageBegin{%d}{%d}", grid.rows, grid.cols))
    end
    tex.sprint(catlatex, string.format(
      "%s{%s}{%d}{%s}{%s}{%s}",
      cellmacro, tex_escape(pdf), page, sid, tex_escape(irfile), tex_escape(prefix or "0")
    ))
    if page % per_page == 0 or page == pages then
      tex.sprint(catlatex, "\\TagPaxGridPageEnd")
    end
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
