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
  exclude = { ["osglecture-osgbeamer.code.tex"] = true } },
  { name = "osglecture-modes", files = { "osglecture-modes/osglecture-modes.dtx" } },
  { name = "tagpax",           files = { "tagpax/source/tagpax.dtx" } },
  { name = "langselect",       files = { "langselect/langselect.dtx" } },
  { name = "lttheme",          files = { "lttheme/lttheme.dtx" } },
  { name = "lttheme-tuc-2019", files = { "lttheme-tuc-2019/lttheme-tuc-2019.dtx" } },
  { name = "osgdoc",           files = { "osgdoc/osgdoc.dtx" } },
  -- ollm is Perl, not a docstripped LaTeX package: it keeps its version
  -- as the single $VERSION in OLLM::Version, the same file ollm.tex's
  -- own driver already parses (with the same "VERSION = '...'" pattern)
  -- to fill in its documentation's version field.
  { name = "ollm", files = { "ollm/scripts/lib/OLLM/Version.pm" },
    extractor = "perl_version" },
}

-- Editorial annotation appended to a module's name cell in the README table
-- (not inferred)
local NOTES = {
  ["osglecture-modes"] = "[^1]",
}

-- Distribution-compatibility columns are filled in by hand after running
-- the "Distribution compatibility" GitHub Actions workflow (see
-- .github/workflows/compatibility.yml); this script re-reads whatever is
-- currently in the README table before rebuilding it => a version bump does
-- not wipe out that manual work.
local COMPAT_HEADERS = { "TL 2024", "TL 2025", "TL current" }
local COMPAT_SEED = {
  osglecture           = { ":x:",  ":+1:", ":+1:" },
  ["osglecture-modes"] = { ":+1:", ":+1:", ":+1:" },
  tagpax               = { ":+1:", ":+1:", ":+1:" },
  langselect           = { ":+1:", ":+1:", ":+1:" },
  lttheme              = { ":x:",  ":x:",  ":+1:" },
  ["lttheme-tuc-2019"] = { ":x:",  ":x:",  ":+1:" },
  osgdoc               = { ":+1:", ":+1:", ":+1:" },
  ollm                 = { ":x:",  ":+1:", ":+1:" },
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

-- Splits one "| a | b | c |" markdown table row into trimmed cell strings.
local function split_row(row)
  local body = row:match("^%s*|?(.-)|?%s*$") or row
  local cells = {}
  for cell in (body .. "|"):gmatch("(.-)|") do
    table.insert(cells, (cell:gsub("^%s*(.-)%s*$", "%1")))
  end
  return cells
end

-- Reads the compatibility columns currently in README.md's generated
-- table, keyed by module name (with any trailing "[^n]" note stripped),
-- so rebuilding the table preserves hand-edited compatibility marks.
local function read_existing_compat(readme_path)
  local content = read_file(readme_path)
  if not content then return {} end
  local block = content:match(
    "<!%-%- BEGIN MODULE VERSIONS.-\n(.-)\n<!%-%- END MODULE VERSIONS %-%->")
  if not block then return {} end
  local compat = {}
  for line in (block .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^%s*|") and not line:match("^%s*|%s*%-") then
      local cells = split_row(line)
      local name = cells[1]
      if name and name ~= "Module" then
        name = name:gsub("%[%^%d+%]$", "")
        if cells[5] and cells[6] and cells[7] then
          compat[name] = { cells[5], cells[6], cells[7] }
        end
      end
    end
  end
  return compat
end

local existing_compat = read_existing_compat("README.md")

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

-- Markdown table for README.md: version/date/file-count plus the
-- (manually maintained) distribution-compatibility columns.
local header_cells = { "Module", "Version", "Date", "Files" }
for _, h in ipairs(COMPAT_HEADERS) do table.insert(header_cells, h) end
local lines = {
  "<!-- BEGIN MODULE VERSIONS " ..
    "(generated by tools/update-bundle-manifest.lua; " ..
    "compatibility columns are hand-edited, see below) -->",
  "| " .. table.concat(header_cells, " | ") .. " |",
  "|" .. string.rep("---|", #header_cells),
}
for _, r in ipairs(report) do
  local version_cell, date_cell
  if #r.entries == 0 then
    version_cell, date_cell = "n/a", "n/a"
  elseif r.consistent then
    version_cell, date_cell = r.version_list[1], r.date_list[1]
  else
    version_cell = "mixed (" .. table.concat(r.version_list, ", ") .. ")"
    date_cell = "mixed (" .. table.concat(r.date_list, ", ") .. ")"
  end
  local compat = existing_compat[r.name] or COMPAT_SEED[r.name] or { "?", "?", "?" }
  local name_cell = r.name .. (NOTES[r.name] or "")
  local row_cells = { name_cell, version_cell, date_cell, tostring(#r.entries) }
  for _, c in ipairs(compat) do table.insert(row_cells, c) end
  table.insert(lines, "| " .. table.concat(row_cells, " | ") .. " |")
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
