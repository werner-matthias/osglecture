--[[
  Package: tagpax
  Date:
  2026-07-23
  Version:
  v0.8.5-dev
  Description:
  build a target-independent import plan
]]
--<*pkg>
local ir_reader = require("tagpax-ir")
local validator = require("tagpax-validate")
local M = {}

-- \ldeen*{Sortierung und Elterngruppierung stammen aus @1 und werden dort
-- zentral gepflegt.}{Sorting and parent grouping live in @1 and are
-- maintained there centrally.}{\code{tagpax-ir.lua}}
local function root_node_ids(ir)
  local ids = {}
  for _, root in ipairs(ir_reader.sorted_roots(ir)) do ids[#ids + 1] = root.node end
  return ids
end

local function source_children(ir, parent, by_parent)
  local result = {}
  for _, kid in ipairs(by_parent[parent] or {}) do
    if kid.kind == "node" then result[#result + 1] = kid.ref end
  end
  return result
end

-- \ldeen*{@1 erzeugt einen backendneutralen Plan. Bindings bleiben opake
-- Handles; erst das PDF-Backend macht daraus indirekte Referenzen.}{@1 builds
-- a backend-neutral plan. Bindings remain opaque handles; only the PDF backend
-- turns them into indirect references.}{\code{plan}}
function M.plan(ir, bindings, options)
  -- \ldeen{Die Planung akzeptiert nur validierte IR; Backends prüfen keine
  -- verwaisten Knoten, Streams oder Navigationsziele.}{Planning accepts only
  -- validated IR; backends do not check for dangling nodes, streams, or
  -- navigation targets.}
  local ok, errors = validator.validate(ir)
  if not ok then error("invalid tagpax IR: " .. table.concat(errors, "; "), 2) end
  bindings = bindings or {}
  bindings.pages = bindings.pages or {}
  bindings.streams = bindings.streams or {}
  options = options or {}

  local by_parent = ir_reader.sorted_kids_by_parent(ir)
  local plan = {
    version = 1,
    wrapper_role = options.wrapper_role or "Part",
    nodes = {},
    edges = {},
    mcrs = {},
    unresolved = {},
    source_roots = root_node_ids(ir),
  }

  local root_set = {}
  for _, id in ipairs(plan.source_roots) do root_set[id] = true end
  local unwrap = options.unwrap_document ~= false
  local imported_roots = {}

  for _, id in ipairs(plan.source_roots) do
    -- \ldeen*{Jeder Beitrag erhält eine synthetische @1-Hülle; eine
    -- Quell-@2-Wurzel entfällt.}{Each contribution receives a synthetic @1
    -- wrapper; a source @2 root is omitted.}{\code{Part}}{\code{Document}}
    local node = ir.nodes[id]
    if unwrap and node and node.role == "Document" then
      for _, child in ipairs(source_children(ir, id, by_parent)) do
        imported_roots[#imported_roots + 1] = child
      end
    else
      imported_roots[#imported_roots + 1] = id
    end
  end
  plan.imported_roots = imported_roots

  for id, node in pairs(ir.nodes) do
    -- \ldeen{Semantische Attribute werden kopiert, Quellobjektnummern nie.}{Semantic
    -- attributes are copied; source object numbers never are.}
    local omit = unwrap and root_set[id] and node.role == "Document"
    if not omit then
      plan.nodes[#plan.nodes + 1] = {
        source = id,
        role = node.role,
        title = node.title,
        actualtext = node.actualtext,
        alt = node.alt,
        lang = node.lang,
      }
    end
  end
  table.sort(plan.nodes, function(a, b)
    return tonumber(a.source:match("%d+")) < tonumber(b.source:match("%d+"))
  end)

  for parent, kids in pairs(by_parent) do
    local parent_node = ir.nodes[parent]
    local parent_is_unwrapped = unwrap and root_set[parent] and parent_node and parent_node.role == "Document"
    for _, kid in ipairs(kids) do
      if kid.kind == "node" then
        if not parent_is_unwrapped then
          plan.edges[#plan.edges + 1] = {
            parent = parent,
            child = kid.ref,
            index = tonumber(kid.index),
          }
        end
      elseif kid.kind == "mcr" then
        -- \ldeen{Diese Schicht wählt den Quellstream; indirekte Referenzen
        -- gehören dem PDF-Backend.}{This layer selects the source stream;
        -- indirect references belong to the PDF backend.}
        local stream = ir.streams and ir.streams[kid.stream]
        local handle
        if stream and stream.kind == "page" then
          handle = bindings.pages[tonumber(stream.page)]
        elseif stream then
          handle = bindings.streams[stream.id]
        elseif kid.stream == "page" then
          -- \ldeen{Kompatibilität mit Entwürfen der IR-Version~1.}{Compatibility
          -- with IR version~1 drafts.}
          handle = bindings.pages[tonumber(kid.page)]
        end

        local mcr = {
          parent = parent_is_unwrapped and nil or parent,
          wrapper_child = parent_is_unwrapped,
          index = tonumber(kid.index),
          mcid = tonumber(kid.mcid),
          page = tonumber(kid.page),
          stream = kid.stream,
          handle = handle,
        }
        plan.mcrs[#plan.mcrs + 1] = mcr
        if not handle then
          plan.unresolved[#plan.unresolved + 1] = {
            kind = stream and stream.kind or "unknown",
            stream = kid.stream,
            page = tonumber(kid.page),
            parent = parent,
            mcid = tonumber(kid.mcid),
          }
        end
      end
    end
  end

  table.sort(plan.edges, function(a,b)
    if a.parent == b.parent then return a.index < b.index end
    return a.parent < b.parent
  end)
  table.sort(plan.mcrs, function(a,b)
    if a.parent == b.parent then return a.index < b.index end
    return tostring(a.parent) < tostring(b.parent)
  end)
  return plan
end

function M.assert_resolved(plan)
  -- \ldeen{Diagnosen werden gesammelt zurückgegeben, damit alle fehlenden
  -- Stream-Bindings gemeinsam gemeldet werden.}{Diagnostics are returned as a
  -- group so all missing stream bindings can be reported together.}
  if #plan.unresolved == 0 then return true end
  local messages = {}
  for _, item in ipairs(plan.unresolved) do
    messages[#messages + 1] = string.format(
      "%s stream %s (page %s, MCID %s)",
      item.kind, tostring(item.stream), tostring(item.page), tostring(item.mcid)
    )
  end
  return false, messages
end

return M
--</pkg>
