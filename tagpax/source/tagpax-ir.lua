-- tagpax-ir.lua -- IR reader and in-memory helpers
local M = {}

local function unpct(s)
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function parse_line(line)
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
  return { nodes = {}, kids = {}, roots = {}, headings = {}, streams = {}, header = nil, source = nil }
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
