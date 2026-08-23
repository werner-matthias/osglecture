# Beamer-like formatting with `osgstyler`

This `article` example recreates a small, familiar part of Beamer's author
interface: `\alert`, `\structure` (plus the short alias `\struct`), and the
`block`, `alertblock`, and `exampleblock` environments.

The example uses osgstyler for resource palettes, inline template instances,
and command sockets. `tcolorbox` acts only as the provisional block-rendering
backend. This keeps the example independent of both Beamer and the
`osglecture` class while illustrating the intended separation between a
semantic author interface and its renderer.

Compile with LuaLaTeX after installing the bundle:

```sh
lualatex osgstyler-beamerlike.tex
```
