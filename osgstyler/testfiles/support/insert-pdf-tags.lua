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

-- show-pdf-tags started annotating the root element with the PDF's
-- container version (e.g. <PDF version="2.0">) in some releases but not
-- others; that's a toolchain-version artifact, not part of what these
-- tests check (the tag *tree*), so it's stripped before comparison to
-- keep the recorded .tlg stable across show-pdf-tags versions.
tags = tags:gsub("^<PDF[^>]*>", "<PDF>")

local marker = "%-%-INSERT%-PDF%-TAGS%s+[^\r\n]+%s*\r?\n"
local replacements
log, replacements = log:gsub(marker, function()
  return "START-TEST-LOG\n" .. tags .. "END-TEST-LOG\n"
end, 1)
assert(replacements == 1, "PDF-tags marker not found in " .. log_name)

local handle = assert(io.open(log_name, "wb"))
assert(handle:write(log))
assert(handle:close())
