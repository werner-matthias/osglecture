#!/usr/bin/env texlua
-- Scans the bundle's LaTeX packages for \Provides* declarations, reports
-- whether the files generated from one docstrip source agree on version
-- and date, and refreshes the module-version table in README.md between
-- the "MODULE VERSIONS" markers.
--
-- Usage: texlua tools/update-bundle-manifest.lua   (run from the bundle root)

local modules = {
  { name = "osglecture",       files = {
      "osglecture/osglecture.dtx",
      "osglecture/osglecture-adapters.dtx",
      "osglecture/osglecture-profiles.dtx",
  },
  -- osglecture-osgbeamer.code.tex is a frozen, unpublished legacy path
  -- (slated for removal); it deliberately keeps its own version instead
  -- of following the shared osglecture version.
  exclude = { ["osglecture-osgbeamer.code.tex"] = true },
    lua = ':full_moon:' },
  { name = "osglecture-modes", files = { "osglecture-modes/osglecture-modes.dtx" },
    lua = ':full_moon:' },
  -- ollm is Perl, not a docstripped LaTeX package: it keeps its version
  -- as the single $VERSION in OLLM::Version, the same file ollm.tex's
  -- own driver already parses (with the same "VERSION = '...'" pattern)
  -- to fill in its documentation's version field.
  { name = "ollm", files = { "ollm/scripts/lib/OLLM/Version.pm" },
    lua = ':white_circle:',
    extractor = "perl_version" },
  { name = "tagpax",           files = { "tagpax/source/tagpax.dtx" },
    lua = ':full_moon:' },
  { name = "langselect",       files = { "langselect/langselect.dtx" },
    lua = ':full_moon:' },
  { name = "osgstyler",        files = { "osgstyler/osgstyler.dtx" },
    lua = ':first_quarter_moon:'},
  { name = "lttheme",          files = { "lttheme/lttheme.dtx" },
    lua = ':new_moon:' },
  { name = "lttheme-tuc-2019", files = { "lttheme-tuc-2019/lttheme-tuc-2019.dtx" },
    lua = ':new_moon:' },
  { name = "ansiterm",         files = { "ansiterm/ansiterm.dtx" },
    lua = ':full_moon:' },
  { name = "osglistings",      files = { "osglistings/osglistings.dtx" },
    lua = ':full_moon:' },
  { name = "osgdoc",           files = { "osgdoc/osgdoc.dtx" },
    lua = ':first_quarter_moon:' },
}

-- Distribution compatibility has a single point of truth: the expectations
-- evaluated by the "Distribution compatibility" GitHub Actions workflow.
local COMPAT_HEADERS = { "TL 2024", "TL 2025", "TL current" }
local WORKFLOW_TO_TABLE = {
  ["osglecture-modes-core"] = "osglecture-modes",
}
local EXPECTATION_MARK = {
  pass = ":green_circle:",
  fail = ":red_circle:",
  ["n/a"] = ":white_circle:",
}

-- Capability rows are placed directly after the module they extend.
local capabilities_after = {
  ["osglecture-modes"] = {
    "ltx-talk support (osglecture + osglecture-modes)",
    lua = ":full_moon:"
  },
}

-- \Provides commands whose arguments are three braced groups:
-- {name}{date}{version}, in this order for the Expl3/Expl variants, and
-- for the classic \ProvidesPackage/\ProvidesClass with explicit date and
-- version arguments (as opposed to the bracket form below).
local PROVIDES_BRACE = {
  "ProvidesExplPackage", "ProvidesExplClass",
  "ProvidesPackage", "ProvidesClass", "ProvidesExplFile",
}

local function read_file(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local content = fh:read("a")
  fh:close()
  return content
end

local function unquote(value)
  return value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
end

-- This deliberately parses only the small, regular component matrix in our
-- own workflow rather than pretending to be a general YAML parser.
local function read_workflow_compat(path)
  local content = assert(read_file(path), "cannot read compatibility workflow: " .. path)
  local result = {}
  local in_components = false
  local current

  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^%s*component:%s*$") then
      in_components = true
    elseif in_components and line:match("^%s*distribution:%s*$") then
      break
    elseif in_components then
      local name = line:match("^%s*%- name:%s*(.-)%s*$")
      if name then
        name = unquote(name)
        name = WORKFLOW_TO_TABLE[name] or name
        assert(not result[name], "duplicate compatibility table entry: " .. name)
        current = {}
        result[name] = current
      elseif current then
        local distribution, expectation =
          line:match("^%s*expect_([%w]+):%s*([^%s#]+)")
        if distribution == "2024" or distribution == "2025" or
           distribution == "current" then
          expectation = unquote(expectation)
          local mark = EXPECTATION_MARK[expectation]
          assert(mark, "unknown compatibility expectation: " .. expectation)
          current[distribution] = mark
        end
      end
    end
  end

  local ordered = {}
  for name, values in pairs(result) do
    assert(values["2024"] and values["2025"] and values.current,
      "incomplete compatibility expectations for " .. name)
    ordered[name] = { values["2024"], values["2025"], values.current }
  end
  return ordered
end

local workflow_compat = read_workflow_compat(".github/workflows/compatibility.yml")

-- Only the non-driver code sections should be scanned for real versions.
local function strip_driver_sections(content)
  return (content:gsub("%%<%*driver>.-%%</driver>", ""))
end

-- Perl module holding a single "our $VERSION = '...';" line (OLLM's own
-- single-source-of-truth convention; no accompanying date).
local function extract_perl_version(content)
  local version = content:match("VERSION%s*=%s*'([^']*)'")
    or content:match('VERSION%s*=%s*"([^"]*)"')
  if not version then return {} end
  return { { package = "ollm", date = "n/a", version = version } }
end

local EXTRACTORS = {
  perl_version = extract_perl_version,
}

-- Returns a list of {package=, date=, version=} for one file's content.
local function extract_provides(content)
  content = strip_driver_sections(content)
  local found = {}
  for _, kw in ipairs(PROVIDES_BRACE) do
    for name, date, version in content:gmatch(
      "\\" .. kw .. "%s*{([^}]*)}%s*{([^}]*)}%s*{([^}]*)}"
    ) do
      table.insert(found, { package = name, date = date, version = version })
    end
  end
  -- Classic \ProvidesFile{name}\n  [date vVERSION description]. The
  -- version token is only accepted if it actually looks like one
  -- (optional leading "v" followed by a digit); some \ProvidesFile
  -- lines in the bundle omit a version entirely and go straight to a
  -- free-text description, which must not be misread as a version.
  for name, rest in content:gmatch(
    "\\ProvidesFile%s*{([^}]*)}%s*%[%s*(.-)%]"
  ) do
    local date, version = rest:match("^(%S+)%s+v?(%d[%w%.%-]*)")
    if not date then
      date = rest:match("^(%S+)")
      version = "(none)"
    end
    table.insert(found, { package = name, date = date, version = version })
  end
  return found
end

local report = {}
for _, mod in ipairs(modules) do
  local exclude = mod.exclude or {}
  local extract = mod.extractor and EXTRACTORS[mod.extractor] or extract_provides
  local entries = {}
  for _, file in ipairs(mod.files) do
    local content = read_file(file)
    if content then
      for _, e in ipairs(extract(content)) do
        e.file = file
        e.excluded = exclude[e.package] or false
        table.insert(entries, e)
      end
    end
  end
  local versions, dates = {}, {}
  for _, e in ipairs(entries) do
    if not e.excluded then
      versions[e.version] = true
      dates[e.date] = true
    end
  end
  local version_list, date_list = {}, {}
  for v in pairs(versions) do table.insert(version_list, v) end
  for d in pairs(dates) do table.insert(date_list, d) end
  table.sort(version_list)
  table.sort(date_list)
  table.insert(report, {
    name = mod.name,
    entries = entries,
    consistent = (#version_list <= 1 and #date_list <= 1),
    version_list = version_list,
    date_list = date_list,
    lua = mod.lua,
  })
end

-- Console report, flagging mismatches within one module.
local any_mismatch = false
for _, r in ipairs(report) do
  if #r.entries == 0 then
    print(string.format("%-20s (no \\Provides declarations found)", r.name))
  elseif r.consistent then
    print(string.format(
      "%-20s %-10s %-12s [%d file(s), consistent]",
      r.name, r.version_list[1], r.date_list[1], #r.entries))
  else
    any_mismatch = true
    print(string.format("%-20s MIXED: %s", r.name, table.concat(r.version_list, ", ")))
    for _, e in ipairs(r.entries) do
      print(string.format(
        "    %-30s %-10s %-12s (%s)%s", e.package, e.version, e.date, e.file,
        e.excluded and "  [excluded from consistency check]" or ""))
    end
  end
end

-- Markdown table for README.md: version/date/file-count plus compatibility
-- expectations read from the workflow above.
local header_cells = { "Module", "Version", "Date", "Files", "Lua" }
local hformat = "|" .. string.rep("---|", 4)
  .. string.rep(":---:|", 1 + #COMPAT_HEADERS)
for _, h in ipairs(COMPAT_HEADERS) do table.insert(header_cells, h) end
local lines = {
  "<!-- BEGIN MODULE VERSIONS " ..
    "(generated by tools/update-bundle-manifest.lua; " ..
    "compatibility from .github/workflows/compatibility.yml) -->",
  "| " .. table.concat(header_cells, " | ") .. " |",
  hformat,
}
for _, r in ipairs(report) do
  local version_cell, date_cell, lua_cell
  if #r.entries == 0 then
    version_cell, date_cell, lua_cell = "n/a", "n/a","n/a"
  elseif r.consistent then
    version_cell, date_cell = r.version_list[1], r.date_list[1]
  else
    version_cell = "mixed (" .. table.concat(r.version_list, ", ") .. ")"
    date_cell = "mixed (" .. table.concat(r.date_list, ", ") .. ")"
  end
  lua_cell = r.lua
  local compat = assert(workflow_compat[r.name],
    "no workflow compatibility expectations for " .. r.name)
  local row_cells = { r.name, version_cell, date_cell, tostring(#r.entries), lua_cell }
  for _, c in ipairs(compat) do table.insert(row_cells, c) end
  table.insert(lines, "| " .. table.concat(row_cells, " | ") .. " |")
  for _, name in ipairs(capabilities_after[r.name] or {}) do
    local capability_compat = assert(workflow_compat[name],
      "no workflow compatibility expectations for " .. name)
    local capability_cells = { name, "n/a", "n/a", "n/a", ":full_moon:" }
    for _, c in ipairs(capability_compat) do
      table.insert(capability_cells, c)
    end
    table.insert(lines,
      "| " .. table.concat(capability_cells, " | ") .. " |")
  end
end
table.insert(lines, "<!-- END MODULE VERSIONS -->")
local table_block = table.concat(lines, "\n")

-- Splice the table into README.md between the markers.
local readme_path = "README.md"
local readme = read_file(readme_path)
if readme then
  local escaped_block = table_block:gsub("%%", "%%%%")
  local new_readme, count = readme:gsub(
    "<!%-%- BEGIN MODULE VERSIONS.-END MODULE VERSIONS %-%->",
    escaped_block
  )
  if count == 0 then
    print("\nNote: no BEGIN/END MODULE VERSIONS marker pair found in "
      .. readme_path .. "; table not inserted.")
  else
    local out = io.open(readme_path, "w")
    out:write(new_readme)
    out:close()
    print("\n" .. readme_path .. " module-version table refreshed.")
  end
else
  print("\nNote: " .. readme_path .. " not found; table not inserted.")
end

if any_mismatch then
  print("\nSome modules have files sharing one docstrip source but "
    .. "differing \\Provides version/date; consider syncing them.")
end
