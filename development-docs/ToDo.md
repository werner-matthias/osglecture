Dieses Dokument enthält sowohl tatsächliche ToDos als auch längerfristige
Featurewünsche.

# osglecture + Ergänzungspakete
* [x] Übergreifende Links
* [x] Querreferenzen zwischen Folien und Script
* [x] Kapitelübergreifende Literaturreferenzen
* [x] Lang-/Kurzformunterstützung auf Sprachebene
* [ ] Integrationsworkflow
* [ ] tagging bei presitemize und twocolumns
* [ ] Cat-code sichere Includes
* [ ] Windows-CI: `\LoadClass` in `osglecture.cls` (Laden der Basisklasse,
  z.B. `scrbook`) schlägt auf der Windows-Runner-TeX-Live-Installation
  weiterhin fehl (`ollm/testfiles/reference-lifecycle.t`s echter
  LuaLaTeX-Kompilierlauf), obwohl macOS und Linux fehlerfrei bleiben.
  Bestätigte Ursache: `\ExplSyntaxOn` setzt Leerzeichen auf Katcode~9
  (ignoriert); KOMA-Skripts intern gepatchte, nicht-expl3-Makros (etwa
  `\@pr@videpackage`) erwarten Leerzeichen als Trenntoken in ihren
  Parametermustern und brechen kaskadierend zusammen, wenn dieses Token
  fehlt. Mehrere Reparaturversuche mit zunehmend elementareren
  expl3-Bausteinen sind an Windows-spezifischen Eigenheiten gescheitert,
  die sich ohne echten Windows-Zugriff nicht mehr zuverlässig diagnostizieren
  ließen (`\cs_set:Npe` scheint auf dem Windows-Runner zu fehlen; ein
  `\ExplSyntaxOff`/`\ExplSyntaxOn`-Wechsel über eine `\edef`-Zwischenablage
  scheiterte aus unbekanntem Grund ebenfalls; `\LoadClass` innerhalb einer
  `\TeX`-Gruppe ist von LaTeX2e generell verboten). Der letzte lokal
  getestete Stand (`\char_set_catcode:nn {32}{10}` ungruppiert um
  `\exp_args:NV \LoadClass ...`, mit expliziter Wiederherstellung auf
  Katcode~9 danach) besteht alle 326 ollm- und 25 osglecture-Tests lokal
  (macOS), schlägt aber weiterhin in der Windows-CI fehl. Weitere Diagnose
  braucht echten Windows-Zugriff (siehe `development-docs/HISTORY.md` für
  den Kontext der laufenden OLLM/osglecture-Migration, während der der Bug
  auffiel).

# lttheme
* [ ] Unterstützung für innere Themes

# Ergänzungspakete
* [ ] ANSI-Terminal
* [ ] termexec
