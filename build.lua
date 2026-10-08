bundle   = "osglecture"
ctanpkg  = bundle
maindir  = maindir or "."

modules = {
   "ansiterm",
   "osglistings",
   "ollm",
   "osgdoc",
   "langselect",
   "tagbridge",
   "tagdirtree",
   "lttheme",
   "lttheme-tuc-2019",
   "osgstyler",
   "osglecture-modes",
   "osglecture",
   "tagpax",
   "semcat",
   "manual-src",
 }

textfiles = textfiles or { 
  "README-*.md"
 }

unpackfiles = unpackfiles  or { "*.dtx" }

stdengine    = "luatex"
checkengines = { "luatex" }

-- Dokumentation
docfiledir = docfiledir or maindir.."/doc/"
typesetexe = "lualatex"
typesetopts = "-interaction=nonstopmode -shell-escape --synctex=10"
maxruns    = 3

local is_module = type(module) == "string" and module ~= ""

sourcefiles = sourcefiles or { "*.dtx" }
typesetfiles = typesetfiles or (
  is_module
  and { module .. ".dtx" }
  or { "*.dtx" }
)

cleanfiles={
    "*-cnltx*", -- artefacts from cnltx tools
    "*.toc",
    "*.aux",
    "*.log",
    "*.idx",
    "*.ilg",
    "*.ind"
}
--[[ We need the documentation pdf's only at time of distribution,
     but not during build, where they pollute the build/doc directory.
--]]
local target = options["target"]
local with_distributed_docs =
  target == "ctan"
  or target == "bundlectan"
  or target == "install"

if is_module then
  docfiles = docfiles or { }
  if with_distributed_docs then
    table.insert(docfiles, module .. "-en.pdf")
    table.insert(docfiles, module .. "-de.pdf")
  end
else
  docfiles = docfiles or (
    with_distributed_docs
    and { "*.pdf" }
    or {}
  )
end

-- A full installation from the bundle root has two phases.  Modules install
-- their run-time files without documentation; afterwards the root installs
-- the shared documentation collection in doc/<tdsroot>/<bundle>.  Direct
-- module installations retain l3build's normal per-module directory and see
-- only the module-specific PDF names added above.
if not is_module and target_list and target_list.install then
  target_list.install.bundle_func = function(names)
    if names then
      print("Bundle installation does not accept file names")
      return 1
    end

    local module_options = { }
    for key, value in pairs(options) do
      module_options[key] = value
    end
    module_options["full"] = nil

    local errorlevel = call(modules, "install", module_options)
    if errorlevel ~= 0 or not options["full"] then
      return errorlevel
    end

    local doc_options = { }
    for key, value in pairs(options) do
      doc_options[key] = value
    end
    doc_options["full"] = nil
    doc_options["dry-run"] = nil
    doc_options["texmfhome"] = nil

    errorlevel = call(modules, "doc", doc_options)
    if errorlevel ~= 0 then
      return errorlevel
    end

    moduledir = tdsroot .. "/" .. bundle
    return install()
  end
end

-- All documented sources use osgdoc for their driver and langselect for the
-- German/English variants.  Declare those as typesetting dependencies so a
-- documentation build also works with an empty build/local tree.  l3build
-- installs dependencies with its unpack target, which deliberately breaks the
-- apparent documentation cycle between osgdoc and langselect.
if is_module then
  typesetdeps = typesetdeps or { }

  local function add_typeset_dependency(dependency)
    for _, configured_dependency in ipairs(typesetdeps) do
      if configured_dependency == dependency then
        return
      end
    end
    table.insert(typesetdeps, dependency)
  end

  if module ~= "osgdoc" then
    add_typeset_dependency("../osgdoc")
  end
  if module ~= "langselect" then
    add_typeset_dependency("../langselect")
  end
end

-- It is (mainly) a luatex package
tdsroot = "luatex"

--[[ 
The documentation is in two languages, English and German.
I.e., each .dtx file has to be compiled twice.
We use langselect and get the target language from jobname.
Thus, we need a special typeset function.
--]]

function typeset(file, dir, cmd)
   dir = dir or "."
   local jobnames
   local ext = file:match("%.([^.]*)$")
   print(" typeset called")
   if ext == 'dtx' then 
      jobnames = {module.."-en", module.."-de"}
   else
      local jobname = file:match("([^/]+)%.[^.]*$")
      jobnames = {jobname}
   end
   for _, job in ipairs(jobnames) do
      local errorlevel
      
      for i = 1, typesetruns do
	 errorlevel = tex(file, dir, cmd .. " -jobname=" .. job)
	 if errorlevel ~= 0 then return errorlevel end
	 
	 if i == 1 then
	    makeindex(job, dir, ".idx", ".ind", ".ilg", indexstyle)
	 end
	 
	 if i > 1 and not rerun_needed(job, dir) then
	    break
	 end
      end
      --[[ Actually, doc() is responsible to save the results.
	         However, it can't cope with changed file stems.
      --]]
      cp(job..".pdf", typesetdir, docfiledir)
   end
   
  return 0
end

function rerun_needed(job, dir)
  local log = io.open(dir .. "/" .. job .. ".log", "r")
  if not log then return false end
  local s = log:read("*all")
  log:close()

  return
    s:find("Rerun to get cross%-references right") or
    s:find("Label%(s%) may have changed") or
    s:find("There were undefined references") or
    s:find("Rerun LaTeX")
end

--[[
  I want a two-level clean:
  - 'l3build clean' keeps the final build files (pdf)
  - 'l3build cleanall' cleans everything
--]]
stdclean = target_list.clean.func

function cleanlite()
  for _, pattern in ipairs(cleanfiles or {}) do
    rm(typesetdir, pattern)
  end
  return 0
end

target_list.clean.func = cleanlite

target_list.cleanall = {
  desc = "Cleans all generated files",
  func = stdclean,
}

-- Tagging
--[[
  Versions belong to the modules, the bundle as a whole is identified by its
  release date only:
  - 'l3build tag vX.Y.Z' in a module directory sets that module's version
    and date,
  - 'l3build tag' in the bundle root sets the bundle release date in
    README.md and leaves the modules alone,
  - 'l3build gittag' in the bundle root derives the git tags
    ('<module>/vX.Y.Z', '<date>') from the committed sources.
--]]
tagfiles = tagfiles or (is_module and { "*.dtx", "*.lua" } or { "README.md" })

local release_date_pattern =
  "(<!%-%- BUNDLE RELEASE DATE %-%->)(.-)(<!%-%- /BUNDLE RELEASE DATE %-%->)"

local function is_iso_date(value)
  return type(value) == "string"
    and value:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil
end

function normalize_tagname(tagname)
  if not tagname:match("^v") then
    tagname = "v" .. tagname
  end
  return tagname
end

if is_module then
  local stdtagpre = target_list.tag.pre

  target_list.tag.pre = function(names)
    if not names or #names == 0 then
      print("A module needs an explicit version: l3build tag vX.Y.Z")
      return 1
    end
    return stdtagpre and stdtagpre(names) or 0
  end
else
  target_list.tag.bundle_func = function(names)
    local tagdate = options["date"]
    for _, name in ipairs(names or { }) do
      local name_as_date = name:gsub("/", "-")
      if not tagdate and is_iso_date(name_as_date) then
        tagdate = name_as_date
      else
        print("Warning: ignoring '" .. name .. "': the bundle is tagged by "
          .. "date only; module versions are set in the module directories")
      end
    end

    tagdate = (tagdate or os.date("%Y-%m-%d")):gsub("/", "-")
    if not is_iso_date(tagdate) then
      print("Invalid release date '" .. tagdate .. "', expected YYYY-MM-DD")
      return 1
    end

    print("Setting bundle release date to " .. tagdate)
    options["date"] = tagdate
    return tag(nil)
  end
end

local function update_lua_tag(content, tagname, tagdate)
  local updated = content:gsub(
    "(Date:%s*\n%s*)%d%d%d%d%-%d%d%-%d%d",
    "%1" .. tagdate
  )
  updated = updated:gsub(
    "(Version:%s*\n%s*)v?[%w%.%-]+",
    "%1" .. tagname
  )
  return updated
end

function update_tag(file, content, tagname, tagdate)
  --[[
    l3build passes --date through without validation or normalisation.
    We accept both common input forms and use ISO 8601 for every target.
  ]]
  local iso_date = tagdate:gsub("/", "-")

  if not is_module then
    if file ~= "README.md" then
      return content
    end
    local updated, count = content:gsub(
      release_date_pattern,
      "%1" .. iso_date .. "%3",
      1
    )
    if count == 0 then
      print("No BUNDLE RELEASE DATE marker pair found in " .. file)
    end
    return updated
  end

  tagname = normalize_tagname(tagname)

  if file:match("%.lua$") then
    return update_lua_tag(content, tagname, iso_date)
  end

  if file:match("%.dtx$") then
    local updated = content:gsub(
      "(\\ProvidesExpl%a*%s*{[^}]+}%s*\n?%s*{)"
        .. "%d%d%d%d[/-]%d%d[/-]%d%d"
        .. "(}%s*%s*{)[^}%s]+(})",
      "%1" .. iso_date .. "%2" .. tagname .. "%3"
    )

--[[
  Lua has no \Provides... declaration. Restrict its independent metadata
  update to the docstrip guard so that no other embedded file becomes a
  second source for the package version.
  NOTE: Has to be adapted in case of several lua files.
]]
    updated = updated:gsub(
      "(%%<%*lua>\n)(.-)(\n%%</lua>)",
      function(opening, lua, closing)
        return opening .. update_lua_tag(lua, tagname, iso_date) .. closing
      end,
      1
    )
    return updated
  end

  return content
end

-- The module table in README.md mirrors the versions in the sources, so
-- every tagging run refreshes it.  The tool expects the bundle root.
function tag_hook(tagname, tagdate)
  return run(maindir, "texlua tools/update-bundle-manifest.lua")
end

--[[
  Git tags are derived from the sources, never the other way round: commit
  the version changes first (one commit may step several modules), then run
  'l3build gittag'.  Modules whose tag already exists are skipped, so there
  is no need to name the affected ones.  With --dry-run nothing is created
  and missing tags are only reported; .githooks/pre-push relies on that.
--]]
local function git_capture(arguments)
  local handle = io.popen("git " .. arguments .. " 2>" .. os_null)
  local output = handle:read("a")
  handle:close()
  return (output:gsub("%s+$", ""))
end

local function git_succeeds(arguments)
  local result = os.execute("git " .. arguments .. " >" .. os_null .. " 2>&1")
  return result == true or result == 0
end

local function gittag()
  local dry_run = options["dry-run"]

  if not dry_run
    and git_capture("status --porcelain --untracked-files=no") ~= "" then
    print("gittag: uncommitted changes; the tags would not match the sources")
    return 1
  end

  local versions = dofile("tools/bundle-versions.lua")
  local wanted = { }
  local errorlevel = 0

  local function want(name, message)
    if not name:match("^[%w%.%-/]+$") then
      print("gittag: refusing unusual tag name '" .. name .. "'")
      errorlevel = 1
    elseif not git_succeeds("rev-parse -q --verify refs/tags/" .. name) then
      table.insert(wanted, { name = name, message = message })
    else
      return true
    end
    return false
  end

  for _, entry in ipairs(versions.scan()) do
    local version = entry.version_list[1]
    if #entry.entries == 0 then
      print("gittag: no version found for " .. entry.name)
      errorlevel = 1
    elseif not entry.consistent then
      print("gittag: " .. entry.name .. " has mixed versions or dates ("
        .. table.concat(entry.version_list, ", ") .. "); not tagged")
      errorlevel = 1
    elseif version:match("%-dev$") then
      print("Skipping " .. entry.name .. " " .. version
        .. " (development version)")
    else
      version = normalize_tagname(version)
      local name = entry.name .. "/" .. version
      if want(name, entry.name .. " " .. version)
        and not dry_run
        and not git_succeeds(
          "diff --quiet " .. name .. " HEAD -- " .. entry.name
        ) then
        print("Warning: " .. entry.name .. " has changed since " .. name
          .. " but still carries that version")
      end
    end
  end

  local _, release_date = (versions.read_file("README.md") or "")
    :match(release_date_pattern)
  if is_iso_date(release_date) then
    want(release_date, bundle .. " bundle " .. release_date)
  end

  for _, tag in ipairs(wanted) do
    if dry_run then
      print("Missing git tag: " .. tag.name)
      errorlevel = 1
    elseif git_succeeds(
      "tag -a " .. tag.name .. ' -m "' .. tag.message .. '"'
    ) then
      print("Created git tag " .. tag.name)
    else
      print("gittag: could not create " .. tag.name)
      errorlevel = 1
    end
  end

  if #wanted == 0 then
    print("All git tags are up to date")
  elseif not dry_run then
    print("Publish them with: git push --follow-tags")
  end
  return errorlevel
end

target_list.gittag = {
  desc = "Creates the git tags matching the module versions (bundle root)",
  bundle_func = gittag,
  func = function()
    print("Run 'l3build gittag' from the bundle root")
    return 1
  end,
}
