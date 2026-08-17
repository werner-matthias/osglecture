--[[
  Package: osglecture
  Module: osglecture-manifest.lua
  Date:
  2026-08-17
  Version:
  v0.8.5-dev
  Description:
  shared project-manifest reader, used by osglecture and by OLLM via texlua
]]

local toml = require("osglecture-toml")
local series_index = require("osglecture-series-index")

local manifest = {}

local MANIFEST_FILENAME = "ollmconfig.toml"
local DEFAULT_TEX_DIRECTORY = "Include"
local DEFAULT_TEX_CONFIG = "projectconfig.tex"

-- \ldeen*{@1 sucht ausschließlich nach dem Vorhandensein von
-- \code{ollmconfig.toml} und ist unabhängig von der Verzeichnisgrammatik
-- einer Serieneinheit: Anders als @2 darf der Startpfad beliebig tief unter
-- einer Einheit liegen (etwa ein Unterordner), solange irgendein Vorfahre
-- das Manifest enthält.}{@1 looks only for the presence of
-- \code{ollmconfig.toml} and is independent of the series-unit directory
-- grammar: unlike @2, the start path may sit arbitrarily deep below a unit
-- (for example a subdirectory), as long as some ancestor holds the
-- manifest.}{\code{manifest.find}}{\code{series\_index.locate\_unit\_ancestor}}
function manifest.find(start_path, options)
  options = options or {}
  local lfs = options.lfs or require("lfs")
  local path = start_path or lfs.currentdir()
  if lfs.attributes(path, "mode") == "file" then
    path = series_index.dirname(path)
  end

  while true do
    local candidate = series_index.join(path, MANIFEST_FILENAME)
    if lfs.attributes(candidate, "mode") == "file" then
      return { project_root = path, manifest_path = candidate }
    end
    local parent = series_index.dirname(path)
    if parent == path or (path == "." and parent == ".") then break end
    path = parent
  end
  return nil, "no project manifest (" .. MANIFEST_FILENAME
    .. ") found above " .. tostring(start_path or lfs.currentdir())
end

local cache = {}

-- \ldeen*{Cacht nach absolutem Pfad innerhalb eines Laufs, damit
-- wiederholte Anfragen (etwa Auftragsentscheidung vor \cs{LoadClass} und
-- Projektinhalt danach) das Manifest nicht mehrfach lesen und parsen.
-- Aufrufer dürfen die zurückgegebene Tabelle nicht verändern: Sie wird mit
-- jedem weiteren Aufrufer geteilt.}{Caches by absolute path within one run,
-- so repeated requests (for example the build decision before
-- \cs{LoadClass} and project content afterwards) do not re-read and
-- re-parse the manifest. Callers must not mutate the returned table: it is
-- shared with every further caller.}
function manifest.read(manifest_path)
  local cached = cache[manifest_path]
  if cached ~= nil then
    if cached == false then
      return nil, cache[manifest_path .. "\0error"]
    end
    return cached
  end

  local file, open_error = io.open(manifest_path, "r")
  if not file then
    return nil, "cannot open project manifest " .. manifest_path
      .. ": " .. tostring(open_error)
  end
  local data = file:read("*a")
  file:close()

  local result, parse_error = toml.parse(data)
  if not result then
    cache[manifest_path] = false
    cache[manifest_path .. "\0error"] = parse_error
    return nil, "cannot parse project manifest " .. manifest_path
      .. ": " .. tostring(parse_error)
  end
  cache[manifest_path] = result
  return result
end

-- Finds and reads the manifest in one step; see \code{manifest.find} and
-- \code{manifest.read}.
function manifest.load(start_path, options)
  local found, find_error = manifest.find(start_path, options)
  if not found then return nil, find_error end
  local data, read_error = manifest.read(found.manifest_path)
  if not data then return nil, read_error end
  return {
    manifest = data,
    project_root = found.project_root,
    manifest_path = found.manifest_path,
  }
end

-- \ldeen{Projektweite Sprachliste aus \code{[languages]}. Ein fehlender
-- Abschnitt ergibt eine leere Liste, kein Fehler: Nicht jedes Manifest muss
-- Sprachvarianten deklarieren.}{Project-wide language list from
-- \code{[languages]}. A missing section yields an empty list, not an
-- error: not every manifest has to declare language variants.}
function manifest.available_languages(project_manifest)
  local languages = project_manifest.languages
  return (languages and languages.available) or {}
end

-- \ldeen{Der rohe Bundle-Preset-Name, etwa \code{"OSG lecture/1"}. Die
-- Auflösung der zugehörigen Preset-Definition ist nicht Teil dieses
-- Moduls.}{The raw bundle-preset name, e.g. \code{"OSG lecture/1"}.
-- Resolving the associated preset definition is not part of this
-- module.}
function manifest.bundle_preset(project_manifest)
  return project_manifest.bundle_preset
end

-- \ldeen*{Löst @1 mit denselben Defaults auf, die OLLM heute verwendet
-- (\code{Include}/\code{projectconfig.tex}), relativ zur Projektwurzel.
-- @2 ist absolut, damit das Ergebnis unabhängig vom aktuellen
-- Arbeitsverzeichnis des TeX-Laufs ist.}{Resolves @1 with the same
-- defaults OLLM uses today (\code{Include}/\code{projectconfig.tex}),
-- relative to the project root. @2 is absolute so the result is
-- independent of the TeX run's current working directory.}{\code{[project.tex]}}{\code{project\_root}}
function manifest.shared_tex(project_manifest, project_root)
  local tex_config = project_manifest.project and project_manifest.project.tex
  local directory = (tex_config and tex_config.directory) or DEFAULT_TEX_DIRECTORY
  local config = (tex_config and tex_config.config) or DEFAULT_TEX_CONFIG
  local shared_tex_directory = series_index.join(project_root, directory)
  return {
    shared_tex_directory = shared_tex_directory,
    project_config_file = config,
    project_config_path = series_index.join(shared_tex_directory, config),
  }
end

-- \ldeen*{Kombiniert @1 mit den lesenden Zugriffen oben und setzt das
-- Ergebnis als globale \TeX-Makros -- dasselbe Brückenmuster wie
-- \code{series\_index.initialize\_tex}. Ein fehlgeschlagenes Laden ist hier
-- kein Fehler: Der Aufrufer (\code{osglecture.cls}) prüft
-- \code{OsgLectureManifestAvailableFlag} und lässt projektinhaltsabhängige
-- Schritte aus, statt den Lauf abzubrechen -- dieselbe stille
-- Rückfallsemantik, die die entfernte, leere \code{shared-tex-directory}
-- vorher hatte.}{Combines @1 with the read accessors above and sets the
-- result as global \TeX\ macros -- the same bridging pattern as
-- \code{series\_index.initialize\_tex}. A failed load is not an error here:
-- the caller (\code{osglecture.cls}) checks
-- \code{OsgLectureManifestAvailableFlag} and skips project-content-dependent
-- steps instead of aborting the run -- the same silent-fallback semantics
-- the removed, empty \code{shared-tex-directory} had before.}{\code{manifest.load}}
function manifest.load_tex(start_path, options)
  local function set(name, value)
    token.set_macro(name, value == nil and "" or tostring(value), "global")
  end
  local loaded, load_error = manifest.load(start_path, options)
  if not loaded then
    set("OsgLectureManifestAvailableFlag", "0")
    return nil, load_error
  end
  local shared = manifest.shared_tex(loaded.manifest, loaded.project_root)
  local langs = manifest.available_languages(loaded.manifest)
  set("OsgLectureManifestAvailableFlag", "1")
  set("OsgLectureManifestProjectRoot", loaded.project_root)
  set("OsgLectureManifestSharedTexDirectory", shared.shared_tex_directory)
  set("OsgLectureManifestProjectConfigFile", shared.project_config_file)
  set("OsgLectureManifestProjectConfigPath", shared.project_config_path)
  set("OsgLectureManifestAvailableLanguages", table.concat(langs, ","))
  set("OsgLectureManifestBundlePreset", manifest.bundle_preset(loaded.manifest) or "")
  return loaded
end

return manifest
