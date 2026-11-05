#!/usr/bin/env texlua
-- Inspects and validates the CTAN submission data of the release units
-- (see tools/ctan-metadata.lua).
--
-- Usage (from the bundle root):
--   texlua tools/make-ctan-metadata.lua --list            units and their package names
--   texlua tools/make-ctan-metadata.lua --show <unit>     the composed submission fields
--   texlua tools/make-ctan-metadata.lua --deps [<unit>]   dependencies by kind
--   texlua tools/make-ctan-metadata.lua --matrix          the dependency matrix of the register
--   texlua tools/make-ctan-metadata.lua --check [<unit>]  missing texts, field limits;
--                                                         exit status 1 on any problem

local metadata = dofile("tools/ctan-metadata.lua")

local function fail(message)
  io.stderr:write("make-ctan-metadata: " .. message .. "\n")
  os.exit(1)
end

local function units_for(name)
  if not name then
    return metadata.units()
  end
  return { metadata.unit(name) or fail("no such release unit: " .. name) }
end

local function show_value(value)
  if type(value) == "table" then
    return table.concat(value, ", ")
  end
  return tostring(value)
end

local command, name = arg[1], arg[2]

if command == "--list" then
  for _, unit in ipairs(metadata.units()) do
    print((unit.ctanpkg or unit.name)
      .. (unit.bundle and "  (bundle)" or ""))
  end

elseif command == "--show" then
  if not name then fail("--show needs a unit name") end
  local config = metadata.uploadconfig(units_for(name)[1])
  for _, field in ipairs({ "pkg", "version", "update", "ctanPath", "license",
      "topic", "summary", "description", "announcement", "note" }) do
    print("== " .. field)
    print(config[field] ~= nil and show_value(config[field]) or "(none)")
  end

elseif command == "--deps" then
  for _, unit in ipairs(units_for(name)) do
    local deps = metadata.dependencies(unit)
    print((unit.ctanpkg or unit.name) .. ":")
    for _, kind in ipairs({ "run", "optional", "check", "doc" }) do
      if #deps[kind] > 0 then
        print("  " .. kind .. ": " .. table.concat(deps[kind], ", "))
      end
    end
  end

elseif command == "--matrix" then
  print(metadata.matrix_text())

elseif command == "--check" then
  local bad = 0
  if not name then
    for _, problem in ipairs(metadata.matrix_problems()) do
      print("dependency matrix: " .. problem)
      bad = bad + 1
    end
  end
  for _, unit in ipairs(units_for(name)) do
    local problems = metadata.problems(unit)
    for _, problem in ipairs(problems) do
      print((unit.ctanpkg or unit.name) .. ": " .. problem)
    end
    bad = bad + #problems
  end
  if bad > 0 then
    os.exit(1)
  end
  print("CTAN submission data is complete")

else
  fail("usage: make-ctan-metadata.lua --list | --show <unit> | --deps [<unit>] | --matrix | --check [<unit>]")
end
