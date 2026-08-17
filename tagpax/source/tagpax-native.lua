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

-- This is an orchestration adapter. It emits TeX operations but neither
-- inspects source PDF objects nor constructs semantic structure.
--
-- \ldeen*{Escaping stammt aus @1 und wird dort zentral gepflegt.}{Escaping
-- lives in @1 and is maintained there centrally.}{\code{tagpax-ir.lua}}
local tex_escape = ir_reader.tex_escape

function M.emit_page_imports(pdf, irfile, prefix)
  -- Linear full-document import is the supported profile; page Forms are
  -- created in source order after structure slots have been reserved.
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
  -- Generated TOC/bookmark entries use a stable page-level destination.
  -- Precise source destinations are emitted independently by the page writer.
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
