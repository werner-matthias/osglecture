Dieses Dokument enthält sowohl tatsächliche ToDos als auch längerfristige
Featurewünsche.

# osglecture + Ergänzungspakete
* [ ] Integrationsworkflow (Fallback auf ungetaggte Quell-PDFs über
  `pdfpages`/`newpax` ist umgesetzt, siehe `osglecture/README-cls.md`
  Abschnitt „Dokumentintegration"; offen bleiben u.a. `\includeunits` und die
  `...`-Bereichssyntax aus `DESIGN.md` §14.4)
* [ ] tagging bei presitemize und twocolumns
* [ ] Windows-CI: Der echte LuaLaTeX-Kompilierlauf in
  `ollm/testfiles/reference-lifecycle.t` bricht auf dem Windows-Runner an
  `\LoadClass` ab (`! Use of \@pr@videpackage doesn't match its
  definition.`), während macOS und Linux fehlerfrei bleiben.

  Die Fehlersignatur ist lokal byte-genau reproduziert, und sie bedeutet
  etwas anderes als ihr Name suggeriert: Sie entsteht, wenn `\@ifnextchar`
  mit **leerem erstem Argument** aufgerufen wird. Dann verschluckt
  `\let\reserved@d =` das unmittelbar folgende `\def` aus dem eigenen
  Makrorumpf, `\reserved@a` wird expandiert -- und das enthält noch als
  Altlast `\@pr@videpackage` aus dem letzten `\ProvidesPackage` (hier
  `osglecture-project.sty`, die letzte `Package:`-Zeile vor dem Abbruch).
  `\@pr@videpackage` und KOMA-Script sind an dem Fehler also unbeteiligt;
  die frühere Erklärung über Leerzeichen als Trenntoken in
  `\@pr@videpackage`s Parametermuster trifft nicht zu.

  Lokal ausgeschlossen: `\LoadClass{book}`/`{scrbook}` unter
  `\ExplSyntaxOn` (mit *und* ohne Katcode-10-Fenster), Tilde-Pfade
  (`RUNNER~1`) im Temp-Verzeichnis, nicht gelesenes Manifest bzw. nicht
  gelesene `projectconfig.tex` (tritt auf Windows tatsächlich auf, siehe
  Log, ist aber nicht die Ursache), leere oder verstümmelte
  Basisklassennamen, sämtliche Zeilenumbruchvarianten in
  `\ProvidesPackage`/`\ProvidesClass`.

  Offen bleibt der konkrete Aufrufer: Im Windows-Log wird vor dem Abbruch
  keine Klassendatei geöffnet, und im `\LoadClass`-Pfad ruft der Kernel
  `\@ifnextchar` ausschließlich mit literalem `[` auf. `\errorcontextlines`
  steht im Windows-Lauf auf 999, die Aufrufkette im aufbewahrten `.log`
  des Testartefakts zeigt den Aufrufer.


