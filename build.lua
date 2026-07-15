bundle   = "osglecture"
ctanpkg  = bundle

modules = {
   "langselect",
   "osgdoc",
   "tagpax",
   -- "osglecture"
   -- "osgterminal",
   -- "osgref",
   -- "osglectbib",
   -- "osglisting"
 }

textfiles = { "README.md", "CHANGES.md", "LICENSE" }

unpackfiles = { "*.dtx" }

stdengine    = "luatex"
checkengines = { "luatex" }

-- Dokumentation
docfiledir = maindir.."/doc"
typesetexe = "lualatex"
typesetopts = "-interaction=nonstopmode -shell-escape"
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
--  "scripts/ollm.bat",   -- optional; für Windows bequem
--}

docfiles     = {
  "*.dtx",
  "*.pdf",
  "README.md"
}

sourcefiles  = { "*.dtx"}
typesetfiles = { "*.dtx"}

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
