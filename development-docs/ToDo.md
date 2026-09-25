Dieses Dokument enthält sowohl tatsächliche ToDos als auch längerfristige
Featurewünsche.

# osglecture + Ergänzungspakete
* [x] Integrationsworkflow
* [x] tagging bei presitemize und twocolumns
* [x] Windows bug
* [ ] Neue Pakete (tagbridge, tagtree) in README und CI aufnehmen, Kompatibilität ermitteln.

# ltthemer + Co
* [x] Section/Title: `\setltxtalkheadingbehavior{auto-section-title=true}`
  übernimmt Section/Subsection wieder als Frametitle (lttheme.dtx).
* [x] Kleinerer Folgefix (2026-09-26): Titel-zu-Subtitel-Demotion in
  `\frametitle` rendert bei gegebenem Folientext zwei Content-Slots
  (frametitle, framesubtitle) hintereinander; das dazwischenliegende
  `\par` konnte bei aktivem Tagging (`tagging=on`) tagpdfs automatischen
  Absatz-Tagging-Hook erneut auslösen (siehe
  `__ltxtalk_render_content_slots:n`s eigene Dokumentation zum exakt
  selben Mechanismus mit umgekehrter Ursache) -- reproduziert als
  `! Package tagpdf Error: ... para hooks differ`. Fix: gemeinsamer
  `tagpdfparaOff`-Wrap um beide Renderaufrufe (lttheme.dtx).
* [x] Tieferliegender Tagging-Bug gefunden und behoben (2026-09-26):
  `\__ltxtalk_render_slot:nnnnn` (Kopf-/Rand-/Fuß-Slots aller Themes,
  nicht nur TUC-2019) setzt seinen Inhalt immer über eine `\parbox`, die
  intern stets mit einem impliziten `\par` schließt. Für Rollen ohne
  automatisches Tagging (`navigation`, `artifact`, aber auch `note`/
  `heading`/`H1`-`H3`, die zwar ein echtes Struct bekommen, aber
  \emph{zusätzlich} den automatischen Absatz-Tagging-Hook unterdrücken
  müssen) reichte das bisherige `tagpdfparaOff` in
  `__ltxtalk_accessibility_artifact:n`/`__ltxtalk_accessibility_struct:nn`
  nicht: es steht in einer eigenen, lokalen Gruppe, die \emph{vor} dem
  impliziten `\par` der umschließenden `\parbox` schon wieder schließt.
  Fix: `tagpdfparaOff` jetzt in `\__ltxtalk_render_slot:nnnnn` selbst,
  \emph{vor} dem `\hcoffin_set:Nn`-Aufruf, für jede Rolle außer
  `content` -- ohne umschließende Gruppe (die würde den lokal gesetzten
  Koffer-Inhalt vor `\coffin_join:` verwerfen), stattdessen explizit mit
  `\tagpdfparaOn` danach aufgehoben. Per Bisektion abgesichert: ein
  Rollen-Filter, der nur `navigation`/`artifact` abschaltete (nicht aber
  `note`, wie es z.\,B. die TUC-2019-Kopfzeilenfelder `tuc-author`/
  `tuc-url` verwenden), reichte *nicht*.
* [ ] **Versucht, aber weiterhin zurückgezogen (2026-09-25/26, Update
  2026-09-26): TUC-2019 teaching-Mode soll Section im Header führen.**
  Mit dem oben behobenen `tagpdfparaOff`-Scoping-Bug verschwindet der
  Absturz in kleinen/isolierten Testfällen (auch einem eigens gebauten,
  mit dem realen Foliendeck bis Zeile 441 identischen Kurztest) und in
  einem synthetischen Drei-Abschnitte-Test vollständig -- im *realen*
  Kursskript (AuP/Script2/001-Intro, Foliendeck mit ~50 Seiten,
  `ollm build --target=slides`) bleibt derselbe
  `TeX capacity exceeded`-Absturz an derselben Stelle (Zeile 441)
  bestehen. Per Bisektion (Hook-Body schrittweise reduziert: leer -> nur
  `\bool_gset_true:N` -> zusätzlich `\tl_gset_eq:NN ... \l__talk_section_tl`)
  eindeutig auf das Kopieren des *echten, wechselnden*
  `\l__talk_section_tl`-Werts eingegrenzt -- ein Ersatz durch einen
  festen, nie wechselnden String derselben Länge löst den Absturz
  \emph{nicht} aus, ein synthetischer Dreifach-Abschnittswechsel mit
  schlankem Folieninhalt (ohne Bilder/TikZ/Listings/QR-Codes) ebenfalls
  nicht -- der Absturz braucht also sowohl den wechselnden Text als auch
  einen erheblichen Anteil der echten Dokumentkomplexität; welcher
  zusätzliche Faktor genau fehlt, ist nicht mehr eingegrenzt worden. Bis
  dahin bleibt `\__ltxtalk_tuc_teaching_header_section:` (Kopfzeile 2:
  `Lecturenummer.Sectionnummer Abschnittstitel`) zurückgenommen
  (`git checkout -- lttheme-tuc-2019/lttheme-tuc-2019.dtx`); `teaching`
  zeigt Kopfzeile 2 weiterhin unverändert den Lecturetitel. Für einen
  neuen Anlauf: den in dieser Sitzung gefundenen, oben behobenen
  `tagpdfparaOff`-Bug als bereits erledigt voraussetzen und direkt am
  realen Dokument (nicht an verkürzten Auszügen) weiter eingrenzen,
  z.\,B. mit `\tracingall`/gezieltem Herausschneiden von Foliengruppen
  aus einer Kopie von AuP/Script2/001-Intro/main.tex.
* [ ] TStandardtemplates für Titel (Prefix, Nummer), Seitenzahl, etc.

# Handout-Imposition (tagpax/OLLM), Stand 2026-09-16
* [ ] `ollm handout -pvc`: Der Viewer zeigt nach dem ersten (unimponierten)
  Kompilierlauf das flache 1x1-Ergebnis; die Imposition läuft erst nach
  `^C`, weil sie im Perl-Wrapper hinter dem blockierenden `system()`-Aufruf
  sitzt, der bei `-pvc` nie zurückkehrt. Möglicher Ansatz: `latexmk`s
  `$success_cmd`-Hook nutzen, um die Imposition nach jedem Rebuild-Zyklus
  mitlaufen zu lassen -- macht aber jeden Live-Rebuild langsamer, dazu
  hatte OLLM/Executor.pm keine geprüfte Lösung.
* [ ] **Korrigierte Diagnose (2026-09-22, war zuvor als `fit=`/
  `remember picture`-Problem beschrieben):** Ursache ist *nicht* `fit=`
  oder ein Querverweis auf einen Knoten aus einer anderen `tikzpicture`.
  Minimal reproduziert (mit reinem `\documentclass{osglecture}`,
  unabhängig von `ltx-talk`/Handout/Overlay): ein `itemize`-Punkt, gefolgt
  irgendwo im selben `frame` von *irgendeinem* `tikz`-Knoten mit
  `text width=` -- ganz ohne `remember picture`, `fit`, Querverweis oder
  `\markword` --, bricht mit aktivem Tagging
  (`\DocumentMetadata{tagging=on}`) mit `Package tagpdf Error: there is
  no open structure on the stack` bzw. `...para hooks differ`. `fit`
  setzt `text width`/`text height` intern immer, daher der ursprüngliche
  Verdacht. Mechanismus: schließt ein Absatz (z.\,B. ein `itemize`-Punkt)
  seinen echten \LaTeX-Absatz nicht sofort mit `\par`, sondern erst beim
  nächsten Absatzwechsel -- was passiert, wenn direkt danach ein
  `tikzpicture` mit `text width`-Knoten folgt, da dessen Aufbau selbst
  einen echten Absatz anstößt --, kann dieser Abschluss *innerhalb* des
  bereits von `latex-lab-testphase-tikz`s `\tag_suspend:n`/`\tag_resume:n`
  abgeschalteten `\pgfpicture` feuern. Diese Funktionen schalten Tagging
  aber nur *lokal* (gruppenbezogen) ab; der \LaTeX-Kern-Hook
  `\AddToHook{para/begin}`/`{para/end}` löst dann `\tag_struct_begin:n`/
  `\tag_struct_end:` unkoordiniert mit dem Auf-/Abbau-Zustand aus --
  daher der Stack- bzw. Zähler-Fehler. Ein Hook in `tagbridge`, der die
  vier internen Kern-Sockets (`para/semantic/begin`\slash`/end`,
  `para/textblock/begin`\slash`/end`) beim Suspend abfängt und
  auf-/abbaut, behebt den reinen "`Absatz + `text width`-Knoten"'-Fall
  zuverlässig -- versagt aber identisch (Patch greift gar nicht erst),
  sobald der auslösende Absatz seinerseits durch ein *eigenes* Inline-
  `\tikz`-Bild (wie `\markword`s `\tikz[remember picture,baseline]
  \node[anchor=text]{...}` als erster Punktinhalt) geöffnet wird --
  exakt osglectures/AuP's tatsächliches Nutzungsmuster. Der Patch wurde
  deshalb *nicht* übernommen (siehe verworfener Branch-Stand,
  nicht committet). **Workaround bis auf Weiteres:** `\markword`/
  ähnliche Inline-Marken nicht als *ersten* Inhalt eines `itemize`-Punkts
  setzen (in normalem Fließtext funktioniert es), bzw. auf `text width`
  setzende Schlüssel (inkl. `fit=`) auf Knoten verzichten, die einem
  solchen Punkt im selben `frame` folgen. Optionen für eine echte
  Lösung: die verbleibende Inline-Tikz-Interaktion weiter aufklären,
  oder das Ganze (mit den beiden Minimalbeispielen) upstream bei
  `tagpdf`/`latex-lab` melden -- es ist ein generelles
  `tikz`+`tagpdf`-Problem, nicht osglecture-spezifisch.
* [x] `tagpax`: Rollenregistrierung beim Import.
* [ ] Für die neue `mode/handout`-Setup-Area (`layout`-Schlüssel,
  `osglecture.dtx`) fehlt noch ein regulärer l3build-Regressionstest nach
  dem Muster der bestehenden `continuation`-Setup-Area
  (`projectconfig-test.tex`-Konvention in `osglecture/testfiles/`) --
  bisher nur manuell verifiziert.

