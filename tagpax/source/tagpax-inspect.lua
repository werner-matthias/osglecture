--[[
  Package: tagpax
  Date:
  2026-07-23
  Version:
  v0.8.5-dev
  Description:
  inspection API over the extractor and IR
]]
--<*pkg>
local ir_module = require("tagpax-ir")
local validator = require("tagpax-validate")
local M = {}

function M.from_pdf(filename, output)
  -- Parse the artifact just written: this validates exactly what later builds
  -- consume, rather than a privileged in-memory extractor representation.
  --
  -- \ldeen*{Bewusst lazy: @1 verlangt beim Laden @2. Wer nur @3 nutzt, soll
  -- diese Abhängigkeit nicht erzwungen bekommen.}{Deliberately lazy: @1
  -- asserts @2 at load time. Callers who only use @3 should not be forced
  -- to pay for that dependency.}{\code{tagpax.lua}}{\code{pdfe}}{\code{from\_file}}
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
--</pkg>