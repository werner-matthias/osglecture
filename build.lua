bundle   = "osglecture"
ctanpkg  = bundle
maindir  = maindir or "."

modules = {
   "ansiterm",
   "osglistings",
   "ollm",
   "osgdoc",
   "langselect",
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
tagfiles =     tagfiles or { "*.dtx", "*.lua"}

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
  if not tagname then
    local handle = io.popen("git describe --tags --abbrev=0")
    tagname = handle:read("*a"):match("[^\n]+")
    handle:close()
    print("Set tagname to '" .. tagname .. "'")
  end

  --[[
    l3build passes --date through without validation or normalisation.
    We accept both common input forms and derive the format required by each target.
  ]]
  local iso_date = tagdate:gsub("/", "-")

  if file:match("%.lua$") then
    return update_lua_tag(content, tagname, iso_date)
  end

  if file:match("%.dtx$") then
    local package_date = iso_date:gsub("-", "/")
    local updated = content:gsub(
      "(\\ProvidesExpl%a*%s*{[^}]+}%s*\n?%s*{)"
        .. "%d%d%d%d[/-]%d%d[/-]%d%d"
        .. "(}%s*%s*{)[^}%s]+(})",
      "%1" .. package_date .. "%2" .. tagname .. "%3"
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
