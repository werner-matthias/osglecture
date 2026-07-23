# Canonical IR and plan formats

## Canonical IR

The canonical IR is the semantic boundary between PDF inspection and import.
It has two equivalent representations:

- a line-oriented `.tagpax` transport file;
- the indexed Lua table returned by `tagpax-ir.read`.

IR version 1 is current. Fields not listed here are not part of the format.

### Transport encoding

Each non-empty line contains a record name followed by tab-separated
`key=value` fields:

```text
record	key=value	key=value
```

Keys and record names are ASCII identifiers. Values are UTF-8 strings with
percent encoding for bytes outside `[A-Za-z0-9-._~]`. Field order is stable for
readable diffs but has no semantic meaning. Record order matters for `kid`,
`root`, `heading` and `annotation` records.

### In-memory indexes

```lua
{
  header       = record,
  source       = record,
  nodes        = { [node_id] = record },
  streams      = { [stream_id] = record },
  destinations = { [destination_id] = record },
  kids         = { record, ... },
  roots        = { record, ... },
  headings     = { record, ... },
  annotations  = {
    record, ...,
    [annotation_id] = record,
  },
}
```

Annotations intentionally have both an ordered array view and an ID index.
Callers iterating with `ipairs` see source page/annotation order.

### Records

#### `tagpax`

| Field | Required | Meaning |
| --- | --- | --- |
| `version` | yes | IR format version, currently `1` |
| `generator` | yes | extractor version for diagnostics |

#### `source`

| Field | Required | Meaning |
| --- | --- | --- |
| `file` | yes | source filename, informational after extraction |
| `pages` | yes | positive source page count |

#### `stream`

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | stable local ID (`pN` for pages, `sN` for objects) |
| `kind` | yes | `page` or `object` |
| `page` | page streams | one-based source page |
| `source-object` | object streams | extraction-only PDF object number |
| `structparents` | no | source value for diagnostics |
| `subtype` | no | source stream subtype |

`source-object` is never a target handle. Object streams require an explicit
target binding.

#### `node`

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | stable local StructElem ID |
| `role` | yes | source structure type without leading slash |
| `title` | no | decoded `/T` |
| `actualtext` | no | decoded `/ActualText` |
| `alt` | no | decoded `/Alt` |
| `lang` | no | decoded `/Lang` |

#### `kid`

| Field | Required | Meaning |
| --- | --- | --- |
| `parent` | yes | owning node ID |
| `index` | yes | one-based position in source `/K` |
| `kind` | yes | `node`, `mcr` or `objr` |
| `ref` | node/objr | child node ID or annotation ID |
| `page` | mcr | inferred source page |
| `stream` | mcr | stream ID |
| `mcid` | mcr | unchanged source MCID |

Mixed child kinds are sorted by `index`; this is the authoritative semantic
order.

#### `root`

| Field | Required | Meaning |
| --- | --- | --- |
| `index` | yes | source StructTreeRoot child position |
| `node` | yes | root node ID |

#### `heading`

| Field | Required | Meaning |
| --- | --- | --- |
| `node` | yes | heading node ID |
| `role` | yes | `H1` through `H6` |
| `page` | yes | first page reached by the subtree |
| `text` | no | navigation label |
| `source` | yes | `ActualText`, `T`, `Alt` or `missing` |

Heading records drive master TOC and outline creation; they do not change the
imported structure role.

#### `destination`

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | stable local destination ID |
| `name` | no | decoded source name |
| `page` | yes | one-based target source page |
| `view` | yes | `XYZ`, `Fit`, `FitH`, `FitV`, `FitR`, `FitB`, `FitBH`, `FitBV` |
| `arg1`…`arg4` | view-dependent | numeric destination parameters |

Arguments retain PDF order. For example, `XYZ` uses left, top, zoom; `FitR`
uses left, bottom, right, top.

#### `annotation`

Common fields:

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | stable local annotation ID |
| `page` | yes | one-based source page |
| `subtype` | yes | currently `Link` |
| `action` | yes | `GoTo`, `URI` or `GoToR` |
| `parent` | tagged links | source Link node owning the OBJR |
| `llx`, `lly`, `urx`, `ury` | yes | source rectangle |

Action fields:

| Action | Fields |
| --- | --- |
| `GoTo` | `destination` |
| `URI` | `uri` |
| `GoToR` named | `file`, `remote-destination` |
| `GoToR` page | `file`, `remote-page`, `remote-view` |

## Target-independent import plan

`tagpax-import.plan(ir, bindings, options)` is an optional planning API. The
active native backend emits directly from IR because object references become
available across multiple TeX phases, but the plan remains the stable format
for alternate backends and validation.

### Inputs

```lua
bindings = {
  pages = {
    [source_page_number] = opaque_target_form_handle,
  },
  streams = {
    [source_stream_id] = opaque_target_stream_handle,
  },
}

options = {
  wrapper_role = "Part",       -- default
  unwrap_document = true,      -- default
}
```

Handles are opaque. A planner must not assume PDF object-reference syntax.

### Output

```lua
{
  version = 1,
  wrapper_role = "Part",
  source_roots = { node_id, ... },
  imported_roots = { node_id, ... },

  nodes = {
    {
      source = node_id,
      role = role,
      title = optional_string,
      actualtext = optional_string,
      alt = optional_string,
      lang = optional_string,
    },
    ...
  },

  edges = {
    { parent = node_id, child = node_id, index = integer },
    ...
  },

  mcrs = {
    {
      parent = node_id_or_nil,
      wrapper_child = boolean,
      index = integer,
      mcid = integer,
      page = integer,
      stream = stream_id,
      handle = opaque_handle_or_nil,
    },
    ...
  },

  unresolved = {
    {
      kind = "page" | "object" | "unknown",
      stream = stream_id,
      page = integer,
      parent = node_id,
      mcid = integer,
    },
    ...
  },
}
```

The source `Document` node is omitted when unwrapping is enabled. Its node
children become `imported_roots`; an MCR directly owned by it is marked as a
`wrapper_child`. `assert_resolved(plan)` succeeds only when `unresolved` is
empty.

The current plan contains structure nodes, edges and MCR bindings. Annotation
and destination reconstruction is performed from canonical IR by the native
page writer because those records depend on final page geometry.

## TeX backend protocol

`tagpax-backend.lua` emits a private command stream consumed by the bridge:

### Reservation

```text
\TagPaxBackendDocumentBegin
\TagPaxBackendNode{source-id}{role}{source-parent-id}
\TagPaxBackendReserveMCR{serial}{page}{mcid}{stream}{parent}
\TagPaxBackendReserveOBJR{annotation-id}{parent}
```

### Page writing

```text
\TagPaxImportOnePage{pdf}{page}{stream-id}{ir}{import-prefix}
\TagPaxBackendForm{page}{form-object-ref}{stream-id}
```

### Binding/finalization

```text
\TagPaxBackendBindMCR{serial}{page}{mcid}{stream}{parent}
\TagPaxBackendDocumentEnd
```

This protocol is private and may change with `tagpdf`. Canonical IR and the
target-independent import plan are the intended backend-neutral boundaries.
