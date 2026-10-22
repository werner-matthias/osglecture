--[[
  CTAN submission data for the osglecture bundle, read by the root build.lua
  and used by l3build's upload target:

    l3build ctan                                  -- build osglecture-ctan.zip
    l3build upload --email=<address> --dry-run    -- let CTAN validate only
    l3build upload --email=<address>              -- validate, then submit

  This file replaces filling in the web form by hand: every field CTAN asks
  for is kept here, so nothing is forgotten between releases. 
--]]

-- Contents of a text file, or nil when it is missing or blank.
local function file_text(name)
  local handle = io.open(name, "rb")
  if not handle then
    return nil
  end
  local text = handle:read("a")
  handle:close()
  if text:match("^%s*$") then
    return nil
  end
  return text
end

-- The bundle as a whole is identified by its release date, maintained by
-- "l3build tag" in README.md.  An unreleased bundle has no version, and
-- l3build then asks for one instead of submitting a wrong one.  A version
-- given on the command line ("l3build upload 2026-11-02") wins.
local function bundle_release_date()
  local readme = file_text("README.md") or ""
  local date = readme:match(
    "<!%-%- BUNDLE RELEASE DATE %-%->(.-)<!%-%- /BUNDLE RELEASE DATE %-%->"
  )
  if date and date:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return date
  end
  return nil
end

uploadconfig = {
  pkg      = "osglecture",
  version  = bundle_release_date(),
  author   = "Matthias Werner",
  uploader = "Matthias Werner",

  -- First submission.  Switch to true for every later upload.
  update   = false,
  ctanPath = "/macros/luatex/latex/osglecture",

  -- Bundle code is LPPL 1.3c.  Vendored third-party code: toml2lua (MIT,
  -- osglecture/THIRD_PARTY-osglecture-cls.md) and the TOML::Tiny parser (same terms as
  -- Perl 5: Artistic 1.0 or GPL 1 or later, ollm/THIRD_PARTY-ollm.md).
  -- Keys as listed by https://ctan.org/json/2.0/licenses.
  license  = { "lppl1.3c", "mit", "artistic", "gpl1+" },

  summary  = "Lecture materials from one source: slides, script, and tagged PDF",

  description = [[
<p>The osglecture bundle supports the generation of lecture materials.
It can produce several documents from one LaTeX source: slides,
handouts, a presenter version, or script, each in several
languages. The class osglecture selects the actual document class
(ltx-talk or beamer for presentations, book or scrbook for long forms)
through document profiles, so the source contains nothing class-specific.
The build manager ollm builds whole lecture series, carries cross-references
and counters between units, and collects units into one document.
In addition, the bundle aims at accessible, tagged PDFs.</p>

<p>Several of the bundle's packages can also be used on their own.
The bundle currently contains:</p>
<ul>
<li>osglecture: document class that produces slides, script, handouts, and other materials from a common source</li>
<li>ollm (OSG LaTeX Lecture Maker): latexmk-based build manager for creating and deploying lecture materials</li>
<li>osglecture-modes: portable document modes in the style of beamer/ltx-talk for arbitrary classes</li>
<li>langselect: several language versions of a document from a common source</li>
<li>tagpax: semantic import of tagged PDFs</li>
<li>osgstyler: template-based formatting</li>
<li>ltxtalk-theme: theme engine for ltx-talk, with a few themes modelled after Beamer themes</li>
<li>ltxtalk-theme-tuc-2019: unofficial version of the TU Chemnitz presentation theme for ltx-talk</li>
<li>ansiterm: ANSI-aware, optionally executable terminal windows</li>
<li>osglistings: minted-based code-listing front end</li>
<li>semcat: semantic-category markup</li>
<li>tagdirtree: taggable directory trees</li>
<li>tagbridge: transitional patches for a few third-party packages that lack native tagging (PDF/UA) support</li>
<li>osgdoc: small wrapper for cnltx with further support for documentation</li>
</ul>

<p>The bundle requires LuaLaTeX and is under active development.</p>]],

  topic    = { "presentation", "course-material", "subdocs", "accessible", "tagged-pdf", "multilingual" },

  home       = "https://github.com/werner-matthias/osglecture",
  repository = "https://github.com/werner-matthias/osglecture",
  bugtracker = "https://github.com/werner-matthias/osglecture/issues",

  -- nil (empty file) makes l3build asks.
  announcement = file_text("ctan/announcement.txt"),
  note         = file_text("ctan/note.txt"),
}
