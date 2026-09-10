local log_name, tags_name = arg[1], arg[2]

local function read(name)
  local handle = assert(io.open(name, "rb"))
  local content = assert(handle:read("*a"))
  assert(handle:close())
  return content
end

local log = read(log_name)
local tags = read(tags_name):gsub("\r\n", "\n")
if tags:sub(-1) ~= "\n" then
  tags = tags .. "\n"
end

local marker = "%-%-INSERT%-PDF%-TAGS%s+[^\r\n]+%s*\r?\n"
local replacements
log, replacements = log:gsub(marker, function()
  return "START-TEST-LOG\n" .. tags .. "END-TEST-LOG\n"
end, 1)
assert(replacements == 1, "PDF-tags marker not found in " .. log_name)

local handle = assert(io.open(log_name, "wb"))
assert(handle:write(log))
assert(handle:close())
