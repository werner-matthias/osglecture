# Design decisions

These decisions describe the current design and the constraints behind it.
They replace the former duplicate ADR collection.

## Canonical IR is the semantic boundary

PDF objects are backend-specific, cyclic and tied to source object numbers.
The extractor therefore normalizes them into a small acyclic IR with local
IDs. All semantic validation and alternate planning operate on that IR.

Consequence: adding a supported PDF feature requires an explicit IR record or
field, validation, serialization and a reconstruction path. Backend modules
must not smuggle source object userdata through the IR.

## The native importer is authoritative

Whole-page linear import is the package's defined use case. The native LuaTeX
writer controls page Forms, scaling, destinations and annotations. The
migration option accepts the familiar `\includepdf[pages=-]` spelling but is
implemented entirely inside `tagpax`.

Consequence: no external page-import package or annotation sidecar is a
dependency, and unsupported selection or imposition options are rejected.

## Source MCIDs are retained

MCIDs are local to a content stream. Every copied page stream receives a fresh
target `StructParents` context, so renumbering would add complexity without
preventing collisions.

Consequence: the ParentTree mapping changes, but each MCR keeps its source
MCID. Explicit object streams need their own copied target stream and must not
be redirected to a page Form.

## Contribution Document roots become one Part

A complete contribution normally has a `Document` root. A master document
already owns its own `Document`, so nesting another one is semantically wrong.
The source `Document` is unwrapped and its ordered children are attached below
one synthetic `Part`.

Consequence: all other source roles, including heading levels, remain
unchanged. Navigation mapping is independent of structure-role rewriting.

## tagpax owns destination and annotation import

The package needs page geometry, destination namespaces, tagging association
and source OBJR order in one pipeline. Delegating annotations to a separate
sidecar importer would split those responsibilities and lose the original Link
ownership.

Consequence: supported actions are extracted into canonical IR and recreated
by the native writer. Unsupported actions fail validation rather than being
silently copied without tagging.

## Structure creation uses explicit parents

Normal `tagpdf` structure commands are stack-oriented and interact with
automatic paragraph/page structures in the master document. Imported structure
already has an explicit graph and must not disturb that stack.

Consequence: the bridge creates StructElems with explicit parents through a
small private compatibility layer. All dependence on private `tagpdf` names is
kept in the generated bridge.

## Child order is reserved before object references exist

Form and annotation object references are allocated while pages are written,
but their positions in source `/K` are known earlier. Appending them at shipout
would reorder mixed MCR, StructElem and OBJR children.

Consequence: the backend reserves ordered expandable slots, records object
references later, then lets `tagpdf` expand the slots during final
serialization. This is the reason for reserve/write/finalize execution.

## Destination geometry belongs to the page writer

The extractor knows source coordinates; only the page writer knows final Form
dimensions and rotation. Coordinate conversion anywhere else would duplicate
or guess layout state.

Consequence: destination records preserve source PDF parameters. The writer
applies one shared mapping to destinations and annotation rectangles.

## ParentTree ownership is singular

PDF permits one ParentTree below the StructTreeRoot. `tagpdf` already manages
the master tree and its next-key allocation.

Consequence: `tagpax` registers page-stream and annotation entries with
`tagpdf`; it never emits a parallel tree or guesses `ParentTreeNextKey`.
