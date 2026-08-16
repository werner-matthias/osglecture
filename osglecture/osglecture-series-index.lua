--[[
  Package: osglecture
  Module: osglecture-series-index.lua
  Date:
  2026-08-15
  Version:
  v0.8.5-dev
  Description:
  doctype-specific physical series index
]]

local series_index = {}
local active_index

local separator = package.config:sub(1, 1)

local function basename(path)
  local value = path:gsub("[\\/]+$", "")
  return value:match("([^\\/]+)$") or value
end

local function dirname(path)
  local value = path:gsub("[\\/]+$", "")
  local parent = value:match("^(.*)[\\/][^\\/]+$")
  if not parent or parent == "" then
    return value:match("^[\\/]") and separator or "."
  end
  return parent
end

local function join(left, right)
  if left == "." then return right end
  if left:match("[\\/]$") then return left .. right end
  return left .. separator .. right
end

function series_index.parse_unit_name(name)
  if type(name) ~= "string" then return nil, "unit name must be a string" end
  local number, scope, tail = name:match("^(%d%d%d)(%l*)%-(.+)$")
  if not number or #scope > 2 then
    return nil, "not a series-unit directory name: " .. name
  end
  local role, slug = tail:match("^([aei])%-(.+)$")
  if not role then
    role, slug = "content", tail
  end
  if slug == "" then return nil, "unit slug must not be empty" end
  return {
    name = name,
    physical_number = number,
    number = tonumber(number),
    scope = scope,
    role = role,
    slug = slug,
  }
end

local function scope_set(unit_scopes)
  local allowed = {}
  for _, scope in ipairs(unit_scopes) do
    if type(scope) ~= "string" or not scope:match("^%l%l?$") then
      return nil, "invalid applicable unit scope: " .. tostring(scope)
    end
    allowed[scope] = true
  end
  return allowed
end

local function bytes(value)
  local result = {}
  for index = 1, #value do
    result[#result + 1] = string.format("%02X", string.byte(value, index))
  end
  return table.concat(result, " ")
end

local function describe_entry(name, allowed)
  if type(name) ~= "string" then
    return string.format("%q [type=%s]", tostring(name), type(name))
  end
  local unit, parse_error = series_index.parse_unit_name(name)
  if not unit then
    return string.format("%q [not-unit: %s; bytes=%s]",
      name, parse_error, bytes(name))
  end
  return string.format("%q [scope=%q; applicable=%s; bytes=%s]",
    name, unit.scope, tostring(unit.scope == "" or allowed[unit.scope] == true),
    bytes(name))
end

function series_index.analyze(entries, current_name, context)
  if type(entries) ~= "table" then return nil, "directory entries must be a table" end
  if type(context) ~= "table" or type(context.doctype) ~= "string"
      or context.doctype == "" then
    return nil, "doctype context is required"
  end
  local allowed, scope_error = scope_set(context.unit_scopes or {})
  if not allowed then return nil, scope_error end
  local units = {}
  for _, name in ipairs(entries) do
    local unit = series_index.parse_unit_name(name)
    if unit and (unit.scope == "" or allowed[unit.scope]) then
      unit.doctype = context.doctype
      units[#units + 1] = unit
    end
  end
  table.sort(units, function(left, right) return left.name < right.name end)

  local position
  for index, unit in ipairs(units) do
    if unit.name == current_name then
      if position then return nil, "duplicate current unit: " .. current_name end
      position = index
    end
  end
  if not position then
    local observed = {}
    for _, name in ipairs(entries) do
      observed[#observed + 1] = describe_entry(name, allowed)
    end
    table.sort(observed)
    return nil, "current unit is not present in the series directory: "
      .. tostring(current_name) .. "; observed entries: "
      .. (#observed > 0 and table.concat(observed, "; ") or "<none>")
  end
  return {
    doctype = context.doctype,
    unit_scopes = context.unit_scopes or {},
    units = units,
    position = position,
    current = units[position],
    previous = units[position - 1],
    next = units[position + 1],
  }
end

local function directory_entries(path, lfs)
  local ok, result = pcall(function()
    local entries = {}
    for name in lfs.dir(path) do
      if name ~= "." and name ~= ".." then entries[#entries + 1] = name end
    end
    return entries
  end)
  if not ok then return nil, result end
  return result
end

function series_index.locate(start_path, options)
  options = options or {}
  local lfs = options.lfs or require("lfs")
  local path = start_path or lfs.currentdir()
  if lfs.attributes(path, "mode") == "file" then path = dirname(path) end

  while true do
    local name = basename(path)
    if series_index.parse_unit_name(name) then
      local root = dirname(path)
      local entries, error_message = directory_entries(root, lfs)
      if not entries then return nil, "cannot read series directory " .. root .. ": " .. tostring(error_message) end
      local result, analyze_error = series_index.analyze(entries, name, options)
      if not result then return nil, analyze_error end
      result.unit_directory = path
      result.series_directory = root
      for _, unit in ipairs(result.units) do
        unit.path = join(root, unit.name)
      end
      return result
    end
    local parent = dirname(path)
    if parent == path or (path == "." and parent == ".") then break end
    path = parent
  end
  return nil, "no series-unit directory found above " .. tostring(start_path or lfs.currentdir())
end

function series_index.initialize(start_path, context)
  local result, error_message = series_index.locate(start_path, context)
  if not result then return nil, error_message end
  active_index = result
  return result
end

function series_index.current()
  return active_index
end

function series_index.initialize_tex(start_path, context)
  local result, error_message = series_index.initialize(start_path, context)
  if not result then return nil, error_message end
  local function set(name, value)
    token.set_macro(name, value == nil and "" or tostring(value), "global")
  end
  set("OsgLectureSeriesAvailableFlag", "1")
  set("OsgLectureSeriesPosition", result.position)
  set("OsgLectureSeriesCurrentPhysicalUnit", result.current.name)
  set("OsgLectureSeriesPreviousPhysicalUnit",
    result.previous and result.previous.name or "")
  set("OsgLectureSeriesNextPhysicalUnit",
    result.next and result.next.name or "")
  return result
end

function series_index.initialize_tex_csv(start_path, doctype, scopes_csv)
  local scopes = {}
  for scope in string.gmatch(scopes_csv or "", "[^,]+") do
    table.insert(scopes, scope)
  end
  local result, error_message = series_index.initialize_tex(start_path, {
    doctype = doctype,
    unit_scopes = scopes,
  })
  if not result then
    tex.error("osglecture series index initialization failed", {error_message})
  end
  return result
end

return series_index
