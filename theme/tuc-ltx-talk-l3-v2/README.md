# TU Chemnitz ltx-talk/beamer Theme

Korrigierte Fassung 0.3.2.

Wichtig: In `ltx-talk` für `\verb`, Listings und ähnliche fragile Inhalte `frame*` verwenden.

Die Fakultätsfarbe wird intern auf den stabilen xcolor-Namen `TUCFaculty` gemappt. Dadurch wird kein expl3-Tokenlistenname mehr direkt an `xcolor` übergeben.

```tex
\documentclass{ltx-talk}
\usepackage[faculty=etit,logo=tuc-logo-white.pdf]{tuc-ltx-talk}
```

Logo zur Laufzeit:

```tex
\tucsetlogo{tuc-logo-white.pdf}
```
