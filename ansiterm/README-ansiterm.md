# ansiterm

`ansiterm` provides terminal-window typesetting and reproducible, live shell
transcripts for LuaLaTeX.  The executable environment requires LuaLaTeX and
`--shell-escape`; the display-only environment does not execute anything.

```tex
\usepackage{ansiterm}

\begin{ansiterm}[title={A transcript}]
$ printf '\033[31mred\033[0m normal\n'
red normal
\end{ansiterm}

\begin{ansitermexec}[
  shell=/bin/sh,
  cache=true,
  sandbox=true,
  show-input=true,
  lines={1-8,12-}
]
printf '\033[1;32mHello from %s\033[0m\n' "$0"
uname -s
\end{ansitermexec}
```

Important `ansitermexec` keys are `shell`, `cache`, `sandbox`, `cwd`,
`show-input`, `prompt`, `lines`, `ellipsis`, and `fail-on-error`.  Cached
results live below `\jobname.ansiterm-cache`; use `cache=refresh` to replace
them.  `sandbox=false` runs in `cwd` (the document directory by default), so
commands may deliberately have persistent effects.

ANSI SGR attributes include the standard and bright 16-colour palettes,
256-colour and true-colour sequences, bold/faint, italic, underline, inverse,
conceal, and strikeout. Carriage returns and backspaces are resolved before
typesetting, which also makes many progress-style command outputs useful.

Shell commands are arbitrary code with the permissions of the TeX process.
Only compile trusted documents with `--shell-escape`.
