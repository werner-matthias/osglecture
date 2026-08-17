# Third-party components

## toml2lua

`osglecture-toml.lua` bundles the TOML 1.0 parser `toml2lua`, vendored
unchanged from the copy shipped with TeX Live 2026's `expltools` package
(`scripts/expltools/explcheck-toml.lua`, used there by `explcheck`):

- upstream project: <https://github.com/nexo-tech/toml2lua>
- upstream distribution as vendored: `explcheck-toml.lua` from
  `texmf-dist/scripts/expltools/` (TeX Live 2026)
- license: MIT (SPDX `MIT`); the full upstream license text is included as
  the file's header comment, unchanged
- copyright: 2017 Jonathan Stoler; 2025 Oleg Pustovit; 2020-2025
  Contributors (<https://github.com/nexo-tech/toml2lua>)

The file is stored unchanged as `osglecture-toml.lua`, renamed only so it is
findable via `require("osglecture-toml")` alongside the bundle's own Lua
modules; no code inside it was modified. Only `TOML.parse` is used by
`osglecture-manifest.lua`; the file's `TOML.encode` and
`TOML.parseToTestFormat` entry points are unused but left in place to keep
the vendored copy a faithful, diffable mirror of upstream.

**Rationale for vendoring a copy already present in a full TeX Live
install:** relying on `expltools`'s copy at its TeX Live path would tie
`osglecture` to a specific companion package's internal file layout, which
is not a stable public interface and is not guaranteed present in a minimal
installation. Vendoring, as `ollm` already does for `TOML::Tiny` (see
`ollm/THIRD_PARTY.md`), keeps the dependency self-contained and portable
under the same constraint: no dependency on anything beyond a normal TeX
Live install, and no dependency on another package's unversioned internals.
