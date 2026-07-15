# ADR 0004: Unwrap Document and create Part

A complete contribution PDF normally has a `Document` root. During proceedings
assembly this root is unwrapped and its children are attached below a new
`Part` in the master structure tree. Heading roles are preserved.
