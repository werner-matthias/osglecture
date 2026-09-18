-- Isolates the test that depends on Babel's own autoload.bcp47 tag
-- resolution, which is incomplete on older Babel releases (see build.lua),
-- so its version-dependent outcome doesn't fail the default run.
excludetests = {}
includetests = { "bcp47-autoselect" }
