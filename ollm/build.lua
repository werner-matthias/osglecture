bundle = "osglecture"
module = "ollm"
maindir = ".."
docfiledir = maindir .. "/doc/ollm"

-- OLLM is installed as a program, not as a TeX input file.
scriptfiles = {
  "ollm",
  "ollm.cmd",
  "ollm-latexmk.rc",
  "ollm-legacy.rc",
}
installfiles = { }

tdsdirs = {
  ["definitions"] = "scripts/osglecture/definitions",
  ["lib"] = "scripts/osglecture/lib",
  ["vendor"] = "scripts/osglecture/vendor",
}

-- Keep the bundle name in the TDS script path.  Without this explicit
-- location l3build would use scripts/ollm/ollm for a module named "ollm".
tdslocations = {
  "scripts/osglecture/ollm",
  "scripts/osglecture/ollm.cmd",
  "scripts/osglecture/ollm-latexmk.rc",
  "scripts/osglecture/ollm-legacy.rc",
}

sourcefiles = {
  "ollm",
  "ollm.cmd",
  "ollm-latexmk.rc",
  "ollm-legacy.rc",
  "ollm.tex",
  "definitions/profiles/*.toml",
  "definitions/targets/*.toml",
  "lib/OLLM/*.pm",
  "vendor/TOML-Tiny-0.22/LICENSE",
  "vendor/TOML-Tiny-0.22/lib/TOML/Tiny/*.pm",
}

typesetfiles = { "ollm.tex" }

textfiles = {
  "README.md",
  "DEPENDENCIES.md",
  "DESIGN.md",
  "THIRD_PARTY.md",
}

docfiles = {
  "DEPENDENCIES.md",
  "THIRD_PARTY.md",
}

function docinit_hook()
  mkdir(docfiledir)
  cp("README.md", ".", docfiledir)
  cp("DEPENDENCIES.md", ".", docfiledir)
  cp("THIRD_PARTY.md", ".", docfiledir)
  return 0
end

-- The functional test suite will grow with the new implementation.  Keeping
-- the syntax check in the normal l3build check path catches broken releases
-- even before there are stable CLI contracts to exercise.
function checkinit_hook()
  local errorlevel = runcmd("perl -c ollm", ".", { })
  if errorlevel ~= 0 then
    return errorlevel
  end
  errorlevel = runcmd("perl -c ollm-latexmk.rc", ".", { })
  if errorlevel ~= 0 then
    return errorlevel
  end
  errorlevel = runcmd("perl -c ollm-legacy.rc", ".", { })
  if errorlevel ~= 0 then
    return errorlevel
  end
  return runcmd(
    "prove -Ilib -Ivendor/TOML-Tiny-0.22/lib testfiles",
    ".",
    { }
  )
end

dofile("../build.lua")
