# osglecture-modes: Filtermodus-Scanner nach Lua verlagern

**Status:** Umbau abgeschlossen (Plan angelegt 2026-09-26; Phasen 0-4, 6,
7 fertig, alle 15 bestehenden Tests grün, Pakete neu installiert; Phase 5
zurückgestellt -- keine exakte Minimalreproduktion gefunden, siehe
Abschnitt 7. **Offen: Bestätigung am realen Kursskript**, siehe `ToDo.md`.)
**Auslöser:** `TeX capacity exceeded, sorry [input stack size=10000]` in einem
realen Kursskript (AuP/Script2/001-Intro), reproduziert unabhängig von
TUC-2019 und von `auto-section-title` (siehe `ToDo.md`, Abschnitt
"ltthemer + Co", Eintrag vom 2026-09-25/26).

Dieses Dokument ist der Fortsetzungspunkt, falls eine einzelne Sitzung für
den vollständigen Umbau nicht reicht. Der **Fortschritt** steht in
Abschnitt 7 -- dort zuerst nachsehen.

## 1. Befund (gesichert, per Bisektion reproduziert)

- Auslöser ist die **Schalterform** `\mode<name>` (kein Inhaltsargument,
  z.\,B. `\mode<presentation>`), *nicht* `\mode<name>{...}` oder
  `\lecturemode<name>{...}`.
- Diese Schalterform aktiviert `\osglecture_modes_switch:n`, das (sofern
  kein natives `\mode*` ausreicht oder eigene `mode=`-Ausnahmen
  registriert sind) `\g_osglecture_modes_scan_engaged_bool` setzt und
  `\osglecture_modes_start_scan:` aufruft.
- Der Crash tritt nur auf, wenn **zusätzlich** ein Header-/Rand-/Fuß-Slot
  bei jedem Foliendurchlauf unterschiedlichen, von `\section` abgeleiteten
  Text zeigt (siehe unten, Abschnitt 2) -- ein rein statischer Header
  crasht mit demselben `\mode<presentation>` nicht.
- Isolierte Minimaltests (bis zu 40 Wiederholungen: konstanter String,
  pro Folie neuer fertiger String, pro Folie zu expandierender Wert,
  dichter Folieninhalt mit Alertblock/verschachtelten Listen/Overlays,
  Zweispalter+Bild) lösten den Crash **nicht** aus, auch nicht mit echten
  `\section`-Aufrufen und identischem Hook-Mechanismus, solange
  `\mode<presentation>` fehlte. Sobald `\mode<presentation>` present war
  (in einem aus dem echten Dokument gekürzten Repro, ca. 110--230 Zeilen),
  crashte es unabhängig davon, welcher konkrete Mechanismus den Header
  füllte (die ursprüngliche TUC-2019-Funktion ebenso wie ein
  selbstgebauter Fünfzeiler mit `\AddToHook{section/begin}`).
- Die **exakte** minimale Kombination aus Folienzahl/-inhalt, die neben
  `\mode<presentation>` noch nötig ist, wurde *nicht* gefunden -- mehrere
  gezielte Nachbauten mit realistischem Inhalt blieben sauber. Das
  spricht dafür, dass die Tiefe/Akkumulation vom Zusammenspiel mit
  `ltx-talk`s eigener Folien-/Tagging-Buchhaltung abhängt, nicht (nur) von
  der Menge verworfenen Textes.
- Ein chirurgischer Testfix (`tagpdfparaOff`/`tagpdfparaOn` nur um den
  Aufruf von `\osglecture_modes_scan:` in `\osglecture_modes_start_scan:`
  gelegt) **behob den Crash nicht** -- byteidentischer Absturz. Das passt
  dazu, dass die Rekursion sich selbst über viele Folien/Umgebungsgrenzen
  hinwegzieht (siehe Abschnitt 2); ein einzelner Einstiegspunkt lässt sich
  nicht sinnvoll einklammern.
- Repro-Dateien (nicht committet, liegen unter
  `/private/tmp/.../scratchpad/repro-bisect/` und `.../repro-intro/` der
  Debug-Sitzung -- bei Bedarf aus dem echten Dokument neu ableiten, siehe
  Abschnitt 6.2) demonstrieren den Crash ohne `ollm`, mit reinem
  `lualatex`.

## 2. Architektur des bestehenden TeX-Level-Scanners

Kern: `\osglecture_modes_scan:` (osglecture-modes.dtx, um Zeile 2229).

```
\osglecture_modes_scan:
  -> \peek_remove_spaces:n
       -> ist nächstes Token \begin?  -> \osglecture_modes_scan_begin:
       -> ist nächstes Token \end?    -> \osglecture_modes_scan_end:
       -> sonst                      -> \osglecture_modes_scan_token:
```

- **`scan_begin:`** liest den Umgebungsnamen. Ist er in
  `\g_osglecture_modes_keep_envs_clist` (z.\,B. `frame`) *und* für den
  aktuellen Modus aktiv (oder ohne `mode=`-Bindung registriert, wie
  `frame` selbst), wird `\begin{#1}` **unverändert in den Tokenstrom
  eingefügt** -- ab hier übernimmt TeX/`ltx-talk` wieder normal, bis
  `\end{#1}` feuert. Sonst: `\osglecture_modes_skip_environment:n`
  (native, *nicht* rekursive, delimitierte Argumentabholung bis zum
  passenden `\end{...}`) und danach erneutes `\osglecture_modes_scan:`.
  Registrierte, aber raw-skip-fähige Umgebungen nutzen stattdessen
  `\osglecture_modes_lua_raw_skip:n` (siehe Abschnitt 3).
- **`scan_token:`** unterscheidet Controlword vs. Einzelzeichen
  (`\peek_N_type:TF`). Ein Controlword wird gegen
  `\g_osglecture_modes_dispatch_prop` geprüft (Registrierung über
  `\DeclareLectureKeepCommand`/`\DeclareLectureKeepLabelCommand`, plus
  intern vordefinierte Basisausnahmen: Gliederungsbefehle, `\mode`,
  `\lecturemode`, `\maketitle`, `frame`). Bekannt und (falls
  modusgebunden) aktiv: der registrierte Handler übernimmt normal --
  typischerweise `#1 {#2}` mit **nativer** Argumentabholung für `#2` (z.\,B.
  `\section{Titel}` liest den Titel wie gewohnt), dann erneutes
  `\osglecture_modes_scan:`. Unbekannt: das einzelne Token wird verworfen,
  ohne Argumente zu berühren -- diese werden beim *nächsten* rekursiven
  Aufruf Zeichen für Zeichen (bzw. Gruppenklammer für Gruppenklammer)
  ebenfalls verworfen, weil `{`/`}` weder `\begin` noch `\end` sind und
  daher `\osglecture_modes_scan_token:`'s Einzelzeichen-Zweig
  (`\osglecture_modes_discard_one:`) durchlaufen.
- Jede dieser Fortsetzungen endet mit einem **erneuten Aufruf von
  `\osglecture_modes_scan:`** -- die Rekursion läuft, bis eine
  registrierte, aktive Umgebung erreicht wird oder `\end{document}`
  fällt. `\AddToHook{env/frame/after}{\osglecture_modes_start_scan:}`
  setzt sie nach jedem `\end{frame}` neu in Gang (ein *neuer*
  Top-Level-Aufruf, keine Fortsetzung der alten Kette).
- `\peek_meaning:NTF`/`\peek_remove_spaces:n`/`\peek_N_type:TF` (expl3s
  Standard-Lookahead) verbrauchen **echte TeX-Input-Stack-Tiefe pro
  Aufruf**, die erst frei wird, wenn die gesamte Scan-Kette bis zu einer
  „kept" Umgebung durchgelaufen ist -- anders als in vielen anderen
  Sprachen wird das hier *nicht* wegoptimiert.

**Kernrisiko, unabhängig vom Tagging-Detail:** Für hinreichend lange
"nicht erkannter Inhalt"-Strecken (viele Zeichen/Befehle zwischen zwei
registrierten Ankerpunkten) wächst diese Rekursionstiefe linear mit der
Zahl der verworfenen Token. Bei genügend Inhalt -- und offenbar
begünstigt durch zusätzliche Verschachtelung aus `ltx-talk`s eigener
Folien-/Tagging-Buchhaltung beim Schließen einer Folie -- reißt das die
harte Input-Stack-Grenze (hier: 10000).

## 3. Bestehende Lua-Precedent (und warum sie nicht direkt reicht)

`osglecture-modes-ltxtalk.lua` (eingebettet in `osglecture-modes.dtx`,
`%<*lua>`-Block, Ende der Datei) registriert `process_input_buffer`
(LuaTeX-Callback) und ersetzt **ganze Quelltextzeilen** durch `""`, bis
eine Zeile auf `\end{<env>}` matcht:

```lua
function osglecture_modes_ltxtalk.start_raw_skip(env) ... end
-- process_input_buffer liefert "" für jede Zeile, bis \end{env} auftaucht
```

Das ist **zeilenbasiert, vor jeder Tokenisierung**, und **Alles-oder-Nichts
für eine einzelne, namentlich bekannte Umgebung** (aktuell genutzt für in
`raw-skip-envs` gelistete Umgebungen). Für unseren Fall reicht das nicht:

- Die Schalterform `\mode<name>` filtert **nicht** an
  Umgebungsgrenzen gebunden, sondern token-/befehlsweise, mit
  eingestreuten *behaltenen* Befehlen (`\section`, `\mode`, ...) mitten im
  sonst verworfenen Strom.
- `process_input_buffer` sieht rohen Quelltext, keine Token/Catcodes --
  eine Zeile teilweise zu behalten (etwa `Text \section{X} mehr Text`)
  ist damit nicht sauber möglich.

Für den Ersatz des allgemeinen Scanners brauchen wir echtes
**Token-Level-Scanning**, vermutlich über LuaTeX' `token_filter`-Callback
und die `token`-Library (`token.get_next()`, `token.put_next()`,
`token.scan_toks()` o.ä.), nicht `process_input_buffer`. Das ist neu zu
bauen, keine Erweiterung des Bestehenden.

## 4. Zielarchitektur (korrigiert nach Recherche in der LuaTeX-Referenz)

**Wichtige Korrektur gegenüber der ersten Fassung dieses Plans:** LuaTeX
kennt **keinen** `token_filter`-Callback (geprüft gegen
`texmf-dist/doc/luatex/base/luatex.pdf`, Abschnitt 9, Callback-Liste --
es gibt nur datei-, zeilen- (`process_input_buffer`) und
Node-Level-Callbacks, keinen automatischen Token-Abfangpunkt). Was
tatsächlich existiert (Abschnitt 10.6, "The token library"): **manuelle**
Scanner-Funktionen, die man *aus einem laufenden `\directlua`-Aufruf
heraus* benutzt: `token.get_next()` (nächstes Token holen, ohne es zu
expandieren), `token.put_next(...)` (Token zurück in den TeX-Eingabestrom
schieben), `token.scan_string()`/`token.scan_toks()` (balancierte Gruppe
bzw. `\cs`-Bedeutung einlesen), `token.create(name_or_char [,catcode])`
(Token bauen). Kein Dauer-Callback nötig -- **eine einzige
`\directlua{...}`-Aufrufstelle**, die intern eine gewöhnliche
Lua-`while`-Schleife fährt, reicht: diese Schleife kostet **keine**
TeX-Input-Stack-Tiefe (es ist Luas eigener Aufrufstapel), egal wie viele
Token sie verwirft.

Grundidee: Die Entscheidung "behalten oder verwerfen" wandert komplett
nach Lua, **bevor** TeX die verworfenen Token je zu Gesicht bekommt --
umgesetzt als eine Lua-Funktion, die bei jedem
"`\osglecture_modes_scan:`-Aufruf auf LuaTeX" einmal läuft und selbst so
lange weiterliest, bis sie auf etwas Behaltenes stößt.

1. **Registrierung spiegeln -- erledigt (Phase 1):** Name, Handler-Name
   und optionale `mode=`-Bindung jedes behaltenen Befehls/jeder
   behaltenen Umgebung liegen in
   `osglecture_modes_ltxtalk.keep_cmds`/`.keep_envs` vor.
2. **Aktivmodus-Zustand -- erledigt (Phase 1):**
   `osglecture_modes_ltxtalk.active_modes`/`.is_mode_active(name)`
   spiegelt den tatsächlichen, einzigen Änderungspunkt
   (`\osglecture_modes_visit:n`, das sowohl vom Graphdurchlauf in
   `\osglecture_modes_finalize:` als auch von der direkten
   Laufzeitaktivierung `\osglecture_modes_activate_runtime:n` --
   d.\,h. der Schalterform `\mode<name>` selbst -- benutzt wird) und den
   zugehörigen Clear-Punkt. Verifiziert: `\mode<solutions>` setzt
   `is_mode_active("solutions")` sofort auf `true`.
3. **Scan-Kern, Lua-seitig (`osglecture_modes_ltxtalk.scan()`):**
   Läuft in einer `while`-Schleife über `token.get_next()`:
   - Token ist `\begin`: nächstes balanciertes Gruppenargument als
     Umgebungsname lesen (`token.scan_string()` oder händisches
     Zusammensetzen über weitere `get_next()`-Aufrufe, je nachdem was
     robuster ist). Umgebungsname in `keep_envs` bekannt *und* (falls
     `mode` gesetzt) aktiv: `\begin{<name>}` per `token.put_next()`
     rekonstruieren und **zurückkehren** (Lua-Aufruf endet, TeX
     übernimmt normal -- das zugehörige `env/<name>/after`-Hook ruft
     später `\osglecture_modes_start_scan:` erneut auf). Sonst: Token bis
     zum passenden `\end{<name>}` **ohne `put_next`** wegzählen
     (Tiefenzähler für gleichnamige Verschachtelung -- entspricht
     `\osglecture_modes_skip_environment:n`s Delimiter-Matching), danach
     Schleife fortsetzen.
   - Token ist `\end`: bei `document` durchreichen (`token.put_next`) und
     zurückkehren; sonst (unerwartetes `\end` außerhalb einer behaltenen
     Umgebung) verwerfen und Schleife fortsetzen (entspricht
     `scan_end_aux:n`).
   - Token ist ein anderes Controlword: Name in `keep_cmds` bekannt *und*
     (falls `mode` gesetzt) aktiv: **nicht** das Originaltoken
     zurückschieben, sondern den registrierten **Handler-Namen** (z.\,B.
     `osglecture_modes_keep_section:`) als Controlword-Token bauen und per
     `put_next` einfügen, dann zurückkehren. Der Handler ist unverändert
     bestehender TeX-Code, der das Originalkommando mit seiner normalen
     `xparse`-Signatur ausführt und danach selbst `\osglecture_modes_scan:`
     aufruft, um fortzusetzen -- **das** ist der Kniff, der uns erspart,
     Argumentzahl/-form pro Befehl in Lua nachzubilden (siehe Abschnitt 5,
     jetzt beantwortet). Unbekanntes Controlword: verwerfen, Schleife
     weiter.
   - Alles andere (einzelne Zeichen: Gruppenklammern, Buchstaben, Leerraum
     etc.): verwerfen, Schleife weiter (entspricht
     `osglecture_modes_discard_one:`).
4. **Einzige Integrationsstelle: `\osglecture_modes_scan:` wird
   engine-abhängig:**
   ```
   \cs_set_protected:Npn \osglecture_modes_scan:
     {
       \sys_if_engine_luatex:TF
         { \directlua{ osglecture_modes_ltxtalk.scan() } }
         { <bisheriger TeX-Level-Körper, unverändert> }
     }
   ```
   Das ist der **einzige** Änderungspunkt am Kontrollfluss: jeder
   bestehende Aufrufer von `\osglecture_modes_scan:` (die Handler wie
   `osglecture_modes_keep_generic:Nn`, `scan_begin_aux:n`s
   "kept+aktiv"-Fall, `scan_end_aux:n` usw.) bekommt die
   Lua-Fortsetzung automatisch, ohne dass jede einzelne Stelle angefasst
   werden muss.
5. **Nicht-LuaTeX-Fallback erhalten:** Der TeX-Level-Körper bleibt
   unverändert als `\sys_if_engine_luatex:F`-Zweig bestehen (wie bei
   `ignorenonframetext`/Raw-Skip bereits gehandhabt, inkl.
   `\PackageWarning` bei fehlendem LuaTeX).

## 5. Offene Designfragen

- ~~Wie werden Argumente behaltener Befehle in Lua korrekt erkannt?~~
  **Beantwortet:** gar nicht in Lua -- Lua schiebt nur den registrierten
  **Handler-Namen** zurück (der bereits als bestehender, unveränderter
  TeX-Code die normale `xparse`-Signatur des Originalbefehls kennt) und
  kehrt zurück; TeX übernimmt die Argumentabholung wie bisher. Siehe
  Abschnitt 4, Punkt 3.
- Wie verhält sich das Lua-Scannen gegenüber **verbatim-artigem Inhalt**
  (`\begin{verbatim}`, `minted`, Kommentaren mit Sonderkatcodes) *bevor*
  eine kept-Umgebung erreicht wird? `token.get_next()` liest mit den zum
  Lesezeitpunkt *bereits aktiven* Catcodes -- exakt wie TeX' eigener
  Tokenizer. Der bestehende TeX-Scanner hat dasselbe Problem
  grundsätzlich schon (`\osglecture_modes_skip_environment:n`s
  Delimiter-Suche läuft ebenfalls, bevor `\begin{verbatim}` selbst die
  Catcodes umstellen konnte) -- keine Verschlechterung durch Lua, aber
  auch keine Verbesserung; bleibt eine bekannte, vorbestehende Grenze.
- **Nested/gleichnamige Umgebungen** innerhalb einer verworfenen Strecke
  (z.\,B. ein verschachteltes `itemize` in einer verworfenen,
  nicht-registrierten Umgebung) -- der TeX-Scanner behandelt das über
  `\osglecture_modes_skip_environment:n`s Delimiter-Matching auf den
  *äußersten* Namen; Lua-Seite braucht dieselbe Tiefenzählung.
- **Fehlerverhalten**: Was passiert bei unausgeglichenen `\begin`/`\end`
  am Dokumentende, oder wenn Lua und TeX-Zustand (z.\,B. durch einen Bug)
  auseinanderlaufen? Sollte nicht stillschweigend Inhalt verschlucken --
  eine Diagnose-/Fallback-Warnung einplanen.
- Sollte der TeX-Fallback-Pfad langfristig **abgekündigt** werden (das
  Bundle testet ohnehin nur LuaTeX), oder bleibt er dauerhaft als
  Sicherheitsnetz? Nicht in dieser Sitzung entscheiden, nur nicht
  versehentlich kaputt machen.

## 6. Vorgehen

### 6.1 Phasen (Fortschritt in Abschnitt 7)

- **Phase 0 -- Verstehen** (diese Sitzung, siehe Abschnitt 1--3): TeX-Level-
  Mechanismus vollständig gelesen und dokumentiert; bestehende
  Lua-Precedent gelesen und als unzureichend erkannt. **Abgeschlossen.**
- **Phase 1 -- Interface-Design**: Lua-Tabellenstruktur für gespiegelte
  Registrierung festlegen; `\directlua`-Spiegelpunkte in
  `\osglecture_modes_declare_allowed_command:nn`/
  `\osglecture_modes_declare_keep_environment:nn`/Basisausnahmen
  einbauen -- *ohne* das Scan-Verhalten selbst schon zu ändern (rein
  additiv, testbar durch Prüfen der gespiegelten Lua-Tabelle).
- **Phase 2 -- Token-Filter-Kern**: `token_filter`-Callback, der
  registrierte kept-Umgebungen/-Befehle durchreicht und alles andere
  verwirft, zunächst *hinter einem Opt-in-Schalter* (nicht automatisch
  aktiv), damit der bestehende Pfad unangetastet bleibt, während der neue
  parallel getestet wird.
- **Phase 3 -- Umschalten**: `\osglecture_modes_switch_own:`/
  `\osglecture_modes_start_scan:` auf LuaTeX den neuen Pfad nutzen lassen,
  TeX-Pfad als expliziten Fallback für andere Engines erhalten.
- **Phase 4 -- Bestehende Tests**: Alle 15 vorhandenen `.lvt`-Dateien in
  `osglecture-modes/testfiles/` müssen unverändert grün bleiben.
- **Phase 5 -- Neuer Regressionstest**: Test, der den ursprünglichen
  Crash nachstellt (tagging=on, `\mode<presentation>`, dynamischer
  Header-Slot, mehrere Folien) und jetzt sauber durchläuft.
- **Phase 6 -- Doku**: `osglecture-modes.dtx`-Kommentare und
  `README-modes.md` auf die neue Dual-Pfad-Architektur aktualisieren.
- **Phase 7 -- Abschluss**: `ToDo.md`-Eintrag aktualisieren, dieses
  Dokument als "Status: erledigt" markieren oder verbleibende
  Restarbeiten (z.\,B. TeX-Pfad-Abkündigung) neu eintragen.

### 6.2 Repro für Regressionstest (Phase 5)

Die in dieser Sitzung gebauten Kurztests liegen nicht im Repository
(Scratch-Verzeichnis der Debug-Sitzung). Für Phase 5 entweder von dort
übernehmen oder neu bauen: Kern ist ein `osglecture`+`tuc-2019`-Dokument
mit `\DocumentMetadata{tagging=on}`, `\settucthemeheader{custom}` +
einem `\AddToHook{section/begin}`, das den Header-Zeileninhalt ändert,
mehreren `\section`+`\frame`-Zyklen, und `\mode<presentation>` zwischen
zwei Abschnitten -- siehe Abschnitt 1 für die Details, die *nicht*
reichten (die exakte Minimalkombination ist offen). Pragmatisch: das
gekürzte Realdokument-Repro (aus `AuP/Script2/001-Intro/main.tex`, auf
die ersten ca. 480 Zeilen bis zur zweiten Folie in "Organisatorisches"
gekürzt) ist der zuverlässigste bekannte Fall und sollte als Ausgangsbasis
für die neue `.lvt`-Datei dienen, notfalls mit Verweis auf den
Originalinhalt statt 1:1-Kopie (Lizenz/Umfang).

## 7. Fortschritt (hier aktuell halten)

- [x] Phase 0: Mechanismus verstanden und dokumentiert.
- [x] Phase 1: Interface-Design + Spiegel-Infrastruktur. Umgesetzt:
  `osglecture_modes_ltxtalk.keep_cmds`/`.keep_envs` in
  `osglecture-modes-ltxtalk.lua`, gefüllt über neue `\directlua`-Aufrufe
  in `\osglecture_modes_declare_allowed_command:nn`,
  `\osglecture_modes_register_command:nnn` und
  `\osglecture_modes_declare_keep_environment:nn`. Verifiziert per
  Kurztest (`\directlua{for k,v in pairs(...) do ... end}` nach Laden von
  `osglecture-modes` mit eigenen `\DeclareLectureKeepEnvironment`/
  `\DeclareLectureKeepCommand`-Aufrufen): Basisausnahmen erscheinen mit
  `mode=nil`, modusgebundene Einträge mit korrektem Modusnamen. Alle 15
  bestehenden Tests weiterhin grün (rein additiv, keine
  Verhaltensänderung).
- [x] Phase 2: Scan-Kern implementiert -- `osglecture_modes_ltxtalk.scan()`
  im `%<*lua>`-Block von `osglecture-modes.dtx` (nach
  `register_keep_env`): `\begin`/`\end`/Controlword-Dispatch gegen
  `keep_cmds`/`keep_envs`/`raw_skip_envs`/`active_modes`, inklusive
  Tiefen-korrektem `skip_environment` und einer vollständigen Lua-Spiegel
  von `\g_osglecture_modes_raw_skip_envs_clist` (neu:
  `\osglecture_modes_sync_raw_skip_envs_lua:`). Details in Abschnitt 8.
- [x] Phase 3: `\osglecture_modes_scan:` ist jetzt engine-abhängig
  (`\sys_if_engine_luatex:TF` -- Lua-Scan vs. unverändertem TeX-Zweig als
  Fallback für pdfTeX/XeTeX).
- [x] Phase 4: Bestehende 15 Tests grün -- **darunter ein echter,
  vorbestehender Bug im TeX-Scanner gefunden (Abschnitt 9.2, weiterhin
  ungefixt für pdfTeX/XeTeX); drei Testdateien fehlte die an anderer
  Stelle bereits etablierte `\END`-Registrierung, ergänzt, Original-`.tlg`
  unverändert gelassen. Details in Abschnitt 9.**
- [~] Phase 5: **Zurückgestellt, keine exakte Minimalreproduktion
  gefunden** -- schon frühere Bisektion in dieser Sitzung (Abschnitt 1)
  zeigte, dass reine Wiederholung (bis 40 Zyklen) den Crash nicht
  auslöst; er braucht offenbar die volle Kombination aus
  Tagging + dynamischem Header-Slot (tagpdf/lttheme-Koffer-Interaktion)
  + erheblichem Realdokumentumfang, was eine `.lvt`-Regressionsdatei
  innerhalb von `osglecture-modes`' eigenständiger Testsuite (bisher ohne
  Abhängigkeit auf `osglecture`/`lttheme`/tagpdf) unverhältnismäßig teuer
  macht. Die architektonische Begründung, warum der Lua-Scanner die
  Ursache trotzdem behebt, steht in Abschnitt 9 (kein TeX-Eingabestapel-
  Verbrauch mehr pro gescanntem Token). **Endgültige Bestätigung
  aussehend:** das reale Kursskript (AuP/Script2/001-Intro) mit dem
  installierten, neuen `osglecture-modes` bauen (Pakete bereits per
  `l3build install` aktualisiert) -- siehe `ToDo.md`.
- [x] Phase 6: Doku -- interne `\ldeen{}`-Kommentare an jeder geänderten
  Stelle in `osglecture-modes.dtx` (deutsch/englisch, wie im Rest der
  Datei üblich); `README-modes.md` bewusst unverändert gelassen (rein
  interner Implementierungswechsel, keine sichtbare API-/
  Verhaltensänderung für Nutzer).
- [x] Phase 7: Abschluss -- `ToDo.md` aktualisiert (Eintrag "dynamischer
  Text in Header-Slot" auf strukturell behoben umgestellt, mit Verweis
  hierher und auf den noch ausstehenden Realdokument-Test).

**Nächster Schritt, falls hier unterbrochen:** Kein weiterer
Implementierungsschritt offen. Verbleibend: (1) das reale Kursskript
gegen das installierte, neue `osglecture-modes` bauen und bestätigen,
dass der `TeX capacity exceeded`-Crash verschwunden ist (die eigentliche
Bestätigung dieses gesamten Umbaus); (2) optional, als separater
Folgeauftrag, den in Abschnitt 9.2 beschriebenen TeX-Scanner-Bug für
pdfTeX/XeTeX fixen (dort steht ein konkreter, aber ungetesteter
Fix-Vorschlag); (3) optional, falls doch noch gewünscht, einen
Regressionstest für den Original-Crash nachreichen (siehe Abschnitt 6.2
für Repro-Hinweise).

## 8. Phase-2-Stand: Kernmechanik funktioniert -- der ursprünglich
   vermerkte Blocker war ein Debugging-Artefakt

### 8.1 Zusammenfassung

Die vorige Fassung dieses Abschnitts vermerkte fälschlich, dass eine aus
Einzelzeichen rekonstruierte `\begin{env}`-Sequenz den Umgebungscode
nicht auslöse. **Das stimmt nicht** -- der eigentliche Fehler lag in den
*Testdateien* dieser Debug-Sitzung, nicht im Ansatz selbst. Ursache und
Fix stehen in 8.2; 8.3 bestätigt, dass die für die echte Implementierung
vorgesehene Architektur (Scan-Logik als Funktion in der separat
`require`ten `.lua`-Datei, siehe Abschnitt 4) davon **gar nicht
betroffen** ist.

### 8.2 Ursache des vermeintlichen Blockers

`\directlua`s Argument wird laut LuaTeX-Referenz (Abschnitt 2.4.1)
**vollständig expandiert** ("as if `\edef`'d"), bevor es an Lua
übergeben wird. Ein catcode-6-Zeichen (`#`, macro parameter -- Luas
Längenoperator!) übersteht diese Expansion nicht unbeschadet: Inline
verwendet, wird der Tokenstrom ab dem `#` beschädigt/abgeschnitten --
beobachtete Symptome reichten von einem Lua-Laufzeitfehler ("attempt to
get length of a number value", der bei einem `grep "^!"` nicht auffällt,
weil Lua-Fehler mit `[\directlua]:` beginnen, nicht mit `!`) bis zu
"unfinished string near &lt;eof&gt;" bei einem `#` in einem
String-Literal. **Das erklärt exakt das ursprünglich beobachtete
Symptom:** Der Scan-Code, der `token.put_next()` aufrufen sollte, brach
vorher mit einem (unbemerkten) Lua-Fehler ab -- `\begin{env}` wurde also
nie tatsächlich rekonstruiert, nicht weil die Technik nicht funktioniert,
sondern weil der Lua-Code, der sie ausführen sollte, gar nicht bis dahin
kam.

Bestätigt per Minimalrepro: `local toks = {} print(#toks)` inline in
`\directlua{...}` schlägt fehl; mit `\catcode`\#=12` (ungruppiert, davor
gesetzt) davor funktioniert derselbe Code (`local toks = {} local n =
#toks print(n)` -> `0`) einwandfrei. Mit dieser Erkenntnis lief auch die
ursprüngliche `\begin{foo}`-Rekonstruktion (Minimalbeispiel aus der
vorigen Fassung) korrekt: `FOO-BEGAN` erscheint, `\@currenvir` wird
korrekt zu `foo`, `FOO-ENDED` erscheint beim echten `\end{foo}` -- keine
Fehler.

**Falle beim Reparieren:** `\begingroup\catcode`\#=12 ... \endgroup` um
den `\directlua`-Aufruf funktioniert *nicht* zuverlässig, wenn der
rekonstruierte Inhalt selbst eine Gruppe öffnet, die erst viel später
(z.\,B. bei `\end{foo}`) wieder schließt (wie `\begin`s eigenes
`\begingroup`): Das äußere `\endgroup` schließt dann die *innere*,
noch offene Gruppe (`\begin{foo}`s eigene) statt der eigenen --
`\@currenvir` wird dadurch sofort wieder zurückgesetzt, und das echte
`\end{foo}` findet später die falsche Gruppe vor ("Extra `\endgroup`").
Fix: **ungruppierte**, globale `\catcode`-Zuweisungen
(`\catcode`\#=12 ... \catcode`\#=6`, kein `\begingroup`/`\endgroup`)
verwenden, falls überhaupt inline mit `#` in `\directlua` gearbeitet
werden muss.

### 8.3 Warum die echte Implementierung davon nicht betroffen ist

Die für Abschnitt 4 vorgesehene Architektur ruft die Scan-Logik als
**Funktion aus der separat geladenen `.lua`-Datei** auf
(`\directlua{osglecture_modes_ltxtalk.scan()}`) -- diese Aufrufzeile
selbst enthält kein `#`. Die `.lua`-Datei wird über `require(...)` direkt
vom Dateisystem gelesen, **vollständig außerhalb von TeX' Tokenisierung
und Expansion** -- jedes `#` in den dortigen Funktionsdefinitionen
(Tabellenlängen etc.) ist davon nie betroffen, unabhängig davon, wie
`\directlua`s Argument-Expansion funktioniert. Verifiziert per Repro:
eine `helper.lua` mit einer Funktion `myhelper.make_begin_foo()`, die
exakt dieselbe Token-Rekonstruktion **mit `#`** enthält, per `require`
geladen und mit dem schlichten Aufruf `\directlua{myhelper.make_begin_foo()}`
aufgerufen (kein Catcode-Trick nötig) -- Ergebnis: `FOO-BEGAN`,
`\@currenvir` korrekt `foo`, `FOO-ENDED`, keine Fehler.

**Konsequenz:** Der komplette `osglecture_modes_ltxtalk.scan()`-Kern
gehört in die `.lua`-Datei (den `%<*lua>`-Block in
`osglecture-modes.dtx`), nicht inline in ein `\directlua{...}`. Für
zukünftiges Debugging inline im `.tex`/`.dtx`-Kontext (etwa
Kurztestaufrufe während der Entwicklung): entweder `#` ganz vermeiden
(z.\,B. `string.len(x)`/`table.pack(...).n` statt `#x`), oder mit
ungruppierten globalen `\catcode`-Zuweisungen wie in 8.2 arbeiten.

### 8.4 Stand der Implementierung (Phase 2/3 abgeschlossen)

Die Erkenntnisse aus 8.2/8.3 sind mittlerweile in `osglecture-modes.dtx`
eingearbeitet: `osglecture_modes_ltxtalk.scan()` existiert im
`%<*lua>`-Block (nach `register_keep_env`), implementiert die
Scan-Schleife gemäß Abschnitt 4, Punkt 3 (`token.get_next()`-Schleife,
Fallunterscheidung `\begin`/`\end`/Controlword/Einzelzeichen anhand
`t.cmdname`/`t.csname` -- siehe die empirisch bestätigten Werte in 8.4.1
-- gegen die in Phase 1 gespiegelten `keep_cmds`/`keep_envs`/
`active_modes`-Tabellen, plus eine zusätzliche, in Phase 1 noch fehlende
Spiegelung von `raw_skip_envs`), und `\osglecture_modes_scan:` ist gemäß
Punkt 4 engine-abhängig (siehe Abschnitt 9.3). Alle 15 bestehenden Tests
laufen grün -- Abschnitt 9 beschreibt einen dabei gefundenen
vorbestehenden Bug im TeX-Scanner, den der Lua-Scan-Kern nicht hat.

#### 8.4.1 Bestätigte `token.get_next()`-Feldwerte (empirisch, diese Sitzung)

| Token-Art | `t.cmdname` | `t.csname` | `t.mode` |
|---|---|---|---|
| Buchstabe (catcode 11) | `letter` | `nil` | Zeichencode |
| Sonstiges Zeichen (catcode 12) | `other_char` (vermutet, nicht einzeln verifiziert) | `nil` | Zeichencode |
| `{` (catcode 1) | `left_brace` | `nil` | `123` |
| `}` (catcode 2) | `right_brace` | `nil` | `125` |
| Makro/Kernelbefehl ohne `\long` (`\begin`, `\section`, `\relax`) | `call` (`relax`: `cmdname`==`csname`==`"relax"`, da Primitiv) | Name ohne Backslash | -- |
| Makro mit `\long` (`\newcommand`-Standard) | `long_call` | Name ohne Backslash | -- |
| Undefinierter Befehl | `undefined_cs` | `""` (leerer String, **nicht** `nil`) | `0` |

`token.create(name)` (Primitive/Makros) und
`token.create(char_code, catcode)` (Einzelzeichen) erzeugen korrekte
Token -- verifiziert durch Rücklesen mit `get_next()`. `token.put_next(
{t1, t2, ...})` fügt eine Liste von Token **in Listenreihenfolge** (nicht
umgekehrt) vor die weitere Eingabe ein.

## 9. Phase 4: 15 Tests grün -- dabei gefundener, vorbestehender Bug im
   TeX-Scanner (nur LuaTeX-Pfad automatisch mitbehoben)

### 9.1 Zusammenfassung

Nach Implementierung von `scan()` (Abschnitt 8.4) und der
Engine-Weiche (Abschnitt 9.3) schlugen 3 der 15 bestehenden Tests fehl:
`filter-mode-article`, `filter-mode-article-off`,
`ltxtalk-filter-profiles`. Diff in allen drei Fällen identisch im Muster:
das neue (Lua-)Log zeigt *zusätzlich* einen echten Seitenumbruch
(`[1] (....aux)`) und die Standard-Erstlauf-Warnung
`LaTeX Warning: Label(s) may have changed`, die im alten, eingefrorenen
`.tlg` fehlen.

**Das ist keine Regression, sondern die Aufdeckung eines echten,
vorbestehenden Bugs im TeX-Scanner selbst** (siehe 9.2), den der neue
Lua-Scanner architekturbedingt nicht hat. Erster Reflex war, die drei
`.tlg`-Baselines per `l3build save` auf das "lautere" Verhalten
anzuheben -- **das war der falsche Fix** und wurde wieder verworfen
(siehe 9.4): richtig ist, die drei Testdateien um dieselbe, bereits an
anderer Stelle im Testkorpus etablierte `\END`-Registrierung zu ergänzen
(siehe `ltxtalk-ignore-non-frame.lvt`), wonach alle 15 Tests wieder
gegen ihre **unveränderten Original-`.tlg`** grün sind -- sowohl mit dem
neuen Lua-Scanner als auch mit dem unveränderten TeX-Scanner (beides
verifiziert).

### 9.2 Der gefundene Bug (TeX-Scanner, alle Engines außer LuaTeX
    weiterhin betroffen)

`\osglecture_modes_skip_environment:n` (osglecture-modes.dtx) überspringt
eine nicht beibehaltene Umgebung per TeX-Parameter-Text mit Delimiter:

```latex
\cs_new_protected:Npn \osglecture_modes_skip_environment:n #1
  {
    \cs_set_protected:Npn \osglecture_modes_skip:w ##1 \end ##2
      {
        \str_if_eq:nnF {#1} {##2}
          { \osglecture_modes_skip:w }
      }
    \osglecture_modes_skip:w
  }
```

Alle drei Aufrufstellen schreiben danach im selben Makrokörper
sequentiell `\osglecture_modes_skip_environment:n {#1} \osglecture_modes_scan:`
-- die Absicht: nach dem Überspringen weiterscannen. **Das funktioniert
nicht zuverlässig:** `##1 \end ##2`s Delimiter-Suche durchsucht den
Tokenstrom blind nach dem nächsten `\end`-Token, *unabhängig davon, ob
die durchsuchten Token aus dem Dokument stammen oder aus dem eigenen,
noch nicht verarbeiteten Rest des aufrufenden Makrokörpers* -- TeX
unterscheidet das beim Scannen nicht. Wird die Ziel-Umgebung erst
*nach* dem eigenen, direkt anschließend geschriebenen
`\osglecture_modes_scan:`-Aufruf im Dokument gefunden (z.\,B. weil die
übersprungene Umgebung die letzte vor `\END`/`\end{document}` ist), wird
genau dieser Wiederaufsetz-Aufruf als Teil von `##1` **stillschweigend
mitverschluckt** und nie ausgeführt. Der Scanner "stirbt" damit lautlos;
alles danach (inklusive `\END` und dem echten `\end{document}`) läuft
ungefiltert und ungescannt weiter.

In allen drei betroffenen Testdateien endet das Dokument mit exakt
diesem Muster: einer nicht beibehaltenen bzw. modusinaktiven Umgebung
unmittelbar vor `\END`/`\end{document}` (z.\,B.
`\begin{unregisteredenv}...\end{unregisteredenv}` in
`ltxtalk-filter-profiles.lvt`). Dadurch lief der bare `\END`
(regression-test.tex) *ungefiltert direkt*, statt (wie eigentlich
korrekt) vom Scanner als unbekannter Befehl verworfen zu werden, sodass
erst das echte, textuelle `\end{document}` danach greift und den
vollständigen, normalen `\enddocument`-Mechanismus (inklusive
`\clearpage`, Aux-Schreiben) durchläuft, an dessen Ende `\END` via des
umgebogenen `\@@end`-Hooks nochmal (korrekt) aufgerufen wird. Ohne den
Bug entsteht also *mehr*, nicht weniger, sichtbare Ausgabe (ein
tatsächlich erzeugtes `\maketitle` kommt z.\,B. wirklich aufs Blatt,
statt lautlos nie geshippt zu werden) -- verifiziert per isoliertem
Minimaltest (`\maketitle` ohne den ganzen Scanner-Apparat shippt
zuverlässig eine Seite) und per Vorher/Nachher-Vergleich mit temporärer
`\iow_term:x`-Ablaufverfolgung in einer Stash-Kopie des unveränderten
Codes.

**Der neue Lua-Scanner hat diesen Bug nicht:** `scan()`s
`skip_environment(name)` ist eine echte Lua-`while`-Schleife, die nach
dem Finden des passenden `\end{name}` normal in ihre aufrufende
`scan()`-Schleife zurückkehrt (kein TeX-Delimiter-Parameter-Text, der
blind weitersuchen könnte) -- das Weiterscannen passiert einfach als
nächste Schleifeniteration, ohne Sonderfall.

**Nicht behoben in dieser Sitzung:** Der TeX-Scanner
(`\osglecture_modes_skip_environment:n`) hat diesen Bug weiterhin --
relevant für pdfTeX/XeTeX-Nutzer (der Lua-Pfad greift nur unter LuaTeX,
und `checkengines` in `build.lua` deckt ohnehin nur `luatex` ab, sodass
dieser Bug für andere Engines auch künftig unbemerkt bliebe). Ein
möglicher, kleiner Fix: `\str_if_eq:nnF` durch `\str_if_eq:nnTF` mit
`\osglecture_modes_scan:` im Treffer-Zweig ersetzen und die drei
Aufrufstellen entsprechend um ihren jetzt redundanten
`\osglecture_modes_scan:`-Aufruf kürzen -- aber **ungetestet** (keine
Testabdeckung für den TeX-Pfad) und daher absichtlich nicht in dieser
Sitzung angefasst, um kein unbeobachtetes Risiko im aktuell
"funktionierenden" (weil eingefroren-buggy getesteten) Pfad einzugehen.
Separater Folgeauftrag.

### 9.3 Engine-Weiche (Phase 3, Abschnitt 4 Punkt 4)

`\osglecture_modes_scan:` selbst entscheidet jetzt per
`\sys_if_engine_luatex:TF`, ob `\directlua{osglecture_modes_ltxtalk.scan()}`
(ein einziger Aufruf, der den kompletten Scan-Lauf in einer Lua-Schleife
durchführt) oder der unveränderte TeX-Zweig läuft. Da jeder
Wiederaufsetzpunkt -- sowohl der initiale Scan-Start als auch die
Fortsetzung nach einem beibehaltenen Befehl -- ausschließlich über
diesen einen Befehl läuft, reicht die Weiche an dieser einzigen Stelle.

### 9.4 Tatsächlicher Fix: Testdateien statt Baselines korrigiert

Die neuen Logs wurden zunächst manuell geprüft (kein `SHOULD NOT
APPEAR`-Leck, keine sonstigen unerwarteten Abweichungen -- nur der
zusätzliche Seitenumbruch/Aux-Block), und die drei `.tlg`s per
`l3build save` angehoben. Das ist aber der **falsche Fix**: er würde
bedeuten, ab jetzt bei jedem Testlauf eine echte Seite zu shippen und
Aux-Dateien zu schreiben, nur weil eine Testdatei ihr `\END` nicht
korrekt registriert -- unnötiger Overhead und ein unsauberer, an eine
konkrete Scanner-Implementierung gekoppelter Testabgleich.

`ltxtalk-ignore-non-frame.lvt` (bereits im Testkorpus vorhanden, war die
ganze Zeit über grün) zeigt das korrekte Muster: `\END` explizit per
`\DeclareLectureKeepCommand`-Infrastruktur als beizubehaltender Befehl
registrieren, mit einem Handler, der `\END` direkt (bare) aufruft:

```latex
\ExplSyntaxOn
\cs_new_protected:Npn \test_keep_end:
  { \END \osglecture_modes_scan: }
\osglecture_modes_declare_allowed_command:nn { END } { test_keep_end: }
\ExplSyntaxOff
```

Damit läuft `\END`s Testabschluss-Nachricht *immer* bare/direkt (egal ob
TeX- oder Lua-Scanner, egal ob der in 9.2 beschriebene Bug greift oder
nicht) -- exakt das ursprünglich gewollte, saubere, seitenlose Testende.
Die drei betroffenen Dateien (`filter-mode-article.lvt`,
`filter-mode-article-off.lvt`, `ltxtalk-filter-profiles.lvt`) hatten
diese Registrierung schlicht vergessen; ergänzt, unter Beibehaltung der
**unveränderten Original-`.tlg`-Dateien** (`git checkout` auf die
vorherige `save`-Änderung). Verifiziert: `l3build clean && l3build
check` -- alle 15 Tests grün, sowohl mit dem neuen Lua-Scanner als auch
(separat geprüft, alte `.dtx`-Fassung mit den korrigierten `.lvt`-Dateien
kombiniert) mit dem unveränderten TeX-Scanner. Damit bleibt der in 9.2
beschriebene TeX-Scanner-Bug zwar weiterhin ungefixt (siehe dort), aber
er wird von keinem der 15 Tests mehr zufällig verdeckt oder aufgedeckt --
die Testsuite ist unabhängig davon grün.

## 10. Nachtrag (2026-09-26): weiterer Handler-Dispatch-Bug gefunden und
    behoben -- `\osglecture_modes_keep_mode:`

Beim Testen der wieder aufgesetzten Section-in-Header-Funktion (siehe
`ToDo.md`, "ltthemer + Co") meldete der Nutzer: `\mode<presentation>`
(Schalterform, kein Inhaltsargument), direkt gefolgt von `\section{...}`
in der nächsten Zeile ohne Leerzeile dazwischen, übernahm dessen Argument
inkorrekt. Ursache: `\osglecture_modes_keep_mode:` (der
Scanner-Handler für ein gescanntes `\mode`) hatte die Signatur
`{ d<> +m }` -- **bedingungslos**, als hätte `\mode<name>` *immer* ein
Inhaltsargument. Bei der Schalterform grabschte `+m` blind das nächste
Token im Dokument (typischerweise den folgenden Befehl selbst) und
führte es *vor* dessen eigenem Argument aus -- praktisch dasselbe
Bugmuster wie der in Abschnitt 9.2 dokumentierte
`\osglecture_modes_skip_environment:n`-Bug, nur an einer anderen Stelle
im Handler-Dispatch.

Fix: `\osglecture_modes_keep_mode:` spiegelt jetzt exakt die Weiche des
echten `\mode`-Befehls selbst (Signatur `{ s d<> }`, `\peek_meaning:NTF
\c_group_begin_token` prüft vor jedem `+m`-artigen Griff, ob überhaupt
eine Klammergruppe folgt; ohne folgende Gruppe direkt
`\osglecture_modes_switch:n` aufrufen, das selbst fürs Weiterscannen
sorgt -- kein zusätzlicher `\osglecture_modes_scan:`-Aufruf danach, sonst
würde das eigene Wiederaufsetz-Token als unbekannter Befehl verworfen).
Neuer Test: `osglecture-modes/testfiles/ltxtalk-mode-then-section.lvt`
(gegen den unbehobenen Stand verifiziert -- schlägt dort mit sichtbarer
Zeichen-Korruption fehl). Alle jetzt 16 Tests grün.

**Debugging-Fußnote:** Die Live-Diagnose dieses Bugs lief zeitweise ins
Leere, weil die Testläufe versehentlich über eine veraltete
`TEXINPUTS`-Umleitung (`.../osglecture-modes/../build/test`, aus einer
früheren `l3build check`-Sitzung dieser Konversation) liefen, statt auf
das frisch installierte Paket -- jede Codeänderung schien wirkungslos.
Bemerkt über `\meaning` einer frisch benannten, eindeutigen
Test-Hilfsfunktion (`\osglecture_modes_keep_mode_resume:`), die als
"undefined" zurückkam, obwohl die installierte `.sty`-Datei sie
nachweislich enthielt.
