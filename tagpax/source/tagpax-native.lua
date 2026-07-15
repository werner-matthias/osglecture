-- tagpax-native.lua -- TeX emission for native linear document import
local ir_reader = require("tagpax-ir")
local M = {}
local catlatex = luatexbase.registernumber("catcodetable@latex")
local function esc(s)
  s=tostring(s or "")
  return (s:gsub("([{}%%#\\])", "\\%1"))
end
function M.emit_page_imports(pdf, irfile)
  local ir=ir_reader.read(irfile)
  local pages=assert(ir.source and tonumber(ir.source.pages), "IR has no source page count")
  for page=1,pages do
    local sid="p"..page
    tex.sprint(catlatex, string.format("\\TagPaxImportOnePage{%s}{%d}{%s}",esc(pdf),page,sid))
  end
end
return M
