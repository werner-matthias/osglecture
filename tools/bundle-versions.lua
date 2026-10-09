-- Shared by tools/update-bundle-manifest.lua and the bundle's build.lua
-- (target "gittag"): which files carry each module's version, and how to
-- read it.  Paths are relative to the bundle root.

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
  { name = "tagbridge",        files = { "tagbridge/tagbridge.dtx" },
    note = "The compatibility with TL 2024 and TL 2025 refers to untagged use; the tagging tests need the current distribution.",
    lua = ':new_moon:' },
  { name = "tagdirtree",       files = { "tagdirtree/tagdirtree.dtx" },
    note = "The compatibility with TL 2024 and TL 2025 refers to untagged use; the tagging tests need the current distribution.",
    lua = ':new_moon:' },
  { name = "langselect",       files = { "langselect/langselect.dtx" },
    lua = ':full_moon:' },
  { name = "osgstyler",        files = { "osgstyler/osgstyler.dtx" },
    lua = ':first_quarter_moon:'},
  { name = "lttheme",          files = { "lttheme/lttheme.dtx" },
    lua = ':new_moon:' },
  { name = "lttheme-tuc-2019", files = { "lttheme-tuc-2019/lttheme-tuc-2019.dtx" },
    lua = ':new_moon:' },
  { name = "ansiterm",         files = { "ansiterm/ansiterm.dtx" },
    lua = ':full_moon:',
    note = "The incompatibility for TL 2025 refers to tagging only; the basis features are okay." },
  { name = "osglistings",      files = { "osglistings/osglistings.dtx" },
    lua = ':full_moon:' },
  { name = "semcat",           files = { "semcat/semcat.dtx" },
    lua = ':full_moon:' },
  { name = "osgdoc",           files = { "osgdoc/osgdoc.dtx" },
    lua = ':first_quarter_moon:' },
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

-- Returns one entry per module: {name=, entries=, consistent=,
-- version_list=, date_list=, lua=, note=}.
local function scan()
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
      note = mod.note,
    })
  end
  return report
end

return {
  modules = modules,
  read_file = read_file,
  scan = scan,
}
