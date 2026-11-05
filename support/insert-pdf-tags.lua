local log_name, tags_name = arg[1], arg[2]

local function read(name)
  local handle = assert(io.open(name, "rb"))
  local content = assert(handle:read("*a"))
  assert(handle:close())
  return content
end

local log = read(log_name)
local tags = read(tags_name):gsub("\r\n", "\n")
if tags:sub(-1) ~= "\n" then
  tags = tags .. "\n"
end

-- show-pdf-tags started annotating the root element with the PDF's
-- container version (e.g. <PDF version="2.0">) in some releases but not
-- others; that's a toolchain-version artifact, not part of what these
-- tests check (the tag *tree*), so it's stripped before comparison to
-- keep the recorded .tlg stable across show-pdf-tags versions.
tags = tags:gsub("^<PDF[^>]*>", "<PDF>")

-- latex-lab-namespace.dtx (changes.txt, 2026-07-29 and later) renamed
-- some generic structure-type synonyms and, for others, introduced a
-- new element that wraps what used to stand directly as the plain
-- PDF-namespace role element -- including reusing the name "section"
-- itself for such a wrapper, while renaming the former, heading-specific
-- "section" to "section-heading" at the same time. A left-to-right text
-- substitution cannot resolve that reuse or pair up nested closing tags
-- correctly (section/subsection nest inside each other), so the tag
-- tree is walked once with an explicit element stack: each opening tag
-- decides, by its own name and (if present) its "rolemaps-to" target,
-- what its matching closing tag must become, and that decision travels
-- with it on the stack regardless of nesting depth.
--
-- RENAMED holds plain, context-free renames (both the open and the
-- close keyword always change the same way). WRAPPED holds elements
-- latex-lab now wraps around what used to be the bare role element
-- directly -- resolved via each instance's own "rolemaps-to" attribute,
-- never a fixed target, since the same element name recurs at every
-- heading level (section/subsection/...) or is reused for unrelated
-- roles (plain "section" vs. the former "section-heading"). It is
-- deliberately a narrow allowlist, not every element with a
-- "rolemaps-to" attribute: most structure types (text-unit, text, ...)
-- carry one permanently, and unwrapping those would erase exactly the
-- symbolic-to-role mapping these tests check. Extend either table as
-- further renames or wrappers turn up.
local RENAMED = {
  ["semantic-para"]       = "text-unit",
  ["text-block"]           = "text",
  ["section-heading"]      = "section",
  ["subsection-heading"]   = "subsection",
  ["subsubsection-heading"] = "subsubsection",
}
local WRAPPED = {
  ["text-fragment"] = true, ["text-parbox"] = true, ["text-minipage"] = true,
  ["section"] = true, ["subsection"] = true, ["subsubsection"] = true,
}

local function rewrite(xml)
  local out, stack = { }, { }
  local pos, len = 1, #xml
  while pos <= len do
    local lt = xml:find("<", pos)
    if not lt then
      out[#out + 1] = xml:sub(pos)
      break
    end
    out[#out + 1] = xml:sub(pos, lt - 1)
    if xml:sub(lt + 1, lt + 1) == "?" then
      -- A processing instruction, e.g. <?MarkedContent page="1" ?>: not
      -- an element, passed through unchanged and never pushed.
      local close = xml:find("?>", lt + 2, true) or (len - 1)
      out[#out + 1] = xml:sub(lt, close + 1)
      pos = close + 2
    elseif xml:sub(lt + 1, lt + 1) == "/" then
      local gt = assert(xml:find(">", lt, true), "unterminated closing tag")
      -- A stray extra close (malformed input, not a valid tag tree)
      -- falls back to the tag's own name rather than erroring on an
      -- empty stack.
      local name = xml:sub(lt + 2, gt - 1)
      local target = table.remove(stack) or name
      out[#out + 1] = "</" .. target .. ">"
      pos = gt + 1
    else
      local gt = assert(xml:find(">", lt, true), "unterminated opening tag")
      local tag = xml:sub(lt, gt)
      local name = assert(tag:match("^<([%w%-]+)"), "tag without a name")
      local rolemapsto = tag:match('rolemaps%-to="([^"]+)"')
      -- "-" is a Lua pattern metacharacter (lazy "*"), not literal, so
      -- renaming the element name is done by position (it always
      -- starts right after "<"), never by re-matching "name" or
      -- "target" as part of a pattern. WRAPPED is checked against the
      -- tag's own, original name, never against a RENAMED target: the
      -- renamed section-heading (now named "section", like the
      -- unrelated wrapper) also carries a "rolemaps-to" of its own and
      -- must not be mistaken for that wrapper and unwrapped again.
      local target
      if WRAPPED[name] and rolemapsto then
        target = rolemapsto
        -- Drop the rolemaps-to attribute, switch the element name and
        -- namespace to the plain role it names. show-pdf-tags indents
        -- the closing ">" of a multi-line tag one column left of its
        -- attributes, regardless of the element or how many attributes
        -- it has; recompute that from the (kept) attribute indentation
        -- instead of reusing this opening tag's own, which sits one
        -- level deeper because of the attribute line just removed.
        local attr_indent = tag:match("\n(%s*)%S") or ""
        local close_indent = attr_indent:sub(1, -2)
        tag = tag:gsub('%s*rolemaps%-to="[^"]*"', "")
        tag = tag:gsub('xmlns="https://www%.latex%-project%.org/ns/dflt"',
          'xmlns="http://iso.org/pdf2/ssn"')
        tag = "<" .. target .. tag:sub(#name + 2)
        tag = tag:gsub("%s*>$", "\n" .. close_indent .. ">")
      else
        target = RENAMED[name] or name
        if target ~= name then
          tag = "<" .. target .. tag:sub(#name + 2)
        end
      end
      out[#out + 1] = tag
      stack[#stack + 1] = target
      pos = gt + 1
    end
  end
  return table.concat(out)
end

tags = rewrite(tags)

local marker = "%-%-INSERT%-PDF%-TAGS%s+[^\r\n]+%s*\r?\n"
local replacements
log, replacements = log:gsub(marker, function()
  return "START-TEST-LOG\n" .. tags .. "END-TEST-LOG\n"
end, 1)
assert(replacements == 1, "PDF-tags marker not found in " .. log_name)

local handle = assert(io.open(log_name, "wb"))
assert(handle:write(log))
assert(handle:close())
