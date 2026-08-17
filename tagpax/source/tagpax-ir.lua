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

-- Decode only the transport layer. Semantic typing remains a consumer concern,
-- which keeps the line format simple and forward-compatible.
local function unpct(s)
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function parse_line(line)
  -- The first tab-separated column is the record discriminator.
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
  -- Annotation records become both an ordered sequence and an ID index.
  return {
    nodes = {}, kids = {}, roots = {}, headings = {}, streams = {},
    destinations = {}, annotations = {}, header = nil, source = nil,
  }
end

-- \ldeen{Ein Lauf importiert dieselbe IR-Datei typischerweise mehrfach --
-- einmal pro Reserve-/Bind-Phase und zusätzlich einmal pro Seite für
-- Navigation und Seiten-Form. Ohne Cache würde jeder dieser Aufrufe die
-- Datei erneut von der Platte lesen und den kompletten Baum neu aufbauen.
-- Der Cache ist pro Dateiname und lebt für die Dauer des \LuaTeX-Laufs; das
-- IR-Ergebnis ist unveränderlich (siehe unten), Wiederverwendung ist also
-- sicher.}{
-- A single run typically imports the same IR file multiple times -- once
-- per reserve/bind phase and once more per page for navigation and the page
-- Form. Without caching, every such call would re-read the file from disk
-- and rebuild the whole tree. The cache is keyed by filename and lives for
-- the duration of the \LuaTeX\ run; the IR result is immutable (see below),
-- so reuse is safe.}
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
        -- Order drives page emission; keyed access resolves OBJR references.
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
-- \ldeen*{Einzige Stelle, an der die Kind- und Wurzel-Reihenfolge einer
-- IR-Tabelle interpretiert wird; @1, @2 und @3 nutzen diese Funktionen
-- gemeinsam. Da @4 die zurückgegebene IR-Tabelle cached und mit jedem
-- Aufrufer teilt (siehe oben), dürfen beide Funktionen weder \code{ir.kids}
-- noch \code{ir.roots} mutieren -- sie sortieren stets eine Kopie.}{
-- The single place that interprets an IR table's kid and root order; @1,
-- @2 and @3 share these functions. Since @4 caches the returned IR table
-- and shares it with every caller (see above), neither function may
-- mutate \code{ir.kids} or \code{ir.roots} -- both always sort a copy.
-- }{\code{tagpax-backend.lua}}{\code{tagpax-import.lua}}{\code{tagpax-compare.lua}}{\code{M.read}}

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

-- \ldeen{Escaped die \LaTeX-Sonderzeichen, die in generierten
-- Kontrollwort-Argumenten vorkommen können: geschweifte Klammern,
-- Prozentzeichen, Rautezeichen und Backslash. Jeder Wert, der aus
-- Quelldokument-Text stammt und in generierten \TeX-Code eingebettet wird,
-- muss durch diese Funktion laufen -- fehlt insbesondere das Escapen des
-- Backslashs, kann Text mit einem literalen Backslash als
-- \TeX-Kontrollsequenz interpretiert werden.}{Escapes the \LaTeX\ special
-- characters that can occur in generated control-word arguments: curly
-- braces, percent sign, hash sign and backslash. Every value that
-- originates from source-document text and is embedded in generated \TeX\
-- code must pass through this function -- if escaping of the backslash in
-- particular is missing, text containing a literal backslash can be
-- interpreted as a \TeX\ control sequence.}
function M.tex_escape(s)
  s = tostring(s or "")
  return (s:gsub("([{}%%#\\])", "\\%1"))
end

return M
--</pkg>