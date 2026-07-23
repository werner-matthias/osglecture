--[[
  Package: tagpax
  Date:
  2026-07-23
  Version:
  v0.8.5-dev
  Description:
  IR reader and in-memory helpers
]]

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

function M.read(filename)
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
  return ir
end

function M.count_nodes(ir)
  local n = 0
  for _ in pairs(ir.nodes) do n = n + 1 end
  return n
end

return M
