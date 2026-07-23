# Status

Version: 0.8.3-dev

Implemented:
- Extractor
- Canonical IR
- Import planning
- Native importer
- Roundtrip
- Named destinations and internal GoTo link annotations
- URI and remote GoToR link annotations
- Master TOC and outline entries from imported headings

Internal destinations preserve their view type and transformed coordinates.
Reattachment of reconstructed annotations to the original imported `Link`
structure element is implemented.
