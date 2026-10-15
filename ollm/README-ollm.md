# OLLM

OLLM (OSG LaTeX Lecture Maker) is the build front end of the `osglecture`
bundle. It turns a lecture project into its requested document and language
variants and delegates the individual LaTeX runs to `latexmk`.

OLLM keeps generated artifacts below `.osglecture/build`, separate from the
source material. Projects are described in TOML, allowing targets, languages,
profiles, and deployment steps to be managed consistently across a complete
series of teaching materials.

For users migrating from OSGBeamer, OLLM can convert the former Perl-based
project configuration; the result should be reviewed afterwards.

See `ollm-en.pdf` or `ollm-de.pdf` for the English or German documentation.
