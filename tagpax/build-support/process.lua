-- Portable process helpers for tagpax's l3build support.
local M = {}
local windows = package.config:sub(1,1) == "\\"

local function quote_posix(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end
local function quote_windows(s)
  return '"' .. tostring(s):gsub('"', '\\"') .. '"'
end
function M.quote(s)
  return windows and quote_windows(s) or quote_posix(s)
end
function M.command(program, args)
  local p = { M.quote(program) }
  for _, a in ipairs(args or {}) do p[#p+1] = M.quote(a) end
  return table.concat(p, " ")
end
local function status(a,b,c)
  if type(a) == "number" then return a end
  if a == true then return 0 end
  return tonumber(c) or 1
end
function M.run(program,args,opts)
  opts = opts or {}
  local cmd = M.command(program,args)
  if opts.stdout then cmd = cmd .. " >" .. M.quote(opts.stdout)
  elseif opts.quiet then cmd = cmd .. (windows and " >NUL" or " >/dev/null") end
  if opts.stderr then cmd = cmd .. " 2>" .. M.quote(opts.stderr)
  elseif opts.quiet then cmd = cmd .. (windows and " 2>NUL" or " 2>/dev/null") end
  if not opts.silent then print("tagpax: " .. cmd) end
  return status(os.execute(cmd))
end
function M.capture(program,args,opts)
  opts = opts or {}
  local tmp = os.tmpname()
  local cmd = M.command(program,args) .. " >" .. M.quote(tmp) .. " 2>&1"
  if not opts.silent then print("tagpax: " .. M.command(program,args)) end
  local code = status(os.execute(cmd))
  local f = io.open(tmp,"rb")
  local out = f and (f:read("*a") or "") or ""
  if f then f:close() end
  os.remove(tmp)
  return code == 0, out, code
end
function M.exists(program)
  if windows then
    return M.run("where",{program},{quiet=true,silent=true}) == 0
  end
  return M.run("sh",{"-c","command -v " .. M.quote(program)},{quiet=true,silent=true}) == 0
end
return M
