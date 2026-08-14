# Contributing

Read `architecture.md`, `DESIGN.md`, `FORMATS.md` and `PDF-MODEL.md` before
changing extraction or backend behavior.

## Change discipline

- Preserve the canonical-IR boundary. Do not pass `pdfe` userdata or source
  object numbers into backend code.
- Add or change an IR field only together with serialization, parsing,
  validation and format documentation.
- Keep private `tagpdf` access inside the generated bridge section of
  `source/tagpax.dtx`.
- Preserve source child order across StructElem, MCR and OBJR records.
- Reject unresolved or unsupported semantics explicitly.
- Update `DESIGN.md` when a rationale or invariant changes; do not add a
  one-sentence ADR that duplicates existing documentation.
- Comment Lua code at the level of data transformations, ownership and PDF
  constraints, not by paraphrasing individual syntax.

## Verification

Run:

```sh
l3build check
l3build check -c roundtrip
l3build doc
qpdf --check ../build/test-roundtrip/roundtrip-master.pdf
git diff --check
```

Unit tests belong in `testfiles`. A change affecting generated PDF structure,
destinations or annotations also requires the live roundtrip test. When a
relevant validator is available in the environment, run it in addition to
`qpdf`.
