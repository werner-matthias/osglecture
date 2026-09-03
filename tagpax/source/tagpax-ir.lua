--[[
  Package: tagpax
  Date:
  2026-07-23
  Version:
  v0.8.5-dev
  Description:
  IR reader and in-memory helpers
]]
--<*pkg>
local M = {}

-- \ldeen{Nur die Transportschicht wird dekodiert; semantische Typisierung bleibt
-- bei den Konsumenten und das Zeilenformat dadurch erweiterbar.}{Only the
-- transport layer is decoded; semantic typing remains with consumers, keeping
-- the line format extensible.}
local function unpct(s)
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function parse_line(line)
  -- \ldeen{Die erste tabulatorgetrennte Spalte bestimmt den Datensatztyp.}{The
  -- first tab-separated column selects the record type.}
  local cols = {}
  for col in line:gmatch("[^\t]+") do cols[#cols + 1] = col end
  local record = { record_type = cols[1] }
  for index = 2, #cols do
    local key, val = cols[index]:match("^([^=]+)=(.*)$")
    if key then record[key] = unpct(val) end
  end
  return record
end

function M.new()
  -- \ldeen{Annotationen liegen zugleich geordnet und per ID indiziert vor.}{Annotations
  -- are stored both in order and indexed by ID.}
  return {
    nodes = {}, kids = {}, roots = {}, headings = {}, streams = {},
    destinations = {}, annotations = {}, header = nil, source = nil,
  }
end

-- \ldeen{Der laufzeitweite Cache ist nach Dateiname indiziert. Gelesene
-- IR-Tabellen gelten als unveränderlich und dürfen von Aufrufern nicht
-- modifiziert werden.}{The run-wide cache is keyed by filename. Read IR tables
-- are immutable and must not be modified by callers.}
local cache = {}

function M.read(filename)
  local cached = cache[filename]
  if cached then return cached end
  local ir = M.new()
  for line in assert(io.lines(filename)) do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local record = parse_line(line)
      if record.record_type == "tagpax" then ir.header = record
      elseif record.record_type == "node" then ir.nodes[record.id] = record
      elseif record.record_type == "kid" then ir.kids[#ir.kids + 1] = record
      elseif record.record_type == "root" then ir.roots[#ir.roots + 1] = record
      elseif record.record_type == "heading" then ir.headings[#ir.headings + 1] = record
      elseif record.record_type == "stream" then ir.streams[record.id] = record
      elseif record.record_type == "destination" then ir.destinations[record.id] = record
      elseif record.record_type == "annotation" then
        -- \ldeen{Die Reihenfolge steuert die Seitenausgabe; der ID-Zugriff löst
        -- OBJR-Verweise auf.}{Order drives page output; ID access resolves OBJR
        -- references.}
        ir.annotations[#ir.annotations + 1] = record
        ir.annotations[record.id] = record
      elseif record.record_type == "source" then ir.source = record end
    end
  end
  cache[filename] = ir
  return ir
end

function M.count_nodes(ir)
  local n = 0
  for _ in pairs(ir.nodes) do n = n + 1 end
  return n
end

-- \ldeen{Gemeinsame Traversierungs- und Ausgabehelfer.}{Shared traversal and
-- output helpers.}
--
-- \ldeen*{Diese Helfer sind die zentrale Interpretation der Kind- und
-- Wurzelreihenfolge. Wegen des geteilten Caches sortieren sie Kopien und
-- verändern weder @1 noch @2.}{These helpers are the central interpretation of
-- kid and root order. Because the cache is shared, they sort copies and mutate
-- neither @1 nor @2.
-- }{\code{ir.kids}}{\code{ir.roots}}

-- \ldeen*{Gruppiert @1 nach Elternknoten und sortiert jede Gruppe nach dem
-- ursprünglichen @2-Index. Die Quell-/K-Reihenfolge ist semantisch (Knoten,
-- MCRs und OBJRs können verschachtelt sein), daher muss diese Sortierung
-- vor jeder Traversierung stehen.}{Groups @1 by parent node and sorts each
-- group by the original @2 index. Source /K order is semantic (nodes, MCRs
-- and OBJRs may be interleaved), so this sort must precede any traversal.
-- }{\code{ir.kids}}{\code{index}}
function M.sorted_kids_by_parent(ir)
  local by_parent = {}
  for _, kid in ipairs(ir.kids or {}) do
    local list = by_parent[kid.parent]
    if not list then list = {}; by_parent[kid.parent] = list end
    list[#list + 1] = kid
  end
  for _, list in pairs(by_parent) do
    table.sort(list, function(a, b)
      return tonumber(a.index or 0) < tonumber(b.index or 0)
    end)
  end
  return by_parent
end

-- \ldeen*{Liefert die Wurzelknoten-Datensätze, sortiert nach @1. Sortiert
-- eine Kopie, niemals @2 selbst -- die IR-Tabelle kann zwischengespeichert
-- und von mehreren Aufrufern geteilt werden, s.\,o.}{Returns the root-node
-- records, sorted by @1. Sorts a copy, never @2 itself -- the IR table may
-- be cached and shared between several callers, see above.
-- }{\code{index}}{\code{ir.roots}}
function M.sorted_roots(ir)
  local list = {}
  for _, root in ipairs(ir.roots or {}) do list[#list + 1] = root end
  table.sort(list, function(a, b)
    return tonumber(a.index or 0) < tonumber(b.index or 0)
  end)
  return list
end

-- \ldeen{Escaped Klammern, Prozent, Raute und Backslash für erzeugte
-- \TeX-Makroargumente. Jeder eingebettete Quelltext muss diese Funktion
-- durchlaufen.}{Escapes braces, percent, hash, and backslash for generated
-- \TeX\ macro arguments. All embedded source text must pass through this
-- function.}
function M.tex_escape(s)
  s = tostring(s or "")
  return (s:gsub("([{}%%#\\])", "\\%1"))
end

return M
--</pkg>
