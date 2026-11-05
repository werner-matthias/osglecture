bundle = "osglecture"
module = "osgdocmk"
maindir = ".."

docfiles = {
  "osgdocmk-en.pdf",
  "osgdocmk-de.pdf",
}

installfiles = { }

tdsdirs = {
  ["scripts"] = "scripts/osgdocmk",
  ["scripts/definitions"] = "scripts/osgdocmk/definitions",
  ["scripts/lib"] = "scripts/osgdocmk/lib",
  ["scripts/vendor"] = "scripts/osgdocmk/vendor",
  ["man"] = "doc/man/man1",
}

sourcefiles = {
  "osgdocmk.tex",
  "scripts/lib/OLLM/Version.pm"
}

-- Typeset twice, as osgdocmk-en and osgdocmk-de (see bilingualfiles in ../build.lua).
typesetfiles = { "osgdocmk.tex" }
bilingualfiles = { "osgdocmk.tex" }

textfiles = {
  "README-osgdocmk.md",
  "THIRD_PARTY-osgdocmk.md",
}

-- The functional test suite will grow with the new implementation.  Keeping
-- the syntax check in the normal l3build check path catches broken releases
-- even before there are stable CLI contracts to exercise.
function checkinit_hook()
  local errorlevel = runcmd("perl -c osgdocmk", "scripts", { })
  if errorlevel ~= 0 then
    return errorlevel
  end
  errorlevel = runcmd("perl -c osgdocmk-latexmk.rc", "scripts", { })
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

-- osgdocmk has no .dtx; its only version source is the Perl module, which the
-- documentation reads at typesetting time.
tagfiles = { "scripts/lib/OLLM/Version.pm", "man/osgdocmk.1" }

dofile("../build.lua")

local update_bundle_tag = update_tag

function update_tag(file, content, tagname, tagdate)
  if file:match("%.1$") then
    -- .TH OSGDOCMK 1 "<date>" "osgdocmk <version>" "osglecture bundle"
    local updated, count = content:gsub(
      '(%.TH OSGDOCMK 1 ")[^"]*(" "osgdocmk )[^"]*(")',
      function(opening, middle, closing)
        return opening .. tagdate:gsub("/", "-") .. middle
          .. normalize_tagname(tagname) .. closing
      end,
      1
    )
    if count == 0 then
      print("No .TH line found in " .. file)
    end
    return updated
  end
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
