-- Only osglecture, osgdocmk, and the manual form a bundle in CTAN's sense
-- (one submission); every other module is a package of its own and sets
-- `bundle = ""` in its build.lua, which makes l3build treat it as
-- standalone (its own TDS directory, its own ctan/upload).
bundle   = bundle or "osglecture"
maindir  = maindir or "."

local is_module = type(module) == "string" and module ~= ""

-- Only the bundle root lists its modules.  l3build's ctan target in a module
-- that belongs to a bundle calls bundlecheck/bundlectan for every entry of
-- `modules`; inherited from here, a module would run those targets for the
-- whole bundle list from inside its own directory (the "cd <module>" fails,
-- the command continues in the module) and rebuild itself over and over.
if not is_module then
  modules = {
     "ansiterm",
     "osglistings",
     "osgdocmk",
     "osgdoc",
     "langselect",
     "tagdirtree",
     "lttalk-themeengine",
     "lttalk-theme-tuc-2019",
     "osgstyler",
     "osgmodes",
     "osglecture",
     "tagpax",
     "semcat",
     "manual-src",
   }
end

-- The package register is only available in the repository, not in the CTAN
-- copy (which has no tools/ directory); l3build ctan runs in the repository.
local function register_entry(name)
  local file = maindir .. "/tools/packages.lua"
  if not fileexists(file) then
    return nil
  end
  for _, entry in ipairs(dofile(file).modules) do
    if entry.name == name then
      return entry
    end
  end
  return nil
end

-- CTAN submission data for "l3build upload", kept in its own file.  The
-- CTAN copy of a package has no ctan/ directory; it is only built there.
-- The bundle root submits the bundle; a standalone module submits itself.
-- ctan/upload.lua reads files relative to the repository root.
local function load_upload_config()
  local upload_lua = maindir .. "/ctan/upload.lua"
  if fileexists(upload_lua) then
    local current = lfs.currentdir()
    lfs.chdir(maindir)
    dofile("ctan/upload.lua")
    lfs.chdir(current)
  end
end

-- Members of a bundle are packaged by the bundle root; a module that is
-- merged into another one is not packaged at all.
if is_module and target_list and target_list.ctan then
  local reason
  if bundle ~= "" then
    reason = "is packaged as part of the " .. bundle
      .. " bundle: run 'l3build %s' in the bundle root."
  elseif merged_into then
    reason = "is not a package of its own (merged into " .. merged_into .. ")."
  end
  if reason then
    for _, name in ipairs({ "ctan", "upload" }) do
      if target_list[name] then
        target_list[name].func = function()
          print("'" .. module .. "' " .. reason:format(name))
          return 1
        end
      end
    end
  else
    load_upload_config()
    -- Never package a README whose dependency section no longer matches the
    -- dependency matrix.
    if fileexists(maindir .. "/tools/make-package-readmes.lua") then
      local std_ctan = target_list.ctan.func
      target_list.ctan.func = function(...)
        local errorlevel = run(maindir,
          "texlua tools/make-package-readmes.lua --check " .. module)
        if errorlevel ~= 0 then
          return errorlevel
        end
        return std_ctan(...)
      end
    end
  end
end

-- l3build's upload target has no bundle function, so in the bundle root it
-- would run in every module and look for the zip file there; run it in the
-- root itself instead.
if not is_module and target_list and target_list.upload then
  target_list.upload.bundle_func = function(names) return upload(names) end
  load_upload_config()
end

-- The GitHub README.md is not distributed: CTAN gets the snapshot
-- ctan/README.md derived from it (tools/make-ctan-readme.lua).  Modules
-- distribute their own README.md.
-- In the CTAN copy the snapshot already is the top-level README.md.
if not is_module then
  textfiledir = fileexists("ctan/README.md") and "ctan" or "."
  textfiles = { "README.md" }
end

-- The package directory mirrors the repository, so that the l3build files
-- work there as well: build.lua and config-*.lua must therefore not be
-- excluded.  CTAN prefers uploads without a TDS archive; l3build still
-- builds the TDS tree (see copyctan below), and setting packtdszip adds
-- <package>.tds.zip to the upload again should it ever be wanted.  This
-- holds for the bundle root as well as for the standalone packages, which
-- zip their own package directory.
packtdszip = false
excludefiles = { "*~" }
if not is_module then
  -- l3build drops the executable bit unless a file is listed here.
  exefiles = { "osgdocmk" }
end

--[[
  The CTAN package directory mirrors the repository rather than l3build's
  flat collection: each module gets its own directory with its tracked
  files (sources, l3build files, tests, README.md) and its
  documentation PDFs, so "l3build check/doc/install" also work there.
  Git symlinks stay behind; so do development-docs/, doc/, tools/, ctan/,
  and images/ apart from images/logos (the other images serve osglecture
  projects, not the bundle), which no module copies.
  The top-level build.lua and LICENSE come along with every package (the
  copies are identical).  What else is shared is decided by the package
  register: a package ships only the example directories and the support
  directories it owns (the logos used by the lttalk-theme-tuc-2019 tests
  and example, the series examples of osglecture).  The examples of one
  standalone package live in its own examples/ directory and travel with it.
  support/insert-pdf-tags.lua, a test-time helper, belongs to no package;
  the notes of the packages whose tests need it say so.
  Hidden files are left out: CTAN does not accept them.  So are the
  PDF-based visual tests (*.pvt, *.tpf): their normalised reference PDFs
  are rejected by CTAN's checks, and CTAN asked to leave them out.  They
  remain part of the repository and its CI.

  If a TDS archive is uploaded, CTAN requires it to hold every file of the
  package tree.  Documentation (PDFs, README files, LICENSE, examples)
  goes to doc/<tdsroot>/<bundle>, everything else to
  source/<tdsroot>/<bundle>, which therefore mirrors the package tree.
--]]
local ctan_excluded = { "%.pvt$", "%.tpf$" }

local function git_tracked_files(dir)
  local handle = io.popen("git -C " .. dir .. " ls-files -s -- . 2>" .. os_null)
  local files = { }
  for line in handle:lines() do
    local mode, path = line:match("^(%d+) %x+ %d+\t(.+)$")
    if mode and mode ~= "120000" then
      local excluded = false
      for _, pattern in ipairs(ctan_excluded) do
        excluded = excluded or path:match(pattern) ~= nil
      end
      if path:match("^%.[^/]") or path:match("/%.[^/]") then
        print("copyctan: hidden file " .. dir .. "/" .. path
          .. " is not distributed")
      elseif not excluded then
        table.insert(files, path)
      end
    end
  end
  handle:close()
  return files
end

local function copy_listed(sourcedir, files, ...)
  for _, targetdir in ipairs({ ... }) do
    for _, path in ipairs(files) do
      local dir, name = splitpath(path)
      mkdir(targetdir .. "/" .. dir)
      local errorlevel = cp(name, sourcedir .. "/" .. dir, targetdir .. "/" .. dir)
      if errorlevel ~= 0 then
        return errorlevel
      end
    end
  end
  return 0
end

local function copy_tracked(sourcedir, ...)
  local files = git_tracked_files(sourcedir)
  if #files == 0 then
    print("copyctan: no tracked files in " .. sourcedir)
    return 1
  end
  return copy_listed(sourcedir, files, ...)
end

-- The files of the given example directories (relative to examples/), as
-- { name, sourcedir, targetdir } entries, without hidden files such as an
-- activated .osgdocmkconfig.local.toml.
local function example_files(directories)
  local files = { }
  for _, directory in ipairs(directories) do
    for _, p in ipairs(tree(maindir .. "/examples/" .. directory, "**")) do
      local path = p.src:gsub("^%./", "")
      if lfs.attributes(p.cwd, "mode") == "file"
        and not path:match("^%.") and not path:match("/%.") then
        local dir, name = splitpath(path)
        local relative = "examples/" .. directory .. "/" .. dir
        table.insert(files, { name, relative, relative })
      end
    end
  end
  return files
end

-- The files below examples/ in the module directory as
-- { name, sourcedir, targetdir } entries, without hidden files.
local function module_example_files()
  local files = { }
  local base = lfs.currentdir() .. "/examples"
  if lfs.attributes(base, "mode") ~= "directory" then
    return files
  end
  for _, p in ipairs(tree(base, "**")) do
    local path = p.src:gsub("^%./", "")
    if lfs.attributes(p.cwd, "mode") == "file"
      and not path:match("^%.") and not path:match("/%.") then
      local dir, name = splitpath(path)
      table.insert(files, { name, base .. "/" .. dir, "examples/" .. dir })
    end
  end
  return files
end

-- What a package ships besides its own directory is decided by the register:
-- the example directories it owns (`examples`) and the support directories
-- it owns (`owns_support`, e.g. images/logos).  The test helper
-- support/insert-pdf-tags.lua belongs to no package.  Without a register
-- (a CTAN copy) a package ships nothing of that kind.
local function owned_assets()
  local entry = register_entry(module)
  return (entry and entry.examples) or { }, (entry and entry.owns_support) or { }
end

if is_module then
  function copyctan()
    local pkgdir = ctandir .. "/" .. ctanpkg
    local tdsdocdir = tdsdir .. "/doc/" .. tdsroot .. "/" .. bundle
    local tdssourcedir = tdsdir .. "/source/" .. tdsroot .. "/" .. bundle
    local dirname = lfs.currentdir():match("([^/\\]+)$")
    local targetdir = pkgdir .. "/" .. dirname
    mkdir(targetdir)
    -- The mirror replaces l3build's own, flattened source directory.
    rmdir(tdsdir .. "/source/" .. moduledir)
    local examples, support = owned_assets()
    -- The examples of the module itself belong to the documentation tree.
    local own, examplefiles = git_tracked_files("."), { }
    local rest = { }
    for _, path in ipairs(own) do
      table.insert(path:match("^examples/") and examplefiles or rest, path)
    end
    local errorlevel = copy_listed(".", own, targetdir)
      + copy_listed(".", rest, tdssourcedir .. "/" .. dirname)
      + copy_listed(".", examplefiles, tdsdocdir)
      + cp("build.lua", maindir, pkgdir)
      + cp("build.lua", maindir, tdssourcedir)
      + cp("LICENSE", maindir, pkgdir)
      + cp("LICENSE", maindir, tdsdocdir)
    for _, name in ipairs(support) do
      errorlevel = errorlevel + copy_tracked(maindir .. "/" .. name,
        pkgdir .. "/" .. name, tdssourcedir .. "/" .. name)
    end
    for _, name in ipairs(examples) do
      errorlevel = errorlevel + copy_tracked(maindir .. "/examples/" .. name,
        pkgdir .. "/examples/" .. name, tdsdocdir .. "/examples/" .. name)
    end
    for _, files in ipairs({ docfiles, pdffiles, typesetlist }) do
      for _, pattern in ipairs(files or { }) do
        if pattern:match("%.pdf$") then
          cp(pattern, docfiledir, targetdir)
        end
      end
    end
    return errorlevel
  end

  -- l3build looks for the text files (README.md, THIRD_PARTY-*.md)
  -- in docfiledir when installing, where they never are; install them from
  -- the module directory instead.
  local std_install_files = install_files
  function install_files(target, full, dry_run)
    local errorlevel = std_install_files(target, full, dry_run)
    if errorlevel ~= 0 or not full or dry_run then
      return errorlevel
    end
    local docdir = target .. "/doc/" .. moduledir
    mkdir(docdir)
    for _, pattern in ipairs(textfiles) do
      for _, name in ipairs(filelist(textfiledir, pattern)) do
        errorlevel = errorlevel + cp(name, textfiledir, docdir)
      end
    end
    -- A standalone package carries its own examples; those of a bundle
    -- member are installed by the bundle root.
    if bundle == "" then
      for _, file in ipairs(module_example_files()) do
        mkdir(docdir .. "/" .. file[3])
        errorlevel = errorlevel + cp(file[1], file[2], docdir .. "/" .. file[3])
      end
    end
    return errorlevel
  end
end

textfiles = textfiles or { "README.md" }

unpackfiles = unpackfiles  or { "*.dtx" }

stdengine    = "luatex"
checkengines = { "luatex" }

-- Dokumentation
docfiledir = docfiledir or maindir.."/doc/"
typesetexe = "lualatex"
typesetopts = "-interaction=nonstopmode -shell-escape --synctex=10"
maxruns    = 3


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

-- A full installation from the bundle root installs every module with its
-- documentation in doc/<tdsroot>/<bundle>/<module> (PDFs, README and
-- THIRD_PARTY files), as in the TDS tree of the CTAN package; the root then
-- adds README.md, LICENSE, and the examples to doc/<tdsroot>/<bundle>.
-- The relative links between these files depend on that layout.
local function texmfhome_dir()
  local texmfhome = options["texmfhome"]
  if not texmfhome then
    local handle = io.popen("kpsewhich -var-value TEXMFHOME")
    texmfhome = handle and handle:read("*l")
    if handle then handle:close() end
  end
  return texmfhome
end

-- l3build installs osgdocmk below TEXMFHOME/scripts, which is never on PATH.
-- A distribution creates the launcher itself; an installation from the
-- repository has to be told how.
local function osgdocmk_path_hint()
  if options["dry-run"] then
    return
  end
  local windows = os_type == "windows"
  local probe = windows and "where osgdocmk >NUL 2>NUL" or "command -v osgdocmk >/dev/null 2>&1"
  if os.execute(probe) == 0 then
    return
  end
  local script_dir = (texmfhome_dir() or "<TEXMFHOME>") .. "/scripts/osgdocmk"
  print("")
  print("Note: 'osgdocmk' is installed in " .. script_dir)
  print("      but is not on your PATH.  To call it as 'osgdocmk', either")
  if windows then
    print("        - add that directory to PATH (it contains osgdocmk.cmd), or")
    print("        - call it as: perl \"" .. script_dir .. "/osgdocmk\"")
  else
    print("        - link it into a directory on PATH, e.g.")
    print("            ln -s \"" .. script_dir .. "/osgdocmk\" ~/.local/bin/osgdocmk")
    print("        - or add that directory to PATH.")
  end
end

-- README.md, LICENSE, and the examples (without hidden files such as an
-- activated .osgdocmkconfig.local.toml).
local function install_bundle_docs()
  local texmfhome = texmfhome_dir()
  if not texmfhome then
    print("Cannot determine TEXMFHOME for the bundle documentation")
    return 1
  end
  local docdir = texmfhome .. "/doc/" .. tdsroot .. "/" .. bundle
  local files = { { "README.md", textfiledir }, { "LICENSE", "." } }
  local entry = register_entry(bundle)
  for _, name in ipairs(example_files(entry and entry.examples or { })) do
    table.insert(files, name)
  end
  local errorlevel = 0
  for _, file in ipairs(files) do
    local name, sourcedir, targetdir = file[1], file[2], file[3] or "."
    if options["dry-run"] then
      print("- doc/" .. tdsroot .. "/" .. bundle .. "/" .. targetdir .. "/" .. name)
    else
      mkdir(docdir .. "/" .. targetdir)
      errorlevel = errorlevel + cp(name, sourcedir, docdir .. "/" .. targetdir)
    end
  end
  return errorlevel
end

if not is_module and target_list and target_list.install then
  target_list.install.bundle_func = function(names)
    if names then
      print("Bundle installation does not accept file names")
      return 1
    end
    local errorlevel = call(modules, "install", options)
    if errorlevel == 0 and options["full"] then
      errorlevel = install_bundle_docs()
    end
    if errorlevel == 0 then
      osgdocmk_path_hint()
    end
    return errorlevel
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
tdsroot = tdsroot or "luatex"

--[[ 
The documentation is in two languages, English and German.
I.e., each .dtx file has to be compiled twice.
We use langselect and get the target language from jobname.
Thus, we need a special typeset function.  Other bilingual sources (the
manuals of osgdocmk and of the bundle) are listed in 'bilingualfiles' and get
<name>-en and <name>-de as jobnames in the same way.
--]]
bilingualfiles = bilingualfiles or { }

function typeset(file, dir, cmd)
   dir = dir or "."
   local jobnames
   local ext = file:match("%.([^.]*)$")
   local stem = file:match("([^/]+)%.[^.]*$")
   local bilingual = false
   for _, name in ipairs(bilingualfiles) do
      if name == file:match("([^/]+)$") then
         bilingual = true
      end
   end
   print(" typeset called")
   if ext == 'dtx' then 
      jobnames = {module.."-en", module.."-de"}
   elseif bilingual then
      jobnames = {stem.."-en", stem.."-de"}
   else
      jobnames = {stem}
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
-- every tagging run refreshes it, then the CTAN snapshot of README.md and
-- the dependency sections of the package READMEs.
-- The tools expect the bundle root.
function tag_hook(tagname, tagdate)
  local errorlevel = run(maindir, "texlua tools/update-bundle-manifest.lua")
  if errorlevel ~= 0 then
    return errorlevel
  end
  errorlevel = run(maindir, "texlua tools/make-ctan-readme.lua")
  if errorlevel ~= 0 then
    return errorlevel
  end
  return run(maindir, "texlua tools/make-package-readmes.lua")
end

-- The bundle root submits only the bundle (osglecture, osgdocmk, and the
-- manual); the standalone packages are submitted from their own directories
-- (or all at once with 'l3build ctanall').  l3build's ctan function relays
-- to the global `modules`, so that list is narrowed for the duration of the
-- call.  Never package a CTAN README that no longer matches README.md.
local bundle_modules = { "osglecture", "osgdocmk", "manual-src" }

local function ctan_of_bundle(names)
  local all_modules = modules
  modules = bundle_modules
  local errorlevel = 0
  if fileexists("tools/make-ctan-readme.lua") then
    errorlevel = run(maindir, "texlua tools/make-ctan-readme.lua --check")
  end
  if errorlevel == 0 and fileexists("tools/make-package-readmes.lua") then
    errorlevel = run(maindir, "texlua tools/make-package-readmes.lua --check osglecture")
  end
  if errorlevel == 0 then
    errorlevel = target_list.ctan.stdfunc(names)
  end
  modules = all_modules
  return errorlevel
end

if not is_module and target_list and target_list.ctan then
  target_list.ctan.stdfunc = target_list.ctan.bundle_func
  target_list.ctan.bundle_func = ctan_of_bundle

  -- The standalone packages: every module of the register that has a CTAN
  -- package of its own and is not part of the bundle.
  local function standalone_modules()
    local list = { }
    local file = "tools/packages.lua"
    if fileexists(file) then
      for _, entry in ipairs(dofile(file).modules) do
        if entry.ctan ~= false and not entry.bundle then
          table.insert(list, entry.name)
        end
      end
    end
    return list
  end

  target_list.ctanall = {
    desc = "Builds the CTAN zip files of the bundle and of every standalone package",
    bundle_func = function(names)
      local errorlevel = ctan_of_bundle(names)
      if errorlevel ~= 0 then
        return errorlevel
      end
      return call(standalone_modules(), "ctan")
    end,
    func = function()
      print("Run 'l3build ctanall' from the bundle root")
      return 1
    end,
  }
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

  local versions = dofile("tools/packages.lua")
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
