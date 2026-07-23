-- tagpax-validate.lua -- semantic IR validation
local M = {}

function M.validate(ir)
  -- Validation is cumulative and deterministic enough for build diagnostics:
  -- report every independent defect rather than stopping at the first one.
  local errors = {}
  if not ir.header or tonumber(ir.header.version) ~= 1 then errors[#errors + 1] = "unsupported or missing IR version" end
  if not ir.source then errors[#errors + 1] = "missing source record" end
  for _, root in ipairs(ir.roots) do
    if not ir.nodes[root.node] then errors[#errors + 1] = "root references missing node " .. tostring(root.node) end
  end
  for id, stream in pairs(ir.streams or {}) do
    if stream.id ~= id then errors[#errors + 1] = "stream id mismatch " .. tostring(id) end
    if stream.kind ~= "page" and stream.kind ~= "object" then errors[#errors + 1] = "invalid stream kind " .. tostring(stream.kind) end
    if stream.kind == "page" and tonumber(stream.page) == nil then errors[#errors + 1] = "page stream has invalid page" end
  end
  -- Relations are valid only if both their semantic parent and typed target
  -- exist. MCID zero is valid, hence numeric conversion rather than truthiness.
  for _, kid in ipairs(ir.kids) do
    if not ir.nodes[kid.parent] then errors[#errors + 1] = "kid has missing parent " .. tostring(kid.parent) end
    if kid.kind == "node" and not ir.nodes[kid.ref] then errors[#errors + 1] = "kid references missing node " .. tostring(kid.ref) end
    if kid.kind == "objr" and not (ir.annotations or {})[kid.ref] then errors[#errors + 1] = "OBJR references missing annotation " .. tostring(kid.ref) end
    if kid.kind == "mcr" and tonumber(kid.mcid) == nil then errors[#errors + 1] = "MCR has invalid MCID" end
    if kid.kind == "mcr" and ir.streams and next(ir.streams) and not ir.streams[kid.stream] then errors[#errors + 1] = "MCR references missing stream " .. tostring(kid.stream) end
  end
  for _, heading in ipairs(ir.headings) do
    local node = ir.nodes[heading.node]
    if not node then errors[#errors + 1] = "heading references missing node " .. tostring(heading.node)
    elseif node.role ~= heading.role then errors[#errors + 1] = "heading role mismatch at " .. heading.node end
  end
  -- Navigation is checked here, before page geometry is ever consulted.
  local page_count = ir.source and tonumber(ir.source.pages)
  for id, destination in pairs(ir.destinations or {}) do
    if destination.id ~= id then errors[#errors + 1] = "destination id mismatch " .. tostring(id) end
    local page = tonumber(destination.page)
    if not page or page < 1 or (page_count and page > page_count) then
      errors[#errors + 1] = "destination has invalid page " .. tostring(destination.page)
    end
    local view = destination.view or "Fit"
    local supported = { XYZ=true, Fit=true, FitH=true, FitV=true,
      FitR=true, FitB=true, FitBH=true, FitBV=true }
    if not supported[view] then errors[#errors + 1] = "destination has unsupported view " .. tostring(view) end
    for index = 1, 4 do
      local argument = destination["arg" .. index]
      if argument ~= nil and tonumber(argument) == nil then
        errors[#errors + 1] = "destination has invalid arg" .. index .. " " .. tostring(id)
      end
    end
    if view == "FitR" and
      (not tonumber(destination.arg1) or not tonumber(destination.arg2)
        or not tonumber(destination.arg3) or not tonumber(destination.arg4)) then
      errors[#errors + 1] = "FitR destination has incomplete rectangle " .. tostring(id)
    end
  end
  -- The native writer intentionally supports a narrow, explicit action set.
  for _, annotation in ipairs(ir.annotations or {}) do
    if annotation.subtype ~= "Link"
      or (annotation.action ~= "GoTo"
        and annotation.action ~= "URI"
        and annotation.action ~= "GoToR") then
      errors[#errors + 1] = "unsupported annotation " .. tostring(annotation.id)
    end
    if annotation.action == "GoTo" and not (ir.destinations or {})[annotation.destination] then
      errors[#errors + 1] = "annotation references missing destination " .. tostring(annotation.destination)
    end
    if annotation.action == "URI" and not annotation.uri then
      errors[#errors + 1] = "URI annotation has no URI " .. tostring(annotation.id)
    end
    if annotation.action == "GoToR" and
      (not annotation.file or
        (not annotation["remote-destination"] and annotation["remote-page"] == nil)) then
      errors[#errors + 1] = "GoToR annotation has incomplete target " .. tostring(annotation.id)
    end
    if annotation.parent and not ir.nodes[annotation.parent] then
      errors[#errors + 1] = "annotation references missing parent " .. tostring(annotation.parent)
    end
    for _, key in ipairs({"page", "llx", "lly", "urx", "ury"}) do
      if tonumber(annotation[key]) == nil then
        errors[#errors + 1] = "annotation has invalid " .. key .. " " .. tostring(annotation.id)
      end
    end
  end
  return #errors == 0, errors
end

return M
