# Architecture notes

## v0.1 invariants

- A contribution is imported completely, in source order, once.
- Source `Document` is unwrapped and its children are attached below a new master `Part`.
- Heading roles and MCIDs are preserved.
- One `StructParents` key is allocated per imported structure-bearing Form XObject.
- Every new MCR contains `/Stm <target-form-ref>` and the original `/MCID`.
- ParentTree arrays are registered through the single LaTeX/tagpdf owner of the master ParentTree.
- TOC and outline destinations point to source-page starts.

## Required backend contract

The LaTeX side needs a public or narrowly isolated implementation of:

1. `external_stream_allocate(form-ref) -> StructParents`
2. `external_stream_set_structparents(form-ref, key)`
3. `external_struct_create(role, properties) -> struct-id`
4. `external_struct_append_node(parent, child)`
5. `external_struct_append_mcr(parent, form-ref, mcid, target-page-ref)`
6. `external_parenttree_register(key, mcid, struct-id)`
7. `external_stream_commit(key)`

The core package must not write a second ParentTree or guess `ParentTreeNextKey`.

## Stream graph and import plan (0.4 development)

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

A first live backend prototype confirmed that imported PDF pages can be created as
LuaTeX image/Form resources with a `/StructParents` attribute.  However, using
`tagpdf`'s normal `tag_struct_begin/end` operations to clone a complete external
structure tree is not safe: those operations are stack-oriented and interact with
automatically opened paragraph and page structures in the master document.

The production backend therefore needs a non-stack API for creating StructElem
objects with an explicit parent, appending existing-stream MCR dictionaries, and
registering ParentTree arrays.  The narrowly isolated private bridge now supplies that operation for the
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

## Frozen layer model (0.7)

The maintained architecture is:

1. Inspector reads PDF objects and produces canonical IR.
2. Transformations modify only IR semantics.
3. Import planning resolves streams and placement bindings.
4. Backend planning orders PDF-writing operations.
5. Backend emits Forms, StructElems, MCRs, OBJRs and ParentTree entries.

No backend or navigation module may read the source PDF directly. The user
manual is maintained bilingually with tightly coupled `langselect` templates;
the developer documentation remains English.
