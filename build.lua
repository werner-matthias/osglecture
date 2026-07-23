bundle   = "osglecture"
ctanpkg  = bundle

modules = {
   "langselect",
   "osgdoc",
   "lttheme",
   "modeext",
   "tagpax",
   -- "osglecture"
   -- "osgterminal",
   -- "osgref",
   -- "osglectbib",
   -- "osglisting"
 }

textfiles = { "README.md", "CHANGES.md", "LICENSE" }

unpackfiles = unpackfiles  or { "*.dtx" }

stdengine    = "luatex"
checkengines = { "luatex" }

-- Dokumentation
docfiledir = maindir.."/doc/"
typesetexe = "lualatex"
typesetopts = "-interaction=nonstopmode -shell-escape --synctex=10"
maxruns    = 3

cleanfiles={
    "*-cnltx*", -- artefacts from cnltx tools
    "*.toc",
    "*.aux",
    "*.log",
    "*.idx",
    "*.ilg",
    "*.ind"
}

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
   if ext == 'dtx' then 
      jobnames = {module.."-en", module.."-de"}
   else
      local jobname = file:match("(%).[^.]*$")
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


-- Script-Auslieferung (landet in TEXMF/scripts/osglecture/)
-- scriptfiles = {
--  "scripts/ollm",
--  "scripts/ollm.bat",   -- optional; für Windows
--}

docfiles     = docfiles or {
  "*.dtx",
  "*.pdf",
  "README.md"
}

sourcefiles  = sourcefiles  or { "*.dtx"}
typesetfiles = typesetfiles or { "*.dtx"}
tagfiles =     tagfiles or { "*.dtx", "*.lua"}

-- Tagging
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
      "(\\ProvidesExpl%a*%s*{[%a_-]*}%s*\n%s*{)"
        .. "%d%d%d%d[/-]%d%d[/-]%d%d"
        .. "(}%s*\n%s*{)[^}%s]+(})",
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

--[[
-- Tests: Standard-Lauf (Unit je Modul) + Integrations-Lauf (siehe config-integ.lua)
-- checkconfigs = { "build", "config-integ" }
checkconfigs = { "build"}

-- Integration hängt von allen Modulen ab (sorgt für Entpacken/Build vor dem Test)
checkdeps = {
  --"./osglecture",
  "./langselect",
  --"./osgterminal",
  "./osglecturebib"
  --"./osgcombine",
  --"./osglisting",
}

-- Tagging (optional)
tagfiles = {
  -- "osglecture/osglecture.dtx",
  -- "multibabel/multibabel.dtx",
  -- "osgterminal/osgterminal.dtx",
  -- "osgbib/osgbib.dtx",
  -- "osgcombine/osgcombine.dtx",
  -- "osglisting/osglisting.dtx",
  "scripts/ollm",
}
tagfmt = "v%Y-%m-%d"
--]]
