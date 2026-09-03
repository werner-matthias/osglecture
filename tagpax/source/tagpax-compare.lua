--[[
  Package: tagpax
  Date:
  2026-07-23
  Version:
  v0.8.5-dev
  Description:
  semantic IR comparison for roundtrip tests
]]

local ir_reader = require("tagpax-ir")
local M = {}
local default_role_map = {
  section = "H1", subsection = "H2", subsubsection = "H3",
  ["text-unit"] = "Part", text = "P", item = "LI",
}

-- \ldeen{Der Roundtrip-Vergleich normalisiert konventionelle Rollennamen und
-- vergleicht Semantik statt PDF-Objekte.}{The roundtrip comparison normalizes
-- conventional role names and compares semantics rather than PDF objects.}
local function role_of(role, options)
  local map = options and options.role_map or default_role_map
  return map[role] or role
end

-- \ldeen*{Sortierung und Elterngruppierung stammen aus @1 und werden dort
-- zentral gepflegt.}{Sorting and parent grouping live in @1 and are
-- maintained there centrally.}{\code{tagpax-ir.lua}}
local function root_node_ids(ir)
  local ids = {}
  for _, root in ipairs(ir_reader.sorted_roots(ir)) do ids[#ids + 1] = root.node end
  return ids
end

local function signatures(ir, unwrap_document, options)
  -- \ldeen{Der Tiefenstrom bewahrt Verschachtelung, Kindreihenfolge, MCIDs und
  -- Annotationstypen; instabile PDF-Objektnummern bleiben außen vor.}{The
  -- depth-first stream preserves nesting, child order, MCIDs, and annotation
  -- kinds while excluding unstable PDF object numbers.}
  local by_parent = ir_reader.sorted_kids_by_parent(ir)
  local out = {}
  local function walk(id)
    local node = assert(ir.nodes[id], "missing node " .. tostring(id))
    out[#out + 1] = "N:" .. tostring(role_of(node.role, options))
    for _, kid in ipairs(by_parent[id] or {}) do
      if kid.kind == "node" then
        walk(kid.ref)
      elseif kid.kind == "mcr" then
        out[#out + 1] = "M:" .. tostring(kid.mcid)
      elseif kid.kind == "objr" then
        local annotation = (ir.annotations or {})[kid.ref]
        out[#out + 1] = "O:" .. tostring(annotation and annotation.action or "?")
      end
    end
    out[#out + 1] = "E:" .. tostring(role_of(node.role, options))
  end
  for _, id in ipairs(root_node_ids(ir)) do
    local node = ir.nodes[id]
    if unwrap_document and node and node.role == "Document" then
      for _, kid in ipairs(by_parent[id] or {}) do
        if kid.kind == "node" then walk(kid.ref) end
      end
    else
      walk(id)
    end
  end
  return out
end

local function all_subtree_signatures(ir, role, options)
  -- \ldeen{Da Masterdokumente weiteres Material enthalten können, werden
  -- passende Beitragshüllen statt ganzer Dokumente verglichen.}{Because master
  -- documents may contain other material, candidate contribution wrappers are
  -- compared instead of whole documents.}
  local by_parent = ir_reader.sorted_kids_by_parent(ir)
  local result = {}
  local function sig(id, out)
    local node = ir.nodes[id]
    out[#out + 1] = "N:" .. tostring(role_of(node.role, options))
    for _, kid in ipairs(by_parent[id] or {}) do
      if kid.kind == "node" then
        sig(kid.ref, out)
      elseif kid.kind == "mcr" then
        out[#out + 1] = "M:" .. tostring(kid.mcid)
      elseif kid.kind == "objr" then
        local annotation = (ir.annotations or {})[kid.ref]
        out[#out + 1] = "O:" .. tostring(annotation and annotation.action or "?")
      end
    end
    out[#out + 1] = "E:" .. tostring(role_of(node.role, options))
  end
  for id, node in pairs(ir.nodes or {}) do
    if node.role == role then
      local out = {}
      sig(id, out)
      result[#result + 1] = out
    end
  end
  return result
end

local function equal(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

function M.semantic(source, target, options)
  options = options or {}
  local expected = signatures(source, options.unwrap_source_document ~= false, options)
  local candidates = all_subtree_signatures(target, options.target_wrapper_role or "Part", options)
  -- \ldeen{Die Zielhülle ist synthetisch; verglichen werden ihre Kinder.}{The
  -- target wrapper is synthetic; its children are compared.}
  for _, candidate in ipairs(candidates) do
    local stripped = {}
    for i = 2, #candidate - 1 do stripped[#stripped + 1] = candidate[i] end
    if equal(expected, stripped) then return true, {} end
  end
  return false, {
    "no target Part subtree has the source semantic signature",
    "source=" .. table.concat(expected, "|"),
  }
end

return M
