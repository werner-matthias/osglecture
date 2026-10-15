# osgstyler

`osgstyler` provides reusable, template-based styles for LaTeX documents. It
keeps semantic choices in document code independent of the fonts, colours,
measurements, decorations, and inline rendering chosen by a visual theme.

Named palettes and portable roles make themes interchangeable across document
types. Ordered colour series support material whose colours distinguish data
or categories rather than semantic roles. Named decorations describe such
effects as lines, backgrounds, frames, margin marks, and affixes without
binding them to one particular way of rendering.

Inline styles combine these resources with semantic roles and can be attached
to familiar author commands. Optional integration connects styles to
`osglecture-modes`, `ltxtalk-theme`, and LuaLaTeX-based decoration rendering.

`osgstyler` is part of the `osglecture` bundle but can be used independently.
Its public interface is still pre-1.0 and may change before the first stable
release.

For the complete interface and examples, run `texdoc osgstyler`.
