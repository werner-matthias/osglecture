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
  "scripts/lib/OLLM/Version.pm"
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
  -- [[
  return runcmd(
    "prove -Iscripts/lib -Iscripts/vendor/TOML-Tiny-0.22/lib testfiles",
    ".",
    { }
  )
--]]
end

-- ollm has no .dtx; its only version source is the Perl module, which the
-- documentation reads at typesetting time.
tagfiles = { "scripts/lib/OLLM/Version.pm" }

dofile("../build.lua")

local update_bundle_tag = update_tag

function update_tag(file, content, tagname, tagdate)
  if not file:match("%.pm$") then
    return update_bundle_tag(file, content, tagname, tagdate)
  end

  tagname = normalize_tagname(tagname)

  local updated, count = content:gsub(
    "(our%s+%$VERSION%s*=%s*['\"])[^'\"]*(['\"])",
    function(opening, closing)
      return opening .. tagname .. closing
    end,
    1
  )
  if count == 0 then
    print("No $VERSION assignment found in " .. file)
  end
  return updated
end
