-- tagpax.lua -- semantic tagged-PDF extractor and IR reader
-- LPPL 1.3c or later
local M = { version = "0.7.1-dev", date = "2026-07-15" }

local pdfe = assert(pdfe, "tagpax requires LuaTeX's pdfe library")

local function pct(s)
  s = tostring(s or "")
  return (s:gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

local function unpct(s)
  return (s:gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
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

local function value(dict, key)
  local typ, val, detail = pdfe.getfromdictionary(dict, key)
  return typ, val, detail
end

local function pdf_string(dict, key)
  local typ, val = value(dict, key)
  if typ == 4 or typ == "string" then return val end
  return nil
end

local function pdf_name(dict, key)
  local typ, val = value(dict, key)
  if typ == 5 or typ == "name" then return val end
  return nil
end

local function as_dict(v)
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
  local pages = pdfe.pagestotable(doc)
  local map = {}
  for number, page in ipairs(pages) do map[page[3]] = number end
  return map, #pages
end

local function min_page(a, b)
  if not a or a == 0 then return b end
  if not b or b == 0 then return a end
  return math.min(a, b)
end


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
  assert(type(filename) == "string" and filename ~= "", "missing PDF filename")
  outname = outname or filename:gsub("%.pdf$", "") .. ".tagpax"

  local doc = assert(pdfe.open(filename), "cannot open PDF: " .. filename)
  local pmap, npages = page_map(doc)
  local root = pdfe.getdictionary(doc.Catalog, "StructTreeRoot")
  assert(root, "PDF has no StructTreeRoot")
  local struct_page = build_struct_page_map(root)

  local f = assert(io.open(outname, "wb"))
  write_record(f, "tagpax", { __order = { "version", "generator" }, version = 1, generator = M.version })
  write_record(f, "source", { __order = { "file", "pages" }, file = filename, pages = npages })

  local nextid, seen = 0, {}
  local headings, node_meta = {}, {}
  local streams, stream_by_object, nextstream = {}, {}, 0

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

  f:close()
  pdfe.close(doc)
  return outname
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

function M.read(filename)
  local ir = { nodes = {}, kids = {}, roots = {}, headings = {}, streams = {}, header = nil, source = nil }
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

function M.validate(ir)
  local errors = {}
  if not ir.header or tonumber(ir.header.version) ~= 1 then errors[#errors + 1] = "unsupported or missing IR version" end
  if not ir.source then errors[#errors + 1] = "missing source record" end
  for _, root in ipairs(ir.roots) do
    if not ir.nodes[root.node] then errors[#errors + 1] = "root references missing node " .. tostring(root.node) end
  end
  for id, stream in pairs(ir.streams or {}) do
    if stream.id ~= id then errors[#errors + 1] = "stream id mismatch " .. tostring(id) end
    if stream.kind ~= "page" and stream.kind ~= "object" then errors[#errors + 1] = "invalid stream kind " .. tostring(stream.kind) end
  end
  for _, kid in ipairs(ir.kids) do
    if not ir.nodes[kid.parent] then errors[#errors + 1] = "kid has missing parent " .. tostring(kid.parent) end
    if kid.kind == "node" and not ir.nodes[kid.ref] then errors[#errors + 1] = "kid references missing node " .. tostring(kid.ref) end
    if kid.kind == "mcr" and tonumber(kid.mcid) == nil then errors[#errors + 1] = "MCR has invalid MCID" end
    if kid.kind == "mcr" and ir.streams and next(ir.streams) and not ir.streams[kid.stream] then errors[#errors + 1] = "MCR references missing stream " .. tostring(kid.stream) end
  end
  for _, heading in ipairs(ir.headings) do
    local node = ir.nodes[heading.node]
    if not node then errors[#errors + 1] = "heading references missing node " .. tostring(heading.node)
    elseif node.role ~= heading.role then errors[#errors + 1] = "heading role mismatch at " .. heading.node end
  end
  return #errors == 0, errors
end

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
