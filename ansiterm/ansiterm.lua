--[[
  Package: ansiterm
  Date:
  2026-08-26
  Version:
  v0.2.1
]]
--<*lua>
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

local function dedent(s)
  s=s:gsub("\r\n","\n")
  local margin
  for line in (s.."\n"):gmatch("(.-)\n") do
    if line:find("%S") then
      local indent=#(line:match("^[ \t]*") or "")
      margin=margin and math.min(margin,indent) or indent
    end
  end
  if not margin or margin==0 then return s end
  local out={}
  for line,nl in s:gmatch("([^\n]*)(\n?)") do
    out[#out+1]=line:sub(margin+1)..nl
    if nl=="" then break end
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
    ['_']='\\_',['~']='\\textasciitilde{}',[' ']='\\ '}
  return map[s] or s
end
local function styled(text,state)
  if text=="" then return "" end
  local fg,bg=state.fg,state.bg
  if state.inverse then fg,bg=bg or {248,248,248},fg or {30,30,30} end
  local out={}
  for _,codepoint in utf8.codes(text) do
    local x
    if codepoint==10 then
      out[#out+1]="\n"
      x=""
    elseif codepoint==9 then x=string.rep("\\ ",4)
    elseif codepoint<32 or codepoint==127 then x=""
    else x=tex_escape(state.conceal and " " or utf8.char(codepoint)) end
    if x~="" then
    if fg then x="\\textcolor[RGB]{"..colour(fg).."}{"..x.."}" end
    if bg then x="\\colorbox[RGB]{"..colour(bg).."}{"..x.."}" end
    if state.bold then x="\\textbf{"..x.."}" end
    if state.italic then x="\\textit{"..x.."}" end
    if state.underline then x="\\underline{"..x.."}" end
    if state.strike then x="\\ansitermstrike{"..x.."}" end
    if state.faint then x="\\textcolor{black!55}{"..x.."}" end
    out[#out+1]=x.."\\allowbreak{}"
    end
  end
  return table.concat(out)
end

local function render_ansi(s)
  local result,state,pos={}, {},1
  local function emit(last)
    if last>=pos then result[#result+1]=styled(s:sub(pos,last),state) end
  end
  while pos<=#s do
    local esc=s:find("\27",pos,true)
    if not esc then emit(#s); break end
    emit(esc-1)
    local introducer=s:sub(esc+1,esc+1)
    if introducer=="[" then
      -- A CSI sequence ends in a byte from 0x40 through 0x7e.  SGR (final
      -- byte "m") affects subsequent text; cursor/erasure commands such as
      -- grep's ESC[K have no useful static-page equivalent and are ignored.
      local final=esc+2
      while final<=#s do
        local byte=s:byte(final)
        if byte>=0x40 and byte<=0x7e then break end
        final=final+1
      end
      if final>#s then break end
      if s:sub(final,final)=="m" then
        local params=s:sub(esc+2,final-1)
        if params:match("^[0-9;:]*$") then state=sgr(clone(state),params) end
      end
      pos=final+1
    elseif introducer=="]" then
      -- OSC strings terminate with BEL or ST (ESC backslash).  They carry
      -- terminal metadata such as a window title, not printable content.
      local i=esc+2
      while i<=#s and s:byte(i)~=7
          and not (s:byte(i)==27 and s:sub(i+1,i+1)=="\\") do
        i=i+1
      end
      if i>#s then break end
      pos=(s:byte(i)==7) and i+1 or i+2
    else
      -- Other two-byte escape sequences likewise describe terminal state.
      pos=math.min(#s+1,esc+2)
    end
  end
  return table.concat(result)
end

-- Records keep a per-line "input" (echoed prompt/command) vs "output"
-- (actual command output) kind alongside the text, so that kind survives
-- line selection and can drive the tagged Div grouping in emit\_runs.
local function lines_of(s,kind)
  local out={}; s=s:gsub("\n$","")
  for line in (s.."\n"):gmatch("(.-)\n") do out[#out+1]={kind=kind,text=line} end
  return out
end

local trace_marker="__ANSITERM_INPUT_7E3D1A__"

-- Shell tracing writes a uniquely marked command immediately before that
-- command's output.  Converting the merged stream preserves this order and,
-- unlike echoing the saved source, also handles compound shell constructs.
local function transcript_records(s,script,prompt)
  local source={}
  for line in (script:gsub("\n$","").."\n"):gmatch("(.-)\n") do
    if line:find("%S") and not line:match("^%s*#") then
      source[#source+1]=line
    end
  end
  local records,next_source={},1
  for line in (normalise_controls(s):gsub("\n$","").."\n"):gmatch("(.-)\n") do
    if line:sub(1,#trace_marker)==trace_marker then
      if source[next_source] then
        records[#records+1]={kind="input",text=prompt..source[next_source]}
        next_source=next_source+1
      end
    else
      records[#records+1]={kind="output",text=line}
    end
  end
  return records
end

local function select_records(records,spec,ellipsis)
  local selected={}
  for part in spec:gmatch("[^,%s]+") do
    local a,b=part:match("^(%d*)%-(%d*)$")
    if not a then a=part; b=part end
    a=tonumber(a) or 1; b=tonumber(b) or #records
    for i=math.max(1,a),math.min(#records,b) do selected[i]=true end
  end
  local out,last={},false
  for i,rec in ipairs(records) do
    if selected[i] then out[#out+1]=rec; last=true
    elseif last and ellipsis then
      out[#out+1]={kind="ellipsis",text="\27[2m        ⋮\27[0m"}; last=false
    else last=false end
  end
  return out
end

-- Groups consecutive same-kind records into one rendered run each and
-- wraps input/output runs in the matching \cs{ansitermtag...} macro (defined
-- in ansiterm.dtx); an ellipsis run is emitted bare, it is neither.
local function emit_runs(records)
  local macro={input="\\ansitermtaginput",output="\\ansitermtagoutput"}
  local out,i={},1
  while i<=#records do
    local kind=records[i].kind
    local buf={}
    while i<=#records and records[i].kind==kind do
      buf[#buf+1]=records[i].text; i=i+1
    end
    local body=render_ansi(table.concat(buf,"\n")).."\\par\n"
    if macro[kind] then out[#out+1]=macro[kind].."{%\n"..body.."}\n"
    else out[#out+1]=body end
  end
  return table.concat(out)
end

local function introduce_escape(s,marker)
  if not marker or marker=="" then return s end
  local out,pos={},1
  while pos<=#s do
    local first,last=s:find(marker,pos,true)
    if not first then out[#out+1]=s:sub(pos); break end
    out[#out+1]=s:sub(pos,first-1)
    local next_first,next_last=s:find(marker,last+1,true)
    if next_first==last+1 then
      out[#out+1]=marker; pos=next_last+1
    else
      out[#out+1]="\27"; pos=last+1
    end
  end
  return table.concat(out)
end

function M.render(o)
  local source=dedent(read(o.source,true))
  source=introduce_escape(source,o.escape_char)
  local tex="\\providecommand\\ansitermstrike[1]{#1}\n"
    .."\\raggedright\\sloppy\\obeylines\\parindent=0pt\n"
    ..render_ansi(normalise_controls(source)).."\\par\n"
  write(o.output,tex)
end

function M.run(o)
  mkdir(o.cache_dir)
  local script=dedent(read(o.source,true))
  local key=md5.sumhexa(table.concat({"3",script,o.shell,o.cwd,tostring(o.sandbox),tostring(o.show_input),o.prompt},"\0"))
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
    local runnable=o.cache_dir.."/.script-"..key
    write(runnable,script,true)
    local tracing=o.show_input and "PS4="..quote(trace_marker).." " or ""
    local option=o.show_input and " -x" or ""
    local command="cd "..quote(work).." && "..tracing..quote(o.shell)..option.." "..quote(lfs.currentdir().."/"..runnable).." >"..quote(lfs.currentdir().."/"..raw).." 2>&1"
    status=status_code(os.execute(command)); output=read(raw,true); os.remove(raw)
    os.remove(runnable)
    if o.sandbox then erase_tree(work) end
    if o.cache~="false" then write(cached,output,true); write(meta,tostring(status)) end
  end
  local records
  if o.show_input then records=transcript_records(output,script,o.prompt)
  else records=lines_of(normalise_controls(output),"output") end
  records=select_records(records,o.lines,o.ellipsis)
  local tex="\\providecommand\\ansitermstrike[1]{#1}\n"
    .."\\global\\def\\ansitermstatus{"..status.."}\n\\raggedright\\sloppy\\obeylines\\parindent=0pt\n"
    ..emit_runs(records)
  write(o.output,tex)
end

return M
--</lua>
