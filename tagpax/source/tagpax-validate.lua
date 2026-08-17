-- tagpax-validate.lua -- semantic IR validation
local M = {}
--<*pkg>

-- \ldeen*{Validierung ist kumulativ und für Build-Diagnosen deterministisch
-- genug: Jeder unabhängige Defekt wird gemeldet, statt beim ersten
-- abzubrechen. @1 sammelt die Meldungen; die Felder von @2 selbst sind
-- immer vorbelegt (siehe @3), defensive @4-Fallbacks sind hier deshalb
-- nicht nötig.}{Validation is cumulative and deterministic enough for
-- build diagnostics: every independent defect is reported rather than
-- stopping at the first one. @1 collects the messages; the fields of @2
-- itself are always pre-populated (see @3), so defensive @4 fallbacks are
-- not needed here.}{\code{fail}}{\code{ir}}{\code{tagpax-ir.lua}}{\code{or \{\}}}
function M.validate(ir)
  local errors = {}
  local function fail(message) errors[#errors + 1] = message end

  if not ir.header or tonumber(ir.header.version) ~= 1 then fail("unsupported or missing IR version") end
  if not ir.source then fail("missing source record") end
  for _, root in ipairs(ir.roots) do
    if not ir.nodes[root.node] then fail("root references missing node " .. tostring(root.node)) end
  end
  for id, stream in pairs(ir.streams) do
    if stream.id ~= id then fail("stream id mismatch " .. tostring(id)) end
    if stream.kind ~= "page" and stream.kind ~= "object" then fail("invalid stream kind " .. tostring(stream.kind)) end
    if stream.kind == "page" and tonumber(stream.page) == nil then fail("page stream has invalid page") end
  end
  -- Relations are valid only if both their semantic parent and typed target
  -- exist. MCID zero is valid, hence numeric conversion rather than truthiness.
  for _, kid in ipairs(ir.kids) do
    if not ir.nodes[kid.parent] then fail("kid has missing parent " .. tostring(kid.parent)) end
    if kid.kind == "node" and not ir.nodes[kid.ref] then fail("kid references missing node " .. tostring(kid.ref)) end
    if kid.kind == "objr" and not ir.annotations[kid.ref] then fail("OBJR references missing annotation " .. tostring(kid.ref)) end
    if kid.kind == "mcr" and tonumber(kid.mcid) == nil then fail("MCR has invalid MCID") end
    if kid.kind == "mcr" and next(ir.streams) and not ir.streams[kid.stream] then fail("MCR references missing stream " .. tostring(kid.stream)) end
  end
  for _, heading in ipairs(ir.headings) do
    local node = ir.nodes[heading.node]
    if not node then
      fail("heading references missing node " .. tostring(heading.node))
    elseif node.role ~= heading.role then
      fail("heading role mismatch at " .. heading.node)
    end
  end
  -- Navigation is checked here, before page geometry is ever consulted.
  local page_count = ir.source and tonumber(ir.source.pages)
  for id, destination in pairs(ir.destinations) do
    if destination.id ~= id then fail("destination id mismatch " .. tostring(id)) end
    local page = tonumber(destination.page)
    if not page or page < 1 or (page_count and page > page_count) then
      fail("destination has invalid page " .. tostring(destination.page))
    end
    local view = destination.view or "Fit"
    local supported = { XYZ=true, Fit=true, FitH=true, FitV=true,
      FitR=true, FitB=true, FitBH=true, FitBV=true }
    if not supported[view] then fail("destination has unsupported view " .. tostring(view)) end
    for index = 1, 4 do
      local argument = destination["arg" .. index]
      if argument ~= nil and tonumber(argument) == nil then
        fail("destination has invalid arg" .. index .. " " .. tostring(id))
      end
    end
    if view == "FitR" and
      (not tonumber(destination.arg1) or not tonumber(destination.arg2)
        or not tonumber(destination.arg3) or not tonumber(destination.arg4)) then
      fail("FitR destination has incomplete rectangle " .. tostring(id))
    end
  end
  -- The native writer intentionally supports a narrow, explicit action set.
  for _, annotation in ipairs(ir.annotations) do
    if annotation.subtype ~= "Link"
      or (annotation.action ~= "GoTo"
        and annotation.action ~= "URI"
        and annotation.action ~= "GoToR") then
      fail("unsupported annotation " .. tostring(annotation.id))
    end
    if annotation.action == "GoTo" and not ir.destinations[annotation.destination] then
      fail("annotation references missing destination " .. tostring(annotation.destination))
    end
    if annotation.action == "URI" and not annotation.uri then
      fail("URI annotation has no URI " .. tostring(annotation.id))
    end
    if annotation.action == "GoToR" and
      (not annotation.file or
        (not annotation["remote-destination"] and annotation["remote-page"] == nil)) then
      fail("GoToR annotation has incomplete target " .. tostring(annotation.id))
    end
    if annotation.parent and not ir.nodes[annotation.parent] then
      fail("annotation references missing parent " .. tostring(annotation.parent))
    end
    for _, key in ipairs({"page", "llx", "lly", "urx", "ury"}) do
      if tonumber(annotation[key]) == nil then
        fail("annotation has invalid " .. key .. " " .. tostring(annotation.id))
      end
    end
  end
  return #errors == 0, errors
end

return M
--</pkg>
