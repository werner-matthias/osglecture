--[[
  Package: osglecture-integration
  Description:
  Persists which logical units have been \includeunit'd into the current
  combined document, across compilation passes, so tagpax can rewrite
  cross-unit \olref links (GoToR) into internal jumps (GoTo) once their
  target is known to be part of the same document -- including targets
  that are \includeunit'd only later in the same document (forward
  references), which need one extra compilation pass to resolve, exactly
  like ordinary \label/\ref.
]]
local tagpax_luatex = require("tagpax-luatex")
local M = {}

local function identity_key(unit, doctype, lang)
  return table.concat({ unit or "", doctype or "", lang or "" }, "\t")
end

local registry_path
local write_handle

-- \ldeen*{Liest die im vorigen Lauf geschriebene Registrierungsdatei (falls
-- vorhanden) und macht die darin enthaltenen Einheiten sofort für @1s
-- @2-Callback sichtbar. Fehlt die Datei (erster Lauf), bleibt die
-- Registry schlicht leer -- Vorwärtsreferenzen lösen sich dann erst im
-- nächsten Lauf auf, wie bei \cs{ref}.}{Reads the registration file
-- written by the previous run (if any) and immediately makes the units
-- it lists visible to @1's @2 callback. If the file is missing (first
-- run), the registry simply stays empty -- forward references then
-- resolve only on the next run, just like with \cs{ref}.}{\code{tagpax}}
-- {\code{resolve\_goToR}}
function M.load_registry(jobname)
  registry_path = jobname .. "-osglecture-integration.registry"
  local f = io.open(registry_path, "r")
  if f then
    for line in f:lines() do
      local unit, doctype, lang, prefix = line:match("^(.-)\t(.-)\t(.-)\t(.-)$")
      if unit then
        tagpax_luatex.known_units[identity_key(unit, doctype, lang)] = prefix
      end
    end
    f:close()
  end
  tagpax_luatex.resolve_goToR = function(annotation)
    if not annotation["osglecture-unit"] then return nil end
    local key = identity_key(
      annotation["osglecture-unit"], annotation["osglecture-doctype"],
      annotation["osglecture-lang"]
    )
    local prefix = tagpax_luatex.known_units[key]
    local page = annotation["osglecture-source-page"]
    if prefix and page then return prefix, page end
    return nil
  end
end

-- \ldeen*{Wird von \cs{includeunit} nach jedem erfolgreichen
-- \cs{tagpaxinclude}-Aufruf ausgeführt. Macht die Einheit sofort (noch im
-- selben Lauf) für spätere @1-Aufrufe in @2 sichtbar -- Rückwärtsreferenzen
-- brauchen deshalb keinen zusätzlichen Lauf -- und schreibt sie zusätzlich
-- in die Registrierungsdatei für den nächsten Lauf. Die Datei wird beim
-- ersten Schreiben dieses Laufs neu angelegt (nicht angehängt), damit
-- entfernte Einheiten nicht als Karteileichen erhalten
-- bleiben.}{Executed by \cs{includeunit} after each successful
-- \cs{tagpaxinclude} call. Makes the unit immediately (still within the
-- same run) visible to later @1 calls in @2 -- so backward references
-- need no extra run -- and additionally writes it to the registration
-- file for the next run. The file is freshly created (not appended to)
-- on this run's first write, so removed units do not linger as stale
-- entries.}{\code{\textbackslash includeunit}}{\code{tagpax\_luatex.known\_units}}
function M.register_unit(unit, doctype, lang, prefix)
  tagpax_luatex.known_units[identity_key(unit, doctype, lang)] = prefix
  if not write_handle then
    write_handle = assert(io.open(registry_path, "w"))
  end
  write_handle:write(unit, "\t", doctype, "\t", lang, "\t", prefix, "\n")
  write_handle:flush()
end

return M
