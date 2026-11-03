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

-- latex-lab-namespace.dtx renamed its generic paragraph-level structure
-- synonyms (text-unit -> semantic-para, text -> text-block; changes.txt,
-- 2026-07-29) without changing the tag tree these tests actually check.
-- Map the newer spelling back to the one recorded in the .tlg files so a
-- single reference matches either tagpdf generation; order matters, since
-- "text-block" contains "text" and must be handled before any bare "text"
-- substitution (there is none here, so this is otherwise order-independent).
tags = tags:gsub("semantic%-para", "text-unit")
tags = tags:gsub("text%-block", "text")
-- The same restructuring also renamed the existing heading-specific
-- wrapper to section-heading and reused its old name "section" for a
-- new, differently-scoped wrapper (see NEW_LEAF_WRAPPERS below) --
-- this rename must run first, so the reused name is free for that
-- unwrap step to claim without colliding with it.
tags = tags:gsub("section%-heading", "section")

-- The same latex-lab update also started wrapping leaf content that
-- previously stood directly as its plain PDF-namespace role element in
-- a new symbolic element of its own (so far spotted: text-fragment for
-- Span -- "Added text-fragment (default Span)" -- and text-parbox for
-- Div). Unwrap any of these back to the plain element it replaces, so
-- the same reference matches either tagpdf generation. Each is a
-- leaf/inline wrapper -- never containing another instance of itself --
-- so its opening and closing tags pair up by document order alone.
-- New names join NEW_LEAF_WRAPPERS below as they turn up; the list is
-- deliberately an allowlist of elements that are leaves (never contain
-- another instance of themselves), not every element with a
-- rolemaps-to attribute -- most structure types (text-unit, text, ...)
-- carry one permanently, and unwrapping those would erase exactly the
-- symbolic-to-role mapping these tests check.
--
-- NOT handled here: the same restructuring reused the name "section"
-- for a second, nesting wrapper around what used to be a bare Sect
-- (while the original, heading-specific "section" became
-- "section-heading", renamed above) -- two elements of the same name
-- can be nested inside each other, so matching closing tags needs
-- real nesting-depth tracking, not the flat, sequential pairing that
-- works for an actual leaf. Left as a known remaining gap; see
-- development-docs/CTAN-SPLIT.md or the session notes for which tests
-- that still affects.
local NEW_LEAF_WRAPPERS = { "text%-fragment", "text%-parbox", "text%-minipage" }
for _, element in ipairs(NEW_LEAF_WRAPPERS) do
  -- show-pdf-tags indents the closing ">" of a multi-line tag one
  -- column left of its attributes, regardless of the element or how
  -- many attributes it has; recompute that from the attribute block's
  -- own indentation rather than reusing the wrapper's (one extra
  -- attribute line, hence one indent level deeper than the plain
  -- element's closing ">" used to be).
  local roles = { }
  tags = tags:gsub(
    '<' .. element .. ' xmlns="https://www%.latex%-project%.org/ns/dflt"'
      .. '(.-)rolemaps%-to="([^"]+)"%s*\n%s*>',
    function(attrs, role)
      table.insert(roles, role)
      local attr_indent = attrs:match("\n(%s*)%S") or ""
      local close_indent = attr_indent:sub(1, -2)
      local trimmed_attrs = attrs:gsub("%s*$", "")
      return "<" .. role .. ' xmlns="http://iso.org/pdf2/ssn"' .. trimmed_attrs
        .. "\n" .. close_indent .. ">"
    end
  )
  local index = 0
  tags = tags:gsub("</" .. element .. ">", function()
    index = index + 1
    return "</" .. assert(roles[index],
      "insert-pdf-tags: more </" .. element .. "> closing tags than opening ones")
      .. ">"
  end)
end

local marker = "%-%-INSERT%-PDF%-TAGS%s+[^\r\n]+%s*\r?\n"
local replacements
log, replacements = log:gsub(marker, function()
  return "START-TEST-LOG\n" .. tags .. "END-TEST-LOG\n"
end, 1)
assert(replacements == 1, "PDF-tags marker not found in " .. log_name)

local handle = assert(io.open(log_name, "wb"))
assert(handle:write(log))
assert(handle:close())
