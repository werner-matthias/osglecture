-- The package register: one entry per CTAN-versioned release unit, read by
-- tools/update-bundle-manifest.lua, tools/make-ctan-readme.lua, and the
-- bundle's build.lua ("l3build gittag"). It is the single place that knows
-- a module's \Provides-carrying files, its CTAN identity, and its
-- dependencies on other modules of this repository; generators and
-- build.lua derive everything else (the README module table, the
-- checkdeps/typesetdeps lists, the per-package dependency sections, the
-- CTAN upload metadata) from it instead of repeating it.
--
-- Fields:
--   name     the module's directory and l3build `module` name (unchanged
--            by any CTAN-side rename; this is what checkdeps paths,
--            git tags, and the testfiles/ layout key on)
--   ctanpkg  the package's CTAN/TDS name; equal to `name` unless the
--            package is being renamed for CTAN (see
--            development-docs/CTAN-SPLIT.md)
--   files    paths (relative to the bundle root) scanned for
--            \Provides*/\ProvidesFile declarations
--   exclude  package names within those files to leave out of the
--            version-consistency check (frozen legacy code, say)
--   lua      Lua-dependency marker, also the input to `tdsroot_for`/
--            `ctanpath_for` below
--   note     footnote text shown next to this module's row in the
--            generated README table
--   extractor  non-standard version extraction (e.g. a Perl module that
--            carries no \Provides... declaration at all)
--   bundle   "osglecture" for the two modules that remain one CTAN
--            submission (osglecture itself is useless without its build
--            manager, and vice versa); absent for every standalone
--            package, which is released and uploaded on its own
--   deps     this module's dependencies on other modules of this
--            repository (never on third-party CTAN packages), by
--            `ctanpkg` name: `run` (unconditional \RequirePackage),
--            `optional` (integration the module's own code checks for
--            before using), `check` (needed only to build/run its test
--            suite), `doc` (needed only to typeset its documentation)
--   ctan     false for a module that is not released as its own CTAN
--            package; `merged_into` then names the package whose source
--            carries its code instead
--
-- Perl has no \Provides... declaration; osgdocmk keeps its version as
-- the single $VERSION in OSGDocMk::Version instead (see the `extractor`
-- entry below).
local modules = {
  { name = "osglecture",       ctanpkg = "osglecture", bundle = "osglecture",
    files = {
      "osglecture/osglecture.dtx",
      "osglecture/osglecture-adapters.dtx",
      "osglecture/osglecture-profiles.dtx",
  },
  -- osglecture-osgbeamer.code.tex is a frozen, unpublished legacy path
  -- (slated for removal); it deliberately keeps its own version instead
  -- of following the shared osglecture version.
  exclude = { ["osglecture-osgbeamer.code.tex"] = true },
    lua = ':full_moon:',
    -- tagbridge is not a run dependency: its accessibility patches belong
    -- to semcat, the only package that actually exercises them (see
    -- development-docs/CTAN-SPLIT.md, Abschnitt 4). osglecture loading it
    -- on semcat's behalf is exactly the coupling that split removes.
    deps = { run = { "osgmodes", "tagpax" }, check = { "langselect" } } },
  { name = "osgmodes", ctanpkg = "osgmodes",
    files = { "osgmodes/osgmodes.dtx" },
    lua = ':full_moon:' },
  { name = "osgdocmk", ctanpkg = "osgdocmk", bundle = "osglecture",
    files = { "osgdocmk/scripts/lib/OLLM/Version.pm" },
    lua = ':white_circle:',
    extractor = "perl_version" },
  { name = "tagpax", ctanpkg = "tagpax", files = { "tagpax/source/tagpax.dtx" },
    lua = ':full_moon:' },
  -- Not its own CTAN package: a transitional patch for third-party
  -- packages without native PDF/UA support, only actually exercised by
  -- semcat (semcat.dtx calls the `tag` key this file defines on qrcode;
  -- see development-docs/CTAN-SPLIT.md, Abschnitt 4). It keeps its own
  -- version-tracking entry here only until its code is moved into
  -- semcat's own sources.
  { name = "tagbridge",        files = { "tagbridge/tagbridge.dtx" },
    lua = ':new_moon:', ctan = false, merged_into = "semcat" },
  { name = "tagdirtree",       ctanpkg = "tagdirtree",
    files = { "tagdirtree/tagdirtree.dtx" },
    note = "The incompatibility for TL 2024 refers to tagging only; the untagged tree is okay.",
    lua = ':new_moon:' },
  { name = "langselect",       ctanpkg = "langselect",
    files = { "langselect/langselect.dtx" },
    lua = ':full_moon:' },
  { name = "osgstyler",        ctanpkg = "osgstyler",
    files = { "osgstyler/osgstyler.dtx" },
    lua = ':first_quarter_moon:',
    deps = { check = { "osgmodes" } } },
  -- Neither lttalk-themeengine nor lttalk-theme-tuc-2019 touches Lua in
  -- its own code, but each unconditionally \RequirePackage{}s a package
  -- that only degrades without Lua (osgstyler directly;
  -- lttalk-theme-tuc-2019 transitively through lttalk-themeengine) -- a
  -- hard dependency's Lua requirement is the using package's own, so
  -- both carry :first_quarter_moon: rather than :new_moon: here
  -- (development-docs/CTAN-SPLIT.md, Abschnitt 6).
  { name = "lttalk-themeengine",          ctanpkg = "lttalk-themeengine",
    files = { "lttalk-themeengine/lttalk-themeengine.dtx" },
    lua = ':first_quarter_moon:',
    deps = { run = { "osgstyler" }, check = { "osgstyler" } } },
  { name = "lttalk-theme-tuc-2019", ctanpkg = "lttalk-theme-tuc-2019",
    files = { "lttalk-theme-tuc-2019/lttalk-theme-tuc-2019.dtx" },
    lua = ':first_quarter_moon:',
    -- Images used only by this theme's example and tests; it is the sole
    -- owner of images/logos for the purposes of a CTAN export (see
    -- development-docs/CTAN-SPLIT.md, Abschnitt 12).
    owns_support = { "images/logos" },
    deps = {
      run = { "lttalk-themeengine" },
      -- checkdeps/typesetdeps are not transitive, so the teaching-lecture-
      -- number test (which loads osglecture directly) and the dependency
      -- lttalk-themeengine itself has on osgstyler both have to be
      -- repeated here.
      check = { "lttalk-themeengine", "osgstyler", "osglecture",
                "osgmodes", "tagpax" },
    } },
  { name = "ansiterm",         ctanpkg = "ansiterm",
    files = { "ansiterm/ansiterm.dtx" },
    lua = ':full_moon:',
    note = "The incompatibility for TL 2025 refers to tagging only; the basis features are okay." },
  { name = "osglistings",      ctanpkg = "osglistings",
    files = { "osglistings/osglistings.dtx" },
    lua = ':full_moon:' },
  { name = "semcat",           ctanpkg = "semcat",
    files = { "semcat/semcat.dtx" },
    lua = ':full_moon:',
    -- Optional per semcat's own README: osgstyler supplies theme-aware
    -- colours, osgmodes restricts annotations to selected
    -- document variants. Neither is \RequirePackage'd unconditionally.
    deps = { optional = { "osgstyler", "osgmodes" },
             check = { "osgmodes", "osgstyler" } } },
  { name = "osgdoc",           ctanpkg = "osgdoc",
    files = { "osgdoc/osgdoc.dtx" },
    lua = ':first_quarter_moon:' },
}

-- Where a package's lua-dependency marker places it in the installed TeX
-- tree: CTAN/TL categorise by minimal engine requirement, not by best
-- use, so a package that only improves under LuaTeX (:first_quarter_moon:)
-- is placed exactly like one that requires it outright
-- (development-docs/CTAN-SPLIT.md, Abschnitt 6). A Perl script has no
-- tex/ tree at all; its own build.lua places it under scripts/ via
-- `tdsdirs` directly.
local TDSROOT = {
  [':full_moon:']          = "luatex",
  [':first_quarter_moon:'] = "luatex",
  [':new_moon:']           = "latex",
}

local function tdsroot_for(entry)
  return TDSROOT[entry.lua]
end

-- The CTAN path to propose for a package's own submission. CTAN treats
-- this as a proposal and may place the package elsewhere; `osglecture`
-- and `osgdocmk` are the one exception that is not a proposal at all,
-- since CTAN already accepted their shared, mixed macros+scripts path
-- with the 2026-10-23 release and that submission is only ever updated,
-- never resubmitted (development-docs/CTAN-SPLIT.md, Abschnitt 13).
local BUNDLE_CTANPATH = "/macros/luatex/latex/osglecture"

local function ctanpath_for(entry)
  if entry.bundle == "osglecture" then
    return BUNDLE_CTANPATH
  end
  local pkg = entry.ctanpkg or entry.name
  if entry.lua == ':white_circle:' then
    return "/support/" .. pkg
  elseif tdsroot_for(entry) == "luatex" then
    return "/macros/luatex/latex/" .. pkg
  else
    return "/macros/latex/contrib/" .. pkg
  end
end

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

-- Perl module holding a single "our $VERSION = '...';" line (OSGDocMk's
-- own single-source-of-truth convention; no accompanying date).
local function extract_perl_version(content)
  local version = content:match("VERSION%s*=%s*'([^']*)'")
    or content:match('VERSION%s*=%s*"([^"]*)"')
  if not version then return {} end
  return { { package = "osgdocmk", date = "n/a", version = version } }
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
  tdsroot_for = tdsroot_for,
  ctanpath_for = ctanpath_for,
}
