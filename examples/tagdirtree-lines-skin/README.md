# tagdirtree with a connector-line skin

This example demonstrates that `tagdirtree`'s accessible tagging and its
visual appearance are fully independent: the same `\dtdir`/`\dtfile`/
`\dtarchive` calls that produce the package's plain default look here
instead render classic connector lines, colored from an `osgstyler` theme
— by redefining exactly one hook (`\tagdirtreeconnector`), nothing in
`tagdirtree` itself.

Compile with LuaLaTeX after installing the bundle:

```sh
lualatex tagdirtree-lines-skin.tex
```

Requires `osgstyler-lua` (for the theme color) and `tagdirtree`.

## What to look at

- The `/Alt` text and tag structure in the resulting PDF are identical to
  a plain `tagdirtree` document with the same tree — the connector lines
  are marked `artifact` and carry no semantics of their own, exactly like
  the default skin's icons.
- `\tagdirtreedepth` is a plain nesting counter, not a position within
  the sibling list, so this skin cannot tell whether an entry is the
  *last* one at its level — every branch uses the same connector rather
  than a distinct closing corner for the last child. Real "is this the
  last sibling" awareness would need look-ahead across the enclosing
  `\dtdir`'s argument, which is a bigger undertaking than this demo
  warranted.
