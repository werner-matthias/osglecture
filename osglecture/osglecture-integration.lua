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
local tagpax = require("tagpax")
local M = {}

-- \ldeen*{Dünner Adapter auf \cs{tagpax.is\_tagged}, damit @1 die einzige
-- Stelle bleibt, die \code{require("tagpax")} aufruft.}{Thin adapter over
-- \cs{tagpax.is\_tagged}, so that @1 remains the only place calling
-- \code{require("tagpax")}.}{\code{osglecture-integration.lua}}
function M.probe_tagged(filename)
  return tagpax.is_tagged(filename)
end

local function identity_key(unit, doctype, lang)
  return table.concat({ unit or "", doctype or "", lang or "" }, "\t")
end

local registry_path
local write_handle

-- \ldeen*{Aggregierter Tagging-Status eines Doctypes aus dem vorigen Lauf:
-- \code{nil} (im vorigen Lauf keine Einheit dieses Doctypes eingebunden),
-- \code{"tagged"}, \code{"untagged"} oder \code{"mixed"}. @1 liest dies vor
-- der ersten \cs{includeunit}-Einbindung eines Doctypes in diesem Lauf, um
-- zwischen dem getaggten und dem ungetaggten Einbindungspfad zu entscheiden,
-- ohne jede zuvor bekannte Quell-PDF erneut zu öffnen.}{Aggregated tagging
-- status of a doctype from the previous run: \code{nil} (no unit of this
-- doctype was included in the previous run), \code{"tagged"},
-- \code{"untagged"} or \code{"mixed"}. @1 reads this before the first
-- \cs{includeunit} call of a doctype in this run to decide between the
-- tagged and the untagged inclusion path, without reopening every
-- previously known source PDF.}{\code{osglecture-integration.sty}}
local previous_status = {}
local previous_units = {}

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
  previous_status = {}
  previous_units = {}
  registry_path = jobname .. "-osglecture-integration.registry"
  local f = io.open(registry_path, "r")
  if f then
    for line in f:lines() do
      local unit, doctype, lang, prefix, tagged =
        line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)$")
      if unit then
        tagpax_luatex.known_units[identity_key(unit, doctype, lang)] = prefix
        previous_units[doctype] = previous_units[doctype] or {}
        table.insert(previous_units[doctype], unit)
        local seen = (tagged == "1") and "tagged" or "untagged"
        local status = previous_status[doctype]
        if not status then
          previous_status[doctype] = seen
        elseif status ~= seen then
          previous_status[doctype] = "mixed"
        end
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

-- \ldeen*{Liefert \code{"tagged"}, \code{"untagged"}, \code{"mixed"} oder
-- \code{"unknown"} (Bootstrap: Doctype im vorigen Lauf nicht
-- eingebunden).}{Returns \code{"tagged"}, \code{"untagged"},
-- \code{"mixed"} or \code{"unknown"} (bootstrap: doctype was not included
-- in the previous run).}
function M.previous_mode(doctype)
  return previous_status[doctype] or "unknown"
end

-- \ldeen*{Kommagetrennte Unit-IDs, die im vorigen Lauf zu @1 gehörten --
-- ausschließlich für die Mix-Warnmeldung.}{Comma-separated unit IDs that
-- belonged to @1 in the previous run -- only used for the mixed-tagging
-- warning message.}{\meta{doctype}}
function M.previous_units_of(doctype)
  return table.concat(previous_units[doctype] or {}, ", ")
end

-- \ldeen*{Wird von \cs{includeunit} nach jedem erfolgreichen Einbindeversuch
-- ausgeführt, gleich ob über den getaggten oder den ungetaggten Pfad. Macht
-- die Einheit sofort (noch im selben Lauf) für spätere @1-Aufrufe in @2
-- sichtbar -- Rückwärtsreferenzen brauchen deshalb keinen zusätzlichen Lauf
-- -- und schreibt sie zusätzlich mitsamt ihrem tatsächlichen Tagging-Status
-- in die Registrierungsdatei für den nächsten Lauf. Die Datei wird beim
-- ersten Schreiben dieses Laufs neu angelegt (nicht angehängt), damit
-- entfernte Einheiten nicht als Karteileichen erhalten
-- bleiben.}{Executed by \cs{includeunit} after every successful inclusion
-- attempt, whether through the tagged or the untagged path. Makes the unit
-- immediately (still within the same run) visible to later @1 calls in @2
-- -- so backward references need no extra run -- and additionally writes
-- it, together with its actual tagging status, to the registration file
-- for the next run. The file is freshly created (not appended to) on this
-- run's first write, so removed units do not linger as stale
-- entries.}{\code{\textbackslash includeunit}}{\code{tagpax\_luatex.known\_units}}
function M.register_unit(unit, doctype, lang, prefix, tagged)
  tagpax_luatex.known_units[identity_key(unit, doctype, lang)] = prefix
  if not write_handle then
    write_handle = assert(io.open(registry_path, "w"))
  end
  write_handle:write(
    unit, "\t", doctype, "\t", lang, "\t", prefix, "\t",
    tagged and "1" or "0", "\n"
  )
  write_handle:flush()
end

return M
