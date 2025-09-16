bundle = "osglecture"
module = "langselect"

mainindir=".."

unpackfiles = { "langselect.dtx" }

stdengine    = "luatex"
checkengines = { "luatex" }

sourcefiles  = { "langselect.dtx" }

docfiles     = {
  "langselect.dtx",
  "langselect.pdf",
  "langselect-de.pdf",
  "README.txt"
}

jobnames = { "langselect", "langselect-de" }

typesetfiles = { "langselect.dtx" } 

typesetexe = "lualatex"
typesetopts = "-interaction=nonstopmode -shell-escape"

cleanfiles={
    "*-cnltx*",
    "*.toc",
    "*.aux",
    "*.log",
    "*.fdb_latexmk",
    "*.fls",
    "*.idx",
    "*.ilg",
    "*.ind"
}

--  
function typeset(name, engine, _)
   print(">>> typeset() called with engine: " .. engine)
  for _, job in ipairs(jobnames) do
    local cmd = string.format("%s %s -jobname=%s langselect.dtx", typesetexe, typesetopts, job)
    print("Running: " .. cmd)
    for _ = 1,typesetruns do 
       local result = os.execute(cmd)
    end
    if result ~= 0 then
      return result
    end
  end
  return 0
end


-- dofile("../build.lua")
