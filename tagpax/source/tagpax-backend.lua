--[[
  Package: tagpax
  Date:
  2026-07-23
  Version:
  v0.8.5-dev
  Description:
  emit TeX instructions for the tagpdf backend
]]

local ir_reader = require("tagpax-ir")
local M = {}
local catlatex = luatexbase.registernumber("catcodetable@latex")

-- All output is executable TeX. Escape identifiers and select LaTeX catcodes
-- explicitly so Lua's current callback context cannot reinterpret them.
local function tex_escape(s)
  s = tostring(s or "")
  return (s:gsub("([{}%%#\\])", "\\%1"))
end

local function sorted_kids(ir)
  -- Source /K order is semantic: nodes, MCRs and OBJRs may be interleaved.
  local by_parent = {}
  for _, kid in ipairs(ir.kids or {}) do
    local list = by_parent[kid.parent]
    if not list then list = {}; by_parent[kid.parent] = list end
    list[#list + 1] = kid
  end
  for _, list in pairs(by_parent) do
    table.sort(list, function(a,b)
      return tonumber(a.index or 0) < tonumber(b.index or 0)
    end)
  end
  return by_parent
end

local function roots(ir)
  local list = {}
  for _, root in ipairs(ir.roots or {}) do list[#list + 1] = root end
  table.sort(list, function(a,b)
    return tonumber(a.index or 0) < tonumber(b.index or 0)
  end)
  return list
end

local function walk_ir(filename, phase)
  -- The same deterministic traversal drives two phases. “reserve” allocates
  -- StructElems and kid slots; “bind” fills slots whose PDF objects exist only
  -- after pages have been constructed.
  local ir = ir_reader.read(filename)
  local by_parent = sorted_kids(ir)
  local mcr_serial = 0

  local function out(s)
    tex.sprint(catlatex, s)
  end

  local function emit_kids(parent, target_parent)
    target_parent = target_parent or parent
    for _, kid in ipairs(by_parent[parent] or {}) do
      if kid.kind == "node" then
        local node = assert(ir.nodes[kid.ref], "missing node " .. tostring(kid.ref))
        if phase == "reserve" then
          out("\\TagPaxBackendNode{" .. tex_escape(kid.ref) .. "}{" .. tex_escape(node.role or "Div") .. "}{" .. tex_escape(target_parent) .. "}")
        end
        emit_kids(kid.ref, kid.ref)
      elseif kid.kind == "mcr" then
        local stream = ir.streams and ir.streams[kid.stream]
        if stream and stream.kind ~= "page" then
          out("\\TagPaxBackendUnsupportedStream{" .. tex_escape(kid.stream) .. "}{" .. tex_escape(stream.kind) .. "}")
        else
          -- A traversal serial is the stable rendezvous key between phases.
          mcr_serial = mcr_serial + 1
          local command = phase == "reserve"
            and "\\TagPaxBackendReserveMCR"
            or "\\TagPaxBackendBindMCR"
          out(string.format("%s{%d}{%s}{%s}{%s}{%s}", command,
              mcr_serial, tex_escape(kid.page or (stream and stream.page) or "0"),
              tex_escape(kid.mcid or "0"), tex_escape(kid.stream or "page"),
              tex_escape(target_parent)))
        end
      elseif kid.kind == "objr" and phase == "reserve" then
        out("\\TagPaxBackendReserveOBJR{" .. tex_escape(kid.ref) ..
          "}{" .. tex_escape(target_parent) .. "}")
      end
    end
  end

  if phase == "reserve" then out("\\TagPaxBackendDocumentBegin") end
  -- A source Document is a transport wrapper. Its children attach directly to
  -- the synthetic contribution Part; other roots remain explicit children.
  for _, root in ipairs(roots(ir)) do
    local node = ir.nodes[root.node]
    if node and node.role == "Document" then
      emit_kids(root.node, "@wrapper")
    elseif node then
      if phase == "reserve" then
        out("\\TagPaxBackendNode{" .. tex_escape(root.node) .. "}{" ..
          tex_escape(node.role or "Div") .. "}{@wrapper}")
      end
      emit_kids(root.node, root.node)
    end
  end
  if phase == "bind" then out("\\TagPaxBackendDocumentEnd") end
end

function M.emit_reservations(filename)
  walk_ir(filename, "reserve")
end

function M.emit_bindings(filename)
  walk_ir(filename, "bind")
end

-- Compatibility entry point for callers which only need the old, monolithic
-- emitter. Native inclusion deliberately uses the two phase API above.
function M.emit_tex(filename)
  M.emit_reservations(filename)
  M.emit_bindings(filename)
end

return M
