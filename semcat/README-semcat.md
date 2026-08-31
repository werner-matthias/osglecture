# semcat

`semcat` assigns passages of text to named, color-distinguished semantic
categories -- for instance "required", "supplementary", or "background" --
and provides inline marking, a block-level marking that survives multiple
paragraphs and page breaks (a box or a continuous margin bar), a floating
explanation box, and QR-code annotations for them.

```tex
\usepackage{semcat}

Ordinary text with a \SemCat{B}{marked phrase} in the middle.

\begin{SemCatMark}[category=B]
  Supplementary material, with a footnote\footnote{like this one},
  spanning as many paragraphs as needed.
\end{SemCatMark}

\begin{SemCatExplain}[category=B]{Why this matters}
  Supplementary background that a reader could skip.
\end{SemCatExplain}

\SemCatQR[B]{https://example.org}{Further reading}
```

Categories `A` (the default), `B`, `C`, and `D` are predefined; further
categories are declared with `\SemCatDefine`:

```tex
\SemCatDefine{E}[label={Historical background}, color=teal]
\SemCatDefine*{F}[label={Core material}, slot=primary]
```

Without an explicit `color` or `slot`, colors are assigned round-robin from a
dedicated `semcat-categories` palette while `osgstyler` is loaded, otherwise
from a built-in color sequence; `slot` only takes effect while `osgstyler` is
actually loaded. This palette is kept separate from the document's generic
theme slots on purpose -- switching themes shouldn't also change category
colors -- and defaults to ColorBrewer "Dark2"; redeclare `semcat-categories`
via `\DeclareOsgColorPalette` (after loading `semcat`) for different category
colors.

A category can also specify *how* its block-level marking renders: as a box
(the default) or a continuous margin bar. While `osgstyler` is loaded, a
declared decoration can be referenced instead -- its `margin` component
supplies the bar, its `enclosure` component the box, each with its own
colors/measurements. A `variants` key overrides style or decoration
depending on the active `osglecture-modes` mode, on top of the unqualified
default:

```tex
\SemCatDefine{G}[label={Aside}, style=bar]
\DeclareOsgDecoration{marked-caution}{
  enclosure = { border-color=accent, fill-color=secondary }
}
\SemCatDefine{H}[
  label={Caution}, decoration=marked-caution,
  variants={ slides = {style=box} }
]
```

Colors are not always available -- a textbook print run may have few or
none. For that case, a symbol can take the category color's place, at the
start of the margin bar or in the box header:

```tex
\SemCatDeclareSymbol{pin}{\ding{43}}
\SemCatDefine{J}[label={Caution}, symbol=warning]
```

`symbol` names a registered symbol; `\SemCatDeclareSymbol` registers further
ones (the built-in ones come from `pifont`, chosen for its universal
availability, unlike Unicode symbols which body-text fonts often lack). When
a resolved decoration has an `affix` component, its `content`/`symbol` key
takes precedence over the category's plain `symbol` key; the `affix`
component's `position`, `font`, and `gap` are not evaluated yet.

The margin bar is not drawn via the output routine the way changebar does;
`semcat.lua` decorates every output line at paragraph-breaking time via a
LuaTeX `post_linebreak_filter` callback, so it survives page breaks without
special handling.

Every inline/marking command accepts a leading angle-bracket mode
specification that, while `osglecture-modes` is loaded, is forwarded to
`\IfLectureModeTF`; without it, the restriction is ignored and the markup
always appears. `SemCatMark` and `SemCatExplain`, both `environ`-based
environments, instead take the mode via a `mode=` key, since they cannot
accept angle-bracket syntax:

```tex
\SemCat<article>{B}{printed-only remark}

\begin{SemCatMark}[mode=slides,category=B]
  Slides-only supplementary passage.
\end{SemCatMark}
```

Unlike `\SemCat` and `SemCatMark`, which always stay *within* the reading
flow, `SemCatExplain` is a genuine, numbered and captioned floating
environment (built on the `float` package, type `semcatexplain`, default
placement `tbp`) for content *outside* the reading flow -- skippable
supplementary explanations. It is structurally always a box regardless of
the category's chosen style, and uses the category color only for visual
identity. `\listof{semcatexplain}{List of Explanations}` produces a list of
all explanation boxes.

`\SemCatQRRedirect` builds a QR target from a base URL (set once via
`\SemCatSetRedirectBase`) plus a document id and an entry id; under
LuaLaTeX both parts are robustly percent-encoded via `semcat.lua`.

When a document is tagged via `\DocumentMetadata{tagging=on}`, every
category registers its own PDF structure names, and inline marking and
`SemCatMark` are tagged accordingly -- both stay *within* the reading flow.
`SemCatExplain` instead uses the single, category-independent structure
`semcat/explain` with role `Aside`, since it deliberately sits *outside*
the reading flow. QR codes themselves stay untagged, since `qrcode` draws
them via a `tikz` graphic that does not nest cleanly inside a manually
opened tag structure; the caption next to a code is tagged normally as
ordinary flow text.

`semcat` is part of the `osglecture` bundle, but -- apart from the two
optional integrations above -- depends on none of the bundle's other
packages and can be used on its own. The margin-bar mechanism requires
LuaLaTeX.
