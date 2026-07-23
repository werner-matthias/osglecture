# Changelog

## 0.8.3-dev

The current development release provides:

- canonical extraction of structure nodes, ordered node/MCR/OBJR children,
  streams, headings, destinations and supported Link annotations;
- native whole-document import using one tagged Form XObject per source page;
- explicit-parent structure reconstruction with retained MCIDs and central
  `tagpdf` ParentTree ownership;
- source-ordered annotation OBJRs bound to their original imported Link
  elements;
- `GoTo`, `URI` and `GoToR` annotation reconstruction;
- namespaced `XYZ`, `Fit`, `FitH`, `FitV`, `FitR`, `FitB`, `FitBH` and `FitBV`
  destinations with scale, MediaBox and rotation transformation;
- master TOC and bookmark generation from imported heading records;
- an opt-in `\includepdf` migration alias for the restricted `pages=-` case,
  with explicit conflict handling for the command's original provider;
- semantic extraction, validation, planning, geometry and PDF roundtrip tests.

Explicit nested source Form streams are represented and validated but are not
yet copied by the native page writer.
