-- tagpax-luatex.lua -- controlled LuaTeX page Form-XObject import
local M = { version = "0.7.1-dev" }
local images = {}

local function tex_escape(s)
  s = tostring(s or "")
  return (s:gsub("([{}%%#\\])", "\\%1"))
end

--- Write one source PDF page as a Form XObject into the current TeX list.
-- @param filename source PDF
-- @param page one-based page number
-- @param structparents reserved ParentTree key
-- @param stream_id stable tagpax stream ID
-- @return image userdata (also retained until the end of the run)
function M.write_page(filename, page, structparents, stream_id, max_width, max_height)
  local image = assert(img.scan {
    filename = assert(filename),
    page = assert(tonumber(page)),
    pagebox = "media",
    attr = string.format("/StructParents %d", assert(tonumber(structparents))),
  })
  max_width = tonumber(max_width)
  max_height = tonumber(max_height)
  if max_width and max_height and image.width and image.height then
    local scale = math.min(max_width / image.width, max_height / image.height)
    if scale < 1 or scale > 0 then
      image.width = math.floor(image.width * scale + 0.5)
      image.height = math.floor(image.height * scale + 0.5)
      if image.depth then image.depth = math.floor(image.depth * scale + 0.5) end
    end
  end
  img.write(image)
  assert(image.objnum and image.objnum > 0, "LuaTeX did not allocate an image object")
  images[#images + 1] = image
  tex.sprint(string.format(
    "\\TagPaxBackendForm{%s}{%d 0 R}{%s}",
    tex_escape(page), image.objnum, tex_escape(stream_id)
  ))
  return image
end

return M
