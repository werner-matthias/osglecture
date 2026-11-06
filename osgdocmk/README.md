# osgdocmk

`osgdocmk` (OSG Lecture Document Maker) is the build front end of the `osglecture`
bundle. It turns a lecture project into its requested document and language
variants and delegates the individual LaTeX runs to `latexmk`.

`osgdocmk` keeps generated artifacts below `.osglecture/build`, separate from the
source material. Projects are described in TOML, allowing targets, languages,
profiles, and deployment steps to be managed consistently across a complete
series of teaching materials.

For users migrating from OSGBeamer, `osgdocmk` can convert the former Perl-based
project configuration. The result should be reviewed afterwards.

Run `l3build doc` to generate the English (`osgdocmk-en.pdf`) or German (`osgdocmk-de.pdf`) documentation.
