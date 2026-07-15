# ADR 0003: Retain source MCIDs

MCIDs are local to a content stream. Every imported stream receives a new
`StructParents` context, so source MCIDs are retained rather than renumbered.
