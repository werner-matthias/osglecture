--[[
  Package: osglistings
  Date:
  2026-08-28
  Version:
  v0.1.0
]]
--<*lua>
local M = {}
local lfs = require("lfs")
local md5 = require("md5")

-- ============================================================
-- generic helpers (same shape as ansiterm.lua)
-- ============================================================
local function read(path, binary)
  local f, err = io.open(path, binary and "rb" or "r")
  if not f then error("osglistings: " .. err) end
  local s = f:read("*a"); f:close(); return s
end

local function write(path, value, binary)
  local f, err = io.open(path, binary and "wb" or "w")
  if not f then error("osglistings: " .. err) end
  f:write(value); f:close()
end

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function mkdir(path) lfs.mkdir(path) end
local function now_iso() return os.date("!%Y-%m-%dT%H:%M:%SZ") end

-- ============================================================
-- locator validation -- an allow-list, not just quoting, so a
-- malformed/hostile locator is rejected before it ever reaches a
-- curl command line, rather than relying solely on quote() being
-- bug-free.
-- ============================================================
local function is_safe_component(s)
  return s ~= nil and s ~= "" and s:match("^[%w%-%._~]+$") ~= nil
end
local function is_safe_path(s)
  return s ~= nil and s ~= "" and s:match("^[%w%-%._~/]+$") ~= nil
    and not s:find("%.%.")
end

-- ============================================================
-- locator parsing: "github:<owner>/<repo>@<ref>/<path>"
--                  "gist:<owner>/<gist-id>/<filename>"
-- ============================================================
local function parse_locator(locator)
  local owner, repo, ref, path = locator:match("^github:([^/]+)/([^@/]+)@([^/]+)/(.+)$")
  if owner then
    if not (is_safe_component(owner) and is_safe_component(repo)
        and is_safe_component(ref) and is_safe_path(path)) then
      error("osglistings: unsafe characters in locator '" .. locator .. "'")
    end
    return {
      kind = "github", owner = owner, repo = repo, ref = ref, path = path,
      source_key = owner .. "/" .. repo .. "@" .. ref, file_key = path,
    }
  end
  local gowner, gid, fname = locator:match("^gist:([^/]+)/([^/]+)/(.+)$")
  if gowner then
    if not (is_safe_component(gowner) and is_safe_component(gid) and is_safe_path(fname)) then
      error("osglistings: unsafe characters in locator '" .. locator .. "'")
    end
    return {
      kind = "gist", owner = gowner, id = gid, file = fname,
      source_key = gowner .. "/" .. gid, file_key = fname,
    }
  end
  return nil
end
M.parse_locator = parse_locator

function M.is_remote(locator)
  return locator ~= nil and (locator:match("^gist:") ~= nil or locator:match("^github:") ~= nil)
end

-- RFC 3986 percent-encoding, for splicing arbitrary source text into an
-- editor-url query string (the {CODE} placeholder).
function M.percent_encode(s)
  return (s:gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
end

-- Plain (non-pattern) single-occurrence substring replacement. Used
-- instead of string.gsub for splicing values into a URL template: the
-- values (percent-encoded source, a gist id) may contain "%", which
-- gsub's replacement-string syntax would misinterpret as a capture
-- reference -- plain concatenation sidesteps that entirely.
function M.replace_once(s, needle, replacement)
  local i, j = s:find(needle, 1, true)
  if not i then return s end
  return s:sub(1, i - 1) .. replacement .. s:sub(j + 1)
end

-- ============================================================
-- HTTP via curl (texlua has no ssl.https, so -- like ansiterm.lua
-- shelling out for its own commands -- this goes through the shell,
-- not a native socket).
-- ============================================================
local function http_get(url, headers, out_body_path)
  local hdr_args = {}
  for _, h in ipairs(headers or {}) do
    hdr_args[#hdr_args + 1] = "-H " .. quote(h)
  end
  local header_file = os.tmpname()
  local cmd = "curl -s -L -D " .. quote(header_file) .. " -o " .. quote(out_body_path)
    .. " -w '%{http_code}' " .. table.concat(hdr_args, " ") .. " -- " .. quote(url)
  local p = io.popen(cmd)
  local out = p:read("*a") or ""
  p:close()
  local status = tonumber(out:match("(%d+)%s*$"))
  local header_text = ""
  if lfs.attributes(header_file) then
    header_text = read(header_file, true); os.remove(header_file)
  end
  local etag = header_text:match("[Ee][Tt][Aa][Gg]:%s*([^\r\n]+)")
  if etag then etag = etag:gsub("%s+$", "") end
  return status, etag
end

local function auth_headers(extra)
  local h = {}
  if extra then for _, v in ipairs(extra) do h[#h + 1] = v end end
  local token = os.getenv("GITHUB_TOKEN")
  if token and token ~= "" then h[#h + 1] = "Authorization: Bearer " .. token end
  h[#h + 1] = "User-Agent: osglistings"
  return h
end

-- ============================================================
-- minimal hand-rolled JSON decoder -- just enough for GitHub's
-- gist/compare responses (objects, arrays, strings, numbers,
-- true/false/null); no external dependency beyond the Lua that
-- already ships with texlua/LuaTeX.
-- ============================================================
local json_decode
do
  local decode_value
  local function skip_ws(s, i) local _, e = s:find("^%s*", i); return e + 1 end
  local function decode_string(s, i)
    i = i + 1
    local out = {}
    while true do
      local c = s:sub(i, i)
      if c == "" then error("osglistings: unterminated JSON string") end
      if c == '"' then return table.concat(out), i + 1 end
      if c == "\\" then
        local e = s:sub(i + 1, i + 1)
        local map = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
        if map[e] then out[#out + 1] = map[e]; i = i + 2
        elseif e == "u" then
          local hex = s:sub(i + 2, i + 5)
          local cp = tonumber(hex, 16) or 0x3F
          out[#out + 1] = (utf8 and utf8.char(cp)) or "?"
          i = i + 6
        else out[#out + 1] = e; i = i + 2 end
      else out[#out + 1] = c; i = i + 1 end
    end
  end
  local function decode_array(s, i)
    i = skip_ws(s, i + 1)
    local out = {}
    if s:sub(i, i) == "]" then return out, i + 1 end
    while true do
      local v; v, i = decode_value(s, i); out[#out + 1] = v
      i = skip_ws(s, i)
      local c = s:sub(i, i)
      if c == "," then i = skip_ws(s, i + 1)
      elseif c == "]" then return out, i + 1
      else error("osglistings: malformed JSON array") end
    end
  end
  local function decode_object(s, i)
    i = skip_ws(s, i + 1)
    local out = {}
    if s:sub(i, i) == "}" then return out, i + 1 end
    while true do
      if s:sub(i, i) ~= '"' then error("osglistings: malformed JSON object key") end
      local k; k, i = decode_string(s, i)
      i = skip_ws(s, i)
      if s:sub(i, i) ~= ":" then error("osglistings: malformed JSON object") end
      i = skip_ws(s, i + 1)
      local v; v, i = decode_value(s, i); out[k] = v
      i = skip_ws(s, i)
      local c = s:sub(i, i)
      if c == "," then i = skip_ws(s, i + 1)
      elseif c == "}" then return out, i + 1
      else error("osglistings: malformed JSON object") end
    end
  end
  decode_value = function(s, i)
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == '"' then return decode_string(s, i)
    elseif c == "{" then return decode_object(s, i)
    elseif c == "[" then return decode_array(s, i)
    elseif s:sub(i, i + 3) == "true" then return true, i + 4
    elseif s:sub(i, i + 4) == "false" then return false, i + 5
    elseif s:sub(i, i + 3) == "null" then return nil, i + 4
    else
      local numstr = s:match("^-?%d+%.?%d*[eE]?[%-+]?%d*", i)
      if numstr and numstr ~= "" then return tonumber(numstr), i + #numstr end
      error("osglistings: malformed JSON value")
    end
  end
  json_decode = function(s) return (decode_value(s, 1)) end
end
M._json_decode = json_decode

-- ============================================================
-- TSV-backed cache index: sources.tsv (one row per cached locator)
-- and origins.tsv (one row per distinct repo/gist -- the grouping
-- the batch staleness check works from).
-- ============================================================
local function tsv_read(path)
  local rows = {}
  if not lfs.attributes(path) then return rows end
  for line in io.lines(path) do
    if line ~= "" then
      local fields = {}
      for f in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = f end
      rows[#rows + 1] = fields
    end
  end
  return rows
end
local function tsv_rewrite(path, rowlist)
  local lines = {}
  for _, fields in ipairs(rowlist) do lines[#lines + 1] = table.concat(fields, "\t") end
  write(path, table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
end

local function sources_path(cache_dir) return cache_dir .. "/sources.tsv" end
-- row: locator, source_type, source_key, file_key, cache_hash, content_md5, fetched_at
local function sources_upsert(cache_dir, row)
  local rows = tsv_read(sources_path(cache_dir))
  local replaced = false
  for _, r in ipairs(rows) do
    if r[1] == row[1] then
      for i = 1, 7 do r[i] = row[i] end
      replaced = true; break
    end
  end
  if not replaced then rows[#rows + 1] = row end
  tsv_rewrite(sources_path(cache_dir), rows)
end

local function origins_path(cache_dir) return cache_dir .. "/origins.tsv" end
-- row: source_type, source_key, content_sha, etag, checked_at
local function origins_get(cache_dir, source_key)
  for _, r in ipairs(tsv_read(origins_path(cache_dir))) do
    if r[2] == source_key then return { type = r[1], key = r[2], sha = r[3], etag = r[4], checked_at = r[5] } end
  end
  return nil
end
local function origins_upsert(cache_dir, source_type, source_key, sha, etag)
  local rows = tsv_read(origins_path(cache_dir))
  local replaced = false
  for _, r in ipairs(rows) do
    if r[2] == source_key then
      r[1] = source_type; r[3] = sha; r[4] = etag or ""; r[5] = now_iso()
      replaced = true; break
    end
  end
  if not replaced then rows[#rows + 1] = { source_type, source_key, sha, etag or "", now_iso() } end
  tsv_rewrite(origins_path(cache_dir), rows)
end

-- ============================================================
-- GitHub repositories
-- ============================================================
local function github_current_sha(owner, repo, ref)
  local tmp = os.tmpname()
  local url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/commits/" .. ref
  local status = http_get(url, auth_headers({ "Accept: application/vnd.github.sha" }), tmp)
  local body = read(tmp, true); os.remove(tmp)
  if status == 200 then return (body:gsub("%s+$", "")) end
  if status == 403 then error("osglistings: GitHub API rate limit hit; set GITHUB_TOKEN to raise it") end
  error("osglistings: could not resolve HEAD of " .. owner .. "/" .. repo .. "@" .. ref
    .. " (HTTP " .. tostring(status) .. ")")
end

local function github_fetch_content(loc)
  local tmp = os.tmpname()
  local url = "https://raw.githubusercontent.com/" .. loc.owner .. "/" .. loc.repo
    .. "/" .. loc.ref .. "/" .. loc.path
  local status = http_get(url, auth_headers(), tmp)
  local body = read(tmp, true); os.remove(tmp)
  if status ~= 200 then error("osglistings: could not fetch " .. url .. " (HTTP " .. tostring(status) .. ")") end
  return body
end

-- Precisely which paths changed between two commits of one repo --
-- lets a moved ref invalidate only the cached files it actually
-- touched, not the whole repo's cache.
local function github_compare(owner, repo, old_sha, new_sha)
  local tmp = os.tmpname()
  local url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/compare/" .. old_sha .. "..." .. new_sha
  local status = http_get(url, auth_headers(), tmp)
  local body = read(tmp, true); os.remove(tmp)
  if status ~= 200 then return nil end
  local ok, data = pcall(json_decode, body)
  if not ok then return nil end
  local changed = {}
  for _, f in ipairs(data.files or {}) do changed[f.filename] = true end
  return changed
end

-- ============================================================
-- Gists -- one GET already carries every file's current content,
-- so "check" and "refresh" collapse into the same request.
-- ============================================================
local function gist_fetch(gid, etag)
  local tmp = os.tmpname()
  local url = "https://api.github.com/gists/" .. gid
  local headers = auth_headers()
  if etag and etag ~= "" then headers[#headers + 1] = "If-None-Match: " .. etag end
  local status, new_etag = http_get(url, headers, tmp)
  local body = read(tmp, true); os.remove(tmp)
  if status == 304 then return nil, nil, new_etag end
  if status == 403 then error("osglistings: GitHub API rate limit hit; set GITHUB_TOKEN to raise it") end
  if status ~= 200 then error("osglistings: could not fetch gist " .. gid .. " (HTTP " .. tostring(status) .. ")") end
  local data = json_decode(body)
  local version = (data.history and data.history[1] and data.history[1].version) or data.updated_at or ""
  return data, version, new_etag
end

local function gist_file_content(data, filename)
  local f = data.files and data.files[filename]
  if not f then return nil end
  if f.truncated then
    local tmp = os.tmpname()
    local status = http_get(f.raw_url, auth_headers(), tmp)
    local body = read(tmp, true); os.remove(tmp)
    if status ~= 200 then error("osglistings: could not fetch truncated gist file '" .. filename .. "'") end
    return body
  end
  return f.content or ""
end

-- ============================================================
-- character/token-level marks: splice \osglistingsmark{name} at
-- exact positions into a copy of the source, for later tikz
-- "remember picture" overlays. Positions are resolved against the
-- ORIGINAL content so that multiple marks never see one another's
-- offsets shift underfoot; the splice itself then runs back-to-front
-- (highest offset first).
-- ============================================================

-- Comma-splits a marks= spec while treating anything inside a pair of
-- double quotes as opaque, so a substring like "a, b" in an after/before
-- entry doesn't get cut in half.
local function split_marks_spec(spec)
  local entries, buf, in_quotes = {}, {}, false
  local i, n = 1, #spec
  while i <= n do
    local c = spec:sub(i, i)
    if c == '"' then
      in_quotes = not in_quotes
      buf[#buf + 1] = c
    elseif c == "," and not in_quotes then
      entries[#entries + 1] = table.concat(buf)
      buf = {}
    else
      buf[#buf + 1] = c
    end
    i = i + 1
  end
  local last = table.concat(buf)
  if last:match("%S") then entries[#entries + 1] = last end
  return entries
end

local function parse_mark_entry(entry)
  entry = entry:match("^%s*(.-)%s*$")
  if entry == "" then return nil end
  local name, line, col = entry:match('^(%S+)%s+at%s+(%d+):(%d+)$')
  if name then
    return { name = name, kind = "at", line = tonumber(line), col = tonumber(col) }
  end
  local dname, dir, needle, rest = entry:match('^(%S+)%s+(after)%s+"(.-)"%s*(.-)$')
  if not dname then dname, dir, needle, rest = entry:match('^(%S+)%s+(before)%s+"(.-)"%s*(.-)$') end
  if dname then
    local occurrence = tonumber(rest:match('occurrence%s*=%s*(%d+)')) or 1
    return { name = dname, kind = dir, needle = needle, occurrence = occurrence }
  end
  error("osglistings: could not parse mark entry '" .. entry .. "'")
end

-- (line, col) is 1-based with col counted in *characters*, matching how
-- a person reading the source would point at a position -- resolved via
-- utf8.offset so a multi-byte character (Cyrillic comments, symbols,
-- see the unicode regression test) counts as one column, not one per byte.
local function line_col_to_offset(content, line, col)
  local pos, lineno = 1, 1
  while lineno < line do
    local nl = content:find("\n", pos, true)
    if not nl then error("osglistings: mark line " .. line .. " is past the end of the file") end
    pos = nl + 1
    lineno = lineno + 1
  end
  local nl = content:find("\n", pos, true)
  local line_text = content:sub(pos, (nl and nl - 1) or #content)
  local char_len = utf8.len(line_text) or #line_text
  if col < 1 or col > char_len + 1 then
    error("osglistings: mark column " .. col .. " is out of range on line " .. line)
  end
  local byte_off_in_line = (col <= char_len) and (utf8.offset(line_text, col) - 1) or #line_text
  return pos + byte_off_in_line
end

-- Literal (non-pattern) search for the Nth occurrence of needle;
-- returns the splice offset right before it ("before") or right after
-- it ("after").
local function nth_occurrence_offset(content, needle, occurrence, before)
  local from, count = 1, 0
  while true do
    local s, e = content:find(needle, from, true)
    if not s then
      error("osglistings: could not find occurrence " .. occurrence .. ' of "' .. needle .. '"')
    end
    count = count + 1
    if count == occurrence then return before and s or (e + 1) end
    from = s + 1
  end
end

-- ============================================================
-- public: M.inject_marks -- compile-time entry point for the `marks`
-- key of \osglistinginput. Always regenerates its output (no
-- content-hash cache-skip like M.fetch): this is a cheap, local, fully
-- deterministic text transform with no network cost to amortize, and
-- skipping it would leave a stale marked-up copy behind after a local
-- source edit that left path/marks/escape unchanged.
-- ============================================================
function M.inject_marks(o)
  local content = read(o.path, true)

  local resolved = {}
  for _, raw in ipairs(split_marks_spec(o.marks)) do
    local e = parse_mark_entry(raw)
    local offset
    if e.kind == "at" then
      offset = line_col_to_offset(content, e.line, e.col)
    else
      offset = nth_occurrence_offset(content, e.needle, e.occurrence, e.kind == "before")
    end
    resolved[#resolved + 1] = { offset = offset, name = e.name }
  end
  table.sort(resolved, function(a, b) return a.offset > b.offset end)

  local marked = content
  for _, r in ipairs(resolved) do
    local insert = o.escape_open .. "\\osglistingsmark{" .. r.name .. "}" .. o.escape_close
    marked = marked:sub(1, r.offset - 1) .. insert .. marked:sub(r.offset)
  end

  mkdir(o.cache_dir)
  local hash = md5.sumhexa(o.path .. "\1" .. o.marks .. "\1" .. o.escape_open .. "\1" .. o.escape_close)
  local out_path = o.cache_dir .. "/" .. hash .. ".marked"
  write(out_path, marked, true)
  return out_path
end

-- ============================================================
-- public: M.fetch -- compile-time entry point
-- ============================================================
function M.fetch(o)
  local locator, cache_dir = o.locator, o.cache_dir
  local cache_mode = o.cache or "true"
  local loc = parse_locator(locator)
  if not loc then error("osglistings: not a remote locator: " .. tostring(locator)) end
  mkdir(cache_dir)
  local cache_hash = md5.sumhexa(locator)
  local content_path = cache_dir .. "/" .. cache_hash .. ".content"
  if cache_mode ~= "refresh" and lfs.attributes(content_path) then
    return content_path
  end

  local content, sha, etag
  if loc.kind == "github" then
    content = github_fetch_content(loc)
    sha = github_current_sha(loc.owner, loc.repo, loc.ref)
  else
    local data, version, new_etag = gist_fetch(loc.id)
    -- first fetch of this gist can't legally 304 (no stored etag yet)
    content = gist_file_content(data, loc.file)
    if not content then error("osglistings: gist " .. loc.id .. " has no file '" .. loc.file .. "'") end
    sha, etag = version, new_etag
  end

  write(content_path, content, true)
  sources_upsert(cache_dir, {
    locator, loc.kind, loc.source_key, loc.file_key, cache_hash, md5.sumhexa(content), now_iso(),
  })
  origins_upsert(cache_dir, loc.kind, loc.source_key, sha, etag)
  return content_path
end

-- ============================================================
-- public: M.check_updates -- the shared staleness-check core used
-- by both the standalone CLI script and the opt-in in-document
-- trigger. One request per DISTINCT (source_type, source_key), not
-- one per cached file.
-- ============================================================
function M.check_updates(cache_dir, opts)
  opts = opts or {}
  local groups, order = {}, {}
  for _, r in ipairs(tsv_read(sources_path(cache_dir))) do
    local gkey = r[2] .. "\1" .. r[3]
    if not groups[gkey] then
      groups[gkey] = { type = r[2], key = r[3], rows = {} }
      order[#order + 1] = gkey
    end
    table.insert(groups[gkey].rows, r)
  end

  local report = {}
  for _, gkey in ipairs(order) do
    local group = groups[gkey]
    local origin = origins_get(cache_dir, group.key)
    local baseline = (origin and origin.sha) or ""
    local entry = { type = group.type, key = group.key, changed = false, stale_files = {}, refreshed = {}, error = nil }

    local ok, err = pcall(function()
      if group.type == "github" then
        local owner, rest = group.key:match("^([^/]+)/(.+)$")
        local repo, ref = rest:match("^([^@]+)@(.+)$")
        local current = github_current_sha(owner, repo, ref)
        if current == baseline then return end
        entry.changed = true
        local changed_paths = (baseline ~= "") and github_compare(owner, repo, baseline, current) or nil
        local all_refreshed = true
        for _, r in ipairs(group.rows) do
          local file_key = r[4]
          local affected = (changed_paths == nil) or changed_paths[file_key]
          if affected then
            entry.stale_files[#entry.stale_files + 1] = r[1]
            if opts.refresh then
              local loc = { kind = "github", owner = owner, repo = repo, ref = ref, path = file_key }
              local content = github_fetch_content(loc)
              write(cache_dir .. "/" .. r[5] .. ".content", content, true)
              sources_upsert(cache_dir, { r[1], r[2], r[3], r[4], r[5], md5.sumhexa(content), now_iso() })
              entry.refreshed[#entry.refreshed + 1] = r[1]
            else
              all_refreshed = false
            end
          end
        end
        if opts.refresh and all_refreshed then
          origins_upsert(cache_dir, "github", group.key, current)
        end
      else -- gist
        local gid = group.key:match("^[^/]+/(.+)$")
        local data, version, new_etag = gist_fetch(gid, origin and origin.etag)
        if not data then
          -- 304: nothing changed; still refresh the stored etag so the
          -- next check's conditional request stays valid
          if new_etag and new_etag ~= (origin and origin.etag) then
            origins_upsert(cache_dir, "gist", group.key, baseline, new_etag)
          end
          return
        end
        if version == baseline then
          origins_upsert(cache_dir, "gist", group.key, baseline, new_etag)
          return
        end
        entry.changed = true
        local all_refreshed = true
        for _, r in ipairs(group.rows) do
          local file_key = r[4]
          local fresh = gist_file_content(data, file_key)
          if fresh and md5.sumhexa(fresh) ~= r[6] then
            entry.stale_files[#entry.stale_files + 1] = r[1]
            if opts.refresh then
              write(cache_dir .. "/" .. r[5] .. ".content", fresh, true)
              sources_upsert(cache_dir, { r[1], r[2], r[3], r[4], r[5], md5.sumhexa(fresh), now_iso() })
              entry.refreshed[#entry.refreshed + 1] = r[1]
            else
              all_refreshed = false
            end
          end
        end
        if opts.refresh and all_refreshed then
          origins_upsert(cache_dir, "gist", group.key, version, new_etag)
        end
      end
    end)
    if not ok then entry.error = tostring(err) end
    report[#report + 1] = entry
  end
  return report
end

return M
--</lua>
