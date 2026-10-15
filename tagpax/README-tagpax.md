# tagpax

`tagpax` imports complete, tagged PDF documents into a new tagged PDF while
reconstructing their logical structure. It is intended for assembling
independently produced contributions without reducing their pages to
inaccessible graphics.

Alongside the structure tree, the package preserves relevant links and named
destinations and can transfer headings to the table of contents and PDF
outline. Its current scope is complete, linear documents imported as whole
pages. `tagpax` requires LuaLaTeX.

For the full interface, supported PDF features, and current limitations, run
`texdoc tagpax`.
