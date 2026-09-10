-- Algorithmic color-series generation for osgstyler.
local M = {}

local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
local function hexrgb(s)
  return tonumber(s:sub(1,2),16)/255, tonumber(s:sub(3,4),16)/255,
         tonumber(s:sub(5,6),16)/255
end
local function lin(x)
  return x <= .04045 and x/12.92 or ((x+.055)/1.055)^2.4
end
local function gam(x)
  return x <= .0031308 and 12.92*x or 1.055*x^(1/2.4)-.055
end
local function rgb_lab(r,g,b)
  r,g,b=lin(r),lin(g),lin(b)
  local l=.4122214708*r+.5363325363*g+.0514459929*b
  local m=.2119034982*r+.6806995451*g+.1073969566*b
  local s=.0883024619*r+.2817188376*g+.6299787005*b
  l,m,s=l^(1/3),m^(1/3),s^(1/3)
  return .2104542553*l+.7936177850*m-.0040720468*s,
         1.9779984951*l-2.4285922050*m+.4505937099*s,
         .0259040371*l+.7827717662*m-.8086757660*s
end
local function lab_rgb(L,a,b)
  local l=(L+.3963377774*a+.2158037573*b)^3
  local m=(L-.1055613458*a-.0638541728*b)^3
  local s=(L-.0894841775*a-1.2914855480*b)^3
  return gam(4.0767416621*l-3.3077115913*m+.2309699292*s),
         gam(-1.2684380046*l+2.6097574011*m-.3413193965*s),
         gam(-.0041960863*l-.7034186147*m+1.7076147010*s)
end
local function lab_lch(L,a,b)
  return L, math.sqrt(a*a+b*b), math.deg(math.atan(b,a))%360
end
local function lch_lab(L,C,h)
  h=math.rad(h); return L,C*math.cos(h),C*math.sin(h)
end
local function gamut(L,C,h)
  local r,g,b,a,bb
  for _=1,30 do
    _,a,bb=lch_lab(L,C,h); r,g,b=lab_rgb(L,a,bb)
    if r>=0 and r<=1 and g>=0 and g<=1 and b>=0 and b<=1 then
      return {L=L,a=a,b=bb,r=r,g=g,blue=b}
    end
    C=C*.92
  end
  return {L=L,a=0,b=0,r=clamp(r,0,1),g=clamp(g,0,1),blue=clamp(b,0,1)}
end
local function record(hex)
  local r,g,b=hexrgb(hex); local L,a,bb=rgb_lab(r,g,b)
  return {L=L,a=a,b=bb,r=r,g=g,blue=b}
end
local function lum(c)
  return .2126*lin(c.r)+.7152*lin(c.g)+.0722*lin(c.blue)
end
local function contrast(a,b)
  local x,y=lum(a),lum(b); if x<y then x,y=y,x end
  return (x+.05)/(y+.05)
end
local function distance(a,b)
  return math.sqrt((a.L-b.L)^2+(a.a-b.a)^2+(a.b-b.b)^2)
end
local function html(c)
  return string.format("%02X%02X%02X",math.floor(clamp(c.r,0,1)*255+.5),
    math.floor(clamp(c.g,0,1)*255+.5),math.floor(clamp(c.blue,0,1)*255+.5))
end

function M.generate_color_series(primary_hex,accent_hex,background_hex,count)
  count=clamp(math.floor(tonumber(count) or 8),2,32)
  local p,a,bg=record(primary_hex),record(accent_hex),record(background_hex)
  local pL,pC,pH=lab_lch(p.L,p.a,p.b)
  local aL,aC,aH=lab_lch(a.L,a.a,a.b)
  local distinct=distance(p,a)>=.055
  local light=lum(bg)>.45
  local targetL=clamp((pL+aL)/2,light and .42 or .62,light and .68 or .84)
  local targetC=clamp(math.max(pC,aC,.11),.11,.20)
  local candidates={}
  local function accessible(c,L,C,h)
    local tries=0
    while contrast(c,bg)<3 and tries<16 do
      L=clamp(L+(light and -.025 or .025),.25,.93); c=gamut(L,C,h); tries=tries+1
    end
    candidates[#candidates+1]=c
  end
  local function anchor(c)
    local L,C,h=lab_lch(c.L,c.a,c.b); accessible(c,L,C,h)
  end
  local function candidate(h,offset)
    local L=clamp(targetL+offset,light and .36 or .56,light and .72 or .88)
    accessible(gamut(L,targetC,h%360),L,targetC,h%360)
  end
  anchor(p); if distinct then anchor(a) end
  for i=1,math.max(48,count*8) do
    local base=(i%2==0 and distinct) and aH or pH
    local offset=({0,.055,-.055})[(i-1)%3+1]
    candidate(base+math.ceil(i/(distinct and 2 or 1))*137.50776405,offset)
  end
  local chosen={table.remove(candidates,1)}
  if distinct then chosen[#chosen+1]=table.remove(candidates,1) end
  while #chosen<count do
    local best,bestscore=1,-1
    for i,c in ipairs(candidates) do
      local score=math.huge
      for _,s in ipairs(chosen) do score=math.min(score,distance(c,s)) end
      if contrast(c,bg)<3 then score=score*.5 end
      if score>bestscore then best,bestscore=i,score end
    end
    chosen[#chosen+1]=table.remove(candidates,best)
  end
  local out={}
  for _,c in ipairs(chosen) do out[#out+1]="{model=HTML,value="..html(c).."}" end
  return table.concat(out,",")
end

return M
