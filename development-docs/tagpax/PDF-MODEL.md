# PDF structures used by tagpax

This document collects the PDF concepts on which the implementation depends.
It is a project-oriented map of the object model, not a general introduction to
PDF and not a substitute for the ISO PDF specification. Names beginning with
`/` are PDF dictionary keys or PDF names.

## Objects, references and containers

A PDF is an object graph. Values can be null, booleans, numbers, names, strings,
arrays, dictionaries or streams. An indirect object has an object number and
generation number and can be reached through an indirect reference such as
`17 0 R`.

Object numbers identify objects only inside one concrete PDF serialization.
They can change when a file is rewritten and have no semantic meaning.
`tagpax` therefore uses them only while resolving source references during
extraction. Canonical IR assigns local IDs such as `n3`, `p2`, `s1`, `d4` and
`a2`.

The LuaTeX `pdfe` library exposes direct containers and indirect references as
different userdata types. Extraction normalizes both forms before interpreting
an object. PDF arrays are conceptually zero-based in the specification, while
the relevant `pdfe.getfromarray` access used by `tagpax` is one-based. Page
property access through `pdfe` has separate container conventions; this is why
array access is isolated in helper functions.

## Catalog and page tree

The trailer reaches the document catalog through `/Root`. The catalog is the
entry point for the structures relevant here:

```text
Catalog
  /Pages          -> page tree
  /StructTreeRoot -> logical structure
  /Names /Dests   -> named destinations
  /Dests          -> legacy destination dictionary
```

The page tree contains `/Pages` branch nodes and `/Page` leaves. Properties such
as `/MediaBox`, `/CropBox`, `/Rotate` and `/Resources` may be inherited from an
ancestor. `pdfe.getpage` and `pdfe.getbox` are used so the writer sees the
effective page and box rather than reproducing page-tree inheritance logic.

Every source page is imported as one Form XObject. The page itself is not copied
as a target `/Page` object: LuaTeX places the Form on a newly generated master
page.

## Page content and Form XObjects

A page's `/Contents` streams contain graphics operators and marked-content
operators. A Form XObject is another content stream with its own resources and
coordinate system. It can be painted from a page content stream using `Do`.

Marked content is introduced by `BMC` or `BDC` and closed by `EMC`. Tagged
content normally uses a property dictionary containing `/MCID`:

```pdf
/P << /MCID 7 >> BDC
  ...
EMC
```

An MCID is not globally unique. It is an index local to a page content stream or
another structure-bearing stream. The pair `(content stream, MCID)` identifies
the marked-content sequence. Importing MCID `7` correctly therefore requires
both the unchanged number `7` and the target Form reference.

A structure-bearing target Form receives `/StructParents N`. `N` selects a
ParentTree array whose slot at the MCID identifies the owning StructElem.
Unused array positions are represented by `null`.

Explicit source MCR dictionaries may contain `/Stm`, pointing to a nested Form
instead of page content. `tagpax` records these streams separately because
binding their MCIDs to the outer page Form would be incorrect. The native
whole-page writer currently rejects such unresolved nested Forms.

## Logical structure tree

The catalog's `/StructTreeRoot` owns the logical document structure. Its `/K`
entry contains the top-level children. A structure element is a `/StructElem`
dictionary whose important entries include:

| Entry | Meaning used by tagpax |
| --- | --- |
| `/S` | structure role, for example `/Document`, `/H2`, `/P`, `/Link` |
| `/P` | logical parent |
| `/K` | ordered children |
| `/Pg` | optional associated page |
| `/T` | title |
| `/ActualText` | replacement text |
| `/Alt` | alternative description |
| `/Lang` | language |

`/K` is polymorphic. It can be a single object or an array, and each child can
be another StructElem, an integer MCID, an MCR dictionary or an OBJR dictionary.
The order is semantic: these child kinds can be interleaved. `tagpax` therefore
serializes every child as a `kid` record with an explicit `index`; grouping by
kind would corrupt reading order.

Integer children are shorthand for an MCID associated with the page inherited
from the owning structure element. An explicit MCR can state `/MCID`, `/Pg` and
`/Stm`. Page association can also be inferred from the ParentTree when `/Pg` is
absent.

The source `/Document` element is a document-level wrapper. A PDF master has one
logical document hierarchy, so import unwraps a source `/Document` and attaches
its children below a newly created `/Part`.

## ParentTree and reverse association

The `/ParentTree` under `/StructTreeRoot` is a number tree. It provides the
reverse mapping from page streams, Form streams and annotations back to
structure elements.

For marked content:

```text
Form /StructParents N
        |
        v
ParentTree key N -> [ StructElem-for-MCID-0, null, StructElem-for-MCID-2, ... ]
```

For an annotation:

```text
Annotation /StructParent N
        |
        v
ParentTree key N -> owning Link StructElem
```

This is a singular document-wide structure. LaTeX PDF management and `tagpdf`
own the master ParentTree and allocate its keys. `tagpax` registers additional
entries through its bridge; it must not calculate `/ParentTreeNextKey`
independently or write a competing ParentTree.

## Annotations and OBJR

Annotations are page-level interactive objects listed in a page's `/Annots`
array. `tagpax` currently imports annotations whose `/Subtype` is `/Link`.
Their `/Rect` is expressed in source page coordinates.

Tagging an annotation requires two directions of association:

1. the annotation contains `/StructParent N`, and the ParentTree maps `N` to
   the owning `/Link` StructElem;
2. the StructElem's ordered `/K` contains an OBJR dictionary whose `/Obj`
   refers back to the annotation.

An OBJR may also contain `/Pg`. Its position among the other `/K` children must
match the source position. Since LuaTeX allocates the target annotation object
only during page construction or shipout, `tagpax` first reserves an ordered
OBJR slot and binds the late object reference afterward.

The source annotation dictionary is not copied wholesale. The target writer
creates a new overlay annotation with transformed geometry, a supported action
and a fresh `/StructParent`.

## Link actions

A link can use a direct `/Dest` entry or an action dictionary `/A`. The
implemented action subset is:

| Action | Relevant source entries | Target behavior |
| --- | --- | --- |
| internal GoTo | `/Dest`, or `/A << /S /GoTo /D ... >>` | namespaced destination |
| URI | `/A << /S /URI /URI (...) >>` | URI action |
| remote GoTo | `/A << /S /GoToR /F ... /D ... >>` | remote named or page target |

A file specification can be a string or a dictionary. `/UF` is preferred for a
Unicode filename and `/F` is the compatibility fallback. Unsupported actions
are not silently converted because that could change their semantics.

## Destinations and name trees

A destination selects a page and a view. It can be an array, be wrapped in a
dictionary under `/D`, be reached through an indirect reference, or be named.

Named destinations normally live in the catalog's `/Names` name tree under
`/Dests`. A name tree contains alternating keys and values in `/Names` arrays
and may have child nodes in `/Kids`. Older PDFs may instead use a catalog-level
`/Dests` dictionary. The extractor flattens either representation into one
lookup map.

Destination arrays use one of these forms:

| View | Parameters after page | Meaning |
| --- | --- | --- |
| `/XYZ` | left, top, zoom | point and optional magnification |
| `/Fit` | none | fit entire page |
| `/FitH` | top | fit width at vertical coordinate |
| `/FitV` | left | fit height at horizontal coordinate |
| `/FitR` | left, bottom, right, top | fit rectangle |
| `/FitB` | none | fit page bounding box |
| `/FitBH` | top | fit bounding-box width |
| `/FitBV` | left | fit bounding-box height |

`null` parameters mean that the viewer should retain the corresponding current
coordinate or magnification. LaTeX destination primitives cannot express every
such partially retained view. For a missing `XYZ` coordinate, `tagpax` uses the
corresponding MediaBox edge; an explicit zoom is retained.

Destination names are local to a source PDF, but the master can import several
PDFs containing the same name. Every import therefore uses a namespace:

```text
tagpax.<import-prefix>.dest.<destination-id>
```

## Coordinates, boxes and rotation

PDF page coordinates are measured in default user space. A MediaBox is
`[llx lly urx ury]` and need not start at `(0, 0)`. Before scaling, the writer
translates points by the MediaBox lower-left corner. It then applies effective
page rotation and the final scale used for the imported Form.

For a translated point `(u, v)` in an unrotated box of width `w` and height
`h`, the implemented quadrant mappings are:

| Rotation | Display-space point before scaling |
| --- | --- |
| 0 | `(u, v)` |
| 90 | `(v, w - u)` |
| 180 | `(w - u, h - v)` |
| 270 | `(h - v, u)` |

The displayed width and height exchange for 90 and 270 degrees. Separate
horizontal and vertical scale factors are derived from the actual LuaTeX image
dimensions.

An annotation or `FitR` rectangle is transformed by mapping all four corners
and taking their target-space bounding box. Mapping only the source lower-left
and upper-right fails for quarter rotations.

After a quarter rotation, a source horizontal view constraint becomes vertical:
`FitH` and `FitV` exchange roles, as do `FitBH` and `FitBV`.

The visible imported page, annotation rectangles and precise destinations must
all use this same transformation. Separate geometry calculations would make
links clickable at a location different from their visual content.

## Why writing is phased

The source structure graph and its `/K` order are known immediately after
extraction. Target Form and annotation object references are not known until
pages are constructed. These constraints require the backend sequence:

1. reserve StructElems and ordered MCR/OBJR positions;
2. write page Forms, destinations and annotation overlays, recording target
   object references;
3. bind MCIDs and annotations and finalize ParentTree entries.

This is a consequence of the PDF object relationships above, not merely an
implementation preference.

## Project terminology

| Project term | Corresponding PDF concept |
| --- | --- |
| node | StructElem |
| node role | StructElem `/S` |
| kid | ordered member of StructElem `/K` |
| stream | MCID scope: page content or Form XObject |
| MCR | marked-content reference |
| OBJR | object-reference child, currently referring to an annotation |
| binding | association with a newly allocated target PDF object |
| destination | page/view target used by navigation |
| annotation | page-level interactive object |

For the normalized representation of these concepts, see `FORMATS.md`. For
their ownership and execution order, see `architecture.md`; for the rationale
behind the constraints, see `DESIGN.md`.
