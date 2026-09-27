Dieses Dokument enthält sowohl tatsächliche ToDos als auch längerfristige
Featurewünsche.

# osglecture + Ergänzungspakete
* [x] Integrationsworkflow
* [x] tagging bei presitemize und twocolumns
* [x] Windows bug
* [ ] Neue Pakete (tagbridge, tagtree) in README und CI aufnehmen, Kompatibilität ermitteln.
* [x] Bug gefunden und behoben (2026-09-27): `\only<N>` (reines
  Overlay-Atom, z.\,B. `\only<4>`) zeigte unter `\documentclass{osglecture}`
  seinen Inhalt auf \emph{jeder} Folie des umgebenden `frame` und die
  Gesamtfolienzahl blieb auf den von `\item`-Overlays bestimmten Wert
  begrenzt -- reproduziert am realen Kursskript
  (`AuP/Script2/001-Intro/main.tex`, Folie "`Warum überhaupt?"'): drei statt
  sechs Folien, `\only<4>`-Inhalt auf allen dreien sichtbar, `\only<5>`
  (Bild) und `\only<6>` nie. Trat sowohl unter `profile=ltx-talk` als auch
  `profile=beamer` auf; der ursprüngliche Verdacht auf einen
  Mode-Scanner-Bug (siehe `osglecture-modes-lua-scan.md`) bestätigte sich
  \emph{nicht} -- eigenständige Ursache, anderer Mechanismus.
  **Ursache** (`osglecture-modes.dtx`): `\g_osglecture_modes_native_alt_bool`
  (merkt sich, ob ein natives `\alt` fürs Overlay-Backend existiert; steuert
  `\MakeOverlayAwareCommand`s Weiche zwischen echtem `\alt<spec>{...}{...}`
  und dem `flatten`-Fallback, der jede native Spezifikation kommentarlos
  \emph{immer} zeigt) wurde \emph{sofort} beim Laden von
  `osglecture-modes` per `\cs_if_exist_p:N \alt` erfasst -- nicht erst im
  verzögerten `overlays`-Baustein
  (`\__osglecture_modes_patch_overlays:`/`\LectureModesActivateOverlays`).
  `osglecture.cls` bindet `osglecture-modes` aber bewusst mit
  `deferred=true` \emph{vor} `\LoadClass` der Backend-Klasse ein (damit der
  eigentliche Overlay-Patch erst nach deren `\LoadClass` läuft) -- an der
  sofortigen Erfassungsstelle existierte das backend-eigene `\alt`
  (beamer/ltx-talk) deshalb noch gar nicht, die Variable blieb für das
  gesamte Dokument dauerhaft `false`, obwohl `\alt` längst geladen war.
  Ergebnis: jeder mit `\MakeOverlayAwareCommand` gepatchte Befehl (`\only`
  eingeschlossen) nahm für jede native Overlayspezifikation den
  `flatten`-Fallback statt des echten Backends -- Inhalt erscheint
  bedingungslos, das Backend erfährt nie von der referenzierten
  Foliennummer.
  **Fix:** Erfassung in den `overlays`-Baustein verschoben (läuft nach
  `\LoadClass`, weiterhin vor der dort definierten portablen
  `\alt`-Rückfalldefinition, damit die Prüfung nicht deren rein portable
  Fassung fälschlich für ein natives Urteil hält). Bare
  `\usepackage{osglecture-modes}` \emph{nach} `\documentclass{beamer|ltx-talk}`
  (der bisher einzige getestete Fall) ist unverändert korrekt, da `\alt`
  dort auch beim alten, sofortigen Zeitpunkt schon existierte. Alle 16
  bestehenden Tests weiterhin grün; am realen Kursskript bestätigt (per
  `ollm build slides` neu gebaut: Folie "`Warum überhaupt?"' jetzt korrekt
  6 Folien, `KI-Fehler.png` erscheint genau einmal auf der richtigen).
  **Offen:** kein dedizierter Regressionstest in
  `osglecture-modes/testfiles/` nachgereicht -- der Bug braucht exakt das
  Ladereihenfolgemuster von `osglecture.cls` (`deferred=true` \emph{vor}
  `\LoadClass`), das sich in einer eigenständigen `.lvt`-Datei nur über
  einen händisch nachgebauten Fake-Backend-`\alt` nachstellen lässt; ein
  erster Versuch dazu funktionierte inhaltlich (`ALT-CALLED-WITH=4`
  bestätigt den Fix), erzeugte aber einen harmlosen, ungeklärten
  `Missing \begin{document}`-Fehler beim manuellen Aufruf von
  `\LectureModesActivateOverlays` in der Präambel unter
  `\documentclass{article}` (Ursache nicht gefunden: mutmaßlich existiert
  `\mode` dort bereits aus unbekannter Quelle, sodass der
  `\cs_if_exist:NTF \mode`-Zweig in `osglecture-modes-overlays.code.tex`
  einen für diesen Kontext ungeeigneten Pfad nimmt). Sauberer wäre ein
  Test in `osglecture/testfiles/` gegen die echte Klasse
  (`\documentclass[standalone,profile=ltx-talk|beamer]{osglecture}` mit
  echtem `frame`+`\only<N>`, Auswertung z.\,B. über `\arabic{page}` in den
  `\TYPE`-Ausgaben, um unterschiedliche vs. identische Folienzahlen zu
  unterscheiden).

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
* [x] **Bug strukturell behoben (2026-09-26): dynamischer Text in einem
  Header-/Rand-/Fuß-Slot + `tagging=on` + ausreichend Dokumentumfang
  stürzte mit `TeX capacity exceeded [input stack size=10000]` ab.**
  Wahrer Auslöser (nach weiterer Eingrenzung, siehe unten): die
  Schalterform `\mode<name>` engagiert `osglecture-modes`' eigenen,
  rekursiven TeX-Level-Scanner (`\osglecture_modes_scan:`), der unter
  LuaTeX jetzt durch einen flachen Lua-`while`-Loop ersetzt ist (kein
  TeX-Eingabestapel-Verbrauch mehr pro gescanntem/verworfenem Token).
  Details, Vorgehen und ein dabei zusätzlich gefundener, unabhängiger
  Scanner-Bug (TeX-Pfad, weiterhin offen für pdfTeX/XeTeX) in
  `development-docs/osglecture-modes-lua-scan.md`. Alle 15 bestehenden
  `osglecture-modes`-Tests grün; die exakte Minimalreproduktion des
  Original-Crashs (braucht offenbar die volle Kombination aus
  Tagging + dynamischem Header-Slot + Realdokumentumfang, siehe unten)
  wurde nicht gefunden. **Am realen Kursskript bestätigt (2026-09-26):
  AuP/Script2/001-Intro baut mit dem installierten, neuen
  `osglecture-modes` vollständig durch, kein `TeX capacity
  exceeded`-Absturz mehr.** Ursprünglich an
  einer neuen TUC-2019-`teaching`-Funktion entdeckt (Kopfzeile 2 sollte
  `Lecturenummer.Sectionnummer Abschnittstitel` zeigen, sobald eine
  `\section` läuft, statt konstant den Lecturetitel). Mit dem oben
  behobenen `tagpdfparaOff`-Scoping-Bug verschwindet der Absturz in
  kleinen/isolierten Testfällen (auch einem eigens gebauten, mit dem
  realen Foliendeck bis Zeile 441 identischen Kurztest) und in einem
  synthetischen Drei-Abschnitte-Test vollständig -- im *realen*
  Kursskript (AuP/Script2/001-Intro, Foliendeck mit ~50 Seiten,
  `ollm build --target=slides`) bleibt derselbe Absturz an derselben
  Stelle (Zeile 441) bestehen. Per Bisektion (Hook-Body schrittweise
  reduziert: leer -> nur `\bool_gset_true:N` -> zusätzlich
  `\tl_gset_eq:NN ... \l__talk_section_tl`) eindeutig auf das Kopieren
  des *echten, wechselnden* `\l__talk_section_tl`-Werts eingegrenzt --
  ein Ersatz durch einen festen, nie wechselnden String derselben Länge
  löst den Absturz \emph{nicht} aus, ein synthetischer
  Dreifach-Abschnittswechsel mit schlankem Folieninhalt (ohne
  Bilder/TikZ/Listings/QR-Codes) ebenfalls nicht -- der Absturz braucht
  also sowohl den wechselnden Text als auch einen erheblichen Anteil der
  echten Dokumentkomplexität; welcher zusätzliche Faktor genau fehlt,
  ist nicht eingegrenzt.

  **Wichtiger Fund:** Es ist kein TUC-2019-Problem. `\settucthemeheader{section}`
  -- ltx-talks/lthemes eigener, unveränderter Bestandsmechanismus, der
  ebenfalls pro Folie wechselnden Abschnittstext im Header zeigt --
  stürzt mit demselben Realdokument identisch ab (dieselbe
  `Relation is not allowed!`-Vorstufe auf derselben Zeile, nur ein
  anderer finaler Auslöse-Primitive: `\box_gset_to_last:N` statt
  `\g__para_standard_everypar_tl`). Vermutlich wurde das noch nie mit
  `tagging=on` an einem so umfangreichen Dokument getestet. Der
  ursprüngliche Lösungsansatz (Section-in-Header als Artefakt markieren,
  wenn die Section zusätzlich im Fließtext auftaucht, sonst den
  "nativen" ltx-talk-Mechanismus nutzen) geht daher am Kern vorbei -- der
  native Mechanismus selbst ist betroffen.

  Status (2026-09-26 aktualisiert): Ursache behoben und am Realdokument
  bestätigt (siehe oben). Section-in-Header (TUC-2019-`teaching`,
  Kopfzeile 2) ist jetzt wieder ein offener Punkt für einen neuen Anlauf
  -- siehe eigener Eintrag unten.
* [x] **Section-in-Header für `teaching` neu aufgesetzt (2026-09-26), am
  realen Dokument bestätigt -- inklusive Kopfzeilen-Layout-Korrektur und
  eines echten, unabhängigen `osglecture-modes`-Bugs, der dabei gefunden
  wurde:**

  **Layout (Nutzer-Feedback nach erstem Rollout):** Zeile~1 (nach dem
  Trennstrich im Zweizeilenmodus) zeigt jetzt \emph{immer} den
  Lecturenamen (unverändert `Vorlesungsnummer. Einheitstitel`, wie
  schon vor diesem Auftrag), unabhängig vom Abschnittsstatus; Zeile~2
  (vormals die Subsection-Zeile) zeigt `Lecturenummer.Sectionnummer
  Abschnittstitel` (über `\thesection`, das `osglecture` bereits als
  `Kapitel.Abschnitt` definiert), sobald eine `\section` gelaufen ist,
  sonst weiterhin die Subsection-Metadaten wie zuvor
  (`lttheme-tuc-2019.dtx`: `\__ltxtalk_tuc_teaching_unit_title:` für die
  obere, `\__ltxtalk_tuc_teaching_section_line:` für die untere Zeile;
  der erste Rollout hatte beides fälschlich in eine einzige,
  umschaltende Zeile gemischt). `\__ltxtalk_tuc_if_section_active:TF`
  liest weiterhin direkt `\l__talk_section_tl` -- bewusst \emph{nicht}
  über `\LTXTalkMetadata{section}`/`\insertsection`, das ein reiner
  Beamer-Befehl ist und ohne Beamer nicht existiert, `teaching` aber
  auch im Artikel-/Skriptmodus funktionieren soll.

  **Echter, unabhängiger Bug gefunden und behoben (`osglecture-modes.dtx`):**
  Nutzer-Report: nach `\mode<presentation>` (Schalterform, kein
  Inhaltsargument) folgte in der nächsten Zeile ein `\section`-Makro,
  dessen Argument wurde inkorrekt übernommen -- verschwand mit einer
  zusätzlichen Leerzeile dazwischen. Ursache:
  `\osglecture_modes_keep_mode:` (der Scanner-Handler, der ein
  gescanntes `\mode` wieder auslöst) hatte bedingungslos die Signatur
  `{ d<> +m }` -- als griffe \emph{jedes} `\mode<name>` immer ein
  Inhaltsargument. Bei der Schalterform (kein `{...}` danach) grabschte
  sich `+m` blind das \emph{nächste} Token im Dokument -- typischerweise
  den folgenden Befehl selbst (hier `\section`) -- und führte es als
  "'Inhalt"' aus, \emph{bevor} dieser seine eigene, echte
  Titel-Klammer erreichte; die Klammer landete stattdessen auf dem
  nächsten, danach im \emph{eigenen} Makrokörper von
  `\osglecture_modes_keep_mode:` folgenden Token (dasselbe
  Bugmuster wie das in `development-docs/osglecture-modes-lua-scan.md`,
  Abschnitt~9.2, dokumentierte in `\osglecture_modes_skip_environment:n`).
  Fix: `\osglecture_modes_keep_mode:` spiegelt jetzt exakt die eigene
  Weiche des echten `\mode`-Befehls (Signatur `{ s d<> }`, per
  `\peek_meaning:NTF \c_group_begin_token` prüfen, ob überhaupt eine
  Klammergruppe folgt, bevor \code{+m}-artig danach gegriffen wird; ohne
  folgende Gruppe direkt `\osglecture_modes_switch:n` aufrufen, das
  bereits selbst fürs Weiterscannen sorgt). Neuer Regressionstest
  `osglecture-modes/testfiles/ltxtalk-mode-then-section.lvt` (gegen den
  unbehobenen Stand verifiziert: schlägt dort mit sichtbarer
  Zeichen-Korruption fehl). Alle jetzt 16 `osglecture-modes`-Tests grün.

  **Update (2026-09-26, selber Tag): doch kein separater Bug --
  `auto-section-title` als Default für `teaching` wieder aktiviert.**
  Der oben beschriebene `TeX capacity exceeded`-Absturz war per
  Bisektion eindeutig auf die Frametitle-Demotion-Mechanik eingegrenzt
  worden, unabhängig vom Folieninhalt (auch eine triviale Folie ohne
  Bilder/Farbbefehle stürzte ab) -- die eigentliche Ursache blieb damals
  aber ungefunden. Nach dem Fund und Fix des
  `\osglecture_modes_keep_mode:`-Arguments-Korruptionsbugs (siehe oben)
  lag der Verdacht nahe, dass \emph{das} die wahre Ursache war: die
  Bisektion hatte `\mode<presentation>` + darauffolgende `\section`-Aufrufe
  im Testkontext, genau das Muster, das den Bug auslöst -- eine
  korrumpierte `\section`-Kopie hätte über
  `\g__ltxtalk_pending_heading_title_tl` direkt in die demotierte
  Frametitle und damit in hyperrefs Bookmark-Erzeugung geflossen sein
  können. Erneut mit dem Fix installiert getestet: `auto-section-title`
  wieder als Default für `teaching` aktiviert
  (`lttheme.dtx`/`lttheme-tuc-2019.dtx`, dieselbe "explicit"-Flag-Logik
  wie zuvor), am vollständigen Realdokument gebaut -- **kein Absturz, 51
  Seiten, Frametitle zeigt korrekt den Abschnittstitel, ursprünglicher
  Folientitel demotiert zum Subtitel** (z.\,B. Folie "Organisatorisches"
  / Subtitle "Gestatten: Norma Normstudent"). Damit bestätigt: beide
  Teile des ursprünglichen Auftrags sind jetzt aktiv und funktionieren
  auf dem realen Dokument. `lttheme-tuc-2019/testfiles/teaching-lecture-number.lvt`
  wieder auf `auto-section-title-default:passed` aktualisiert. Alle 20
  `lttheme`- und alle 4 `lttheme-tuc-2019`-Tests grün.

  **Update (2026-09-26, noch selber Tag): Nummerierung differenziert --
  Content-Teil schlicht, Header zusammengesetzt.** Nutzerwunsch: die
  demotierte Frametitle (Content-Teil) soll eine \emph{einfache}
  Abschnittsnummer als Prefix bekommen (z.\,B. \enquote{3
  Organisatorisches}), die Kopfzeile weiterhin
  \enquote{Lecturenummer.Sectionnummer} (z.\,B. \enquote{0.3
  Organisatorisches}). Umgesetzt in zwei getrennten Stellen, bewusst
  \emph{ohne} `\thesection` zu verwenden (das `osglecture` global auf
  \enquote{Kapitel.Abschnitt} umdefiniert, in der Praxis aber wegen der
  von `\thechapter` unabhängigen `\OsgLectureDeploymentChapter`-Anzeige
  oft nur die bloße Zahl liefert -- s.\,u.):
  - `lttheme.dtx`, `\AddToHook{section/begin}`/`{subsection/begin}`
    (Frametitle-Demotion): Prefix jetzt `\c@section` bzw.
    `section.subsection` (via `\int_use:N`), direkt vor den
    unveränderten Abschnittstitel gesetzt (`\tl_gput_right:NV`, erhält
    Formatierung im Titel).
  - `lttheme-tuc-2019.dtx`, `\__ltxtalk_tuc_teaching_section_line:`
    (Kopfzeile): Prefix jetzt explizit aus
    `\__ltxtalk_tuc_lecture_number:` (dieselbe Quelle wie die
    Lecture-Nummer in der Zeile darüber) + `.` + `\int_use:N \c@section`
    zusammengesetzt, \emph{nicht} mehr über `\thesection`.
  - **Nebenbefund:** `\thesection` liefert in der realen Deployment
    hier tatsächlich nur die bloße Zahl (kein Kapitel-Prefix) --
    `\OsgLectureDeploymentChapter` schreibt die Lecture-Nummer in
    `\g__osglecture_deployment_chapter_tl`, eine von `\thechapter`
    \emph{unabhängige} Anzeige-Zeichenkette; `\thechapter`/`\thesection`
    selbst bleiben davon unberührt. Nicht weiter verfolgt, da beide
    Stellen jetzt ohnehin ohne `\thesection` auskommen.
  - **Wiederholter Tilde-Bug:** derselbe \enquote{aktive Tilde nach einer
    Zahl verschwindet still} wie beim Kopfzeilen-Fix trat \emph{erneut}
    auf, diesmal in `lttheme.dtx`s `\tl_gset:Nx`-Kontext (Tilde landete
    als Nichts in der getaggten PDF-Bookmark-/Struktur-Titel-Zeichenkette).
    Wieder mit `\c_space_tl` statt `~` behoben.
  - Test `lttheme/testfiles/auto-section-title.lvt`: die drei betroffenen
    `\CHECKTITLE{...}`-Erwartungen um die jetzt korrekten Nummern-Prefixe
    ergänzt (`2 Erster Abschnitt`, `3.1 Ein Unterabschnitt`, `4 Titel und
    Subtitel zugleich`) -- bewusst mit echten Leerzeichen, nicht `~`,
    sonst schlägt der `\str_if_eq:ee`-Vergleich fehl (dieselbe
    Tilde-vs-Leerzeichen-unter-e-Expansion-Falle wie beim
    `teaching-lecture-number.lvt`-Fix zuvor).
  - Am vollständigen Realdokument bestätigt: Kopfzeile zeigt
    \enquote{0.3 Organisatorisches}, Folientitel zeigt \enquote{3
    Organisatorisches} (mit \enquote{Gestatten: Norma Normstudent} als
    Subtitel); kein Absturz, 51 Seiten. Alle 20 `lttheme`- und alle 4
    `lttheme-tuc-2019`-Tests grün.

  **Update (2026-09-26, noch selber Tag): Nummerierung/demotierter Titel
  fehlte auf Folgeseiten mehrseitiger Folien (Overlays/`\pause`) --
  behoben.** `\frametitle` läuft bei Overlays/`\pause` pro Folienschritt
  erneut (Standardverhalten von `ltx-talk`, nicht neu); das
  "vorgemerkt"-Flag der Section-Title-Demotion war aber nur beim
  \emph{ersten} Durchlauf aktiv -- ab Folienschritt~2 fiel `\frametitle`
  auf normales, undemotiertes Verhalten zurück und überschrieb den
  demotierten Titel mit dem ursprünglich gegebenen Text (der Subtitel
  ging dabei ganz verloren). Fix (`lttheme.dtx`): neuer Merker
  `\g__ltxtalk_auto_title_frame_int` (spiegelt exakt das Muster, das
  `\g__ltxtalk_auto_subtitle_frame_int` bereits für einen benachbarten
  Zweck nutzte) -- merkt sich, für welche Foliennummer die Demotion
  zuletzt griff, und wendet sie bei jedem weiteren `\frametitle`-Aufruf
  \emph{derselben} Folie erneut an, statt nur beim ersten. Die
  gemeinsame Anwendungslogik wurde dafür in
  `\__ltxtalk_apply_auto_title:n` ausgelagert. Dabei erneut derselbe
  Tilde-Bug wie oben angetroffen -- war hier gar nicht relevant (schon
  vorher `\c_space_tl`). Neuer Regressionstest in
  `lttheme/testfiles/auto-section-title.lvt` (dreiseitige Folie mit
  zwei `\pause`, Titel-/Subtitel-Check vor und nach jedem `\pause`).
  Alle 20 `lttheme`-Tests grün.

  **Update (2026-09-26, noch selber Tag): `\contframetitle` implementiert.**
  Rechercheergebnis vorab (siehe Chat): weder `ltx-talk` (das eigene
  `auto-break`/`auto-break-coverage` ist reine Inhalts-Seitenaufteilung,
  rührt die Überschrift gar nicht an) noch `osglecture`/`lttheme` hatten
  eine bestehende \enquote{(cont.)}-Konvention -- Neuland, keine
  Kollision. Umgesetzt in `lttheme.dtx` (generische Ebene, also
  themenunabhängig verfügbar):
  - `\contframetitle` (Signatur `D <> {all} O {}`, \emph{kein}
    Pflichtargument -- anders als `\frametitle` braucht die Überschrift
    ja nie neu eingetippt zu werden) wiederholt die zuletzt von
    `\section`/`\subsection` gemerkte, numerierte Überschrift mit
    angehängtem, sprachabhängigem Suffix (`\languagename`-Check wie
    schon in `lttheme-tuc-2019.dtx`s Logo-Auswahl: \enquote{(cont.)} bei
    Englisch, sonst \enquote{(Forts.)}). Optionales
    `\contframetitle`\oarg{Subtitel} (eckige, nicht geschweifte
    Klammern) setzt zusätzlich einen Subtitel.
  - Bewusst \emph{unabhängig} vom `auto-section-title`-Schalter: die
    zugrundeliegende Merker-Variable
    (`\g__ltxtalk_pending_heading_title_tl`) wird jetzt in
    `\AddToHook{section/begin}`/`{subsection/begin}` immer aktualisiert,
    nur das \emph{automatische} Verbrauchen durch `\frametitle` bleibt
    hinter dem Schalter -- `\contframetitle` ist ja ein bewusster,
    expliziter Aufruf.
  - Gemeinsame Render-Logik (Slot-Rendering inkl.\ `tagpdfparaOff`-Hülle)
    aus `\frametitle`s Demotions-Pfad nach `\__ltxtalk_apply_frame_heading:Nn`
    ausgelagert, von beiden Aufrufern genutzt -- keine dritte Kopie des
    tagpdf-kritischen Codes.
  - **Gefundener Fehler beim ersten Implementierungsversuch:** die
    Signatur hatte zunächst ein Pflichtargument (`O{#3} m`, kopiert von
    `\frametitle`). Beim bloßen `\contframetitle` (ohne Argument) griff
    sich xparse dann blind das nächste Token aus dem folgenden
    Fließtext als \enquote{Pflichtargument} -- sichtbar als ein
    einzelner, vom Rest des Wortes abgetrennter Buchstabe auf der Folie
    (\enquote{Z\textbackslash nweiter Teil...} statt \enquote{Zweiter
    Teil...}). Behoben durch rein optionale Signatur (`O{}`, kein `m`).
  - Neue Testfälle in `lttheme/testfiles/auto-section-title.lvt`:
    mehrseitige Folie mit zwei `\pause` (Persistenz-Fix, separat oben
    dokumentiert) sowie ein eigener Abschnitt mit
    \emph{ausgeschaltetem} `auto-section-title`, der `\contframetitle`
    bare und mit `[Subtitel]` prüft (Unabhängigkeit vom Schalter). Alle
    20 `lttheme`-Tests grün; am realen Kursskript ohne Regressionen
    gebaut.

  **Wichtige Methodik-Lektion:** Eine erste, schnelle Kurzfassung des
  Realdokuments (Zeilen 1--422, an `\end{frame}` abgeschnitten) erzeugte
  scheinbar denselben `auto-section-title`-Absturz \emph{und
  zusätzlich} eine bizarre Kopfzeilen-Korruption (der Abschnittstitel
  erschien im PDF wörtlich als `\bool_gset_false:N`). Das erwies sich
  als **Artefakt einer unbalancierten Klammer**: Zeile 406 im Original
  ist `\mode<presentation>{` (Inhaltsform mit Klammer, nicht die
  scanner-auslösende Schalterform!), und die zugehörige schließende
  Klammer steht erst auf Zeile 771 -- die Kurzfassung schnitt genau
  dazwischen ab und ließ die Gruppe offen. Eine korrekt bis Zeile 771
  reichende, klammerbalancierte Kurzfassung baute anstandslos durch (39
  Seiten, korrekte Kopfzeile) -- \emph{und} zeigte damit fälschlich, dass
  die "'Korruption"' kein echtes Problem sei. **Tatsächlich war die
  Korruption ein zweiter, echter, unabhängiger Bug** (siehe oben,
  `osglecture_modes_keep_mode:`) -- nur eben \emph{nicht} durch diese
  spezielle unbalancierte Kurzfassung ausgelöst, sondern durch das
  reale, vom Nutzer separat gemeldete `\mode<presentation>`-dann-`\section`-
  ohne-Trennung-Muster an einer \emph{anderen} Stelle im Dokument. Auch
  die anschließende Live-Debug-Sitzung (Lua-seitige
  `texio.write_nl`/`\message`-Traces direkt in `osglecture-modes.dtx`)
  lief zeitweise ins Leere, weil die Testläufe versehentlich über eine
  veraltete `TEXINPUTS`-Umleitung auf einen alten `l3build
  check`-Build-Ordner liefen, statt auf das frisch installierte Paket --
  jede Codeänderung schien wirkungslos, bis dies bemerkt wurde. **Lehren:**
  (1) Bei Kurzfassungen eines Realdokuments für Bisektion immer auf
  Klammer-/Gruppenbalance prüfen (z.\,B. `\mode<...>{...}`,
  `\lecturemode<...>{...}`), nicht nur auf `\begin`/`\end`-Umgebungen --
  ein naives Abschneiden kann sowohl einen unechten Absturz erzeugen
  als auch einen echten, aber andersartigen Befund fälschlich entlasten.
  (2) Bei "'Code-Änderung hat keine Wirkung"'-Verwirrung während einer
  Debug-Sitzung zuerst prüfen, gegen welchen tatsächlichen Dateipfad
  gerade getestet wird (`\ifdefined`/`\meaning` einer frisch benannten,
  eindeutigen Test-Hilfsfunktion ist zuverlässiger als sich auf die
  eigene `TEXINPUTS`/Kommandozeilen-Historie zu verlassen).

  Regressionstests: `lttheme-tuc-2019/testfiles/teaching-lecture-number.lvt`
  (erweitert, prüft Kopfzeilen-Logik + dass `auto-section-title`
  weiterhin opt-in bleibt) und
  `osglecture-modes/testfiles/ltxtalk-mode-then-section.lvt` (neu, prüft
  den `\mode`-dann-`\section`-Bug direkt). Per `pdftotext` am
  gerenderten PDF verifiziert -- sowohl an Kurztests als auch am
  **vollständigen, ungekürzten Realdokument** (51 Seiten, `ollm build
  --target=slides`, frisch installierte Pakete): Kopfzeile zeigt korrekt
  konstant "Algorithmen & Programmierung -- 0. Einführung" in Zeile~1 und
  in Zeile~2 korrekt wechselnd "1 Willkommen" / "2 Wie funktioniert der
  Kurs?" / "3 Organisatorisches" / "4 Prüfung"; kein Absturz, keine
  Korruption. Kleiner, unabhängig davon gefundener Nebenbefund: ein
  Tilde (`~`) direkt nach `\thesection` wurde in diesem Slot
  stillschweigend verschluckt (kein sichtbares Leerzeichen); Ursache
  nicht weiter verfolgt, behoben durch `\c_space_tl` statt `~` (siehe
  Kommentar an der Stelle). Alle 20 `lttheme`-, alle 4
  `lttheme-tuc-2019`- und alle 16 `osglecture-modes`-Tests grün.
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

