module = "langselect"

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

cleanfiles={
    "*-cnltx*",
    "*.toc",
    "*.aux",
    "*.log"
}

function typeset(name, engine, _)
   print(">>> typeset() called with engine: " .. engine)
  for _, job in ipairs(jobnames) do
    local cmd = string.format("%s %s -jobname=%s langselect.dtx", typesetexe, typesetopts, job)
    print("Running: " .. cmd)
    local result = os.execute(cmd)
    if result ~= 0 then
      return result
    end
  end
  return 0
end


-- dofile("../build.lua")
