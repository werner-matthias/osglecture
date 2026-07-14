# Changelog

## 0.3.2-dev — 2026-07-14

- Consolidated complete l3build development tree.
- Split external command support into process, qpdf, mutool, pdfcpu and veraPDF modules.
- Updated pdfcpu v0.13 syntax to `validate file.pdf --mode=strict`.
- Treat pdfcpu's PDF 2.0 `/AF` limitation as an explicit unsupported result.
- Included all tests and support fixtures in the development archive.

## 0.3.3-dev

- Replaced custom `structure` and `validate` targets with standard l3build configurations.
- Added `structure.lua` and `verapdf.lua` as l3build configurations.
- Added shared validation configuration support in `build-support/config-validation.lua`.
- Kept the default `l3build check` independent of external PDF validators.
