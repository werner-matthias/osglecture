-- tagpax-inspect.lua -- stable inspection API over the extractor and IR
local ir_module = require("tagpax-ir")
local validator = require("tagpax-validate")
local M = {}

function M.from_pdf(filename, output)
  local facade = require("tagpax")
  output = facade.extract(filename, output)
  local ir = ir_module.read(output)
  local ok, errors = validator.validate(ir)
  if not ok then error("invalid tagpax IR: " .. table.concat(errors, "; ")) end
  return ir, output
end

function M.from_file(filename)
  local ir = ir_module.read(filename)
  local ok, errors = validator.validate(ir)
  if not ok then error("invalid tagpax IR: " .. table.concat(errors, "; ")) end
  return ir
end

function M.summary(ir)
  return {
    pages = ir.source and tonumber(ir.source.pages) or 0,
    nodes = ir_module.count_nodes(ir),
    roots = #ir.roots,
    kids = #ir.kids,
    headings = #ir.headings,
  }
end

return M
