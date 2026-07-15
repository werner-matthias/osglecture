# Proposed tagpdf API for existing marked content in Form XObjects

## Motivation

`tagpax` imports already tagged page content. The marked-content sequences and
MCIDs already exist in Form XObjects, so the normal stack-oriented
`\tag_struct_begin:n` / `\tag_struct_end:` interface is the wrong abstraction.
The importer needs to create structure elements with explicit parents and to
attach MCR dictionaries that refer to an existing stream with `/Stm`.

The current tagpdf implementation owns the structure objects and the single
ParentTree. The proposed API deliberately keeps that ownership in tagpdf.

## Proposed public operations

```latex
\tag_struct_new:nnN { <role> } { <parent-struct-id> } <result-tl>
\tag_struct_append_struct:nn { <parent-id> } { <child-id> }
\tag_struct_append_external_mcr:nnn
  { <parent-id> } { <form-object-reference> } { <mcid> }

\tag_external_stream_new:nN { <logical-stream-id> } <structparents-tl>
\tag_external_stream_attribute:n { <logical-stream-id> }
\tag_external_stream_register:nnn
  { <logical-stream-id> } { <mcid> } { <parent-struct-id> }
\tag_external_stream_commit:n { <logical-stream-id> }
```

The names are provisional. The important properties are:

1. Creating a StructElem does not inspect or alter the current structure stack.
2. The parent is explicit and the child is appended in call order.
3. An external MCR is represented by `/Type /MCR`, `/Stm` and the unchanged
   source `/MCID`.
4. `StructParents` is allocated before the Form XObject is written, so the
   returned key can be included in the XObject dictionary at creation time.
5. ParentTree entries are committed through tagpdf's existing single
   ParentTree owner.
6. Sparse MCID arrays are represented with `null` entries.

## Minimal compatibility implementation

`tagpax-tagpdf-bridge.sty` implements the contract against tagpdf 1.0c private
structures. It is an experimental compatibility layer, not a supported public
interface. It is generated from `tagpax.dtx` and is not loaded by `tagpax.sty`.

The bridge currently supports standard PDF/PDF 2.0 roles and external MCRs. It
does not yet expose all StructElem properties, RoleMap creation, ClassMap data,
OBJR kids, or nested source namespaces.

## XObject lifecycle

The required order for each imported page Form is:

```text
allocate external stream
    -> StructParents key
create/import Form XObject with /StructParents <key>
    -> target Form object reference
create explicit StructElems
append MCRs using /Stm <target Form reference>
register MCID -> StructElem in external stream
commit ParentTree array
```

This order is important: a Form dictionary cannot reliably be amended after the
object has already been written.

## Upstream scope

A small generic API in tagpdf would also serve tagged graphics, reusable Forms,
and other importers. The implementation need not expose tagpdf's properties or
sequences; opaque structure and stream handles would be preferable.
