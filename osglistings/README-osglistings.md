# osglistings

`osglistings` is a `minted`-based code-listing front end for LuaLaTeX. It
provides a common interface for inline source and external files, with visual
styles suited to plain listings, printed code sheets, and editor-like windows.

The package adds independently themeable syntax colours, Unicode-capable code
fonts, tagged-PDF support, and annotations for explaining or highlighting
exact source positions. Listings can optionally link to an online editor or
display that link as a QR code.

External source may also be taken from GitHub or a Gist and cached locally.
This optional feature requires `--shell-escape`, performs network access with
the permissions of the TeX process, and is intended only for trusted
documents and source locations.

For the complete interface and examples, run `texdoc osglistings`.
