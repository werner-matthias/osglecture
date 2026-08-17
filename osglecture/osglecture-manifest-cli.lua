--[[
  Package: osglecture
  Module: osglecture-manifest-cli.lua
  Date:
  2026-08-17
  Version:
  v0.8.5-dev
  Description:
  texlua entry point for OLLM: exposes osglecture-manifest.lua and
  osglecture-series-index.lua as a line-oriented command, so OLLM calls the
  same implementation instead of maintaining a second one in Perl.
]]

-- \ldeen*{Standalone-@1 löst \code{require} über \code{package.path} auf,
-- nicht über kpathsea/\code{LUAINPUTS} wie ein echter @2-Lauf. Damit die
-- Geschwisterdateien unabhängig vom Aufrufort und ohne Umgebungsvariable
-- gefunden werden, ergänzt dieses Skript sein eigenes Verzeichnis (aus
-- @3 abgeleitet) selbst.}{Standalone @1 resolves \code{require} via
-- \code{package.path}, not via kpathsea/\code{LUAINPUTS} the way a real @2
-- run does. So the sibling files are found regardless of invocation
-- location and without an environment variable, this script adds its own
-- directory (derived from @3) itself.}{\code{texlua}}{\LuaTeX}{\code{arg[0]}}
local script_directory = arg[0]:match("^(.*)[/\\][^/\\]+$")
if script_directory then
  package.path = script_directory .. "/?.lua;" .. package.path
end

local series_index = require("osglecture-series-index")
local manifest = require("osglecture-manifest")
local toml = require("osglecture-toml")

local function tsv(fields)
  io.write(table.concat(fields, "\t"), "\n")
end

local function fail(message)
  io.stderr:write("osglecture-manifest-cli: " .. tostring(message) .. "\n")
  os.exit(1)
end

local command = arg[1]

if command == "discover-units" then
  local project_root = arg[2]
  if not project_root then fail("discover-units requires a project root") end
  local units, error_message = series_index.discover_units(project_root)
  if not units then fail(error_message) end
  for _, unit in ipairs(units) do
    tsv({unit.name, unit.physical_number, unit.scope, unit.role, unit.slug})
  end

elseif command == "toml-info" then
  tsv({"osglecture-toml", tostring(toml.version), "toml2lua (vendored, MIT)"})

elseif command == "read-project-content" then
  local start_path = arg[2]
  if not start_path then fail("read-project-content requires a start path") end
  local loaded, load_error = manifest.load(start_path)
  if not loaded then fail(load_error) end
  local langs = manifest.available_languages(loaded.manifest)
  tsv({"project_root", loaded.project_root})
  tsv({"bundle_preset", tostring(manifest.bundle_preset(loaded.manifest))})
  tsv({"available_languages", table.concat(langs, ",")})

else
  fail("unknown command: " .. tostring(command)
    .. " (expected discover-units, toml-info, or read-project-content)")
end
