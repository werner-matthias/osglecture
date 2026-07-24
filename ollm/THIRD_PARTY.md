# Third-party components

## TOML::Tiny::Parser

OLLM bundles the parser-only portion of `TOML-Tiny` 0.22:

- upstream distribution: `TOML-Tiny-0.22`
- upstream project: <https://github.com/sysread/TOML-Tiny>
- CPAN page: <https://metacpan.org/release/OALDERS/TOML-Tiny-0.22>
- files: `Grammar.pm`, `Parser.pm`, and `Tokenizer.pm`
- license: the same terms as Perl 5, SPDX expression
  `Artistic-1.0-Perl OR GPL-1.0-or-later`

The files are stored unchanged below `vendor/TOML-Tiny-0.22/`. The upstream
`LICENSE` file is included there.

OLLM only decodes project manifests. It therefore does not bundle the writer
or its optional formatting support. The parser path used by OLLM depends only
on modules shipped with Perl itself.
