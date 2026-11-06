-- Composes the CTAN submission data (an l3build `uploadconfig`) of one
-- release unit from the package register (tools/packages.lua) and the
-- hand-written texts in ctan/<unit>/:
--
--   summary.txt  description.html  announcement.txt  note.txt
--
-- Everything that follows from the register is generated instead of
-- repeated in those texts: license, topics, CTAN path, version, the update
-- flag (ctan/released.lua), the dependency paragraph appended to the
-- description, and the fragments appended to the note (ctan/fragments/).
-- Used by ctan/upload.lua and tools/make-ctan-metadata.lua; run from the
-- bundle root.

local packages = dofile("tools/packages.lua")

local AUTHOR     = "Matthias Werner"
local REPOSITORY = "https://github.com/werner-matthias/osglecture"

-- CTAN's field limits, in bytes.
local LIMITS = { summary = 128, description = 4096,
                 announcement = 8192, note = 8192 }

local M = { LIMITS = LIMITS }

local function by_name()
  local map = { }
  for _, entry in ipairs(packages.modules) do
    map[entry.name] = entry
  end
  return map
end

-- A release unit is a module with its own CTAN package or the module that
-- names a bundle; the other bundle members travel with it.
function M.units()
  local list = { }
  for _, entry in ipairs(packages.modules) do
    if entry.ctan ~= false and (not entry.bundle or entry.bundle == entry.name) then
      table.insert(list, entry)
    end
  end
  return list
end

function M.unit(name)
  for _, entry in ipairs(M.units()) do
    if entry.ctanpkg == name or entry.name == name then
      return entry
    end
  end
  return nil
end

-- Modules whose code is shipped in the unit's package: the unit itself,
-- the other members of its bundle, and modules merged into it.
local function members(unit)
  local list = { }
  for _, entry in ipairs(packages.modules) do
    if entry == unit
        or (unit.bundle and entry.bundle == unit.bundle)
        or entry.merged_into == unit.name then
      table.insert(list, entry)
    end
  end
  return list
end

local function read_text(path)
  local text = packages.read_file(path)
  if text and text:match("^%s*$") then
    return nil
  end
  return text
end

-- "ltx-talk >= 0.5.3" -> "ltx-talk (0.5.3 or later)"
local function external_text(item)
  local name, version = item:match("^(%S+)%s*>=%s*(%S+)$")
  if name then
    return name .. " (" .. version .. " or later)"
  end
  return item
end

local KINDS = { "run", "optional", "check", "doc" }
local VALID_KIND = { }
for _, kind in ipairs(KINDS) do VALID_KIND[kind] = true end

-- The module the context note relates every other package to.
local CONTEXT_ROOT = "osglecture"

-- A package pulled in by `run` is always needed to run its dependent, so it
-- also counts for its test suite and for its documentation.
local function counts_as(kind, wanted)
  return kind == wanted or ((wanted == "check" or wanted == "doc") and kind == "run")
end

-- The rows of the matrix plus the implicit `doc` rows of `doc_default`.
local function all_edges()
  local edges = { }
  for _, edge in ipairs(packages.dependencies) do
    table.insert(edges, edge)
  end
  for _, entry in ipairs(packages.modules) do
    for _, name in ipairs(packages.doc_default) do
      if name ~= entry.name then
        table.insert(edges, { entry.name, name, "doc" })
      end
    end
  end
  return edges
end
M.edges = all_edges

-- The unit's dependencies by kind: { run = { "osgmodes", ... }, ... }, with
-- the unit's own members left out and external packages rendered as text.
-- Repository dependencies come first, each list sorted.
function M.dependencies(unit)
  local names = by_name()
  local own, group = { }, members(unit)
  for _, entry in ipairs(group) do
    own[entry.name] = true
  end
  local result = { }
  for _, kind in ipairs(KINDS) do
    local seen, list, external = { }, { }, { }
    for _, edge in ipairs(all_edges()) do
      local from, to = names[edge[1]], names[edge[2]]
      if from and own[from.name] and counts_as(edge[3], kind) then
        local pkg = to and (to.merged_into and names[to.merged_into] or to)
        if pkg and not own[pkg.name] then
          local label = pkg.bundle or pkg.ctanpkg or pkg.name
          if not seen[label] then
            seen[label] = true
            table.insert(list, label)
          end
        end
      end
    end
    for _, edge in ipairs(packages.external_dependencies) do
      local from = names[edge[1]]
      if from and own[from.name] and counts_as(edge[3], kind) then
        local text = external_text(edge[2])
        if not seen[text] then
          seen[text] = true
          table.insert(external, text)
        end
      end
    end
    table.sort(list)
    table.sort(external)
    for _, text in ipairs(external) do
      table.insert(list, text)
    end
    result[kind] = list
  end
  return result
end

-- How the context root relates to a module: "run" when it is reachable from
-- the root through `run` dependencies alone (the root cannot work without
-- it), "none" otherwise.  Every other kind of dependency is an optional
-- convenience for authors and not a relation worth stating.
local function reachability()
  local level = { [CONTEXT_ROOT] = "run" }
  local changed = true
  while changed do
    changed = false
    for _, edge in ipairs(packages.dependencies) do
      local from, to, kind = edge[1], edge[2], edge[3]
      if kind == "run" and level[from] and not level[to] then
        level[to] = "run"
        changed = true
      end
    end
  end
  return level
end

-- The context relation of a unit to the context root: "run" if any of its
-- members is required by the root.
function M.context_relation(unit)
  local level = reachability()
  for _, entry in ipairs(members(unit)) do
    if level[entry.name] == "run" then
      return "run"
    end
  end
  return "none"
end

-- Problems of the matrix itself: unknown modules, unknown kinds, `run`
-- cycles.
function M.matrix_problems()
  local names, list = by_name(), { }
  local function check(edges, external)
    for _, edge in ipairs(edges) do
      local label = edge[1] .. " -> " .. edge[2] .. " (" .. tostring(edge[3]) .. ")"
      if not names[edge[1]] then
        table.insert(list, label .. ": unknown module " .. edge[1])
      end
      if not external and not names[edge[2]] then
        table.insert(list, label .. ": unknown module " .. edge[2])
      end
      if external and names[edge[2]] then
        table.insert(list, label .. ": " .. edge[2]
          .. " is a module of this repository, not an external package")
      end
      if not VALID_KIND[edge[3]] then
        table.insert(list, label .. ": unknown kind")
      end
    end
  end
  check(packages.dependencies, false)
  check(packages.external_dependencies, true)
  for _, problem in ipairs(M.typeset_problems()) do
    table.insert(list, problem)
  end
  -- A `run` cycle makes no package loadable first.
  local state = { }
  local function visit(name, path)
    if state[name] == "done" then return end
    if state[name] == "open" then
      table.insert(list, "run dependency cycle: " .. path .. name)
      return
    end
    state[name] = "open"
    for _, edge in ipairs(packages.dependencies) do
      if edge[1] == name and edge[3] == "run" then
        visit(edge[2], path .. name .. " -> ")
      end
    end
    state[name] = "done"
  end
  for _, entry in ipairs(packages.modules) do
    visit(entry.name, "")
  end
  return list
end

-- The matrix as text: one row per module, one column per module (numbered),
-- cells R (run), O (optional), C (check only), D (doc only), several letters
-- when a pair has several kinds; third-party packages follow below.
function M.matrix_text()
  local modules = packages.modules
  local index = { }
  for i, entry in ipairs(modules) do index[entry.name] = i end
  local cells = { }
  local function put(from, to, kind)
    local key = from .. "\0" .. to
    local letter = ({ run = "R", optional = "O", check = "C", doc = "D" })[kind]
    cells[key] = (cells[key] or "") .. letter
  end
  for _, edge in ipairs(all_edges()) do put(edge[1], edge[2], edge[3]) end

  local width = 0
  for _, entry in ipairs(modules) do width = math.max(width, #entry.name) end
  local lines = { }
  local header = string.rep(" ", width + 5)
  for i = 1, #modules do header = header .. string.format("%-3d", i) end
  table.insert(lines, header)
  for i, entry in ipairs(modules) do
    local row = string.format("%2d %-" .. width .. "s  ", i, entry.name)
    for _, column in ipairs(modules) do
      local cell = cells[entry.name .. "\0" .. column.name]
      row = row .. string.format("%-3s", cell or ".")
    end
    table.insert(lines, row)
  end
  table.insert(lines, "")
  table.insert(lines, "R run, O optional, C check only, D doc only (rows depend on columns);")
  table.insert(lines, "every module also needs " .. table.concat(packages.doc_default, " and ") .. " for its documentation (D)")
  if #packages.external_dependencies > 0 then
    table.insert(lines, "")
    table.insert(lines, "Third-party packages:")
    for _, edge in ipairs(packages.external_dependencies) do
      table.insert(lines, string.format("  %-" .. width .. "s %-9s %s", edge[1], edge[3], edge[2]))
    end
  end
  return table.concat(lines, "\n")
end

-- Paragraph for the CTAN description; empty when there is nothing to say.
function M.dependency_paragraph(unit)
  local deps = M.dependencies(unit)
  local parts = { }
  if #deps.run > 0 then
    table.insert(parts, "Requires " .. table.concat(deps.run, ", ") .. ".")
  end
  if #deps.optional > 0 then
    table.insert(parts, "Optionally uses " .. table.concat(deps.optional, ", ") .. ".")
  end
  if #parts == 0 then
    return nil
  end
  return "<p>" .. table.concat(parts, " ") .. "</p>"
end

-- Sentence for the CTAN note on what typesetting the documentation needs.
local function documentation_note(unit)
  local deps = M.dependencies(unit)
  if #deps.doc == 0 then
    return nil
  end
  return "Documentation\n   Typesetting the documentation (l3build doc) needs: "
    .. table.concat(deps.doc, ", ") .. "."
end

-- True when the unit's tests compare PDF tag trees, which needs a helper
-- script that is not part of any CTAN package.
local function needs_pdf_tag_support(unit)
  for _, entry in ipairs(members(unit)) do
    local build = packages.read_file(entry.name .. "/build.lua") or ""
    if build:find("insert-pdf-tags", 1, true) then
      return true
    end
  end
  return false
end

local function bundle_release_date()
  local readme = packages.read_file("README.md") or ""
  local date = readme:match(
    "<!%-%- BUNDLE RELEASE DATE %-%->(.-)<!%-%- /BUNDLE RELEASE DATE %-%->"
  )
  if date and date:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return date
  end
  return nil
end

-- Version l3build submits: the release date for a bundle, the version in
-- the sources otherwise. nil when the unit is unreleased or inconsistent.
local function version_of(unit)
  if unit.bundle then
    return bundle_release_date()
  end
  for _, report in ipairs(packages.scan()) do
    if report.name == unit.name and report.consistent then
      return report.version_list[1]
    end
  end
  return nil
end

-- The raw hand-written parts, nil where a file is missing or blank.
function M.texts(unit)
  local dir = "ctan/" .. (unit.ctanpkg or unit.name) .. "/"
  return {
    summary      = read_text(dir .. "summary.txt"),
    description  = read_text(dir .. "description.html"),
    announcement = read_text(dir .. "announcement.txt"),
    note         = read_text(dir .. "note.txt"),
  }
end

local function trim_end(text)
  return (text:gsub("%s+$", ""))
end

-- The uploadconfig of a unit. Missing texts stay nil, so l3build asks for
-- them; M.problems() reports them beforehand.
function M.uploadconfig(unit)
  if type(unit) == "string" then
    unit = M.unit(unit) or error("no such release unit: " .. unit)
  end
  local pkg = unit.ctanpkg or unit.name
  local texts = M.texts(unit)
  local released = dofile("ctan/released.lua")

  local description = texts.description and trim_end(texts.description)
  local deps = M.dependency_paragraph(unit)
  if description and deps then
    description = description .. "\n\n" .. deps
  end

  local note = texts.note and trim_end(texts.note)
  if note then
    local parts = { note }
    local documentation = documentation_note(unit)
    if documentation then
      table.insert(parts, documentation)
    end
    if needs_pdf_tag_support(unit) then
      table.insert(parts, trim_end(packages.read_file("ctan/fragments/test-support-note.txt") or ""))
    end
    if not unit.bundle then
      local fragment = "ctan/fragments/context-"
        .. M.context_relation(unit) .. ".txt"
      table.insert(parts, trim_end(packages.read_file(fragment)
        or error("missing " .. fragment)))
    end
    note = table.concat(parts, "\n\n") .. "\n"
  end

  return {
    pkg          = pkg,
    version      = version_of(unit),
    author       = AUTHOR,
    uploader     = AUTHOR,
    update       = released[pkg] ~= nil,
    ctanPath     = packages.ctanpath_for(unit),
    license      = unit.license or { "lppl1.3c" },
    summary      = texts.summary and trim_end(texts.summary),
    description  = description,
    topic        = unit.topic,
    home         = REPOSITORY,
    repository   = REPOSITORY,
    bugtracker   = REPOSITORY .. "/issues",
    announcement = texts.announcement,
    note         = note,
  }
end

-- Checks the module build files against the register: a bundle member sets
-- `bundle` to the bundle, any other module to "", and `tdsroot` follows the
-- Lua marker.
local function build_file_problems(unit)
  local list = { }
  for _, entry in ipairs(members(unit)) do
    local build = packages.read_file(entry.name .. "/build.lua")
    if build then
      local bundle = build:match('^bundle%s*=%s*"([^"]*)"')
      local expected = entry.bundle or ""
      if bundle ~= expected then
        table.insert(list, entry.name .. "/build.lua: bundle is '"
          .. tostring(bundle) .. "', the register says '" .. expected .. "'")
      end
      local tdsroot = build:match('\ntdsroot%s*=%s*"([^"]*)"')
      local wanted = packages.tdsroot_for(entry)
      if wanted and (tdsroot or "luatex") ~= wanted then
        table.insert(list, entry.name .. "/build.lua: tdsroot is '"
          .. (tdsroot or "luatex") .. "', the register's Lua marker says '"
          .. wanted .. "'")
      end
    end
  end
  return list
end

-- Typesetting dependencies named in the build files must be explained by
-- the matrix, and the root build.lua must apply the same default rule.
function M.typeset_problems()
  local list = { }
  local names = by_name()
  local edges = all_edges()
  local function explained(from, to)
    for _, edge in ipairs(edges) do
      if edge[1] == from and edge[2] == to and counts_as(edge[3], "doc") then
        return true
      end
    end
    return false
  end
  local root = packages.read_file("build.lua") or ""
  for _, name in ipairs(packages.doc_default) do
    if not root:find('add_typeset_dependency("../' .. name .. '")', 1, true) then
      table.insert(list, "build.lua does not add " .. name
        .. " to typesetdeps, but doc_default says it should")
    end
  end
  local builds = { }
  for _, entry in ipairs(packages.modules) do
    builds[entry.name .. "/build.lua"] = entry.name
  end
  builds["manual-src/build.lua"] = "osglecture"
  for file, from in pairs(builds) do
    local build = packages.read_file(file) or ""
    local deps = build:match("\ntypesetdeps%s*=%s*(%b{})")
    for to in (deps or ""):gmatch('"%.%./([^"]+)"') do
      if names[to] and to ~= from and not explained(from, to) then
        table.insert(list, file .. ": typesetdeps names " .. to
          .. ", but the matrix has no doc dependency " .. from .. " -> " .. to)
      end
    end
  end
  return list
end

-- The README of a unit: the module's own, for a bundle that of the module
-- naming the bundle.
function M.readme_path(unit)
  return unit.name .. "/README.md"
end

local function markdown_item(text)
  local name, rest = text:match("^(%S+) %((.-)%)$")
  if name then
    return "`" .. name .. "` " .. rest
  end
  return "`" .. text .. "`"
end

local function markdown_list(list)
  local items = { }
  for _, text in ipairs(list) do
    table.insert(items, markdown_item(text))
  end
  return table.concat(items, ", ")
end

-- The generated "Dependencies" section of a unit's README, markers included.
function M.dependency_section(unit)
  local deps = M.dependencies(unit)
  local lines = {
    "<!-- BEGIN DEPENDENCIES (generated by tools/make-package-readmes.lua) -->",
    "## Dependencies",
    "",
    "Dependencies on other packages of this project and on selected third-party",
    "packages; the usual LaTeX packages the code loads itself are not listed.",
    "",
  }
  local labels = {
    { "run", "Required at run time" },
    { "optional", "Optionally used" },
    { "doc", "Required to build the documentation (`l3build doc`)" },
    { "check", "Required to run the test suite (`l3build check`)" },
  }
  local any = false
  for _, label in ipairs(labels) do
    if #deps[label[1]] > 0 then
      any = true
      table.insert(lines, "- " .. label[2] .. ": " .. markdown_list(deps[label[1]]))
    end
  end
  if not any then
    table.insert(lines, "- None.")
  end
  if not unit.bundle then
    local fragment = "ctan/fragments/context-"
      .. M.context_relation(unit) .. ".txt"
    local text = packages.read_file(fragment) or error("missing " .. fragment)
    text = text:gsub("^Context%s*\n", ""):gsub("^%s+", ""):gsub("%s*\n%s*", " "):gsub("%s+$", "")
    table.insert(lines, "")
    table.insert(lines, text)
  end
  table.insert(lines, "<!-- END DEPENDENCIES -->")
  return table.concat(lines, "\n")
end

-- Human-readable problems that would make a submission wrong or incomplete.
function M.problems(unit)
  local list = { }
  local config = M.uploadconfig(unit)
  for _, field in ipairs({ "summary", "description", "announcement", "note" }) do
    local value = config[field]
    if not value then
      table.insert(list, field .. " is missing (ctan/" .. config.pkg .. "/)")
    elseif #value > LIMITS[field] then
      table.insert(list, string.format("%s is %d bytes, the limit is %d",
        field, #value, LIMITS[field]))
    end
  end
  if config.summary and config.summary:find("\n", 1, true) then
    table.insert(list, "summary spans several lines")
  end
  for _, problem in ipairs(build_file_problems(unit)) do
    table.insert(list, problem)
  end
  if not config.version then
    table.insert(list, "version unknown (unreleased or inconsistent sources)")
  end
  return list
end

return M
