Dieses Dokument enthält sowohl tatsächliche ToDos als auch längerfristige
Featurewünsche.

# osglecture + Ergänzungspakete
* [x] Integrationsworkflow
* [x] tagging bei presitemize und twocolumns
* [x] Windows bug
* [ ] Neue Pakete (tagbridge, tagtree) in README und CI aufnehmen, Kompatibilität ermitteln.

# ltthemer + Co
* [ ] Section/Title: Sollte wieder eingeführt werden.
* [ ] TUC-2019: teatching-Mode soll Section im Header führen. 
* [ ] TStandardtemplates für Titel (Prefix, Nummer), Seitenzahl, etc.

# Handout-Imposition (tagpax/OLLM), Stand 2026-09-16
* [ ] `ollm handout -pvc`: Der Viewer zeigt nach dem ersten (unimponierten)
  Kompilierlauf das flache 1x1-Ergebnis; die Imposition läuft erst nach
  `^C`, weil sie im Perl-Wrapper hinter dem blockierenden `system()`-Aufruf
  sitzt, der bei `-pvc` nie zurückkehrt. Möglicher Ansatz: `latexmk`s
  `$success_cmd`-Hook nutzen, um die Imposition nach jedem Rebuild-Zyklus
  mitlaufen zu lassen -- macht aber jeden Live-Rebuild langsamer, dazu
  hatte OLLM/Executor.pm keine geprüfte Lösung.
* [ ] `tikz`/`pgf` `fit=`, das einen Knoten aus einer *anderen*
  `tikzpicture` referenziert (typisch bei `remember picture`-Annotationen,
  z.\,B. `\markword`), bricht mit aktivem Tagging
  (`\DocumentMetadata{tagging=on}`) mit `Package tagpdf Error: there is
  no open structure on the stack` bzw. `...para hooks differ`. Reproduziert
  minimal mit reinem `article`, unabhängig von `ltx-talk`/Handout/Overlay --
  ein generelles `tikz`+`tagpdf`-Problem, nicht osglecture-spezifisch.
  `fit` *innerhalb derselben* `tikzpicture` sowie Querverweise *ohne* `fit`
  (`at (marke)`) funktionieren beide einwandfrei. Optionen: Workaround in
  `tagbridge` (analog zum bestehenden `qrcode`-Hook), oder upstream
  melden.
* [ ] `tagpax` übernimmt beim Extrahieren/Rekonstruieren nur die
  Rollennamen der Quellstruktur (z.\,B. `ltx-talk`s `frame`/`frametitle`),
  nicht deren `RoleMap`-Registrierung aus der Quell-PDF. Deshalb warnt
  `tagpdf` bei jedem `tagpaxinclude` einer Fremdstruktur mit unbekannten
  Rollennamen ("tag frame is not known") -- nicht fatal, aber massenhaft
  und PDF/UA-seitig unsauber (unbekannte Rolle statt korrektem Mapping auf
  einen Standardtyp). Lösung würde `tagpax-ir.lua` (RoleMap beim Extrahieren
  miterfassen) und die `tagpaxinclude`-Seite (per
  `\tagpdfsetup{role/new-tag=...}` vor dem Seitenimport registrieren)
  betreffen.
* [ ] `tagpax`s `layout=N on 1|notes` (echter `\Note`-Inhalt statt liniierter
  Leerfläche) ist weiterhin nicht implementiert -- siehe die Design-Notiz
  in `development-docs/tagpax/DESIGN.md` ("Note-space rendering behind
  imposition is deferred").
* [ ] `development-docs/tagpax/ARCHITECTURE.md` sagt unter "Scope" noch
  "The native path deliberately does not support ... imposition ...";
  das stimmt seit der `layout=`-Erweiterung nicht mehr und sollte
  aktualisiert werden.
* [ ] Für die neue `mode/handout`-Setup-Area (`layout`-Schlüssel,
  `osglecture.dtx`) fehlt noch ein regulärer l3build-Regressionstest nach
  dem Muster der bestehenden `continuation`-Setup-Area
  (`projectconfig-test.tex`-Konvention in `osglecture/testfiles/`) --
  bisher nur manuell verifiziert.

