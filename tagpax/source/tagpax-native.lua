-- tagpax-native.lua -- TeX emission for native linear document import
local ir_reader = require("tagpax-ir")
local M = {}
local catlatex = luatexbase.registernumber("catcodetable@latex")
local function esc(s)
  s=tostring(s or "")
  return (s:gsub("([{}%%#\\])", "\\%1"))
end
function M.emit_page_imports(pdf, irfile, prefix)
  local ir=ir_reader.read(irfile)
  local pages=assert(ir.source and tonumber(ir.source.pages), "IR has no source page count")
  for page=1,pages do
    local sid="p"..page
    tex.sprint(catlatex, string.format(
      "\\TagPaxImportOnePage{%s}{%d}{%s}{%s}{%s}",
      esc(pdf),page,sid,esc(irfile),esc(prefix or "0")
    ))
  end
end

function M.emit_page_navigation(irfile, page, prefix)
  local ir = ir_reader.read(irfile)
  local page_destination = string.format("tagpax.%s.page.%d", prefix, page)
  tex.sprint(catlatex, "\\TagPaxPageDestination{" .. esc(page_destination) .. "}{fit}")
  for _, heading in ipairs(ir.headings or {}) do
    if tonumber(heading.page) == tonumber(page) and heading.text and heading.text ~= "" then
      tex.sprint(catlatex, string.format(
        "\\TagPaxNavigationHeading{%s}{%s}{%s}",
        esc(heading.role), esc(heading.text), esc(page_destination)
      ))
    end
  end
end
return M
