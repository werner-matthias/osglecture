#!/usr/bin/env texlua
-- legacy-osglecture-rewrites.lua
--
-- Rewrites osgbeamer-era lecture sources to the osglecture interfaces and
-- reports everything that still needs a human decision.
--
-- Usage:
--   texlua tools/legacy-osglecture-rewrites.lua [options] INPUT.tex [OUTPUT.tex]
--
--   --check            only analyse INPUT and print the report; write nothing
--   --rules=a,b,...    restrict to the named rule groups (default: all)
--                      modes, sections, frames, columns, figures, semcat,
--                      listings, terminals, references, class
--   --no-report        suppress the list of manual candidates
--   --quiet            print nothing but errors
--
-- The legacy source is never overwritten: OUTPUT must not exist.  Comments
-- and verbatim material (minted, lstlisting, verbatim, terminal, termexec,
-- \verb, \mintinline) are passed through untouched.
--
-- The script is deliberately conservative.  A construct is rewritten only
-- when its legacy meaning maps onto exactly one osglecture construct;
-- everything else is left as it is and listed with its line number.

local VERSION = "2026-10-05"

----------------------------------------------------------------------------
-- command line
----------------------------------------------------------------------------

local opt = { check = false, report = true, quiet = false, rules = nil }
local files = {}
for _, a in ipairs(arg) do
  if a == "--check" then opt.check = true
  elseif a == "--no-report" then opt.report = false
  elseif a == "--quiet" then opt.quiet = true
  elseif a:match("^%-%-rules=") then
    opt.rules = {}
    for r in a:sub(9):gmatch("[^,]+") do opt.rules[r] = true end
  elseif a == "--help" or a == "-h" then
    io.stdout:write("usage: texlua legacy-osglecture-rewrites.lua "
      .. "[--check] [--rules=LIST] [--no-report] [--quiet] INPUT [OUTPUT]\n")
    os.exit(0)
  elseif a:sub(1, 2) == "--" then
    io.stderr:write("unknown option: " .. a .. "\n"); os.exit(2)
  else files[#files + 1] = a end
end

local function die(msg, code)
  io.stderr:write(msg .. "\n"); os.exit(code or 1)
end

if #files < 1 or (#files < 2 and not opt.check) or #files > 2 then
  die("usage: texlua legacy-osglecture-rewrites.lua "
    .. "[--check] [--rules=LIST] [--no-report] [--quiet] INPUT [OUTPUT]", 2)
end

local input, output = files[1], files[2]
local fh = io.open(input, "rb")
if not fh then die("input does not exist: " .. input) end
local source = fh:read("a"); fh:close()

if output and not opt.check then
  local probe = io.open(output, "rb")
  if probe then probe:close(); die("refusing to overwrite: " .. output) end
end

local function enabled(group)
  return opt.rules == nil or opt.rules[group] == true
end

----------------------------------------------------------------------------
-- masking: comments and verbatim material become opaque placeholders
----------------------------------------------------------------------------

-- A placeholder is "\1<n>\2" followed by as many newlines as the masked
-- region contained, so that line numbers stay valid while rewriting.
local masked = {}

local function mask(region)
  masked[#masked + 1] = region
  local _, nl = region:gsub("\n", "")
  return "\1" .. #masked .. "\2" .. string.rep("\n", nl)
end

local VERBATIM_ENVS = {
  "minted", "lstlisting", "verbatim", "Verbatim", "semiverbatim",
  "terminal", "termexec", "termexec*",
}

local function escape_pattern(s) return (s:gsub("%p", "%%%0")) end

local function mask_all(text)
  -- 1. verbatim environment bodies (the \begin/\end lines stay visible)
  for _, env in ipairs(VERBATIM_ENVS) do
    local e = escape_pattern(env)
    text = text:gsub("(\\begin{" .. e .. "}[^\n]*\n)(.-)(\\end{" .. e .. "})",
      function(b, body, en)
        if body == "" then return b .. en end
        return b .. mask(body) .. en
      end)
  end
  -- 2. \verb<delim>...<delim>
  text = text:gsub("\\verb%*?(%p)(.-)%1", function(d, body)
    return mask("\\verb" .. d .. body .. d)
  end)
  -- 3. comments (an unescaped % up to, not including, the newline)
  local out, pos = {}, 1
  while true do
    local s = text:find("%%", pos)
    if not s then out[#out + 1] = text:sub(pos); break end
    local bs, k = 0, s - 1
    while k >= 1 and text:sub(k, k) == "\\" do bs = bs + 1; k = k - 1 end
    if bs % 2 == 1 then
      out[#out + 1] = text:sub(pos, s); pos = s + 1
    else
      local e = text:find("\n", s, true) or (#text + 1)
      out[#out + 1] = text:sub(pos, s - 1)
      out[#out + 1] = mask(text:sub(s, e - 1))
      pos = e
    end
  end
  return table.concat(out)
end

local function unmask(text)
  -- placeholders may be nested (a comment inside a masked body is not, but
  -- a masked \verb inside a later-masked region could be); iterate.
  local changed = true
  while changed do
    changed = false
    text = text:gsub("\1(%d+)\2(\n*)", function(n, nls)
      changed = true
      local region = masked[tonumber(n)]
      local _, nl = region:gsub("\n", "")
      return region .. nls:sub(nl + 1)
    end)
  end
  return text
end

local text = mask_all(source)

----------------------------------------------------------------------------
-- positions, reporting
----------------------------------------------------------------------------

local line_starts = { 1 }
for p in text:gmatch("()\n") do line_starts[#line_starts + 1] = p + 1 end

local function line_of(pos)
  local lo, hi = 1, #line_starts
  while lo < hi do
    local mid = (lo + hi + 1) // 2
    if line_starts[mid] <= pos then lo = mid else hi = mid - 1 end
  end
  return lo
end

local counts, order = {}, {}
local function count(key)
  if not counts[key] then counts[key] = 0; order[#order + 1] = key end
  counts[key] = counts[key] + 1
end

local manual, manual_order = {}, {}
local function note(pos, topic, detail)
  if not manual[topic] then
    manual[topic] = { lines = {}, detail = detail }
    manual_order[#manual_order + 1] = topic
  end
  local m = manual[topic]
  m.lines[#m.lines + 1] = line_of(pos)
end

-- frame bodies: fancyvrb-based environments cannot be used inside them
local frame_ranges = {}
do
  local pos = 1
  while true do
    local b = text:find("\\begin{frame}", pos)
    if not b then break end
    local e = text:find("\\end{frame}", b, true)
    if not e then break end
    frame_ranges[#frame_ranges + 1] = { b, e }
    pos = e + 1
  end
end
local function in_frame(pos)
  for _, r in ipairs(frame_ranges) do
    if pos >= r[1] and pos <= r[2] then return true end
  end
  return false
end

-- commands that carried a mode specification but are left for
-- \MakeOverlayAwareCommand in the project setup
local aware = {}

----------------------------------------------------------------------------
-- a small argument parser
----------------------------------------------------------------------------

local function skip_ws(s, i)
  -- skips blanks, at most one newline run, and comment placeholders
  while true do
    local j = s:match("^[ \t\n]*()", i)
    local k = s:match("^\1%d+\2()", j)
    if k then i = k else return j end
  end
end

-- returns content, position after the closing delimiter
local function balanced(s, i, open, close)
  if s:sub(i, i) ~= open then return nil end
  local depth, j = 0, i
  while j <= #s do
    local c = s:sub(j, j)
    if c == "\\" then j = j + 1
    elseif c == open then depth = depth + 1
    elseif c == close then
      depth = depth - 1
      if depth == 0 then return s:sub(i + 1, j - 1), j + 1 end
    elseif open ~= "{" and c == "{" then
      local _, e = balanced(s, j, "{", "}")
      if not e then return nil end
      j = e - 1
    end
    j = j + 1
  end
  return nil
end

local function angle(s, i)
  if s:sub(i, i) ~= "<" then return nil end
  local e = s:find(">", i, true)
  if not e then return nil end
  local body = s:sub(i + 1, e - 1)
  if body:find("[\n{}\\]") or #body > 60 then return nil end
  return body, e + 1
end

-- spec: a string of s (star), a (angle), o (optional), m (mandatory),
--       t- / t+ written as "-" and "+".
-- Arguments may be separated by blanks; mandatory ones also by a newline.
local function parse(s, i, spec)
  local args, pos = {}, i
  for k = 1, #spec do
    local kind = spec:sub(k, k)
    if kind == "s" then
      if s:sub(pos, pos) == "*" then args[k] = true; pos = pos + 1
      else args[k] = false end
    elseif kind == "-" or kind == "+" then
      if s:sub(pos, pos) == kind then args[k] = true; pos = pos + 1
      else args[k] = false end
    elseif kind == "a" then
      local j = s:match("^[ \t]*()", pos)
      local body, e = angle(s, j)
      if body then args[k] = body; pos = e else args[k] = nil end
    elseif kind == "o" then
      local j = s:match("^[ \t]*()", pos)
      local body, e = balanced(s, j, "[", "]")
      if body then args[k] = body; pos = e else args[k] = nil end
    elseif kind == "m" then
      local j = skip_ws(s, pos)
      local body, e = balanced(s, j, "{", "}")
      if not body then return nil end
      args[k] = body; pos = e
    end
  end
  return args, pos
end

----------------------------------------------------------------------------
-- mode specifications
----------------------------------------------------------------------------

local MODE = {
  article = "longform", presentation = "presentation", handout = "handout",
  beamer = "slides", all = "all",
}

-- Returns the portable expression for a pure mode specification
-- ("article", "presentation|handout"), "all" for <all>, or nil when the
-- specification contains overlay numbers or unknown names.
local function pure_mode(specification)
  local spec = specification:gsub("%s", "")
  if spec == "" then return nil end
  local parts = {}
  for part in spec:gmatch("[^|,]+") do
    local m = MODE[part]
    if not m then return nil end
    if m == "all" then return "all" end
    parts[#parts + 1] = m
  end
  if #parts == 0 then return nil end
  return table.concat(parts, "||")
end

-- Mode-qualified overlay specifications.  Beamer let a bare overlay atom
-- apply to every presentation mode and used "article:0" to keep material
-- out of the script; osglecture-modes wants each atom qualified:
--   <2|article:0|handout:0>  ->  <slides:2|handout:0>
--   <14-|article:0>          ->  <presentation:14->
--   <presentation|+->        ->  <presentation:+->
-- Returns the new specification, or nil when nothing needs to change.
local function normalise_overlay_spec(specification)
  local spec = specification:gsub("%s", "")
  if not spec:find("%a") or pure_mode(spec) then return nil end
  local segments, bare_modes, atoms, qualified = {}, {}, {}, {}
  local has_article_zero, handout_qualified = false, false
  for seg in spec:gmatch("[^|]+") do
    local mode, rest = seg:match("^(%a+):(.*)$")
    if mode and MODE[mode] then
      if mode == "article" and rest == "0" then has_article_zero = true
      else
        if mode == "handout" then handout_qualified = true end
        qualified[#qualified + 1] = seg
      end
    elseif MODE[seg] then bare_modes[#bare_modes + 1] = seg
    elseif seg:match("^[%d%-+,.]+$") or seg:match("^%a+@[%d%-+,.]+$") then atoms[#atoms + 1] = seg
    else return nil end
  end
  -- action atoms (alert@2-3) next to mode-qualified segments are not
  -- recognised as overlay atoms by osglecture-modes and reach the backend
  -- with the mode prefix still attached
  local has_action = false
  for _, a in ipairs(atoms) do if a:find("@", 1, true) then has_action = true end end
  if not has_article_zero and #bare_modes == 0
     and not (has_action and #qualified > 0) then return nil end
  if #atoms == 0 then return nil end
  -- visibility and action for the same mode ("1-|alert@2") cannot be
  -- written as mode:rest, where rest may not contain "|"
  if has_action and #atoms > 1 then return nil end
  if #bare_modes > 1 then return nil end
  local prefix
  if #bare_modes == 1 then
    if bare_modes[1] == "article" or bare_modes[1] == "all" then return nil end
    prefix = MODE[bare_modes[1]]
  else
    prefix = handout_qualified and "slides" or "presentation"
  end
  local out = {}
  for _, a in ipairs(atoms) do out[#out + 1] = prefix .. ":" .. a end
  for _, q in ipairs(qualified) do out[#out + 1] = q end
  return table.concat(out, "|")
end

local function wrap_mode(mode, content)
  if mode == nil or mode == "all" then return content end
  return "\\lecturemode<" .. mode .. ">{" .. content .. "}"
end

----------------------------------------------------------------------------
-- rule tables
----------------------------------------------------------------------------

-- parameterless switches: \medskip<article> -> \lecturemode<longform>{\medskip}
local SWITCH = {}
for _, n in ipairs {
  "medskip", "smallskip", "bigskip", "par", "pagebreak", "newpage",
  "clearpage", "centering", "raggedright", "raggedleft", "noindent",
  "tiny", "scriptsize", "footnotesize", "small", "normalsize", "large",
  "Large", "LARGE", "huge", "Huge", "cfootnotesize", "cscriptsize", "csmall",
} do SWITCH[n] = true end

local SIZE = {}
for _, n in ipairs { "tiny", "scriptsize", "footnotesize", "small",
  "normalsize", "large", "Large", "LARGE", "huge", "Huge" } do SIZE[n] = true end

-- commands that are simply executed or not: \vspace<article>{1ex}
local GUARDED = {
  vspace = "sm", hspace = "sm", footnote = "om",
  index = "m", label = "m", pagebreak = "o",
  includegraphics = "om", VersionWarning = "", lineellipsis = "",
}

-- styling commands: with a mode they mean "styled here, plain elsewhere".
-- These are not rewritten; the project setup declares them overlay-aware.
local STYLED = {
  textbf = "m", emph = "m", textit = "m", alert = "m", structure = "m",
  stress = "m", sbf = "s m", uline = "m", outline = "m", crossout = "m",
  textcolor = "m m", follows = "", lfollows = "", CircSymb = "o m",
  rusteditor = "o m",
}

local REPORT_ONLY = {
  contframetitle = { "\\contframetitle",
    "kept; the theme provides it (ltxtalk-theme)" },
  dictum = { "\\dictum", "KOMA-Script only; guard with \\lecturemode<longform>" },
  includeChapterNo = { "\\includeChapterNo",
    "combined script; replaced by OLLM series/integration units (\\includeunit)" },
  buildfrom = { "\\buildfrom", "legacy osgcode build helper; no counterpart" },
  againframe = { "\\againframe", "kept; check that the frame label still exists" },
  xrefchap = { "\\xrefchap",
    "reference to a unit: use \\olref[<unit>]{<label of its heading>}" },
  xrefsmart = { "\\xrefsmart",
    "page in the script / frame on slides: no single counterpart; "
      .. "\\olpageref or \\olautoref, decide per use" },
  xrefdist = { "\\xrefdist",
    "'on page N unless on this page': no counterpart; consider varioref or \\olpageref" },
  xreflstname = { "\\xreflstname",
    "name of a listing: \\olnameref once the listing carries a label" },
  keywordindex = { "\\keywordindex", "project macro; keep in the project setup" },
  persindex = { "\\persindex", "project macro; keep in the project setup" },
  dindex = { "\\dindex", "project macro; keep in the project setup" },
  gistid = { "\\gistid", "legacy osggists; use a gist:/github: locator in \\osglistinginput" },
  rustplayground = { "\\rustplayground",
    "legacy playground link; use link=... on the listing" },
  tucurl = { "\\tucurl", "legacy metadata; set in the project configuration" },
  lehrveranstaltung = { "\\lehrveranstaltung", "use \\course<mode>[short]{long}" },
  SetGlobalClassOptions = { "\\SetGlobalClassOptions",
    "legacy class options; move to ollmconfig.toml / projectconfig.tex" },
}

local REPORT_ENV = {
  columns = "beamer columns: use twocolumns, or keep if the profile provides it",
  tearout = "torn-paper box around arbitrary content: only a single listing "
    .. "inside is rewritten (style=paper); otherwise bind a styled block in the project setup",
  codeeditor = "legacy editor box around arbitrary content; use osglisting[style=editor] "
    .. "when the body is plain source",
  task = "project theorem; declare with osgstyler (NewOsgStyledEnvironment) in the project setup",
  chapabstract = "project box; declare with osgstyler in the project setup",
  lessonslearned = "project box; declare with osgstyler in the project setup",
  literaturelist = "legacy bibliography list; use the bibliography of the profile",
  borrowrules = "chapter-local environment",
  subfigure = "kept; needs subcaption in the project setup",
  wrapfigure = "kept; rarely survives a change of text width",
}

----------------------------------------------------------------------------
-- helpers for individual rewrites
----------------------------------------------------------------------------

local rewrite -- forward

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function split_keys(s)
  -- splits "a=b, c={d,e}, f" at top-level commas
  local items, depth, start = {}, 0, 1
  for i = 1, #s do
    local c = s:sub(i, i)
    if c == "{" then depth = depth + 1
    elseif c == "}" then depth = depth - 1
    elseif c == "," and depth == 0 then
      items[#items + 1] = trim(s:sub(start, i - 1)); start = i + 1
    end
  end
  items[#items + 1] = trim(s:sub(start))
  local out = {}
  for _, it in ipairs(items) do if it ~= "" then out[#out + 1] = it end end
  return out
end

local function key_of(item) return trim(item:match("^[^=]*")) end

-- finds the matching \end{env}; returns body start, body end, position after \end{env}
local function env_body(s, i, env)
  local e = escape_pattern(env)
  local depth, pos = 1, i
  while true do
    local b = s:find("\\begin{" .. e .. "}", pos)
    local c, c2 = s:find("\\end{" .. e .. "}", pos)
    if not c then return nil end
    if b and b < c then depth = depth + 1; pos = b + 1
    else
      depth = depth - 1
      if depth == 0 then return i, c - 1, c2 + 1 end
      pos = c + 1
    end
  end
end

----------------------------------------------------------------------------
-- command handlers: return replacement, position after the construct
----------------------------------------------------------------------------

local H = {}

-- \only<mode>{X}  /  \alt<mode>{A}{B}
function H.only(s, i, base)
  if not enabled("modes") then return nil end
  local spec, p = angle(s, i)
  if not spec then return nil end
  local mode = pure_mode(spec)
  if not mode then
    if spec:find("%a") then
      count("kept: \\only with mode-qualified overlays (osglecture-modes evaluates them)")
    end
    return nil
  end
  local args, e = parse(s, p, "m")
  if not args then return nil end
  do
    local _, nb = args[1]:gsub("\\begin%s*{", "")
    local _, ne = args[1]:gsub("\\end%s*{", "")
    if nb ~= ne then
      note(base + i, "environment opened or closed inside \\only<mode>{...}",
        "the two halves end up in different arguments; tagged environments such as "
          .. "tikzpicture break -- use one \\begin with \\ModeValue in its options instead")
    end
  end
  count("\\only<mode> -> \\lecturemode")
  return wrap_mode(mode, rewrite(args[1], base + p)), e
end

function H.alt(s, i, base)
  if not enabled("modes") then return nil end
  local spec, p = angle(s, i)
  if not spec then return nil end
  local mode = pure_mode(spec)
  if not mode then return nil end
  local args, e = parse(s, p, "mm")
  if not args then return nil end
  count("\\alt<mode> -> \\IfLectureModeTF")
  if mode == "all" then return rewrite(args[1], base + p), e end
  return "\\IfLectureModeTF{" .. mode .. "}{" .. rewrite(args[1], base + p)
    .. "}{" .. rewrite(args[2], base + p) .. "}", e
end

-- \mode<presentation>{...}  (block form only; the switch form is kept)
function H.mode(s, i, base)
  if not enabled("modes") then return nil end
  if s:sub(i, i) == "*" then
    count("\\mode* -> \\mode<all>")
    return "\\mode<all>", i + 1
  end
  local spec, p = angle(s, i)
  if not spec then return nil end
  local mode = pure_mode(spec)
  if not mode then return nil end
  local j = s:match("^[ \t]*()", p)
  if s:sub(j, j) == "{" then
    local body, e = balanced(s, j, "{", "}")
    if not body then return nil end
    count("\\mode<mode>{...} -> \\lecturemode")
    return wrap_mode(mode, rewrite(body, base + j)), e
  end
  note(base + i, "\\mode<...> used as a switch",
    "kept (osglecture-modes handles it); with ignorenonframetext most of these are redundant")
  if mode ~= spec:gsub("%s", "") then
    count("\\mode<article> switch -> \\mode<longform>")
    return "\\mode<" .. mode .. ">", p
  end
  return nil
end

-- sectioning with a mode: \section<presentation>*{..}
local function sectioning(name)
  return function(s, i, base)
    if not enabled("sections") then return nil end
    local spec, p = angle(s, i)
    if not spec then return nil end
    local mode = pure_mode(spec)
    if not mode then return nil end
    local args, e = parse(s, p, "som")
    if not args then return nil end
    local body = "\\" .. name .. (args[1] and "*" or "")
      .. (args[2] and ("[" .. args[2] .. "]") or "") .. "{" .. rewrite(args[3], base + p) .. "}"
    count("\\" .. name .. "<mode> -> \\lecturemode{\\" .. name .. "}")
    return wrap_mode(mode, body), e
  end
end
H.section = sectioning("section")
H.subsection = sectioning("subsection")
H.subsubsection = sectioning("subsubsection")
H.chapter = sectioning("chapter")

-- \pipar: paragraph break inside the prose list
function H.pipar(s, i, base)
  if not enabled("modes") then return nil end
  count("\\pipar -> \\prespar")
  return "\\prespar", i
end

-- \centerpic<mode>[w_pres,w_art]{file}
function H.centerpic(s, i, base)
  if not enabled("figures") then return nil end
  local args, e = parse(s, i, "aom")
  if not args then return nil end
  local mode = args[1] and pure_mode(args[1]) or "all"
  if args[1] and not mode then
    note(base + i, "\\centerpic with an overlay specification", "rewrite by hand")
    return nil
  end
  local width = args[2] and trim(args[2]) or "0.9\\textwidth"
  local pres, art = width:match("^(.-),(.*)$")
  if pres then
    pres, art = trim(pres), trim(art)
    if pres == art then width = pres
    else width = "\\ModeValue{" .. pres .. "|longform=" .. art .. "}" end
  end
  count("\\centerpic -> \\centering\\includegraphics")
  local body = "{\\centering\\includegraphics[width=" .. width .. "]{" .. args[3] .. "}\\par}"
  return wrap_mode(mode, body), e
end

-- \qr*<mode>[category]{url}{text}[offset]
local function qr(target)
  return function(s, i, base)
    if not enabled("semcat") then return nil end
    local args, e = parse(s, i, "saomm")
    if not args then
      note(base + i, "\\qr without both mandatory arguments", "rewrite by hand")
      return nil
    end
    local off, e2 = balanced(s, s:match("^[ \t]*()", e), "[", "]")
    local mode = args[2] and pure_mode(args[2])
    if args[2] and not mode then
      note(base + i, "\\qr with an overlay specification", "rewrite by hand")
      return nil
    end
    -- the legacy default was <article>
    mode = mode or "longform"
    count("\\qr -> \\" .. target)
    local out = "\\" .. target .. (mode ~= "all" and ("<" .. mode .. ">") or "")
      .. (args[1] and "*" or "")
      .. (args[3] and ("[" .. trim(args[3]) .. "]") or "")
      .. "{" .. args[4] .. "}{" .. rewrite(args[5], base + i) .. "}"
    if off then out = out .. "[" .. off .. "]"; e = e2 end
    return out, e
  end
end
H.qr = qr("SemCatQR")
H.qrr = qr("SemCatQRRedirect")

function H.OsgDefineCategory(s, i, base)
  if not enabled("semcat") then return nil end
  local args, e = parse(s, i, "smm")
  if not args then return nil end
  count("\\OsgDefineCategory -> \\SemCatDefine")
  -- the legacy block marking (catbar) was a margin bar, not a box
  return "\\SemCatDefine" .. (args[1] and "*" or "") .. "{" .. args[2]
    .. "}[color=" .. args[3] .. ", style=bar]", e
end

-- listings
local LEGACY_LISTING_KEYS = { pre = true, post = true, figure = true, fail = true }

local function listing_options(optstring, extra, pos, base)
  local keep = {}
  for _, it in ipairs(extra) do keep[#keep + 1] = it end
  if optstring and optstring:find("\1", 1, true) then
    -- a comment inside the option list: re-joining the keys could move
    -- material into the comment, so the list is passed through unchanged
    note(base + pos, "listing options containing a comment",
      "passed through unchanged; check for legacy keys (pre, post, figure, fail)")
    local head = #keep > 0 and (table.concat(keep, ", ") .. ", ") or ""
    return "[" .. head .. optstring .. "]"
  end
  if optstring then
    for _, it in ipairs(split_keys(rewrite(optstring, base + pos))) do
      local k = key_of(it)
      if LEGACY_LISTING_KEYS[k] then
        note(base + pos, "listing key '" .. k .. "' dropped",
          "legacy osgcode key without counterpart in osglistings")
      else keep[#keep + 1] = it end
    end
  end
  if #keep == 0 then return "" end
  return "[" .. table.concat(keep, ", ") .. "]"
end

function H.rusteditor(s, i, base)
  if not enabled("listings") then return nil end
  local args, e = parse(s, i, "saom")
  if not args then return nil end
  local mode = args[2] and pure_mode(args[2]) or "all"
  if args[2] and not mode then
    note(base + i, "\\rusteditor with an overlay specification", "rewrite by hand")
    return nil
  end
  if args[1] then
    note(base + i, "\\rusteditor* (floating listing)",
      "rewritten without the float; wrap in figure if it must float")
  end
  local label, e2 = balanced(s, e, "[", "]")
  local file = trim(args[4])
  local out = "\\osglistinginput"
    .. listing_options(args[3], { "style=editor", "title={" .. file .. "}" }, i, base)
    .. "{rust}{code/" .. file .. "}"
  if label then out = out .. "\\label{" .. label .. "}"; e = e2 end
  count("\\rusteditor -> \\osglistinginput[style=editor]")
  return wrap_mode(mode, out), e
end

function H.inputminted(s, i, base)
  if not enabled("listings") then return nil end
  local args, e = parse(s, i, "omm")
  if not args then return nil end
  count("\\inputminted -> \\osglistinginput")
  return "\\osglistinginput" .. listing_options(args[1], {}, i, base)
    .. "{" .. args[2] .. "}{" .. args[3] .. "}", e
end

-- references
function H.xref(s, i, base)
  if not enabled("references") then return nil end
  local args, e = parse(s, i, "om")
  if not args then return nil end
  count("\\xref -> \\olref")
  return "\\olref" .. (args[1] and args[1] ~= "" and ("[" .. args[1] .. "]") or "")
    .. "{" .. args[2] .. "}", e
end

local function typed_ref(doctype)
  return function(s, i, base)
    if not enabled("references") then return nil end
    local args, e = parse(s, i, "om")
    if not args then return nil end
    count("\\x" .. (doctype == "script" and "article" or "presentation") .. "ref -> \\olref[type=...]")
    local address = (args[1] and args[1] ~= "") and (args[1] .. ",") or ""
    return "\\olref[" .. address .. "type=" .. doctype .. "]{" .. args[2] .. "}", e
  end
end
H.xarticleref = typed_ref("script")
H.xpresentationref = typed_ref("slides")

-- \documentclass[...]{osgbeamer}
function H.documentclass(s, i, base)
  if not enabled("class") then return nil end
  local args, e = parse(s, i, "om")
  if not args or trim(args[2]) ~= "osgbeamer" then return nil end
  if args[1] and trim(args[1]) ~= "" then
    note(base + i, "class options of osgbeamer dropped",
      "(" .. trim(args[1]:gsub("%s+", " ")) .. ") -- configure target, profile and "
        .. "bibliography in ollmconfig.toml / projectconfig.tex")
  end
  count("\\documentclass{osgbeamer} -> \\documentclass{osglecture}")
  return "\\documentclass{osglecture}", e
end

----------------------------------------------------------------------------
-- environment handlers: called at the position after \begin{name}
----------------------------------------------------------------------------

local E = {}

local FRAME_KEYS = {
  t = "vertical-alignment=top", c = "vertical-alignment=center",
  b = "vertical-alignment=bottom",
}

function E.frame(s, i, base)
  if not enabled("frames") then return nil end
  local args, e = parse(s, i, "ao")
  if not args or (not args[1] and not args[2]) then return nil end
  if args[2] and args[2]:find("\1", 1, true) then return nil end
  local out, changed = "\\begin{frame}", false
  if args[1] then out = out .. "<" .. args[1] .. ">" end
  if args[2] then
    local keep = {}
    for _, it in ipairs(split_keys(args[2])) do
      if FRAME_KEYS[it] then keep[#keep + 1] = FRAME_KEYS[it]; changed = true
      else
        keep[#keep + 1] = it
        if key_of(it) ~= "label" then
          note(base + i, "frame option '" .. key_of(it) .. "'",
            "kept; check that the profile (ltx-talk/beamer) understands it")
        end
      end
    end
    if #keep > 0 then out = out .. "[" .. table.concat(keep, ",") .. "]" end
  end
  if not changed then return nil end
  count("frame options -> ltx-talk keys")
  return out, e
end

function E.twocolumns(s, i, base)
  if not enabled("columns") then return nil end
  -- legacy accepted <mode> before or after the optional argument
  local a1, p1 = angle(s, i)
  local o, p2 = balanced(s, p1 or i, "[", "]")
  local a2, p3
  if not a1 then a2, p3 = angle(s, p2 or i) end
  local spec, e = a1 or a2, p3 or p2 or p1
  if not spec and not o then return nil end
  if o and o:find("\1", 1, true) then return nil end
  local changed = (a2 ~= nil)
  if o then
    local items = split_keys(o)
    for k, it in ipairs(items) do
      if it == "T" then items[k] = "t"; changed = true
      elseif it == "B" then items[k] = "b"; changed = true
      elseif it == "C" then items[k] = "c"; changed = true end
    end
    o = table.concat(items, ",")
  end
  if not changed then return nil end
  count("twocolumns options normalised")
  return "\\begin{twocolumns}" .. (spec and ("<" .. spec .. ">") or "")
    .. (o and ("[" .. o .. "]") or ""), e
end

local PRESITEMIZE_KEYS = { language = true, punctuation = true, whitespace = true }

function E.presitemize(s, i, base)
  local o, e = balanced(s, i, "[", "]")
  if not o or o:find("\1", 1, true) then return nil end
  local keep = {}
  for _, it in ipairs(split_keys(o)) do
    if PRESITEMIZE_KEYS[key_of(it)] then keep[#keep + 1] = it
    else
      note(base + i, "presitemize option '" .. it .. "' dropped",
        "enumitem option of the legacy list; the osglecture presitemize only "
          .. "knows language, punctuation and whitespace")
    end
  end
  if #keep == #split_keys(o) then return nil end
  count("presitemize: legacy enumitem options removed")
  return "\\begin{presitemize}" .. (#keep > 0 and ("[" .. table.concat(keep, ",") .. "]") or ""), e
end

-- artfigure / arttable
local function float_env(kind)
  return function(s, i, base, env)
    if not enabled("figures") then return nil end
    local star = env:sub(-1) == "*"
    local name = star and env:sub(1, -2) or env
    local args, p = parse(s, i, "s-+o")
    star = star or args[1]
    local caption, label
    local cl, p2 = parse(s, p, "mm")
    if cl then caption, label, p = cl[1], cl[2], p2 end
    local bs, be, after = env_body(s, p, env)
    if not bs then
      note(base + i, "unterminated " .. env, "rewrite by hand"); return nil
    end
    local body = rewrite(s:sub(bs, be), base + bs)
    local placement = star and "H" or (args[4] and trim(args[4]) ~= "" and trim(args[4]) or "htb")
    local cap, moved = "", ""
    if caption then
      -- a QR code cannot live inside \caption (it contains paragraphs);
      -- it is moved behind the caption
      while true do
        local b, name, a = caption:match("()\\(qrr?)()%f[%A]")
        if not b then break end
        local replacement, e = H[name](caption, a, base + i)
        if not replacement then break end
        moved = moved .. "\n  " .. replacement
        caption = caption:sub(1, b - 1) .. caption:sub(e)
        count("QR code moved out of a caption")
      end
      cap = "\\caption{" .. rewrite(caption, base + i) .. "}"
      if label and trim(label) ~= "" then cap = cap .. "\\label{" .. trim(label) .. "}" end
      -- '-' meant: no caption on slides
      if args[2] then cap = "\\lecturemode<longform>{" .. cap .. "}" end
      cap = cap .. moved
    else
      note(base + i, env .. " without caption/label arguments", "check the result")
    end
    count(name .. " -> " .. kind)
    local out
    if kind == "figure" then
      out = "\\begin{figure}[" .. placement .. "]\n  \\centering" .. body
      if cap ~= "" then out = out:gsub("%s*$", "") .. "\n  " .. cap .. "\n" end
      out = out .. "\\end{figure}"
    else
      out = "\\begin{table}[" .. placement .. "]\n  \\centering"
      if cap ~= "" then out = out .. "\n  " .. cap end
      out = out .. body .. "\\end{table}"
    end
    return out, after
  end
end
E.artfigure = float_env("figure")
E["artfigure*"] = E.artfigure
E.arttable = float_env("table")
E["arttable*"] = E.arttable

-- semcat
function E.catbar(s, i, base, env)
  if not enabled("semcat") then return nil end
  local args, p = parse(s, i, "sam")
  if not args then return nil end
  local bs, be, after = env_body(s, p, env)
  if not bs then return nil end
  if args[1] or (args[2] and not pure_mode(args[2])) then
    note(base + i, "catbar with star or overlay specification", "check the result")
  end
  local mode = args[2] and pure_mode(args[2]) or "longform"
  count("catbar -> SemCatMark")
  local out = "\\begin{SemCatMark}[category=" .. trim(args[3]) .. "]"
    .. rewrite(s:sub(bs, be), base + bs) .. "\\end{SemCatMark}"
  -- the legacy bar only existed in the script; SemCatMark is mode-agnostic
  if mode ~= "longform" and mode ~= "all" then out = wrap_mode(mode, out) end
  return out, after
end

function E.catbox(s, i, base, env)
  if not enabled("semcat") then return nil end
  local args, p = parse(s, i, "saom")
  if not args then
    note(base + i, "catbox without title argument", "rewrite by hand"); return nil
  end
  local j = s:match("^[ \t]*()", p)
  local place, p2 = balanced(s, j, "(", ")")
  if place then p = p2 end
  local extra, p3 = balanced(s, s:match("^[ \t]*()", p), "[", "]")
  if extra then p = p3 end
  local bs, be, after = env_body(s, p, env)
  if not bs then return nil end
  if args[1] or place then
    note(base + i, "floating catbox (star / placement)",
      "SemCatExplain floats on its own; placement dropped")
  end
  if extra and trim(extra) ~= "" then
    note(base + i, "catbox with tcolorbox options", "options dropped: " .. trim(extra))
  end
  count("catbox -> SemCatExplain")
  local category = args[3] and trim(args[3]) or "B"
  return "\\begin{SemCatExplain}[category=" .. category .. "]{"
    .. rewrite(args[4], base + i) .. "}" .. rewrite(s:sub(bs, be), base + bs)
    .. "\\end{SemCatExplain}", after
end

-- A catbox wrapped in a float: SemCatExplain floats on its own, and a
-- float inside a float is an error ("Not in outer par mode").
function E.figure(s, i, base, env)
  if not enabled("semcat") then return nil end
  local o, p = balanced(s, i, "[", "]")
  p = p or i
  local bs, be, after = env_body(s, p, env)
  if not bs then return nil end
  local body = s:sub(bs, be)
  local inner = trim(body)
  if inner:match("^\\begin{catbox}") and inner:match("\\end{catbox}$")
     and select(2, inner:gsub("\\begin{catbox}", "")) == 1 then
    count("figure around a single catbox removed")
    return rewrite(body, base + bs), after
  end
  return nil
end

-- terminals
function E.terminal(s, i, base, env)
  if not enabled("terminals") then return nil end
  local bs, be, after = env_body(s, i, env)
  if not bs then return nil end
  if in_frame(base + i) then
    note(base + i, "ansiterm inside a frame",
      "ansiterm scans its body verbatim and cannot sit inside a frame, whose body "
        .. "is grabbed as an argument; move the transcript out of the frame or into a file")
  end
  count("terminal -> ansiterm")
  -- ansiterm currently needs its optional argument: without the brackets
  -- fancyvrb takes the first body line for trailing material of \begin
  return "\\begin{ansiterm}[]" .. s:sub(bs, be) .. "\\end{ansiterm}", after
end

local function termexec(s, i, base, env)
  if not enabled("terminals") then return nil end
  local o, p = balanced(s, i, "[", "]")
  p = p or i
  local bs, be, after = env_body(s, p, env)
  if not bs then return nil end
  local keep = {}
  if o and o:find("\1", 1, true) then
    note(base + i, "termexec options containing a comment", "environment left unchanged")
    return nil
  end
  if o then
    for _, it in ipairs(split_keys(o)) do
      local k, v = it:match("^%s*([%w-]+)%s*=%s*(.-)%s*$")
      if k == "last" then keep[#keep + 1] = "lines={-" .. v .. "}"
      elseif k == "first" then keep[#keep + 1] = "lines={" .. v .. "-}"
      elseif k == "range" or k == "lines" or k == "linerange" then keep[#keep + 1] = "lines={" .. v:gsub("^{(.*)}$", "%1") .. "}"
      else
        note(base + i, "termexec key '" .. (k or it) .. "' dropped",
          "legacy osgcode key without counterpart in ansitermexec")
      end
    end
  end
  if env == "termexec*" then
    note(base + i, "termexec* (unbreakable)", "rewritten as ansitermexec; check page breaks")
  end
  if in_frame(base + i) then
    note(base + i, "ansitermexec inside a frame",
      "ansitermexec scans its body verbatim and cannot sit inside a frame, whose body "
        .. "is grabbed as an argument; move the transcript out of the frame or into a file")
  end
  count("termexec -> ansitermexec")
  return "\\begin{ansitermexec}[" .. table.concat(keep, ", ") .. "]"
    .. s:sub(bs, be) .. "\\end{ansitermexec}", after
end
E.termexec = termexec
E["termexec*"] = termexec

-- tearout around exactly one listing -> style=paper
function E.tearout(s, i, base, env)
  if not enabled("listings") then return nil end
  local o, p = balanced(s, i, "[", "]")
  p = p or i
  local bs, be, after = env_body(s, p, env)
  if not bs then return nil end
  local body = s:sub(bs, be)
  local lead, cmd, rest = body:match("^(%s*)\\(%a+)(.*)$")
  if cmd == "inputminted" then
    local args, e = parse(rest, 1, "omm")
    if args and trim(rest:sub(e)) == "" then
      count("tearout{\\inputminted} -> \\osglistinginput[style=paper]")
      return "\\osglistinginput" .. listing_options(args[1], { "style=paper" }, i, base)
        .. "{" .. args[2] .. "}{" .. args[3] .. "}", after
    end
  end
  note(base + i, "tearout", REPORT_ENV.tearout)
  return "\\begin{tearout}" .. (o and ("[" .. o .. "]") or "")
    .. rewrite(body, base + bs) .. "\\end{tearout}", after
end

----------------------------------------------------------------------------
-- the scanner
----------------------------------------------------------------------------

local function generic_mode_spec(name, s, i, base)
  -- \name<spec> for commands without a dedicated handler
  if not enabled("modes") then return nil end
  local spec, p = angle(s, i)
  if not spec then return nil end
  local mode = pure_mode(spec)
  if not mode then return nil end

  if SWITCH[name] then
    -- \scriptsize<article>\tiny<presentation>  ->  \ModeValue{...}
    if SIZE[name] then
      local n2, q = s:match("^\\(%a+)()", p)
      if n2 and SIZE[n2] then
        local spec2, e2 = angle(s, q)
        local mode2 = spec2 and pure_mode(spec2)
        if mode2 and mode2 ~= mode and mode ~= "all" and mode2 ~= "all" then
          count("size pair -> \\ModeValue")
          local a, b = mode .. "=\\" .. name, mode2 .. "=\\" .. n2
          if mode2 == "presentation" then a, b = b, a end
          -- the presentation value doubles as the default
          if a:match("^presentation=") then a = a:gsub("^presentation=", "") end
          return "\\ModeValue{" .. a .. "|" .. b .. "}", e2
        end
      end
    end
    count("\\" .. name .. "<mode> -> \\lecturemode{\\" .. name .. "}")
    return wrap_mode(mode, "\\" .. name), p
  end

  local sig = GUARDED[name]
  if sig then
    local args, e = parse(s, p, sig)
    if not args then return nil end
    count("\\" .. name .. "<mode> -> \\lecturemode{\\" .. name .. "...}")
    return wrap_mode(mode, "\\" .. name .. rewrite(s:sub(p, e - 1), base + p)), e
  end

  -- frame titles keep their mode: slides themes evaluate it, and in
  -- long-form output the project decides whether a title is a heading
  if name == "frametitle" or name == "framesubtitle" then
    count("kept: \\" .. name .. "<mode> (evaluated by theme / project setup)")
    return nil
  end

  if STYLED[name] then
    aware[name] = STYLED[name]
    count("kept: \\" .. name .. "<mode> (declare overlay-aware in the project setup)")
    return nil
  end

  note(base + i, "\\" .. name .. "<" .. spec .. ">",
    "mode specification on a command the tool does not know; "
      .. "declare it with \\MakeOverlayAwareCommand or rewrite by hand")
  return nil
end

function rewrite(s, base)
  base = base or 0
  local out, pos = {}, 1
  while true do
    local b = s:find("\\", pos, true)
    if not b then out[#out + 1] = s:sub(pos); break end
    local name, after = s:match("^\\(%a+)()", b)
    if not name then
      -- control symbol: copy two characters
      out[#out + 1] = s:sub(pos, b + 1); pos = b + 2
    else
      local replacement, e
      if name == "begin" then
        local env, p = s:match("^{([%a]+%*?)}()", after)
        if env then
          local handler = E[env]
          if handler then replacement, e = handler(s, p, base, env) end
          if not replacement and REPORT_ENV[env] and env ~= "tearout" then
            note(base + b, env, REPORT_ENV[env])
          end
          if not replacement and enabled("modes") then
            local spec = angle(s, p)
            if spec and spec:find("%a") and not pure_mode(spec)
               and not spec:gsub("%s", ""):match("^[%a:|%d,%-+ ]+$") then
              note(base + b, "\\begin{" .. env .. "}<" .. spec .. ">", "unusual specification")
            end
          end
        end
      else
        local handler = H[name]
        if handler then replacement, e = handler(s, after, base) end
        if not replacement and REPORT_ONLY[name] then
          note(base + b, REPORT_ONLY[name][1], REPORT_ONLY[name][2])
        end
        if not replacement and not handler then
          replacement, e = generic_mode_spec(name, s, after, base)
        end
      end
      if not replacement and enabled("modes") then
        -- last resort: only the overlay specification itself is normalised
        local p = after
        if name == "begin" then p = s:match("^{[%a]+%*?}()", after) or after end
        local spec, e2 = angle(s, p)
        local fixed = spec and normalise_overlay_spec(spec)
        if fixed then
          count("overlay specification qualified (article:0 / bare mode)")
          replacement, e = s:sub(b, p - 1) .. "<" .. fixed .. ">", e2
        end
      end
      if replacement then
        out[#out + 1] = s:sub(pos, b - 1); out[#out + 1] = replacement; pos = e
      else
        out[#out + 1] = s:sub(pos, after - 1); pos = after
      end
    end
  end
  return table.concat(out)
end

----------------------------------------------------------------------------
-- run
----------------------------------------------------------------------------

local result = unmask(rewrite(text, 0))

-- sanity: brace balance must not have changed
local function balance(t)
  local n = 0
  for c in t:gsub("\\.", ""):gmatch("[{}]") do n = n + (c == "{" and 1 or -1) end
  return n
end
if balance(mask_all(result)) ~= balance(text) then
  die("internal error: brace balance changed; nothing written", 3)
end

if output and not opt.check then
  local dir = output:match("^(.*)/[^/]*$")
  if dir and dir ~= "" then os.execute('mkdir -p "' .. dir .. '"') end
  local oh = assert(io.open(output, "wb")); oh:write(result); oh:close()
end

if not opt.quiet then
  local w = function(...) io.stderr:write(...) end
  w("legacy-osglecture-rewrites ", VERSION, ": ", input, "\n")
  if output and not opt.check then w("  wrote ", output, "\n") end
  w("\nAutomatic rewrites\n")
  if #order == 0 then w("  (none)\n") end
  table.sort(order)
  for _, k in ipairs(order) do w(string.format("  %5d  %s\n", counts[k], k)) end

  local names = {}
  for n in pairs(aware) do names[#names + 1] = n end
  if #names > 0 then
    table.sort(names)
    w("\nProject setup: these commands carried a mode specification and were kept.\n")
    w("Declare them once (e.g. in Include/all-setup.tex):\n")
    for _, n in ipairs(names) do
      local sig = aware[n]
      w("  \\MakeOverlayAwareCommand", sig ~= "" and ("[arguments={" .. sig .. "}]") or "",
        "{\\", n, "}\n")
    end
  end

  if opt.report then
    w("\nManual candidates\n")
    if #manual_order == 0 then w("  (none)\n") end
    table.sort(manual_order)
    for _, topic in ipairs(manual_order) do
      local m = manual[topic]
      local shown = {}
      for k = 1, math.min(#m.lines, 12) do shown[#shown + 1] = tostring(m.lines[k]) end
      w(string.format("  %4dx %s\n         %s\n         lines: %s%s\n",
        #m.lines, topic, m.detail, table.concat(shown, ", "),
        #m.lines > 12 and ", ..." or ""))
    end
  end
end
