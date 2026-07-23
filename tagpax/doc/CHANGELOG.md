## 0.8.3-dev

- recreate a separate namespaced target for every source destination instead
  of redirecting all links to a page-level target;
- preserve and transform `XYZ`, `Fit`, `FitH`, `FitV`, `FitR`, `FitB`, `FitBH`
  and `FitBV` destination views;
- transform destination coordinates, FitR rectangles, annotation rectangles,
  and XYZ zoom values to the scaled imported page;
- account for `/Rotate` values 0, 90, 180 and 270, including the FitH/FitV and
  FitBH/FitBV view swap;
- validate destination views and arguments and verify precise XYZ targets in
  the live PDF roundtrip.

## 0.8.2-dev

- import URI and remote GoToR annotations with named or page targets;
- decode hexadecimal UTF-16BE PDF strings, fixing heading titles and Unicode
  file specifications;
- retain source OBJR associations in the IR and fix annotation object lookup;
- fix navigation depth comparisons and prevent navigation processing from
  clobbering the reserved page-stream key;
- write URI and GoToR actions through PDF management with valid tagged Link
  annotations and verify the generated PDF syntax with qpdf;
- avoid duplicate `/P` entries produced by the updated tagpdf serializer.
- split backend execution into reservation, page binding, and finalization so
  late annotation and Form object references can fill source-ordered kids;
- bind recreated annotations through `StructParent`, `OBJR`, and the central
  ParentTree to their original imported `Link` elements instead of creating
  synthetic replacement Link structures;
- include OBJR positions and annotation action kinds in semantic roundtrip
  comparison.

## 0.8.1-dev

- extract named and direct PDF destinations into the canonical IR;
- extract internal `Link`/`GoTo` annotations, including rectangle and source
  `OBJR` parent association;
- recreate internal links as scaled overlays targeting namespaced imported
  page destinations;
- add imported headings to the master table of contents and PDF outline;
- make `toc-depth`, `bookmark-depth`, and `heading-map` effective during import;
- update the private tagpdf bridge for the 2026 tagpdf structure internals.

## 0.8.0-dev
- Architecture baseline.
- Added architecture/project documentation.
- Added semantic `commands` documentation for the public TeX interface.
- Added a `luafunctions` list using `\DescribeLuaFunction`; avoids conflict with LuaTeX's `\luafunction` primitive.

## 0.7.2-dev

- make `\tagpaxextract` and `\tagpaxinclude` the consistently named public commands
- retain `\TagPaxExtract` as a deprecated compatibility alias

## 0.7.0-dev

- made the user manual bilingual from one tightly coupled `langselect` source;
- added German and English documentation drivers;
- documented the frozen Inspector → IR → Transformation → Backend-plan → Backend architecture;
- added initial architecture decision records;
- kept the developer manual and Lua API reference in English.

## 0.6.0-dev

- made the controlled LuaTeX importer the normative `\tagpaxinclude` path;
- retained `\tagpaxroundtripinclude` as a compatibility alias;
- removed the hard core dependency on `pdfpages`;
- added `tagpax-pdfpages.sty`, a restricted full-document compatibility
  frontend that routes through the native importer;
- clarified module boundaries and updated the manual and README.

## 0.5.1-dev

- Fixed expansion of MCID keys in the experimental ParentTree bridge.
- Roundtrip bridge now stores numeric property keys rather than literal `\int_eval:n` tokens.

## 0.5.0-dev (2026-07-15)

- Add controlled LuaTeX page Form-XObject importer with `/StructParents`.
- Add experimental `\tagpaxroundtripinclude` for complete page-stream documents.
- Wire the explicit-parent bridge to reconstructed nodes and external MCRs.
- Document the LuaTeX and roundtrip Lua interfaces.

## 0.4.2-dev

- Documented the public Lua modules, their function signatures, return values,
  invariants, the IR records, and the backend contract in the main manual.

## 0.4.1-dev 

- Prototyped live `/StructParents` injection for imported LuaTeX PDF-page resources.
- Confirmed that stack-based `tagpdf` structure creation is unsuitable for cloning
  external trees during `pdfpages` imports.
- Added `tagpax-backend.lua` as an experimental TeX-emission prototype; it is not
  activated by the user-level package.
- Kept the target-independent page/object stream import plan as the stable API.

## 0.4.0-dev — 2026-07-15

- Add explicit stream records to the semantic IR.
- Distinguish page content streams from MCRs with an explicit `/Stm`.
- Preserve source `StructParents`, subtype and source-object locator for nested
  streams without exposing PDF object numbers as semantic node identities.
- Add `tagpax-import.lua`, a target-independent reassembly planner.
- Add binding and unresolved-stream tests for page and nested Form XObjects.

## 0.3.0-dev

- Reorganized the repository for native `l3build` use.
- Added `build.lua` with LuaLaTeX-only regression configuration.
- Replaced the Bash test runner with `.lvt`/`.tlg` tests.
- Generate the tagged source fixture in the isolated test directory through
  `checkinit_hook()`.
- Removed generated test artifacts from the source tree.

## 0.2.0-dev

- Fixed IR parser collision between record type and `kind=node` fields.
- Added ParentTree-based source-page recovery for numeric MCID kids.
- Added explicit `stream=page|object` to MCR records.
- Preserved heading traversal order.
- Added IR validation.
- Added a two-page tagged regression document and automated test runner.


## 0.1.0
- Initial version
