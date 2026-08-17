# OLLM runtime dependencies

## Required programs

OLLM currently expects these programs:

- Perl 5.30 or newer;
- `latexmk`;
- LuaLaTeX.

Run `ollm doctor` to see the executables and TOML parser selected by the
current installation. Use `ollm doctor --format=json` in automated checks.
The Doctor also compiles a minimal LuaLaTeX document. Its JSON output keeps
optional capabilities separate from required runtime checks. In particular,
the `ltx-talk-adapter` capability checks `ltx-talk.cls` and the New Computer
Modern text and math fonts without making plain `osglecture-modes` unusable
when that optional stack is absent or too old. Failed checks name the relevant
TeX Live package and an appropriate `tlmgr install` command.

## TOML parsers

There are two TOML readers, for two different slices of the same manifest
(see `ARCHITECTURE.md` section 12), not two competing implementations of the
same content.

### OLLM (Perl)

End users do not normally install a TOML module. OLLM includes the read-only
portion of `TOML::Tiny` 0.22 and loads it relative to the OLLM launcher:

```text
vendor/TOML-Tiny-0.22/lib/TOML/Tiny/Grammar.pm
vendor/TOML-Tiny-0.22/lib/TOML/Tiny/Parser.pm
vendor/TOML-Tiny-0.22/lib/TOML/Tiny/Tokenizer.pm
```

This parser supports TOML 1.0. The selected parser path only uses modules that
are part of Perl itself. OLLM does not use the TOML writer. It reads only the
slice of the manifest needed to decide what to build (target, doctype,
language, and related registry lookups).

### Shared module (Lua)

Project content that isn't needed for the build decision itself -- series
structure, available languages, bundle-preset content -- is read by a shared
Lua module, callable both from a real compile (`\directlua`) and standalone
via `texlua`. It vendors its own pure-Lua TOML reader under the same
portability constraint as the Perl parser: no dependency on anything outside
what ships with a normal TeX Live install.

Both files live in the `osglecture` package, not in `ollm`, since
`osglecture` is their primary consumer:

- `osglecture/osglecture-manifest.lua`: manifest reading and the project-root
  discovery it needs (reusing `osglecture-series-index.lua`'s path
  utilities).
- `osglecture/osglecture-toml.lua`: the vendored TOML 1.0 reader; see
  `osglecture/THIRD_PARTY.md` for provenance and license.

OLLM does not call this module yet (see `HISTORY.md`); once it does,
`ollm doctor` will report name, version, and origin of both parsers, the
same way it already does for `TOML::Tiny`.

If the bundled files are missing, reinstalling OLLM is the preferred repair.
As a fallback, a full Perl installation can provide the upstream distribution:

```sh
cpanm TOML::Tiny
```

or:

```sh
cpan TOML::Tiny
```

The second command may ask how CPAN should install modules. Follow the Perl
installation's recommendation for a user-local installation when the
system-wide Perl directories are not writable.

On Windows, TeX Live contains a deliberately minimal private Perl. If it
cannot install or find the module, install a complete Perl distribution and
configure TeX Live to try the external Perl by adding this setting to the
appropriate `texmf.cnf`:

```text
TEXLIVE_WINDOWS_TRY_EXTERNAL_PERL = 1
```

This fallback is only relevant for an incomplete or deliberately unbundled
OLLM installation. A normal OLLM installation does not require CPAN access.

See [`THIRD_PARTY.md`](THIRD_PARTY.md) for provenance and licensing.
