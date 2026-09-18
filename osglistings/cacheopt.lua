-- Isolates the minted option that only exists from a minted version newer
-- than the one bundled with older TeX Live releases (see build.lua), so its
-- version-dependent outcome doesn't fail the always-compatible default run.
excludetests = {}
includetests = { "package-options-cacheignoresfilecontents" }
