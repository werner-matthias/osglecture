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
