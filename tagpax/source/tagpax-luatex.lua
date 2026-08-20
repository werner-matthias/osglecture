--[[
  Package: tagpax
  Date:
  2026-07-23
  Version:
  v0.8.5-dev
  Description:
  controlled LuaTeX page Form-XObject import
]]
--<*pkg>
local ir_reader = require("tagpax-ir")
local M = { version = "0.8.5-dev" }

-- \ldeen*{Generischer Erweiterungspunkt: ein Konsument (z.\,B. die
-- osglecture-Integrationsschicht) kann diese Funktion setzen, um eine
-- \code{GoToR}-Annotation vor der Emission in einen internen Sprung
-- umzuschreiben. @1 selbst kennt weder osglecture-Semantik noch die
-- Bedeutung etwaiger zusätzlicher Annotationsschlüssel -- die Funktion
-- erhält den vollständigen IR-Annotationsdatensatz und antwortet entweder
-- mit \code{nil} (unverändert als @2 emittieren, der Default) oder mit
-- \code{prefix, page} (als interner Sprung zu
-- \code{tagpax.<prefix>.page.<page>} emittieren -- derselbe
-- Seiten-Zieltyp, den @1 für jede importierte Seite ohnehin schon
-- anlegt).}{Generic extension point: a consumer (e.g. the osglecture
-- integration layer) may set this function to rewrite a \code{GoToR}
-- annotation into an internal jump before emission. @1 itself knows
-- neither osglecture semantics nor the meaning of any extra annotation
-- keys -- the function receives the full IR annotation record and
-- answers either with \code{nil} (emit unchanged as @2, the default) or
-- with \code{prefix, page} (emit as an internal jump to
-- \code{tagpax.<prefix>.page.<page>} -- the same page-destination type
-- @1 already creates for every imported page anyway).}{\code{tagpax}}
-- {\code{GoToR}}
M.resolve_goToR = nil

-- \ldeen*{Nicht von @1 selbst gefüllt oder gelesen -- ein leeres, immer
-- vorhandenes Tabellenobjekt, das ein Konsument (typischerweise über
-- @2) mit eigenen Daten befüllt und aus seiner eigenen @2-Funktion
-- heraus abfragt.}{Not populated or read by @1 itself -- an empty,
-- always-present table object that a consumer (typically via @2)
-- populates with its own data and queries from within its own @2
-- function.}{\code{tagpax}}{\code{resolve\_goToR}}
M.known_units = {}
-- LuaTeX image userdata must stay reachable until shipout has consumed it.
local images = {}

-- \ldeen*{Geöffnete Quell-PDFs bleiben für die Dauer des Laufs offen, siehe
-- @1 unten.}{Opened source PDFs stay open for the duration of the run, see
-- @1 below.}{\code{open\_document}}
local documents = {}

-- TeX/PDF boundary helpers -------------------------------------------------
-- \ldeen*{Escaping stammt aus @1 und wird dort zentral gepflegt.}{Escaping
-- lives in @1 and is maintained there centrally.}{\code{tagpax-ir.lua}}
local tex_escape = ir_reader.tex_escape

local function hex(s)
  return (tostring(s or ""):gsub(".", function(c)
    return string.format("%02X", string.byte(c))
  end))
end

local function page_rotation(page)
  -- Normalize inherited or direct /Rotate values to the four PDF quadrants.
  local rotation = tonumber(page and page.Rotate) or 0
  if pdfe.getinteger then
    local ok, first, second = pcall(pdfe.getinteger, page, "Rotate")
    if ok then rotation = tonumber(second) or tonumber(first) or rotation end
  end
  return ((rotation % 360) + 360) % 360
end

local function page_geometry(media, rotation, target_width, target_height)
  -- This is the single source-to-target transform. The same mapping must drive
  -- link rectangles and destinations or clickable and visible areas diverge.
  local width, height = media[3] - media[1], media[4] - media[2]
  local displayed_width = (rotation == 90 or rotation == 270) and height or width
  local displayed_height = (rotation == 90 or rotation == 270) and width or height
  local scale_x, scale_y = target_width / displayed_width, target_height / displayed_height
  local function point(x, y)
    local u, v = x - media[1], y - media[2]
    local tx, ty
    if rotation == 90 then
      tx, ty = v, width - u
    elseif rotation == 180 then
      tx, ty = width - u, height - v
    elseif rotation == 270 then
      tx, ty = height - v, u
    else
      tx, ty = u, v
    end
    return tx * scale_x, ty * scale_y
  end
  local function rectangle(llx, lly, urx, ury)
    -- Rotate all corners: after a quarter turn the original lower-left and
    -- upper-right are no longer sufficient to define the target rectangle.
    local x1, y1 = point(llx, lly)
    local x2, y2 = point(llx, ury)
    local x3, y3 = point(urx, lly)
    local x4, y4 = point(urx, ury)
    local left = math.min(x1, x2, x3, x4)
    local bottom = math.min(y1, y2, y3, y4)
    local right = math.max(x1, x2, x3, x4)
    local top = math.max(y1, y2, y3, y4)
    return left, bottom, right - left, top - bottom
  end
  return { point = point, rectangle = rectangle }
end
M.page_geometry = page_geometry

local function emit_destination(destination, prefix, image_width, geometry, media, rotation)
  -- Recreate the source view where LaTeX's destination primitives permit it.
  -- `prefix` prevents equal source names in different imports from colliding.
  local name = string.format("tagpax.%s.dest.%s", prefix, destination.id)
  local view = destination.view or "Fit"
  local a1, a2, a3, a4 = tonumber(destination.arg1), tonumber(destination.arg2),
    tonumber(destination.arg3), tonumber(destination.arg4)
  if view == "FitR" and a1 and a2 and a3 and a4 then
    local x, y, width, height = geometry.rectangle(a1, a2, a3, a4)
    tex.sprint(string.format("\\TagPaxRectangleDestination{%.0f}{%.0f}{%.0f}{%.0f}{%.0f}{%s}",
      image_width, x, y, width, height, tex_escape(name)))
    return
  end
  if view == "XYZ" then
    -- PDF null coordinates mean “retain current view”. LaTeX cannot express
    -- that state, so missing values fall back to the corresponding page edge.
    local x, y = geometry.point(a1 or media[1], a2 or media[4])
    local kind = a3 and a3 > 0 and tostring(math.floor(a3 * 100 + 0.5)) or "xyz"
    tex.sprint(string.format("\\TagPaxPointDestination{%.0f}{%.0f}{%.0f}{%s}{%s}",
      image_width, x, y, tex_escape(name), kind))
    return
  end
  local horizontal = view == "FitH" or view == "FitBH"
  local vertical = view == "FitV" or view == "FitBV"
  if horizontal then
    local x, y = geometry.point(media[1], a1 or media[4])
    local kind = view == "FitBH" and "fitbh" or "fith"
    -- A horizontal source constraint becomes vertical after a quarter turn.
    if rotation == 90 or rotation == 270 then
      kind = view == "FitBH" and "fitbv" or "fitv"
    end
    tex.sprint(string.format("\\TagPaxPointDestination{%.0f}{%.0f}{%.0f}{%s}{%s}",
      image_width, x, y, tex_escape(name), kind))
    return
  elseif vertical then
    local x, y = geometry.point(a1 or media[1], media[2])
    local kind = view == "FitBV" and "fitbv" or "fitv"
    if rotation == 90 or rotation == 270 then
      kind = view == "FitBV" and "fitbh" or "fith"
    end
    tex.sprint(string.format("\\TagPaxPointDestination{%.0f}{%.0f}{%.0f}{%s}{%s}",
      image_width, x, y, tex_escape(name), kind))
    return
  end
  local kind = ({ FitB = "fitb" })[view] or "fit"
  tex.sprint("\\TagPaxPageDestination{" .. tex_escape(name) .. "}{" .. kind .. "}")
end

-- \ldeen*{@1 wird einmal pro Seite aufgerufen. Ohne Cache würde @2 die
-- Quell-PDF für jede Seite erneut öffnen -- Öffnen liest Xref und Trailer
-- neu ein, ein reiner Overhead gegenüber einmaligem Öffnen und
-- Wiederverwenden.}{@1 is called once per page. Without caching, @2 would
-- reopen the source PDF for every page -- opening re-reads the xref table
-- and trailer, pure overhead compared to opening once and reusing the
-- result.}{\code{write\_page(...)}}{\code{pdfe.open}}
local function open_document(filename)
  local document = documents[filename]
  if not document then
    document = assert(pdfe.open(filename))
    documents[filename] = document
  end
  return document
end

-- \ldeen{Schließt jedes zwischengespeicherte Quelldokument genau einmal, am
-- Ende des Laufs.}{Closes every cached source document exactly once, at the
-- end of the run.}
luatexbase.add_to_callback("stop_run", function()
  for _, document in pairs(documents) do pdfe.close(document) end
end, "tagpax: close cached source PDFs")

--- Write one source PDF page as a Form XObject into the current TeX list.
-- @param filename source PDF
-- @param page one-based page number
-- @param structparents reserved ParentTree key
-- @param stream_id stable tagpax stream ID
-- @return image userdata (also retained until the end of the run)
function M.write_page(filename, page, structparents, stream_id, irfile, prefix, max_width, max_height)
  -- Phase 1: scan and size the source page, injecting its reserved ParentTree
  -- key into the Form dictionary before LuaTeX creates the object.
  local image = assert(img.scan {
    filename = assert(filename),
    page = assert(tonumber(page)),
    pagebox = "media",
    attr = string.format("/StructParents %d", assert(tonumber(structparents))),
  })
  max_width = tonumber(max_width)
  max_height = tonumber(max_height)
  if max_width and max_height and image.width and image.height then
    local scale = math.min(max_width / image.width, max_height / image.height)
    if scale < 1 or scale > 0 then
      image.width = math.floor(image.width * scale + 0.5)
      image.height = math.floor(image.height * scale + 0.5)
      if image.depth then image.depth = math.floor(image.depth * scale + 0.5) end
    end
  end
  img.write(image)
  assert(image.objnum and image.objnum > 0, "LuaTeX did not allocate an image object")
  images[#images + 1] = image
  local ir = ir_reader.read(irfile)
  -- Phase 2: reopen only for MediaBox and /Rotate. Semantic objects always
  -- come from the already extracted IR.
  local document = open_document(filename)
  local source_page = pdfe.getpage(document, page)
  local media = pdfe.getbox(source_page, "MediaBox")
  if media then
    local rotation = page_rotation(source_page)
    local target_height = image.height + (image.depth or 0)
    local geometry_map = page_geometry(media, rotation, image.width, target_height)
    local page_destinations = {}
    for _, destination in pairs(ir.destinations or {}) do
      if type(destination) == "table" then page_destinations[#page_destinations + 1] = destination end
    end
    table.sort(page_destinations, function(a, b) return tostring(a.id) < tostring(b.id) end)
    for _, destination in ipairs(page_destinations) do
      if tonumber(destination.page) == page then
        emit_destination(destination, prefix, image.width, geometry_map, media, rotation)
      end
    end
    for _, annotation in ipairs(ir.annotations or {}) do
      -- Overlay annotations are target objects, not copied dictionaries. Their
      -- action and transformed rectangle are emitted through the TeX bridge.
      if tonumber(annotation.page) == page then
        local destination = annotation.destination and ir.destinations[annotation.destination]
        if annotation.action ~= "GoTo" or destination then
          local x, y, width, height = geometry_map.rectangle(
            tonumber(annotation.llx), tonumber(annotation.lly),
            tonumber(annotation.urx), tonumber(annotation.ury))
          local geometry = string.format(
            "{%.0f}{%.0f}{%.0f}{%.0f}{%.0f}",
            image.width, x, y, width, height
          )
          if annotation.action == "GoTo" then
            tex.sprint(string.format(
              "\\TagPaxGotoOverlay%s{%s}{tagpax.%s.dest.%s}",
              geometry, tex_escape(annotation.id), tex_escape(prefix),
              tex_escape(destination.id)
            ))
          elseif annotation.action == "URI" then
            tex.sprint(
              "\\TagPaxURIOverlay" .. geometry ..
              "{" .. tex_escape(annotation.id) .. "}{" .. hex(annotation.uri) .. "}"
            )
          elseif annotation.action == "GoToR" then
            local resolved_prefix, resolved_page
            if M.resolve_goToR then
              resolved_prefix, resolved_page = M.resolve_goToR(annotation)
            end
            if resolved_prefix and resolved_page then
              tex.sprint(string.format(
                "\\TagPaxGotoOverlay%s{%s}{tagpax.%s.page.%s}",
                geometry, tex_escape(annotation.id), tex_escape(resolved_prefix),
                tex_escape(tostring(resolved_page))
              ))
            else
              local target = annotation["remote-destination"]
              if target then
                tex.sprint(
                  "\\TagPaxGoToRNameOverlay" .. geometry ..
                  "{" .. tex_escape(annotation.id) .. "}{" ..
                  hex(annotation.file) .. "}{" .. hex(target) .. "}"
                )
              else
                tex.sprint(
                  "\\TagPaxGoToRPageOverlay" .. geometry ..
                  "{" .. tex_escape(annotation.id) .. "}{" .. hex(annotation.file) .. "}{" ..
                  tostring(annotation["remote-page"] or 0) .. "}{" ..
                  tex_escape(annotation["remote-view"] or "Fit") .. "}"
                )
              end
            end
          end
        end
      end
    end
  end
  -- The source document is left open; the stop_run callback registered
  -- below closes every cached document once, at the end of the run.
  -- Phase 3: publish the late Form object reference for MCR binding.
  tex.sprint(string.format(
    "\\TagPaxBackendForm{%s}{%d 0 R}{%s}",
    tex_escape(page), image.objnum, tex_escape(stream_id)
  ))
  return image
end

return M
--</pkg>