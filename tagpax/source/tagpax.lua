--[[
  Package: tagpax
  Date:
  2026-07-23
  Version:
  v0.8.5-dev
  Description:
  semantic tagged-PDF extractor
]]

-- determine version and date for compatibility check
local function package_info(filename)
  local local file, err = io.open(filename, "r")
  if not err then
    local header = content:match("^%s*%-%-%[%[(.-)%]%]")
    if header then
      return { version = header:match("\n%s*Version:%s*\n%s*([^\r\n]+)"), 
              date = header:match("\n%s*Date:%s*\n%s*([^\r\n]+)")}
    end
  end
end
local M = package_info("tagpax.lua"}

local pdfe = assert(pdfe, "tagpax requires LuaTeX's pdfe library")

-- Transport encoding -------------------------------------------------------
-- The format is line-oriented and diffable. Percent encoding prevents tabs,
-- newlines and arbitrary PDF strings from changing record boundaries.
local function pct(s)
  s = tostring(s or "")
  return (s:gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

local function field(t, k)
  return t[k] ~= nil and (k .. "=" .. pct(t[k])) or nil
end

local function write_record(f, kind, t)
  local fields = { kind }
  for _, key in ipairs(t.__order or {}) do
    local encoded = field(t, key)
    if encoded then fields[#fields + 1] = encoded end
  end
  f:write(table.concat(fields, "\t"), "\n")
end

-- pdfe normalization -------------------------------------------------------
-- These adapters contain LuaTeX's type-tag and reference conventions so the
-- extraction code below can deal in semantic values.
local function value(dict, key)
  local typ, val, detail = pdfe.getfromdictionary(dict, key)
  return typ, val, detail
end

local function decode_pdf_string(s, hexadecimal)
  -- Hex and literal strings both represent bytes. Decode UTF-16BE when a BOM
  -- identifies it; preserve other encodings for lossless transport.
  if hexadecimal then
    s = tostring(s or ""):gsub("%s+", "")
    s = s:gsub("(%x%x)", function(pair)
      return string.char(tonumber(pair, 16))
    end)
  end
  if s and #s >= 2 and s:byte(1) == 0xFE and s:byte(2) == 0xFF then
    local chars = {}
    local index = 3
    while index + 1 <= #s do
      local first = s:byte(index) * 256 + s:byte(index + 1)
      index = index + 2
      if first >= 0xD800 and first <= 0xDBFF and index + 1 <= #s then
        local second = s:byte(index) * 256 + s:byte(index + 1)
        if second >= 0xDC00 and second <= 0xDFFF then
          first = 0x10000 + (first - 0xD800) * 0x400 + second - 0xDC00
          index = index + 2
        end
      end
      chars[#chars + 1] = utf8.char(first)
    end
    return table.concat(chars)
  end
  return s
end

local function pdf_string(dict, key)
  local typ, val, detail = value(dict, key)
  if typ == 6 or typ == "string" then return decode_pdf_string(val, detail) end
  return nil
end

local function pdf_name(dict, key)
  local typ, val = value(dict, key)
  if typ == 5 or typ == "name" then return val end
  return nil
end

local function pdf_filespec(dict, key)
  -- /UF is the Unicode spelling and /F the compatibility fallback.
  local _, item = value(dict, key)
  local current = item
  if type(current) == "string" then return current end
  if pdfe.type(current) == "pdfe.reference" then
    local _, resolved = pdfe.getfromreference(current)
    current = resolved
  end
  if pdfe.type(current) == "pdfe.dictionary" then
    return pdf_string(current, "UF") or pdf_string(current, "F")
  end
  return nil
end

local function as_dict(v)
  -- Structure entries may be direct objects or indirect references.
  if pdfe.type(v) == "pdfe.dictionary" then return v end
  if pdfe.type(v) == "pdfe.reference" then
    local _, resolved = pdfe.getfromreference(v)
    if pdfe.type(resolved) == "pdfe.dictionary" then return resolved end
  end
end

local function as_array(v)
  if pdfe.type(v) == "pdfe.array" then return v end
  if pdfe.type(v) == "pdfe.reference" then
    local _, resolved = pdfe.getfromreference(v)
    if pdfe.type(resolved) == "pdfe.array" then return resolved end
  end
end

local function ref_number(v)
  if pdfe.type(v) == "pdfe.reference" then
    -- LuaTeX's pdfe reference userdata prints as <pdfe.reference N>.
    -- getfromreference() resolves the object but does not expose N reliably.
    return tonumber(tostring(v):match("pdfe%.reference%s+(%d+)"))
  end
  return nil
end

local function page_map(doc)
  -- IR records use stable one-based page numbers, never PDF object numbers.
  local pages = pdfe.pagestotable(doc)
  local map = {}
  for number, page in ipairs(pages) do map[page[3]] = number end
  return map, #pages
end

local function array_values(array)
  local result = {}
  if not array then return result end
  for index = 1, #array do
    local _, item = pdfe.getfromarray(array, index)
    result[#result + 1] = item
  end
  return result
end

local function name_tree(dict, target)
  -- Flatten the balanced PDF name tree into one lookup table.
  if not dict then return end
  local names = pdfe.getarray(dict, "Names")
  if names then
    local index = 1
    while index <= #names do
      local _, key = pdfe.getfromarray(names, index)
      local _, item = pdfe.getfromarray(names, index + 1)
      if key ~= nil and item ~= nil then target[tostring(key)] = item end
      index = index + 2
    end
  end
  local kids = pdfe.getarray(dict, "Kids")
  if kids then
    for index = 1, #kids do
      local _, kid = pdfe.getfromarray(kids, index)
      name_tree(as_dict(kid), target)
    end
  end
end

local function named_destinations(doc)
  local result = {}
  local names = pdfe.getdictionary(doc.Catalog, "Names")
  if names then name_tree(pdfe.getdictionary(names, "Dests"), result) end
  -- PDF 1.1 compatibility: /Dests may be a dictionary in the catalog.
  local legacy = pdfe.getdictionary(doc.Catalog, "Dests")
  if legacy then
    for key, item in pairs(pdfe.dictionarytotable(legacy)) do
      result[tostring(key)] = select(2, value(legacy, key)) or item
    end
  end
  return result
end

local function min_page(a, b)
  if not a or a == 0 then return b end
  if not b or b == 0 then return a end
  return math.min(a, b)
end


-- Page inference -----------------------------------------------------------
-- A StructElem may omit /Pg. ParentTree arrays then reveal where it is used;
-- retain the earliest page as a conservative heading/navigation target.
local function build_struct_page_map(root)
  local result = {}
  local parent_tree = pdfe.getdictionary(root, "ParentTree")
  if not parent_tree then return result end

  local function register_array(key, array)
    local page = tonumber(key)
    if not page then return end
    for index = 1, #array do
      local _, item = pdfe.getfromarray(array, index)
      local object_number = ref_number(item)
      if object_number then result[object_number] = min_page(result[object_number], page) end
    end
  end

  local walk_number_tree
  walk_number_tree = function(dict)
    local _, nums = value(dict, "Nums")
    local nums_array = as_array(nums)
    if nums_array then
      local index = 1
      while index <= #nums_array do
        local _, key = pdfe.getfromarray(nums_array, index)
        local _, val = pdfe.getfromarray(nums_array, index + 1)
        local array = as_array(val)
        if array then register_array(key, array) end
        index = index + 2
      end
    end
    local _, kids = value(dict, "Kids")
    local kids_array = as_array(kids)
    if kids_array then
      for index = 1, #kids_array do
        local _, kid = pdfe.getfromarray(kids_array, index)
        local kid_dict = as_dict(kid)
        if kid_dict then walk_number_tree(kid_dict) end
      end
    end
  end

  walk_number_tree(parent_tree)
  return result
end

function M.extract(filename, outname)
  -- Extraction is one transaction: open the source, serialize a canonical
  -- semantic snapshot, then close both handles.
  assert(type(filename) == "string" and filename ~= "", "missing PDF filename")
  outname = outname or filename:gsub("%.pdf$", "") .. ".tagpax"

  local doc = assert(pdfe.open(filename), "cannot open PDF: " .. filename)
  local pmap, npages = page_map(doc)
  local named_dests = named_destinations(doc)
  local root = pdfe.getdictionary(doc.Catalog, "StructTreeRoot")
  assert(root, "PDF has no StructTreeRoot")
  local struct_page = build_struct_page_map(root)

  local f = assert(io.open(outname, "wb"))
  write_record(f, "tagpax", { __order = { "version", "generator" }, version = 1, generator = M.version })
  write_record(f, "source", { __order = { "file", "pages" }, file = filename, pages = npages })

  local nextid, seen = 0, {}
  local headings, node_meta = {}, {}
  local streams, stream_by_object, nextstream = {}, {}, 0
  local destinations, destination_by_key, annotations = {}, {}, {}
  local annotation_by_object = {}

  -- Destinations and annotations ------------------------------------------
  -- Destination operands may be arrays, references, dictionaries or names.
  local function destination_array(operand)
    local current = operand
    local guard = 0
    while current and guard < 8 do
      guard = guard + 1
      local kind = pdfe.type(current)
      if kind == "pdfe.array" then return current end
      if kind == "pdfe.reference" then
        local _, resolved = pdfe.getfromreference(current)
        current = resolved
      elseif kind == "pdfe.dictionary" then
        local _, resolved = value(current, "D")
        current = resolved
      elseif type(current) == "string" then
        current = named_dests[current]
      else
        return nil
      end
    end
    return nil
  end

  local function register_destination(operand, name)
    -- IDs are contribution-local; the importer adds a unique namespace.
    local key = name and ("name:" .. name) or ("object:" .. tostring(operand))
    if destination_by_key[key] then return destination_by_key[key] end
    local array = destination_array(operand)
    if not array then return nil end
    local items = array_values(array)
    local page = pmap[ref_number(items[1])]
    if not page then return nil end
    local id = "d" .. tostring(#destinations + 1)
    local destination = {
      id = id, name = name, page = page,
      view = tostring(items[2] or "Fit"):gsub("^/", ""),
    }
    for index = 3, math.min(#items, 6) do
      if type(items[index]) == "number" then
        destination["arg" .. tostring(index - 2)] = items[index]
      end
    end
    destinations[#destinations + 1] = destination
    destination_by_key[key] = id
    return id
  end

  local function extract_navigation()
    -- Register the complete name tree, including targets with no source link.
    local names = {}
    for name in pairs(named_dests) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do register_destination(name, name) end

    for page_number = 1, npages do
      local page = pdfe.getpage(doc, page_number)
      -- Page array properties use Lua's zero-based pdfe container access.
      -- getfromarray() is one-based and is used for ordinary destination
      -- arrays elsewhere in this module.
      local annots = page.Annots
      if annots then
        for index = 0, #annots - 1 do
          local annot = pdfe.getdictionary(annots, index)
          local _, annot_item = pdfe.getfromarray(annots, index + 1)
          if annot and pdf_name(annot, "Subtype") == "Link" then
            local rect = array_values(pdfe.getarray(annot, "Rect"))
            local action = pdfe.getdictionary(annot, "A")
            local action_type = action and pdf_name(action, "S")
            local _, direct_dest = value(annot, "Dest")
            local action_dest
            if action then action_dest = select(2, value(action, "D")) end
            local record
            if direct_dest or action_type == "GoTo" then
              local operand = direct_dest or action_dest
              local destination
              if type(operand) == "string" then
                destination = register_destination(operand, operand)
              elseif operand then
                destination = register_destination(operand)
              end
              if destination then
                record = {
                  action = "GoTo",
                  destination = destination,
                }
              end
            elseif action_type == "URI" then
              local uri = pdf_string(action, "URI")
              if uri then record = { action = "URI", uri = uri } end
            elseif action_type == "GoToR" then
              local file = pdf_filespec(action, "F")
              if file and type(action_dest) == "string" then
                record = {
                  action = "GoToR", file = file,
                  ["remote-destination"] = action_dest,
                }
              elseif file and pdfe.type(action_dest) == "pdfe.array" then
                local remote = array_values(action_dest)
                local view = tostring(remote[2] or "Fit"):gsub("^/", "")
                local supported_views = {
                  XYZ = true, Fit = true, FitH = true, FitV = true,
                  FitR = true, FitB = true, FitBH = true, FitBV = true,
                }
                if not supported_views[view] then view = "Fit" end
                record = {
                  action = "GoToR", file = file,
                  ["remote-page"] = tonumber(remote[1]),
                  ["remote-view"] = view,
                }
              end
            end
            if record and #rect >= 4 then
              record.id = "a" .. tostring(#annotations + 1)
              record.page = page_number
              record.subtype = "Link"
              record.llx, record.lly = rect[1], rect[2]
              record.urx, record.ury = rect[3], rect[4]
              annotations[#annotations + 1] = record
              local object_number = ref_number(annot_item)
              if object_number then annotation_by_object[object_number] = record end
            end
          end
        end
      end
    end
  end

  extract_navigation()

  -- Content-stream inventory ----------------------------------------------
  -- MCIDs are local to a stream, so page streams and explicit /Stm objects
  -- receive identities before any MCR record refers to them.
  local function emit_stream(id, kind, page, object_number, structparents, subtype)
    if streams[id] then return id end
    streams[id] = true
    write_record(f, "stream", {
      __order = { "id", "kind", "page", "source-object", "structparents", "subtype" },
      id = id, kind = kind, page = page, ["source-object"] = object_number,
      structparents = structparents, subtype = subtype,
    })
    return id
  end

  local function page_stream(page)
    local id = "p" .. tostring(page or 0)
    return emit_stream(id, "page", page or 0)
  end

  local function object_stream(stm, page)
    local object_number = ref_number(stm)
    if object_number and stream_by_object[object_number] then return stream_by_object[object_number] end
    nextstream = nextstream + 1
    local id = "s" .. tostring(nextstream)
    local dict = as_dict(stm)
    local structparents, subtype
    if dict then
      structparents = select(2, value(dict, "StructParents"))
      subtype = pdf_name(dict, "Subtype")
    end
    if object_number then stream_by_object[object_number] = id end
    return emit_stream(id, "object", page or 0, object_number, structparents, subtype)
  end

  local function newid()
    nextid = nextid + 1
    return "n" .. nextid
  end

  local function page_from_ref(ref, fallback)
    if ref then return pmap[ref_number(ref)] or fallback end
    return fallback
  end

  local function emit_mcr(parent, index, dict, inherited_page)
    -- Preserve both MCID and source /K index; changing either loses meaning.
    local mcid = select(2, value(dict, "MCID"))
    if mcid == nil then return nil end
    local page = page_from_ref(select(2, value(dict, "Pg")), inherited_page)
    local stm = select(2, value(dict, "Stm"))
    local stream_id = stm and object_stream(stm, page) or page_stream(page)
    write_record(f, "kid", {
      __order = { "parent", "index", "kind", "page", "stream", "mcid" },
      parent = parent, index = index, kind = "mcr", page = page or 0,
      stream = stream_id, mcid = mcid,
    })
    return page
  end

  local walk
  local function walkkid(parent, index, kid, inherited_page)
    -- Normalize the polymorphic /K grammar into explicit node/MCR/OBJR kids.
    local kid_type = pdfe.type(kid)
    if type(kid) == "number" then
      write_record(f, "kid", {
        __order = { "parent", "index", "kind", "page", "stream", "mcid" },
        parent = parent, index = index, kind = "mcr", page = inherited_page or 0,
        stream = page_stream(inherited_page), mcid = kid,
      })
      return inherited_page
    elseif kid_type == "pdfe.dictionary" or kid_type == "pdfe.reference" then
      local dict = as_dict(kid)
      if not dict then return nil end
      local typ = pdf_name(dict, "Type")
      if typ == "OBJR" then
        local _, object = value(dict, "Obj")
        local annotation = annotation_by_object[ref_number(object)]
        if annotation then
          annotation.parent = parent
          write_record(f, "kid", {
            __order = { "parent", "index", "kind", "ref" },
            parent = parent, index = index, kind = "objr", ref = annotation.id,
          })
        end
        return page_from_ref(select(2, value(dict, "Pg")), inherited_page)
      end
      if typ == "MCR" or select(2, value(dict, "MCID")) ~= nil then
        return emit_mcr(parent, index, dict, inherited_page)
      end
      local child_id, child_page = walk(dict, inherited_page, ref_number(kid))
      if child_id then
        write_record(f, "kid", {
          __order = { "parent", "index", "kind", "ref" },
          parent = parent, index = index, kind = "node", ref = child_id,
        })
      end
      return child_page
    end
  end

  walk = function(dict, inherited_page, supplied_object_number)
    -- Preserve graph identity when an indirect StructElem is referenced twice.
    local object_number = supplied_object_number or ref_number(dict)
    if object_number and seen[object_number] then
      local id = seen[object_number]
      return id, node_meta[id] and node_meta[id].first_page
    end

    local id = newid()
    if object_number then seen[object_number] = id end

    local role = pdf_name(dict, "S") or "Div"
    local own_page = page_from_ref(select(2, value(dict, "Pg")), inherited_page)
    own_page = own_page or (object_number and struct_page[object_number])
    local title = pdf_string(dict, "T")
    local actual = pdf_string(dict, "ActualText")
    local alt = pdf_string(dict, "Alt")
    local lang = pdf_string(dict, "Lang")

    write_record(f, "node", {
      __order = { "id", "role", "title", "actualtext", "alt", "lang" },
      id = id, role = role, title = title, actualtext = actual, alt = alt, lang = lang,
    })

    local heading_record
    if role:match("^H[1-6]$") then
      local text = actual or title or alt
      heading_record = {
        node = id, role = role, page = 0,
        text = text, source = actual and "ActualText" or title and "T" or alt and "Alt" or "missing",
      }
      headings[#headings + 1] = heading_record
    end

    local first_page = own_page
    local _, kids = value(dict, "K")
    local array = as_array(kids)
    if array then
      for index = 1, #array do
        local _, kid = pdfe.getfromarray(array, index)
        first_page = min_page(first_page, walkkid(id, index, kid, own_page))
      end
    elseif kids ~= nil then
      first_page = min_page(first_page, walkkid(id, 1, kids, own_page))
    end

    node_meta[id] = { first_page = first_page, role = role }
    if heading_record then heading_record.page = first_page or 0 end
    return id, first_page
  end

  -- Root and deferred records ---------------------------------------------
  -- Navigation and annotations depend on traversal results and are written
  -- after the structure graph without weakening their source ordering.
  local _, root_kids = value(root, "K")
  local roots, array = {}, as_array(root_kids)
  if array then
    for index = 1, #array do
      local _, kid = pdfe.getfromarray(array, index)
      local dict = as_dict(kid)
      if dict then roots[#roots + 1] = (walk(dict, nil, ref_number(kid))) end
    end
  else
    local dict = as_dict(root_kids)
    if dict then roots[1] = (walk(dict, nil, ref_number(root_kids))) end
  end

  for index, id in ipairs(roots) do
    write_record(f, "root", { __order = { "index", "node" }, index = index, node = id })
  end
  for _, heading in ipairs(headings) do
    write_record(f, "heading", {
      __order = { "node", "role", "page", "text", "source" },
      node = heading.node, role = heading.role, page = heading.page,
      text = heading.text, source = heading.source,
    })
  end
  for _, destination in ipairs(destinations) do
    write_record(f, "destination", {
      __order = { "id", "name", "page", "view", "arg1", "arg2", "arg3", "arg4" },
      id = destination.id, name = destination.name, page = destination.page,
      view = destination.view, arg1 = destination.arg1, arg2 = destination.arg2,
      arg3 = destination.arg3, arg4 = destination.arg4,
    })
  end
  for _, annotation in ipairs(annotations) do
    write_record(f, "annotation", {
      __order = {
        "id", "page", "subtype", "action", "destination", "uri", "file",
        "remote-destination", "remote-page", "remote-view", "parent",
        "llx", "lly", "urx", "ury",
      },
      id = annotation.id, page = annotation.page, subtype = annotation.subtype,
      action = annotation.action, destination = annotation.destination,
      uri = annotation.uri, file = annotation.file,
      ["remote-destination"] = annotation["remote-destination"],
      ["remote-page"] = annotation["remote-page"],
      ["remote-view"] = annotation["remote-view"],
      parent = annotation.parent,
      llx = annotation.llx, lly = annotation.lly,
      urx = annotation.urx, ury = annotation.ury,
    })
  end

  f:close()
  pdfe.close(doc)
  return outname
end

-- Compatibility facade ----------------------------------------------------
-- Reading and validation have dedicated modules. These forwarding functions
-- preserve the early public API without maintaining duplicate implementations.
function M.read(filename)
  return require("tagpax-ir").read(filename)
end

function M.validate(ir)
  return require("tagpax-validate").validate(ir)
end

-- TeX navigation adapter ---------------------------------------------------
-- Only validated heading records cross from Lua into macro arguments.
local function tex_escape(s)
  return (tostring(s or ""):gsub("([%%#{}])", "\\%1"):gsub("\r?\n", " "))
end

function M.emit_tex_headings(filename)
  local ir = M.read(filename)
  local ok, errors = M.validate(ir)
  if not ok then error("invalid tagpax IR: " .. table.concat(errors, "; ")) end
  for _, heading in ipairs(ir.headings) do
    if heading.text and heading.text ~= "" then
      tex.sprint(string.format(
        "\\tagpax_heading_record:nnnn{%s}{%s}{%s}{%s}",
        heading.role, heading.page, heading.node, tex_escape(heading.text)
      ))
    end
  end
end

return M
