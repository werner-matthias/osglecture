# tagpax developer architecture

This document describes the current implementation. It is normative for module
boundaries and invariants; release history belongs in `CHANGELOG.md`.

## Scope

`tagpax` imports complete tagged contribution PDFs into a tagged LuaLaTeX
master document. Every source page is included exactly once and in source
order. Each page becomes a fresh Form XObject. The source structure tree,
marked-content references, supported link annotations, destinations, headings,
table-of-contents entries and bookmarks are reconstructed around those Forms.

The native path deliberately does not support page selection, imposition,
repetition or arbitrary graphics placement. Explicit nested source Form streams
are represented in the IR but remain unresolved by the native writer.

## Data flow and ownership

```text
tagged source PDF
    |
    | tagpax.lua: pdfe inspection and normalization
    v
canonical IR (.tagpax / plain Lua tables)
    |
    | tagpax-validate.lua
    | tagpax-import.lua: target-independent planning when requested
    v
TeX-facing execution
    |
    +-- tagpax-backend.lua: structure reservation and binding instructions
    +-- tagpax-native.lua: page and navigation instructions
    +-- tagpax-luatex.lua: Form creation, geometry, destinations, annotations
    v
tagpax-tagpdf-bridge.sty
    |
    | explicit-parent StructElems, ordered kids, ParentTree registration
    v
tagged master PDF
```

Only the extractor and the page writer read the source PDF. The extractor reads
semantic PDF objects. The page writer reopens the PDF solely because final page
geometry and the LuaTeX image object are known only while the page Form is
created. Planning and structure modules consume only canonical IR.

LaTeX PDF management and `tagpdf` remain the sole owners of the master
StructTreeRoot, ParentTree, page objects and annotation dictionaries. `tagpax`
adds entries through a narrowly isolated bridge; it never creates a second
ParentTree.

## Core invariants

- Source PDF object numbers are extraction locators, never semantic IDs.
- Node, stream, destination and annotation IDs are local to one IR document.
- MCIDs are retained unchanged and remain scoped to their original stream.
- Every imported page Form receives a fresh `StructParents` key.
- Every reconstructed page-stream MCR contains `/Stm <form-ref>` and the source
  `/MCID`.
- Sparse ParentTree arrays contain `null` for unused MCIDs.
- Source `Document` roots are unwrapped beneath one synthetic master `Part`.
- Source `/K` order is preserved across node, MCR and OBJR children.
- Each import has a unique destination namespace.
- Each source destination gets a distinct target destination.
- An imported annotation's OBJR belongs to the original imported `Link`
  StructElem, not to a synthetic replacement.
- The private bridge does not push or pop the ordinary `tagpdf` structure stack.

## Three-phase backend execution

PDF object references for page Forms and annotations do not exist when the
source structure order is first known. Conversely, waiting until page shipout
to append children would destroy source `/K` order. The backend resolves this
with three phases.

### 1. Reserve

Before any imported page is written:

- create the synthetic `Part`;
- create every imported StructElem with an explicit parent;
- append child StructElem references in source order;
- append deferred MCR slots in source order;
- append deferred OBJR slots in source order;
- remember which reserved StructElem owns each annotation.

The deferred slots are expandable references. They occupy their final position
immediately but resolve only after the relevant PDF object exists.

### 2. Write and bind

For each page:

- allocate its external stream and `StructParents` key;
- create the page Form with `/StructParents`;
- record the Form object reference;
- create transformed destinations and annotation overlays;
- assign each annotation a `StructParent`;
- create its OBJR object and record the OBJR reference;
- register the annotation owner in the central ParentTree.

Imported links locally suppress `tagpdf`'s automatic Lua link association.
Otherwise `tagpdf` would also move the annotation into its fallback link
container and create a duplicate OBJR.

### 3. Finalize

After all pages:

- bind each source MCID to its reserved StructElem;
- commit every external-stream ParentTree array;
- let `tagpdf` serialize StructElems, at which point deferred Form and OBJR
  references expand to their recorded object references.

## Page geometry and destinations

The page writer uses the source MediaBox, inherited page rotation and final
image dimensions to build one affine point mapping. The same mapping is used
for annotation rectangles, `XYZ` points and `FitR` rectangles.

For rotations of 90 or 270 degrees, `FitH`/`FitV` and `FitBH`/`FitBV` exchange
roles. `Fit`, `FitB` and page-start destinations need no coordinate mapping.
An explicit `XYZ` zoom factor is converted from the PDF scale factor to the
percentage expected by LaTeX PDF management.

PDF permits `null` components in an `XYZ` destination to retain the viewer's
current coordinate. A positional LaTeX destination cannot express that state.
For a missing component, `tagpax` uses the corresponding MediaBox edge.

## Module boundaries

| Module | Responsibility | Environment |
| --- | --- | --- |
| `tagpax.lua` | PDF inspection and canonical serialization | LuaTeX `pdfe` |
| `tagpax-ir.lua` | Parse serialized IR into indexed Lua tables | plain Lua |
| `tagpax-validate.lua` | Referential and semantic IR validation | plain Lua |
| `tagpax-inspect.lua` | Validating inspection facade and summaries | LuaTeX for PDF input |
| `tagpax-import.lua` | Target-independent structure/MCR plan | plain Lua |
| `tagpax-backend.lua` | Emit reserve/finalize TeX operations | LuaTeX |
| `tagpax-native.lua` | Emit page imports and master navigation | LuaTeX |
| `tagpax-luatex.lua` | Write Forms and transformed navigation overlays | LuaTeX |
| `tagpax-compare.lua` | Semantic roundtrip comparison | plain Lua |
| `tagpax-roundtrip.lua` | Compatibility alias for `tagpax-native` | LuaTeX |

The generated `tagpax-tagpdf-bridge.sty` contains every use of private
`tagpdf` structure internals. Changes to `tagpdf` should require edits there,
not throughout the Lua modules.

## Failure policy

The implementation rejects ambiguity instead of silently degrading semantics:

- missing roots, nodes, streams or destinations fail validation;
- unsupported annotation actions are rejected;
- incomplete `FitR` destinations are rejected;
- unresolved explicit object streams remain visible in an import plan and make
  `assert_resolved` fail;
- an explicit object stream is never rebound to the containing page Form.

## Verification

`l3build check` covers parsing, validation, planning, API names and geometry.
`l3build check -c roundtrip` compiles a tagged source, extracts it, imports it,
extracts the master and compares the semantic subtree including MCR and OBJR
order. Generated PDFs should additionally pass `qpdf --check`.
