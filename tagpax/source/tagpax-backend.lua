-- tagpax-backend.lua -- emit TeX instructions for the experimental tagpdf backend
local ir_reader = require("tagpax-ir")
local M = {}
local catlatex = luatexbase.registernumber("catcodetable@latex")

local function tex_escape(s)
  s = tostring(s or "")
  return (s:gsub("([{}%%#\\])", "\\%1"))
end

local function sorted_kids(ir)
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

function M.emit_tex(filename)
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
        out("\\TagPaxBackendNode{" .. tex_escape(kid.ref) .. "}{" .. tex_escape(node.role or "Div") .. "}{" .. tex_escape(target_parent) .. "}")
        emit_kids(kid.ref, kid.ref)
      elseif kid.kind == "mcr" then
        local stream = ir.streams and ir.streams[kid.stream]
        if stream and stream.kind ~= "page" then
          out("\\TagPaxBackendUnsupportedStream{" .. tex_escape(kid.stream) .. "}{" .. tex_escape(stream.kind) .. "}")
        else
          mcr_serial = mcr_serial + 1
          out(string.format(
            "\\TagPaxBackendMCR{%d}{%s}{%s}{%s}{%s}",
            mcr_serial,
            tex_escape(kid.page or (stream and stream.page) or "0"),
            tex_escape(kid.mcid or "0"),
            tex_escape(kid.stream or "page"),
            tex_escape(target_parent)
          ))
        end
      end
    end
  end

  out("\\TagPaxBackendDocumentBegin")
  for _, root in ipairs(roots(ir)) do
    local node = ir.nodes[root.node]
    if node and node.role == "Document" then
      emit_kids(root.node, "@wrapper")
    elseif node then
      out("\\TagPaxBackendNode{" .. tex_escape(root.node) .. "}{" .. tex_escape(node.role or "Div") .. "}{@wrapper}")
      emit_kids(root.node, root.node)
    end
  end
  out("\\TagPaxBackendDocumentEnd")
end

return M
