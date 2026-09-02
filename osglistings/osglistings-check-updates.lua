#!/usr/bin/env texlua
--[[
  Package: osglistings
  Date:
  2026-08-28
  Version:
  v0.1.0
]]
--<*lua>
-- Standalone staleness check for an osglistings remote-source cache.
-- Runs entirely outside LaTeX/OLLM: one lightweight request per
-- distinct GitHub repo/gist referenced from the cache, not one per
-- cached file (see osglistings.lua's M.check_updates).
--
-- Usage:
--   texlua osglistings-check-updates.lua [--refresh] <cache-dir> [<cache-dir> ...]
--
-- Exit codes: 0 nothing stale (or everything refreshed); 1 stale
-- entries remain; 2 usage error.

local osglistings = require("osglistings")

local refresh = false
local dirs = {}
for _, a in ipairs(arg) do
  if a == "--refresh" then refresh = true
  elseif a == "-h" or a == "--help" then
    io.write("Usage: texlua osglistings-check-updates.lua [--refresh] <cache-dir> [<cache-dir> ...]\n")
    os.exit(0)
  else dirs[#dirs + 1] = a end
end

if #dirs == 0 then
  io.stderr:write("osglistings-check-updates: no cache directory given (try --help)\n")
  os.exit(2)
end

local any_stale_left = false
local had_error = false

for _, cache_dir in ipairs(dirs) do
  io.write(cache_dir .. ":\n")
  local ok, report = pcall(osglistings.check_updates, cache_dir, { refresh = refresh })
  if not ok then
    io.write("  ERROR: " .. tostring(report) .. "\n")
    had_error = true
  else
    if #report == 0 then
      io.write("  (no remote sources cached here)\n")
    end
    for _, e in ipairs(report) do
      if e.error then
        io.write(string.format("  ERROR  %s %s: %s\n", e.type, e.key, e.error))
        had_error = true
      elseif not e.changed then
        io.write(string.format("  up to date   %s %s\n", e.type, e.key))
      else
        local refreshed_set = {}
        for _, loc in ipairs(e.refreshed) do refreshed_set[loc] = true end
        local left = {}
        for _, loc in ipairs(e.stale_files) do
          if not refreshed_set[loc] then left[#left + 1] = loc end
        end
        if #left > 0 then any_stale_left = true end
        local verb = refresh and "refreshed" or "STALE"
        io.write(string.format("  %-12s %s %s (%d file(s))\n", verb, e.type, e.key, #e.stale_files))
        for _, loc in ipairs(e.stale_files) do
          local mark = refreshed_set[loc] and "refreshed" or "stale"
          io.write("    - [" .. mark .. "] " .. loc .. "\n")
        end
      end
    end
  end
end

if had_error then os.exit(2) end
os.exit(any_stale_left and 1 or 0)
--</lua>
