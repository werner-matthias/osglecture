# Minimal series configuration

This example is the bundle-level executable specification for project
configuration.  OLLM discovers `ollmconfig.toml` while invoked from the chapter
directory and resolves the bundle preset and targets from the installed bundle.

Project-wide TeX files live in `Include`. OLLM adds that directory to
`TEXINPUTS`, and `osglecture` loads `Include/projectconfig.tex` after the mode
graph and metadata interface are available. The directory and filename can be
changed through `[project.tex]` in `ollmconfig.toml`.

The document body is intentionally minimal.  Building it through the new
`osglecture` build-request interface will be added with that interface.
