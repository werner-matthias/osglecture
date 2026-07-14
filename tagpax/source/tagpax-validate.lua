-- tagpax-validate.lua -- semantic IR validation
local M = {}

function M.validate(ir)
  local errors = {}
  if not ir.header or tonumber(ir.header.version) ~= 1 then errors[#errors + 1] = "unsupported or missing IR version" end
  if not ir.source then errors[#errors + 1] = "missing source record" end
  for _, root in ipairs(ir.roots) do
    if not ir.nodes[root.node] then errors[#errors + 1] = "root references missing node " .. tostring(root.node) end
  end
  for _, kid in ipairs(ir.kids) do
    if not ir.nodes[kid.parent] then errors[#errors + 1] = "kid has missing parent " .. tostring(kid.parent) end
    if kid.kind == "node" and not ir.nodes[kid.ref] then errors[#errors + 1] = "kid references missing node " .. tostring(kid.ref) end
    if kid.kind == "mcr" and tonumber(kid.mcid) == nil then errors[#errors + 1] = "MCR has invalid MCID" end
  end
  for _, heading in ipairs(ir.headings) do
    local node = ir.nodes[heading.node]
    if not node then errors[#errors + 1] = "heading references missing node " .. tostring(heading.node)
    elseif node.role ~= heading.role then errors[#errors + 1] = "heading role mismatch at " .. heading.node end
  end
  return #errors == 0, errors
end

return M
