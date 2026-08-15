-- osglecture-series-index.lua -- doctype-specific physical series index

local series_index = {}

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
    return nil, "current unit is not present in the series directory: " .. tostring(current_name)
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
  local entries = {}
  local ok, iterator, state = pcall(lfs.dir, path)
  if not ok then return nil, iterator end
  if not iterator then return nil, state end
  for name in iterator, state do
    if name ~= "." and name ~= ".." then entries[#entries + 1] = name end
  end
  return entries
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

return series_index
