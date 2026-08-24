# osgstyler

Reusable, template-based styles for LaTeX documents.

The public interface is currently an alpha API, reported by
`\OsgStylerAPIVersion` as `0.1.0-alpha`. Test users should expect that names
may still be refined before the first stable release.

`osgstyler` is part of the `osglecture` bundle but is designed for independent
use. It currently provides font and color palettes. The font-palette registry
uses `fontspec` and the portable relational slots `main`, `companion`,
`display`, `accent`, `mono`, `math`, and `symbol`.

```latex
\DeclareOsgFontPalette{example}{
  main      = {font = {Source Serif 4}},
  companion = {font = {Source Sans 3}},
  display   = {alias = companion},
  accent    = {alias = companion},
  mono      = {font = {Source Code Pro}},
  math      = {font = {STIX Two Math}},
  symbol    = {alias = main}
}

\UseOsgFontPalette{example}
```

Text resources are selected with `\UseOsgFont{<slot>}`. The `math` resource
is intentionally only registered for a later `unicode-math` adapter and cannot
be selected as a text family.

Color palettes use the slots `primary`, `secondary`, `accent`, `text`,
`background`, `structure`, `alert`, and `example`; these slot names
deliberately match `lttheme`'s color vocabulary (the declaration syntax
itself is `osgstyler`'s own, key-value based like its font and metric
palettes, not `lttheme`'s positional `{model}{spec}` form):

```latex
\DeclareOsgColorPalette{modern}{
  primary    = {model=RGB, value={43,58,103}},
  secondary  = {model=RGB, value={73,106,129}},
  accent     = {model=RGB, value={102,153,155}},
  text       = {model=RGB, value={51,51,51}},
  background = {model=RGB, value={255,255,255}},
  structure  = {alias=primary},
  alert      = {model=RGB, value={176,0,32}},
  example    = {model=RGB, value={22,101,52}}
}

\UseOsgColorPalette{modern}
```

Only `primary` is required. Missing relational slots fall back through the
palette; `text` and `background` finally fall back to black and white. Active
colors have stable `xcolor` names such as `osgstyler-primary`; the expandable
`\OsgColorName{<slot>}` returns the corresponding name.

`osgstyler` deliberately does not depend on `lttheme`. A later adapter can make
`lttheme` consume an active `osgstyler` palette, while the palette package
remains independently usable. Conversely, when `ltxtalk-theme` is loaded,
osgstyler automatically exposes its current colors as the active `lttheme`
palette. Theme activation, partial themes, and `\setltxtalkcolors` resynchronize
the palette automatically.

Complete built-in font, color, and metric palettes named `osgstyler-default`
are active immediately. The predefined styles and the Lua backend therefore
work without any palette setup. Explicit palette selection replaces these
defaults normally.

Metric palettes provide portable scales for `spacing`, `padding`, `rule`, and
`radius`. Every declaration inherits a complete built-in scale, so a theme may
override only selected values:

```latex
\DeclareOsgMetricPalette{modern}{
  spacing = {sm = {.4\baselineskip}, lg = {1.25\baselineskip}},
  padding = {normal = {.75em}},
  rule    = {thin = {.5pt}, thick = {1.5pt}},
  radius  = {small = {3pt}, round = {8pt}}
}

\UseOsgMetricPalette{modern}
```

The active value `\OsgMetric{rule}{thin}` and the palette-specific value
`\OsgMetricPaletteValue{modern}{rule}{thin}` are expandable. The portable
slots are `none`–`xl` for spacing, `none`, `compact`, `normal`, and `roomy` for
padding, `hairline`–`thick` for rules, and `square`–`round` for radii.

Named decorations combine backend-neutral visual components. The initial
families are `line`, `background`, `enclosure`, `margin`, and `affix`:

```latex
\DeclareOsgDecoration{marked-important}{
  line = {
    position  = below,
    pattern   = wavy,
    color     = alert,
    thickness = .08em,
    offset    = .12em
  },
  background = {
    color   = accent,
    opacity = .25,
    shape   = text
  },
  affix = {
    warning = {
      position = before,
      content  = {!},
      color    = alert,
      font     = accent,
      gap      = .3em
    }
  }
}
```

Each family may instead contain freely named component instances. This permits
several decorations of the same kind, for example simultaneous overlining and
underlining:

```latex
\DeclareOsgDecoration{over-and-under}{
  line = {
    under = {
      position = below,
      pattern  = solid,
      color    = accent,
      offset   = .12em
    },
    over = {
      position = above,
      pattern  = solid,
      color    = accent,
      offset   = .08em
    }
  }
}
```

The short form in the first example creates an instance named `default`.
A conventional frame box is therefore simply an `enclosure` in short form.
Each `affix` instance represents exactly one item at `before` or `after`.
Literal `content={...}` and a named `symbol=...` are mutually exclusive;
`font` and `color` refer to portable palette slots.

Color properties refer to portable color-palette slots. Rendering is left to
separate adapters, so declaring a decoration does not load or commit to
`ulem`, `lua-ul`, a box package, or a particular output implementation.
Adapters inspect resources with
`\OsgDecorationValue{<name>}{<family>}{<property>}` and test components with
`\OsgDecorationIfHasComponentTF`. For multiple instances they use
`\OsgDecorationInstances{<name>}{<family>}` and
`\OsgDecorationInstanceValue{<name>}{<family>}{<instance>}{<property>}`.

Inline styles form the first template composition layer. They are instances of
the kernel template type `osgstyler-inline` and combine palette resources,
decoration, and semantics:

```latex
\DeclareOsgInlineStyle{important}{
  font       = accent,
  weight     = bold,
  shape      = inherit,
  color      = accent,
  decoration = marked-important,
  semantics  = emphasis
}

This is \UseOsgInlineStyle{important}{important text}.
```

The values `font=none`, `color=none`, `decoration=none`, and `semantics=none`
leave the respective layer unchanged. Font and color selection are implemented
by the standard template. The `weight` values are `inherit`, `regular`, and
`bold`; `shape` accepts `inherit`, `upright`, `italic`, `slanted`, and
`small-caps`. Decoration rendering and semantic/tagging behavior
are deliberately delegated to interchangeable functions taking two arguments,
the resource or role name and the content:

```latex
\SetOsgDecorationProcessor{\MyDecorationProcessor}
\SetOsgSemanticProcessor{\MySemanticProcessor}
```

Both processors are transparent by default. Backends can therefore be added
without replacing inline-style instances. The underlying kernel API remains
available as `\DeclareInstance{osgstyler-inline}{...}{standard}{...}` and
`\UseInstance{osgstyler-inline}{...}{...}`.

Author commands are connected through kernel sockets rather than hard-wired
aliases:

```latex
\BindOsgInlineCommand{\emph}{emphasis}
\BindOsgInlineCommand{\textbf}{strong}
\BindOsgInlineCommand{\uline}{underline}
\BindOsgInlineCommand{\highlight}{highlight}
\BindOsgInlineCommand{\fbox}{frame}
```

Each managed command owns a one-input socket. Its saved implementation is
available through the `original` and public `default` plugs, while every
binding creates or selects a `style/<name>` plug.
Assignments obey normal TeX grouping, so a style may be changed locally.
`\RestoreOsgInlineCommand{<command>}` selects its `default` plug again. Robust
commands are preserved with `\NewCommandCopy`, avoiding recursion through an
implementation replaced by the socket wrapper.

All standard command sockets can be switched back together:

```latex
\UseOsgDefaultInlineCommands
```

For commands that existed when first bound, this restores their familiar
LaTeX or package implementation. For commands introduced by `osgstyler`, the
default plug transparently returns their argument. Like every socket
assignment, the collective switch can be scoped with an ordinary TeX group.

The styles `emphasis`, `strong`, `underline`, `highlight`, and `frame` and
their basic decorations are predefined. The `frame` style uses `primary` for
its border, `background` for its fill, and the active metric palette for rule
width and padding. `\highlight` is available immediately;
`\UseOsgStandardInlineCommands` explicitly binds all five standard command
names, including `\fbox`. Existing `\emph`, `\textbf`, `\fbox`, or
package-provided `\uline` definitions are therefore not replaced merely by
loading `osgstyler`.

If `osglecture-modes` is loaded, `\UseOsgInlineStyle` and every command managed
by `\BindOsgInlineCommand` automatically accept a portable mode expression:

```latex
\emph<presentation>{only in presentation modes}
\ProjectTerm<longform|print>{only in long-form or print output}
```

This works in either package load order and also for commands bound later.
Without `osglecture-modes`, their ordinary signatures remain unchanged.

## Lua reference backend

The optional LuaLaTeX backend closes the rendering pipeline for testing and
for straightforward production use:

```latex
\usepackage{osgstyler-lua}
```

It loads `osgstyler`, `luacolor`, and `lua-ul`, installs itself as the active
decoration processor, and supplies a complete fallback metric palette if no
metric palette is active yet. It currently renders:

- any number of solid `line` instances at `below`, `above`, or `through`;
- `background` highlighting with palette colors;
- `affix` instances containing literal material at `before` or `after`;
- unbreakable inline `enclosure` frames with configurable colors, rule width,
  and padding.

Dimension properties accept either literal dimensions or metric references
such as `rule/thin`, `padding/compact`, and `spacing/xs`. Unsupported line
patterns, opacity, background shapes, rounded corners, symbol references, and
inline margin decorations produce explicit warnings and use a documented
fallback where possible. Semantic processing remains a separate backend
concern.

The regression suite includes tagged-PDF structure tests. One verifies that
the standard command bindings and Lua-rendered underline, highlight, and frame
decorations preserve the surrounding paragraph and native `\emph` tagging. A
second installs a tagging-aware semantic processor and verifies that the
`emphasis` and `strong` roles arrive as `Em` and `Strong`, while a style with
`semantics=none` remains semantically neutral.

For `line` instances at `below`, the offset is measured downwards from the
baseline. At `above`, it denotes the clearance above the current font's
capital height. Consequently, overlines remain clear of ordinary capital
letters when the font or font size changes.

Run the regression tests with `l3build check`.
