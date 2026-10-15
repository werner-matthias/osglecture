# ansiterm

`ansiterm` typesets terminal windows and reproducible shell transcripts in
LuaLaTeX documents. It understands common ANSI styling and terminal control
sequences, so captured command output retains the appearance and behaviour
needed for teaching material, manuals, and demonstrations.

The package supports both display-only terminal content and live command
execution. Executed transcripts can be cached and selectively displayed;
because they run arbitrary shell commands, this feature requires
`--shell-escape` and should only be used with trusted documents.

For the full interface and examples, run `texdoc ansiterm`.
