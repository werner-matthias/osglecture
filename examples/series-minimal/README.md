# Minimal series configuration

This example is the bundle-level executable specification for project
configuration.  OLLM discovers `ollmconfig.toml` while invoked from the chapter
directory and resolves the bundle preset and targets from the installed bundle.

Project-wide TeX files live in `Include`. OLLM adds that directory to
`TEXINPUTS`, and `osglecture` reads `Include/projectconfig.tex` through its
early declarative bootstrap. The directory and configuration filename can be
changed through `[project.tex]` in `ollmconfig.toml`.

The user-owned `Include/documentmetadata.tex` contains the actual
`\DocumentMetadata` call. Its filename is fixed; whenever the file exists,
OLLM places it before the main source and defines
`\OsgLectureRequestedLanguage` from the concrete build first.

The document body is intentionally minimal.  Building it through the new
`osglecture` build-request interface will be added with that interface.
