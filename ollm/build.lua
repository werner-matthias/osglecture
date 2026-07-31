bundle = "osglecture"
module = "ollm"
maindir = ".."

docfiles = {
  "ollm-en.pdf",
  "ollm-de.pdf",
}

installfiles = { }

tdsdirs = {
  ["scripts"] = "scripts/osglecture",
  ["scripts/definitions"] = "scripts/osglecture/definitions",
  ["scripts/lib"] = "scripts/osglecture/lib",
  ["scripts/vendor"] = "scripts/osglecture/vendor",
}

sourcefiles = {
  "ollm.tex",
  "ollm-en.tex",
  "ollm-de.tex",
}

typesetfiles = { 
  "ollm-en.tex",
  "ollm-de.tex"
}

textfiles = {
  "README-ollm.md",
  "THIRD_PARTY.md",
}

-- The functional test suite will grow with the new implementation.  Keeping
-- the syntax check in the normal l3build check path catches broken releases
-- even before there are stable CLI contracts to exercise.
function checkinit_hook()
  local errorlevel = runcmd("perl -c ollm", "scripts", { })
  if errorlevel ~= 0 then
    return errorlevel
  end
  errorlevel = runcmd("perl -c ollm-latexmk.rc", "scripts", { })
  if errorlevel ~= 0 then
    return errorlevel
  end
  errorlevel = runcmd("perl -c ollm-legacy.rc", "scripts", { })
  if errorlevel ~= 0 then
    return errorlevel
  end
  -- [[
  return runcmd(
    "prove -Iscripts/lib -Iscripts/vendor/TOML-Tiny-0.22/lib testfiles",
    ".",
    { }
  )
--]]
end
dofile("../build.lua")
