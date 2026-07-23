# Architecture Notes

## Canonical architecture:
The maintained architecture is:
PDF -> Inspector -> Canonical IR -> Transformations -> Import Plan -> Backend Plan -> Backend

1. Inspector reads PDF objects and produces canonical IR.
2. Transformations modify only IR semantics.
3. Import planning resolves streams and placement bindings.
4. Backend planning orders PDF-writing operations.
5. Backend emits Forms, StructElems, MCRs, OBJRs and ParentTree entries.

## Invariants
- A pdf document is imported completely, in source order, once.
- No backend or navigation module may read the source PDF directly.
- Source `Document` is unwrapped and its children are attached below a new master `Part`.
- Heading roles and MCIDs are preserved.
- One `StructParents` key is allocated per imported structure-bearing Form XObject.
- Every new MCR contains `/Stm <target-form-ref>` and the original `/MCID`.
- ParentTree arrays are registered through the single LaTeX/tagpdf owner of the master ParentTree.
- TOC and outline destinations point to source-page starts.
- Every import receives a unique destination namespace; links never target a
  destination belonging to another included contribution.
- Every source destination receives its own target destination. Coordinates
  are transformed through MediaBox translation, page rotation and the final
  whole-page scale used by the imported Form.

Destination transformation is deliberately part of the LuaTeX page writer,
not navigation extraction: only the writer knows the final Form dimensions.
`XYZ` points and `FitR` rectangles are mapped through the page transform.
For quarter-turn rotations, horizontal and vertical fit modes exchange roles.
Fit modes without coordinates remain page-level. A `null` XYZ coordinate,
which means “retain the viewer's current coordinate” in PDF, has no positional
LaTeX destination equivalent; tagpax uses the corresponding MediaBox edge for
that missing component while preserving an explicit zoom when present.

## Required backend contract

The LaTeX side needs a public or narrowly isolated implementation of:

1. `external_stream_allocate(form-ref) -> StructParents`
2. `external_stream_set_structparents(form-ref, key)`
3. `external_struct_create(role, properties) -> struct-id`
4. `external_struct_append_node(parent, child)`
5. `external_struct_append_mcr(parent, form-ref, mcid, target-page-ref)`
6. `external_parenttree_register(key, mcid, struct-id)`
7. `external_stream_commit(key)`
8. `external_annotation_bind(annotation-ref, struct-parent-key, struct-id)`

The core package must not write a second ParentTree or guess `ParentTreeNextKey`.

## Reservation, binding and finalization

Native inclusion deliberately runs in three phases:

1. **Reservation** creates every imported StructElem and fills each `/K`
   sequence in source order. MCR and OBJR positions contain expandable
   placeholders because their target PDF object references do not exist yet.
2. **Binding** writes the page Forms and annotation overlays. It records Form
   references, assigns each annotation a `StructParent`, creates its OBJR
   object, and registers the original imported Link element in tagpdf's
   ParentTree.
3. **Finalization** registers MCID-to-StructElem mappings and commits the
   external-stream ParentTree arrays. When tagpdf serializes the StructElems,
   the placeholders expand to the references recorded during binding.

This ordering is required by two constraints that point in opposite
directions: the `/K` array must preserve source order, while LuaTeX allocates
Form and annotation object numbers only while pages are built or shipped out.
Appending OBJRs at shipout would lose their original position; delaying the
whole structure until after shipout would prevent correct annotation
association. Reserving ordered slots resolves both constraints without
changing the canonical IR.

Imported annotations bypass tagpdf's automatic Link-structure creation. The
bridge disables the Lua link-splitting association for just the reconstructed
overlay, supplies `StructParent` itself, and binds the resulting annotation to
the already reserved source Link. This narrowly isolated use of tagpdf
internals is intentional: allowing both mechanisms to run would create a
duplicate OBJR in tagpdf's fallback link container.

## Stream graph and import plan 
The IR now assigns every marked-content stream a stable local identifier.
Page-content streams use `p<page>` identifiers; explicit `/Stm` references use
`s<n>` identifiers and retain the source object number only as an extraction
locator. MCR records refer to the stream identifier rather than to the generic
values `page` or `object`.

The module `tagpax-import.lua` turns the IR into a target-independent import
plan. It accepts two binding tables:

```lua
{
  pages   = { [1] = page_form_handle, ... },
  streams = { s1 = nested_form_handle, ... },
}
```

The planner unwraps a top-level `Document` by default, creates a `Part` wrapper
request, preserves the original child order and MCIDs, and reports every MCR
whose target stream has not yet been bound.

The native LuaTeX importer now creates one fresh Form XObject for every source
page.  It reserves the stream's `StructParents` key before `img.write()`, places
that key in the Form dictionary, and records the resulting target object
reference.  An explicit `/Stm` MCR still needs an additional mapping from the
source nested Form XObject to the copied target Form XObject; unresolved object
streams are rejected rather than attached to the outer page form.


## Experimental page-stream backend findings (0.4.1-dev)

An experimental prototype confirmed that imported PDF pages can be created as
LuaTeX image/Form resources with a `/StructParents` attribute.  However, using
`tagpdf`'s normal `tag_struct_begin/end` operations to clone a complete external
structure tree is **not safe**: those operations are stack-oriented and interact with
automatically opened paragraph and page structures in the master document.

The backend therefore needs a non-stack API for creating StructElem
objects with an explicit parent, appending existing-stream MCR dictionaries, and
registering ParentTree arrays.  The narrowly isolated private bridge supplies that operation for the
prototype, and the native page-stream writer is connected to `\tagpaxinclude`.
The target-independent import plan and stream bindings remain the stable
boundary; the bridge is still provisional pending an upstream public API.


## Explicit-parent tagpdf bridge (0.4.2-dev)

The experimental bridge reserves a `StructParents` key before an imported Form
XObject is written. The caller inserts the returned `/StructParents` attribute
into the Form dictionary, then supplies the resulting Form object reference to
MCR kids. MCID-to-StructElem entries are collected in a sparse array and added
to tagpdf's single ParentTree during finalization.

StructElem creation takes an explicit parent and does not inspect, push or pop
the automatic LaTeX structure stack. The current implementation is intentionally
isolated in `tagpax-tagpdf-bridge.sty`, because it relies on tagpdf 1.0c private
properties, sequences and object names. The intended upstream interface is
described in `doc/tagpdf-api-proposal.md`.


## Native importer and optional pdfpages frontend (0.6.0-dev)

The core package no longer loads `pdfpages`.  `\tagpaxinclude` is the normative
linear full-document importer and owns Form creation, `StructParents`, object
references, and structure reconstruction.  It scales each source page
proportionally into the current `\textwidth` by `\textheight` area and emits
exactly one master page per source page.

`tagpax-pdfpages.sty` is a small syntax adapter, not a second writer.  Its
`\tagpaxincludepdf` command accepts `pages=-` and `pagecommand`; unsupported
montage or selection options are rejected.  The adapter routes all accepted
imports through the native backend so the tagging invariants remain identical.
