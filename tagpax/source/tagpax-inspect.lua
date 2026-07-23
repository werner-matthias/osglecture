--[[
  Package: tagpax
  Date:
  2026-07-23
  Version:
  v0.8.5-dev
  Description:
  inspection API over the extractor and IR
]]

local ir_module = require("tagpax-ir")
local validator = require("tagpax-validate")
local M = {}

function M.from_pdf(filename, output)
  -- Parse the artifact just written: this validates exactly what later builds
  -- consume, rather than a privileged in-memory extractor representation.
  local facade = require("tagpax")
  output = facade.extract(filename, output)
  local ir = ir_module.read(output)
  local ok, errors = validator.validate(ir)
  if not ok then error("invalid tagpax IR: " .. table.concat(errors, "; ")) end
  return ir, output
end

function M.from_file(filename)
  -- Public inspection never exposes malformed IR to transformations.
  local ir = ir_module.read(filename)
  local ok, errors = validator.validate(ir)
  if not ok then error("invalid tagpax IR: " .. table.concat(errors, "; ")) end
  return ir
end

function M.summary(ir)
  -- Stable, shallow diagnostics; deliberately not a second IR schema.
  return {
    pages = ir.source and tonumber(ir.source.pages) or 0,
    nodes = ir_module.count_nodes(ir),
    roots = #ir.roots,
    kids = #ir.kids,
    headings = #ir.headings,
  }
end

return M
