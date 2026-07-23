-- tagpax-compare.lua -- semantic IR comparison for roundtrip tests
local M = {}
local default_role_map = {
  section = "H1", subsection = "H2", subsubsection = "H3",
  ["text-unit"] = "Part", text = "P", item = "LI",
}
local function role_of(role, options)
  local map = options and options.role_map or default_role_map
  return map[role] or role
end
local function by_parent(ir)
  local t={}
  for _,k in ipairs(ir.kids or {}) do
    t[k.parent]=t[k.parent] or {}; t[k.parent][#t[k.parent]+1]=k
  end
  for _,v in pairs(t) do table.sort(v,function(a,b) return tonumber(a.index or 0)<tonumber(b.index or 0) end) end
  return t
end
local function roots(ir)
  local r={}; for _,x in ipairs(ir.roots or {}) do r[#r+1]=x end
  table.sort(r,function(a,b) return tonumber(a.index or 0)<tonumber(b.index or 0) end)
  local o={}; for _,x in ipairs(r) do o[#o+1]=x.node end; return o
end
local function signatures(ir, unwrap_document, options)
  local bp=by_parent(ir); local out={}
  local function walk(id)
    local n=assert(ir.nodes[id],"missing node "..tostring(id))
    out[#out+1]="N:"..tostring(role_of(n.role, options))
    for _,k in ipairs(bp[id] or {}) do
      if k.kind=="node" then walk(k.ref)
      elseif k.kind=="mcr" then out[#out+1]="M:"..tostring(k.mcid)
      elseif k.kind=="objr" then
        local annotation=(ir.annotations or {})[k.ref]
        out[#out+1]="O:"..tostring(annotation and annotation.action or "?")
      end
    end
    out[#out+1]="E:"..tostring(role_of(n.role, options))
  end
  for _,id in ipairs(roots(ir)) do
    local n=ir.nodes[id]
    if unwrap_document and n and n.role=="Document" then
      for _,k in ipairs(bp[id] or {}) do if k.kind=="node" then walk(k.ref) end end
    else walk(id) end
  end
  return out
end
local function all_subtree_signatures(ir, role, options)
  local bp=by_parent(ir); local result={}
  local function sig(id,out)
    local n=ir.nodes[id]; out[#out+1]="N:"..tostring(role_of(n.role, options))
    for _,k in ipairs(bp[id] or {}) do
      if k.kind=="node" then sig(k.ref,out)
      elseif k.kind=="mcr" then out[#out+1]="M:"..tostring(k.mcid)
      elseif k.kind=="objr" then
        local annotation=(ir.annotations or {})[k.ref]
        out[#out+1]="O:"..tostring(annotation and annotation.action or "?")
      end
    end
    out[#out+1]="E:"..tostring(role_of(n.role, options))
  end
  for id,n in pairs(ir.nodes or {}) do if n.role==role then local o={}; sig(id,o); result[#result+1]=o end end
  return result
end
local function equal(a,b)
  if #a~=#b then return false end
  for i=1,#a do if a[i]~=b[i] then return false end end
  return true
end
function M.semantic(source,target,options)
  options=options or {}
  local expected=signatures(source,options.unwrap_source_document~=false,options)
  local candidates=all_subtree_signatures(target,options.target_wrapper_role or "Part",options)
  -- Target wrapper itself is synthetic; compare its children.
  for _,candidate in ipairs(candidates) do
    local stripped={}
    for i=2,#candidate-1 do stripped[#stripped+1]=candidate[i] end
    if equal(expected,stripped) then return true,{} end
  end
  return false,{"no target Part subtree has the source semantic signature", "source="..table.concat(expected,"|" )}
end
return M
