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

-- \ldeen{Konstruierte Pfade verwenden immer den Vorwärtsschrägstrich, nie
-- den plattformabhängigen \code{package.config}-Trenner: Die
-- Windows-Dateisystem-API akzeptiert ihn nativ (siehe die Begründung bei
-- \code{directory\_entries} unten), und nur so liefert dieses Modul auf
-- allen drei getesteten Plattformen denselben String für denselben
-- logischen Pfad -- Voraussetzung für die plattformübergreifende
-- \code{l3build}-Referenzdatei dieses Tests.}{Constructed paths always use
-- the forward slash, never the platform-dependent \code{package.config}
-- separator: the Windows filesystem API accepts it natively (see the
-- rationale at \code{directory\_entries} below), and only this way does
-- the module produce the same string for the same logical path on all
-- three tested platforms -- a prerequisite for this test's cross-platform
-- \code{l3build} reference file.}
local separator = "/"

local function basename(path)
  local value = path:gsub("[\\/]+$", "")
  return value:match("([^\\/]+)$") or value
end

-- A path made only of separators (POSIX root) or a bare drive letter
-- (Windows root, e.g. "C:") has no parent of its own; dirname must return a
-- value equal to its input so the caller's walk-upward loop reaches a fixed
-- point and terminates, instead of silently collapsing to ".".
local function dirname(path)
  local value = path:gsub("[\\/]+$", "")
  local parent = value:match("^(.*)[\\/][^\\/]+$")
  if not parent or parent == "" then
    if value:match("^[\\/]") then return separator end
    local drive = value:match("^(%a:)$")
    if drive then return drive .. separator end
    return "."
  end
  return parent
end

local function join(left, right)
  if left == "." then return right end
  if left:match("[\\/]$") then return left .. right end
  return left .. separator .. right
end

-- \ldeen{Exportiert die Windows-gehärteten Pfad-Grundfunktionen, damit
-- andere Module (etwa das gemeinsame Manifest-Modul) sie wiederverwenden,
-- statt eine eigene, ungeprüfte Kopie zu pflegen.}{Exports the
-- Windows-hardened path primitives so other modules (such as the shared
-- manifest module) can reuse them instead of maintaining their own,
-- unverified copy.}
series_index.basename = basename
series_index.dirname = dirname
series_index.join = join

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
  local previous_continuation
  for index = position - 1, 1, -1 do
    if units[index].role ~= "i" then
      previous_continuation = units[index]
      break
    end
  end
  return {
    doctype = context.doctype,
    unit_scopes = context.unit_scopes or {},
    units = units,
    position = position,
    current = units[position],
    previous = units[position - 1],
    previous_continuation = previous_continuation,
    next = units[position + 1],
  }
end

-- \ldeen*{@1 nimmt Pfade unverändert, wie sie hereinkommen: @2 schreibt
-- \code{source-directory} immer mit Vorwärtsschrägstrichen (auch auf
-- Windows), und die Windows-Dateisystem-API -- die @1 letztlich aufruft --
-- akzeptiert beide Trenner nativ. Eine Rückkonvertierung auf Backslashes
-- ist daher weder nötig noch unbedenklich: die dafür ursprünglich genutzte
-- Erkennung über \code{package.config} wurde von keinem Test gegen echtes
-- \LuaTeX\ auf Windows abgesichert.}{@1 takes paths exactly as they arrive:
-- @2 always writes \code{source-directory} with forward slashes (even on
-- Windows), and the Windows filesystem API -- which @1 ultimately calls --
-- accepts either separator natively. Converting back to backslashes was
-- therefore neither necessary nor risk-free: the detection originally used
-- for that, based on \code{package.config}, was never exercised against
-- real \LuaTeX\ on Windows by any test.}{\code{lfs.dir}}{OLLM}
-- \ldeen*{Der Existenz-/Verzeichnis-Vortest ist nötig, weil sich
-- \code{lfs.dir} bei einem fehlenden Verzeichnis plattformabhängig
-- verhält: Auf einigen Plattformen löst der Aufruf selbst innerhalb des
-- @1 einen Fehler aus, auf anderen liefert er kommentarlos einen sofort
-- erschöpften Iterator (leere Ergebnisliste statt Fehlermeldung). Ohne
-- diesen Vortest wäre @2 auf solchen Plattformen für ein fehlendes
-- Verzeichnis nicht von einem leeren Verzeichnis zu unterscheiden.}{The
-- existence/directory pre-check is necessary because \code{lfs.dir}'s
-- behavior for a missing directory is platform-dependent: on some
-- platforms the call itself raises an error inside the @1, on others it
-- silently returns an already-exhausted iterator (an empty result list
-- instead of an error). Without this pre-check, @2 could not distinguish
-- a missing directory from an empty one on such platforms.}{\code{pcall}}{\code{discover\_units}}
local function directory_entries(path, lfs)
  local mode = lfs.attributes(path, "mode")
  if mode ~= "directory" then
    return nil, "cannot open " .. tostring(path) .. ": not a directory"
  end
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

-- \ldeen{Listet und parst alle Serieneinheiten unter @1, ohne nach Doctype
-- oder Unit-Scopes zu filtern -- die Rollenzuordnung, die @2 (Perl) heute
-- unabhängig implementiert. Wird von OLLM über \code{texlua} aufgerufen, um
-- diese Duplikation durch einen einzigen Aufrufer zu ersetzen.}{Lists and
-- parses every series unit under @1, without filtering by doctype or unit
-- scopes -- the same job @2 (Perl) implements independently today. Called
-- by OLLM via \code{texlua} to replace that duplication with a single
-- caller.}{project\_root}{\code{OLLM::Config::structure\_snapshot}}
function series_index.discover_units(project_root, lfs)
  lfs = lfs or require("lfs")
  local entries, error_message = directory_entries(project_root, lfs)
  if not entries then return nil, error_message end
  local units = {}
  for _, name in ipairs(entries) do
    local unit = series_index.parse_unit_name(name)
    if unit then units[#units + 1] = unit end
  end
  table.sort(units, function(left, right) return left.name < right.name end)
  return units
end

-- \ldeen{Parst nur den Namen von @1 selbst (Default: das
-- Arbeitsverzeichnis), ohne Serienwurzel oder Geschwister zu suchen. Für
-- Entscheidungen, die ausschließlich von der Identität der aktuellen
-- Einheit abhängen (etwa ob die Rolle \code{integration} ist), ist das
-- robuster als der volle @1-basierte Seriencheck: Es kann nicht an einem
-- fehlenden Serienwurzel-Vorfahren oder einem Scope-Fehler bei
-- Geschwistern scheitern.}{Parses only @1's own name (default: the
-- working directory), without searching for a series root or siblings.
-- For decisions that depend solely on the current unit's own identity
-- (such as whether its role is \code{integration}), this is more robust
-- than the full series check: it cannot fail because of a missing series
-- root ancestor or a sibling scope error.}{path}
function series_index.current_unit(path, lfs)
  lfs = lfs or require("lfs")
  path = path or lfs.currentdir()
  if lfs.attributes(path, "mode") == "file" then
    path = dirname(path)
  end
  return series_index.parse_unit_name(basename(path))
end

-- \ldeen*{Reine Verzeichniswanderung ohne Geschwister-Analyse: von @1
-- unabhängige Aufrufer (etwa das Manifest-Modul) brauchen nur die
-- Serienwurzel, nicht Doctype oder Unit-Scopes. @2 nutzt diese Funktion
-- intern und ergänzt die Analyse.}{Pure upward walk without sibling
-- analysis: callers that do not need a doctype (such as the manifest
-- module) only need the series root, not doctype or unit scopes. @2 uses
-- this function internally and adds the analysis.}{\code{series\_index.analyze}}{\code{series\_index.locate}}
function series_index.locate_unit_ancestor(start_path, options)
  options = options or {}
  local lfs = options.lfs or require("lfs")
  local path = start_path or lfs.currentdir()
  if lfs.attributes(path, "mode") == "file" then
    path = dirname(path)
  end

  while true do
    local name = basename(path)
    if series_index.parse_unit_name(name) then
      return {
        unit_directory = path,
        series_directory = dirname(path),
        unit_name = name,
      }
    end
    local parent = dirname(path)
    if parent == path or (path == "." and parent == ".") then break end
    path = parent
  end
  return nil, "no series-unit directory found above " .. tostring(start_path or lfs.currentdir())
end

function series_index.locate(start_path, options)
  options = options or {}
  local lfs = options.lfs or require("lfs")
  local ancestor, ancestor_error = series_index.locate_unit_ancestor(start_path, options)
  if not ancestor then return nil, ancestor_error end

  local root = ancestor.series_directory
  local entries, error_message = directory_entries(root, lfs)
  if not entries then return nil, "cannot read series directory " .. root .. ": " .. tostring(error_message) end
  local result, analyze_error = series_index.analyze(entries, ancestor.unit_name, options)
  if not result then return nil, analyze_error end
  result.unit_directory = ancestor.unit_directory
  result.series_directory = root
  for _, unit in ipairs(result.units) do
    unit.path = join(root, unit.name)
  end
  return result
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

-- \ldeen{Brückenfunktion zu \code{series\_index.current\_unit} nach
-- demselben Muster wie \code{series\_index.initialize\_tex}: setzt
-- \code{\textbackslash OsgLectureUnitPhysicalUnit} und
-- \code{\textbackslash OsgLectureUnitRole} global, leer bei fehlendem
-- Vorfahren.}{Bridge function to \code{series\_index.current\_unit}
-- following the same pattern as \code{series\_index.initialize\_tex}: sets
-- \code{\textbackslash OsgLectureUnitPhysicalUnit} and
-- \code{\textbackslash OsgLectureUnitRole} globally, empty when there is
-- no matching directory.}
function series_index.current_unit_tex(path, lfs)
  local unit = series_index.current_unit(path, lfs)
  local function set(name, value)
    token.set_macro(name, value == nil and "" or tostring(value), "global")
  end
  set("OsgLectureUnitPhysicalUnit", unit and unit.name or "")
  set("OsgLectureUnitRole", unit and unit.role or "")
  return unit
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
  set("OsgLectureSeriesCurrentRole", result.current.role)
  set("OsgLectureSeriesPreviousPhysicalUnit",
    result.previous and result.previous.name or "")
  set("OsgLectureSeriesPreviousContinuationPhysicalUnit",
    result.previous_continuation and result.previous_continuation.name or "")
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

-- \ldeen*{Fasst den Vorabtest mit @1 und den bedingten Aufruf von @2 in
-- einer einzigen Funktion zusammen. Der Grund ist nicht nur Bequemlichkeit:
-- \code{\textbackslash ExplSyntaxOn} setzt Leerzeichen auf Katcode~9
-- (ignoriert), nicht auf das gewöhnliche Katcode~10 -- ein \code{local}
-- oder \code{if}/\code{then} direkt im \TeX-Quelltext eines
-- \code{\textbackslash directlua}-Aufrufs würde deshalb beim Tokenisieren
-- seine trennenden Leerzeichen vollständig verlieren (etwa
-- \code{local x} zu \code{localx}) und wäre kein gültiges Lua mehr. Ein
-- einzeiliger, verkettender Aufruf wie @2 braucht dagegen keine
-- Leerzeichen zur Token-Trennung und bleibt sicher.}{Combines the
-- pre-check with @1 and the conditional call to @2 into a single
-- function. The reason is not just convenience:
-- \code{\textbackslash ExplSyntaxOn} sets the space character to
-- catcode~9 (ignored), not the usual catcode~10 -- a \code{local} or
-- \code{if}/\code{then} written directly in the \TeX\ source of a
-- \code{\textbackslash directlua} call would therefore lose its
-- separating spaces entirely at tokenization time (e.g.\ \code{local x}
-- becoming \code{localx}) and stop being valid Lua. A single-line,
-- chained call like @2 needs no spaces for token separation and stays
-- safe.}{\code{locate\_unit\_ancestor}}{\code{initialize\_tex\_csv}}
function series_index.initialize_tex_csv_if_available(start_path, doctype, scopes_csv)
  if series_index.locate_unit_ancestor(start_path) then
    return series_index.initialize_tex_csv(start_path, doctype, scopes_csv)
  end
end

return series_index
