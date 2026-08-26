local M = {}
local lfs = require("lfs")
local md5 = require("md5")

local function read(path, binary)
  local f, err = io.open(path, binary and "rb" or "r")
  if not f then error("ansiterm: " .. err) end
  local s = f:read("*a"); f:close(); return s
end

local function write(path, value, binary)
  local f, err = io.open(path, binary and "wb" or "w")
  if not f then error("ansiterm: " .. err) end
  f:write(value); f:close()
end

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function mkdir(path) lfs.mkdir(path) end
local function status_code(ok, why, code)
  if type(ok) == "number" then return ok end
  if ok then return 0 end
  return tonumber(code) or 1
end

local function erase_tree(path)
  for name in lfs.dir(path) do
    if name ~= "." and name ~= ".." then
      local p = path .. "/" .. name
      if lfs.attributes(p, "mode") == "directory" then erase_tree(p) else os.remove(p) end
    end
  end
  lfs.rmdir(path)
end

local function normalise_controls(s)
  s = s:gsub("\r\n", "\n")
  local out = {}
  for line, nl in s:gmatch("([^\n]*)(\n?)") do
    local cells, cursor = {}, 1
    local i = 1
    while i <= #line do
      local c = line:sub(i,i)
      if c == "\r" then cursor = 1
      elseif c == "\b" then cursor = math.max(1, cursor - 1)
      else cells[cursor] = c; cursor = cursor + 1 end
      i = i + 1
    end
    out[#out+1] = table.concat(cells) .. nl
    if nl == "" then break end
  end
  return table.concat(out)
end

local palette = {
  [0]={0,0,0}, {205,49,49}, {13,188,121}, {229,229,16},
  {36,114,200}, {188,63,188}, {17,168,205}, {229,229,229},
  {102,102,102}, {241,76,76}, {35,209,139}, {245,245,67},
  {59,142,234}, {214,112,214}, {41,184,219}, {255,255,255}
}
local function rgb256(n)
  if n < 16 then return table.unpack(palette[n]) end
  if n < 232 then
    n = n - 16; local r=math.floor(n/36); local g=math.floor(n%36/6); local b=n%6
    local function v(x) return x == 0 and 0 or 55 + 40*x end
    return v(r),v(g),v(b)
  end
  local v=8+10*(n-232); return v,v,v
end
local function colour(rgb) return rgb and string.format("%d,%d,%d", rgb[1],rgb[2],rgb[3]) end
local function clone(s)
  local t={}; for k,v in pairs(s) do t[k]=type(v)=="table" and {table.unpack(v)} or v end; return t
end
local function sgr(state, raw)
  local p={}; raw=(raw=="" and "0" or raw)
  for n in raw:gmatch("[^;:]+") do p[#p+1]=tonumber(n) or 0 end
  local i=1
  while i<=#p do
    local n=p[i]
    if n==0 then state={}
    elseif n==1 then state.bold=true elseif n==2 then state.faint=true
    elseif n==3 then state.italic=true elseif n==4 then state.underline=true
    elseif n==7 then state.inverse=true elseif n==8 then state.conceal=true
    elseif n==9 then state.strike=true elseif n==22 then state.bold=nil;state.faint=nil
    elseif n==23 then state.italic=nil elseif n==24 then state.underline=nil
    elseif n==27 then state.inverse=nil elseif n==28 then state.conceal=nil
    elseif n==29 then state.strike=nil elseif n==39 then state.fg=nil
    elseif n==49 then state.bg=nil
    elseif n>=30 and n<=37 then state.fg={table.unpack(palette[n-30])}
    elseif n>=40 and n<=47 then state.bg={table.unpack(palette[n-40])}
    elseif n>=90 and n<=97 then state.fg={table.unpack(palette[n-90+8])}
    elseif n>=100 and n<=107 then state.bg={table.unpack(palette[n-100+8])}
    elseif (n==38 or n==48) and p[i+1]==5 and p[i+2] then
      local r,g,b=rgb256(p[i+2]); state[n==38 and "fg" or "bg"]={r,g,b}; i=i+2
    elseif (n==38 or n==48) and p[i+1]==2 and p[i+4] then
      state[n==38 and "fg" or "bg"]={p[i+2],p[i+3],p[i+4]}; i=i+4
    end
    i=i+1
  end
  return state
end

local function tex_escape(s)
  local map={['\\']='\\textbackslash{}',['{']='\\{',['}']='\\}',['#']='\\#',
    ['$']='\\$',['%']='\\%',['&']='\\&',['^']='\\textasciicircum{}',
    ['_']='\\_',['~']='\\textasciitilde{}',[' ']='~'}
  return (s:gsub("[\\{}#$%%&%^_~ ]",map))
end
local function styled(text,state)
  if text=="" then return "" end
  if state.conceal then text=string.rep(" ",#text) end
  local fg,bg=state.fg,state.bg
  if state.inverse then fg,bg=bg or {248,248,248},fg or {30,30,30} end
  local x=tex_escape(text)
  if fg then x="\\textcolor[RGB]{"..colour(fg).."}{"..x.."}" end
  if bg then x="\\colorbox[RGB]{"..colour(bg).."}{"..x.."}" end
  if state.bold then x="\\textbf{"..x.."}" end
  if state.italic then x="\\textit{"..x.."}" end
  if state.underline then x="\\underline{"..x.."}" end
  if state.strike then x="\\ansitermstrike{"..x.."}" end
  if state.faint then x="\\textcolor{black!55}{"..x.."}" end
  return x
end

local function render_ansi(s)
  local result,state,pos={}, {},1
  while true do
    local a,b,params=s:find("\27%[([0-9;:]*)m",pos)
    if not a then result[#result+1]=styled(s:sub(pos),state); break end
    result[#result+1]=styled(s:sub(pos,a-1),state)
    state=sgr(clone(state),params); pos=b+1
  end
  return table.concat(result)
end

local function select_lines(s,spec,ellipsis)
  local lines={}; s=s:gsub("\n$","")
  for line in (s.."\n"):gmatch("(.-)\n") do lines[#lines+1]=line end
  local selected={}
  for part in spec:gmatch("[^,%s]+") do
    local a,b=part:match("^(%d*)%-(%d*)$")
    if not a then a=part; b=part end
    a=tonumber(a) or 1; b=tonumber(b) or #lines
    for i=math.max(1,a),math.min(#lines,b) do selected[i]=true end
  end
  local out,last={},false
  for i,line in ipairs(lines) do
    if selected[i] then out[#out+1]=line; last=true
    elseif last and ellipsis then out[#out+1]="\27[2m        ⋮\27[0m"; last=false
    else last=false end
  end
  return table.concat(out,"\n")
end

function M.run(o)
  mkdir(o.cache_dir)
  local script=read(o.source,true)
  local key=md5.sumhexa(table.concat({script,o.shell,o.cwd,tostring(o.sandbox),tostring(o.show_input),o.prompt},"\0"))
  local cached=o.cache_dir.."/"..key..".out"
  local meta=o.cache_dir.."/"..key..".status"
  local output,status
  if o.cache=="true" and lfs.attributes(cached) and lfs.attributes(meta) then
    output=read(cached,true); status=tonumber(read(meta)) or 1
  else
    local work=o.cwd
    if o.sandbox then
      work=o.cache_dir.."/.run-"..key.."-"..tostring(math.random(100000,999999)); assert(lfs.mkdir(work))
    end
    local raw=o.cache_dir.."/.output-"..key
    local command="cd "..quote(work).." && "..quote(o.shell).." "..quote(lfs.currentdir().."/"..o.source).." >"..quote(lfs.currentdir().."/"..raw).." 2>&1"
    status=status_code(os.execute(command)); output=read(raw,true); os.remove(raw)
    if o.sandbox then erase_tree(work) end
    if o.cache~="false" then write(cached,output,true); write(meta,tostring(status)) end
  end
  if o.show_input then
    local shown={}; for line in (script:gsub("\n$","").."\n"):gmatch("(.-)\n") do shown[#shown+1]=o.prompt..line end
    output=table.concat(shown,"\n").."\n"..output
  end
  output=select_lines(normalise_controls(output),o.lines,o.ellipsis)
  local tex="\\providecommand\\ansitermstrike[1]{#1}\n"
    .."\\global\\def\\ansitermstatus{"..status.."}\n\\raggedright\\sloppy\\obeylines\\parindent=0pt\n"
    ..render_ansi(output).."\\par\n"
  write(o.output,tex)
end

return M
