# osgstyler

Reusable, template-based styles for LaTeX documents.

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
`background`, `structure`, `alert`, and `example`. Their value syntax and slot
names deliberately match `lttheme`:

```latex
\DeclareOsgColorPalette{modern}{
  primary    = {HTML}{2B3A67},
  secondary  = {HTML}{496A81},
  accent     = {HTML}{66999B},
  text       = {HTML}{333333},
  background = {HTML}{FFFFFF},
  structure  = {alias}{primary},
  alert      = {HTML}{B00020},
  example    = {HTML}{166534}
}

\UseOsgColorPalette{modern}
```

Only `primary` is required. Missing relational slots fall back through the
palette; `text` and `background` finally fall back to black and white. Active
colors have stable `xcolor` names such as `osgstyler-primary`; the expandable
`\OsgColorName{<slot>}` returns the corresponding name.

`osgstyler` deliberately does not depend on `lttheme`. A later adapter can make
`lttheme` consume an active `osgstyler` palette, while the palette package
remains independently usable.

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
  color      = accent,
  decoration = marked-important,
  semantics  = emphasis
}

This is \UseOsgInlineStyle{important}{important text}.
```

The values `font=none`, `color=none`, `decoration=none`, and `semantics=none`
leave the respective layer unchanged. Font and color selection are implemented
by the standard template. Decoration rendering and semantic/tagging behavior
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

Run the regression tests with `l3build check`.
