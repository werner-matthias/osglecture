# OLLM runtime dependencies

## Required programs

OLLM currently expects these programs:

- Perl 5.30 or newer;
- `latexmk`;
- LuaLaTeX.

Run `ollm doctor` to see the executables and TOML parser selected by the
current installation. Use `ollm doctor --format=json` in automated checks.

## TOML parser

End users do not normally install a TOML module. OLLM includes the read-only
portion of `TOML::Tiny` 0.22 and loads it relative to the OLLM launcher:

```text
vendor/TOML-Tiny-0.22/lib/TOML/Tiny/Grammar.pm
vendor/TOML-Tiny-0.22/lib/TOML/Tiny/Parser.pm
vendor/TOML-Tiny-0.22/lib/TOML/Tiny/Tokenizer.pm
```

This parser supports TOML 1.0. The selected parser path only uses modules that
are part of Perl itself. OLLM does not use the TOML writer.

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
