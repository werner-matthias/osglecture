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

-- \ldeen*{Escaping und Traversierungsreihenfolge sind in @1 gebündelt und
-- werden von mehreren Modulen geteilt; siehe dort für Details.}{Escaping and
-- traversal order live together in @1 and are shared across modules; see
-- there for details.}{\code{tagpax-ir.lua}}
local tex_escape = ir_reader.tex_escape

local function walk_ir(filename, phase, prefix)
  -- \ldeen*{Dieselbe deterministische Traversierung steuert @1 und @2:
  -- @1 reserviert Strukturelemente und Kind-Slots, @2 setzt die erst nach dem
  -- Seitenbau verfügbaren PDF-Objekte ein.}{The same deterministic traversal
  -- drives @1 and @2: @1 reserves structure elements and kid slots; @2 inserts
  -- PDF objects that become available only after page construction.}
  -- {\code{reserve}}{\code{bind}}
  local ir = ir_reader.read(filename)
  local by_parent = ir_reader.sorted_kids_by_parent(ir)
  local mcr_serial = 0
  local function stream_id(id)
    return tostring(prefix or "0") .. "." .. tostring(id or "page")
  end

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
          -- \ldeen{Die laufende Nummer verbindet beide Phasen stabil.}{The
          -- traversal serial links both phases stably.}
          mcr_serial = mcr_serial + 1
          local command = phase == "reserve"
            and "\\TagPaxBackendReserveMCR"
            or "\\TagPaxBackendBindMCR"
          out(string.format("%s{%d}{%s}{%s}{%s}{%s}", command,
              mcr_serial, tex_escape(kid.page or (stream and stream.page) or "0"),
              tex_escape(kid.mcid or "0"), tex_escape(stream_id(kid.stream)),
              tex_escape(target_parent)))
        end
      elseif kid.kind == "objr" and phase == "reserve" then
        out("\\TagPaxBackendReserveOBJR{" .. tex_escape(kid.ref) ..
          "}{" .. tex_escape(target_parent) .. "}")
      end
    end
  end

  if phase == "reserve" then out("\\TagPaxBackendDocumentBegin") end
  -- \ldeen*{Ein Quell-@1 dient nur als Transporthülle: Seine Kinder hängen
  -- direkt unter dem synthetischen @2; andere Wurzeln bleiben explizit.}{A
  -- source @1 is only a transport wrapper: its children attach directly to the
  -- synthetic @2; other roots remain explicit.}{\code{Document}}{\code{Part}}
  for _, root in ipairs(ir_reader.sorted_roots(ir)) do
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

function M.emit_reservations(filename, prefix)
  walk_ir(filename, "reserve", prefix)
end

function M.emit_bindings(filename, prefix)
  walk_ir(filename, "bind", prefix)
end

-- \ldeen*{Kompatibilitätseinstieg für den monolithischen Emitter. Der native
-- Import nutzt die Zweiphasen-API @1 und @2.}{Compatibility entry point for
-- the monolithic emitter. Native import uses the two-phase API @1 and @2.}
-- {\code{emit\_reservations}}{\code{emit\_bindings}}
function M.emit_tex(filename, prefix)
  M.emit_reservations(filename, prefix)
  M.emit_bindings(filename, prefix)
end

return M
