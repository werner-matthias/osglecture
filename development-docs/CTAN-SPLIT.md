# CTAN-Aufspaltung – Design

**Status:** Entwurf
**Gegenstand:** Zerlegung des osglecture-Bundles in CTAN-taugliche Einzelpakete
**Ausgangsbasis:** osglecture-Bundle, CTAN-Release 2026-10-23; TeXLive-Rückmeldung
zur Aufnahme

## 1. Zweck und Ausgangslage

TeXLive verlangt für die Aufnahme des Bundles zwei Änderungen, denen CTAN
zugestimmt hat:

1. Einige Modulnamen ändern sich.
2. Das Bundle wird in eine Reihe eigenständiger CTAN-Pakete zerlegt, jedes
   mit eigenem `.dtx` und `build.lua`. CTAN/TL ist bewusst, dass Ziele wie
   `l3build doc`, `l3build check` oder `l3build install --full` bei
   manchen Paketen nicht funktionieren, solange andere noch nicht
   installiert sind; `l3build install` (ohne `--full`) muss aber
   funktionieren. Jedes Paket-Readme listet deshalb seine Abhängigkeiten.

Das Repository bleibt auf GitHub ein einziges Bundle mit gemeinsamer
Tooling-Infrastruktur. Die Bundle-Zugehörigkeit darf laut CTAN weiterhin in
der Dokumentation erwähnt werden, ist aber kein Bauartefakt mehr – mit
einer Ausnahme (Abschnitt 3).

Dieses Dokument hält den aktuellen Entwurfsstand fest. Es ersetzt keine
Abstimmung mit CTAN/TL zu den tatsächlichen Paketnamen; die Namen hier sind
der Arbeitsstand aus der Planungsdiskussion, nicht final bestätigt.

## 2. Zielbild: die Pakete

| Verzeichnis (heute) | CTAN-Paketname | Engine | TDS-Wurzel | Bundle |
|---|---|---|---|---|
| `osglecture` | `osglecture` | 🌕 LuaLaTeX zwingend | `tex/luatex/osglecture` | ja (mit osgdocmk) |
| `ollm` | **`osgdocmk`** (neu) | ⚪ Perl-Skript | `scripts/osgdocmk`, `doc/man/man1` | ja (mit osglecture) |
| `manual-src` | kein eigenes Paket, zu osglecture | - | `doc/luatex/osglecture`¹ | ja (mit osglecture) |
| `langselect` | `langselect` | 🌕 | `tex/luatex/langselect` | nein |
| `tagpax` | `tagpax` | 🌕 | `tex/luatex/tagpax` | nein |
| `osglistings` | `osglistings` | 🌕 | `tex/luatex/osglistings` | nein |
| `ansiterm` | `ansiterm` | 🌕 | `tex/luatex/ansiterm` | nein |
| `tagdirtree` | `tagdirtree` | 🌑 | `tex/latex/tagdirtree` | nein |
| `osgstyler` | `osgstyler` | 🌓 | `tex/luatex/osgstyler` | nein |
| `semcat` | `semcat` | 🌕 | `tex/luatex/semcat` | nein (absorbiert `tagbridge`) |
| `osgdoc` | `osgdoc` | 🌓 | `tex/luatex/osgdoc` | nein |
| `lttheme` | **`lttalk-themeengine`** (neu) | 🌓² | `tex/luatex/lttalk-themeengine` | nein |
| `lttheme-tuc-2019` | **`lttalk-theme-tuc-2019`** (neu) | 🌓² | `tex/luatex/lttalk-theme-tuc-2019` | nein |
| `tagbridge` | *entfällt* | – | – | geht in `semcat` auf |

¹ `luatex`, nicht `lualatex` – es gibt keine TDS-Wurzel dieses Namens; die
Wurzel richtet sich nach der Engine (wie bei allen 🌕/🌓-Paketen), nicht nach
dem Namen des Formats. Bitte gegenprüfen, falls etwas anderes gemeint war.

² Eigener Code ohne Lua-Bezug, aber zwingende Abhängigkeit von `osgstyler`
(direkt bei `lttalk-themeengine`, transitiv bei `lttalk-theme-tuc-2019`
über `lttalk-themeengine`), das selbst 🌓 ist – eine harte Abhängigkeit
vererbt ihre Lua-Anforderung an das abhängige Paket (Abschnitt 6).

Elf eigenständige Pakete plus die Bundle-Einheit `osglecture`+`osgdocmk`
(die `manual-src` als Dokumentation mitführt) – zwölf Release-Einheiten
insgesamt, wie zuvor.

## 3. Die echte Bundle-Einheit: `osglecture` + `osgdocmk`

`osglecture` und `ollm` (→ `osgdocmk`) bleiben zusammen, weil sie
ohneeinander sinnlos sind: `osglecture` erzeugt die fachliche Quelle,
`osgdocmk` orchestriert die Builds einer ganzen Serie darüber. Das ist eine
echte Bundle-Beziehung im CTAN-Sinn (eine Veröffentlichung, ein
Submission-Eintrag), keine bloße Nachbarschaft im Repository.

**Umbenennung `ollm` → `osgdocmk`:** Grund ist die unerwünschte Assoziation
zu Large Language Models. Langform der Selbstidentifikation: *„OSG Lecture
Document Maker"*. Für die erste Umsetzungsrunde **nur die Außenfläche**:

- Verzeichnis `ollm/` → `osgdocmk/`
- Skriptname `ollm` → `osgdocmk` (inkl. `.cmd`-Launcher)
- Manpage `ollm.1` → `osgdocmk.1`
- `.dtx`-Treiber, README, CTAN-Paketname, TDS-Pfad `scripts/osgdocmk/`
- Alle Nennungen von „OSG LaTeX Lecture Maker" → „OSG Lecture Document
  Maker"

Das interne Perl-Namespace (`OLLM::Version` usw.), `.ollmconfig.local.toml`,
`ollm-latexmk.rc` bleiben vorerst unverändert – geringeres Risiko, kleinerer
Diff. Eine Vollumbenennung des Perl-internen Namespace ist eine spätere,
separate Entscheidung.

## 4. Tagbridge geht in `semcat` auf

`tagbridge` wird kein eigenes Paket. Befund aus dem Code (nicht Vermutung):

- `qrcode.sty` definiert selbst nur die Keys `version`, `level`, `height`
  (`qrcode.sty:2774–2776`). Den Key `tag` definiert ausschließlich
  `tagbridge.dtx:294` (`\define@key{qr}{tag}{...}`).
- Genau diesen Key ruft `semcat.dtx:1324` auf
  (`\qrset{height=1.2cm,tag=artifact}`). Ohne Tagbridge wäre das ein
  „Undefined key"-Fehler – **semcat** ist der tatsächliche funktionale
  Konsument, nicht `osglecture`.
- `osglecture.dtx:1287` lädt `tagbridge` nur vorsorglich; es ruft selbst
  nirgends `\qrcode`/`\qrset` auf. Der Code-Kommentar dort sagt sogar
  ausdrücklich, Tagbridge solle „self-contained and reusable outside
  osglecture" sein.
- Der TikZ-Teil von Tagbridge (`tagbridge.dtx:356f`) ist nur
  `\RequirePackage{latex-lab-testphase-tikz}`, bedingt auf aktives Tagging –
  kein eigener Patch-Code, von niemandem im Repository mit
  `alt=`/`artifact=` auf `tikzpicture` tatsächlich genutzt.
- `semcat`s eigenes README nennt `osgstyler`/`osgmodes` als
  *optional* – impliziert eigenständige Nutzbarkeit außerhalb von
  `osglecture`, die heute lautlos bräche, sobald `semcat` ohne `osglecture`
  (und damit ohne das transitive Laden von Tagbridge) verwendet würde.

**Konsequenz:**
- Der Inhalt von `tagbridge.dtx` wandert in `semcat` (als mitgeliefertes
  `semcat-tagbridge.sty`, automatisch von `semcat.sty` nachgeladen).
- `osglecture.dtx:1287` verliert `\RequirePackage{tagbridge}` ersatzlos.
- `semcat`s Testsuite übernimmt Tagbridges Tagging-Test (und damit auch
  dessen Bedarf an `insert-pdf-tags.lua`, s. Abschnitt 12).
- TDS-technisch unproblematisch: Tagbridge ist zwar als 🌑 eingestuft,
  `semcat` aber als 🌕 – Tagbridges Code ist ohnehin nur expl3, nie direkt
  LuaTeX-Engine-Code, und läuft einfach unter `semcat`s
  Engine-Anforderung mit.

## 5. `lttheme`-Umbenennungen

- `lttheme` → **`lttalk-themeengine`** (Paket, `.dtx` und die
  Basis-`.sty` der Engine selbst – von CTAN und TL bestätigt). CTAN/TL
  hatten das Paket zunächst für ein Theme selbst gehalten; der Name trägt
  den Engine-Charakter deshalb bewusst deutlicher als zuvor.
- `lttheme-tuc-2019` → **`lttalk-theme-tuc-2019`** (Bindestrich vor
  `2019` bleibt – so im tatsächlichen Rename konsistent durchgezogen,
  abweichend von einer früheren Zwischenüberlegung ohne Bindestrich)

Die mitgelieferten, fertigen Themen folgen einem eigenen, kürzeren Präfix
als die Engine selbst: `ltxtalk-theme-` → `lttalk-theme-` (nicht
`lttalk-themeengine-`). Paket, `.dtx` und Basis-`.sty` heißen also
übereinstimmend `lttalk-themeengine`, aber jedes einzelne fertige Thema
darin (und ebenso `lttalk-theme-tuc-2019`, ein eigenständiges, über die
Engine gebautes Thema) trägt das kürzere `lttalk-theme-`-Präfix:

| Heute | Neu |
|---|---|
| `lttalk-theme.sty` | `lttalk-themeengine.sty` |
| `lttalk-theme-minimal.sty` | `lttalk-theme-minimal.sty` |
| `lttalk-theme-magpie.sty` | `lttalk-theme-magpie.sty` |
| `lttalk-theme-hawk.sty` | `lttalk-theme-hawk.sty` |
| `lttalk-theme-sparrow.sty` | `lttalk-theme-sparrow.sty` |
| `lttalk-theme-bluebird.sty` | `lttalk-theme-bluebird.sty` |
| `lttalk-theme-goose.sty` | `lttalk-theme-goose.sty` |
| `lttalk-theme-anchovy.sty` | `lttalk-theme-anchovy.sty` |
| `lttalk-theme-carp.sty` | `lttalk-theme-carp.sty` |
| `lttalk-theme-font-sans.sty` | `lttalk-theme-font-sans.sty` |
| `lttalk-theme-font-serif.sty` | `lttalk-theme-font-serif.sty` |
| `lttalk-theme-font-mixed.sty` | `lttalk-theme-font-mixed.sty` |
| `lttalk-theme-font-libertinus.sty` | `lttalk-theme-font-libertinus.sty` |
| `lttalk-theme-font-newcm.sty` | `lttalk-theme-font-newcm.sty` |
| `lttalk-theme-font-texgyre.sty` | `lttalk-theme-font-texgyre.sty` |
| `lttalk-theme-tuc-2019.sty` | `lttalk-theme-tuc-2019.sty` |

Bereits in `lttheme/lttheme.dtx` umgesetzt (das `\generate`-Blatt listet
die neuen Dateinamen schon); die Dokumentation wird dort gerade
entsprechend überarbeitet, mit stärkerem Fokus auf die Engine als solche
(s. Abschnitt 11 zur Inversion: das Paket beschreibt zuerst, was die
Engine selbst leistet, die mitgelieferten Themen sind Beispiele dafür,
nicht der Zweck des Pakets).

Offen: das interne Makro `\lttalkversion` (spiegelt die Version der
*Abhängigkeit* `ltx-talk`, nicht die Version von `lttheme` selbst,
s. `lttheme/build.lua`) – vermutlich unverändert zu lassen, da es sich
auf die fremde Klasse bezieht, nicht auf das umbenannte Paket. Bei
Umsetzung gegenprüfen.

## 6. TDS-Platzierung nach Engine, nicht nach Bundle

Jedes Paket bekommt seinen eigenen Platz im Baum; zusätzlich wird nach
Engine-Bedarf getrennt (luatex/latex), nicht mehr pauschal `tex/luatex/`
für alles. Regel, abgeleitet aus dem `lua`-Feld, das `tools/packages.lua`
pro Modul führt:

| `lua`-Wert | Bedeutung | TDS-Wurzel | vorgeschlagener `ctanPath` |
|---|---|---|---|
| 🌕 `full_moon` | LuaLaTeX zwingend | `tex/luatex/<pkg>/` | `/macros/luatex/latex/<pkg>` |
| 🌓 `first_quarter_moon` | nutzt Lua, wenn verfügbar; degradiert sonst | `tex/luatex/<pkg>/` | `/macros/luatex/latex/<pkg>` |
| 🌑 `new_moon` | kein Lua nötig | `tex/latex/<pkg>/` | `/macros/latex/contrib/<pkg>` |
| ⚪ Perl-Skript | kein TeX-Format | `scripts/<pkg>/`, `doc/man/man1/` | `/support/<pkg>` |

Geklärt: auch Pakete, die Lua nur unter Umständen brauchen (🌓), gehen in
den Lua-Zweig – nicht nach *Minimalanforderung*, wie ursprünglich
angenommen. Nur 🌑 (kein Lua-Bezug) landet unter `tex/latex/`, und zwar
unter `contrib/` (CTANs übliche Kategorie für engine-unabhängige
Fremdpakete), nicht direkt unter `macros/latex/`.

Diese Pfade sind, wie alle `ctanPath`-Angaben, ein **Vorschlag** an CTAN;
CTAN behält sich eigene Einordnung vor (s. Abschnitt 13).

**Der `lua`-Wert gilt dem Paket, nicht nur seinem eigenen Code:** Eine
zwingende (nicht optionale) Abhängigkeit auf ein Paket mit höherem
Lua-Bedarf hebt den eigenen Wert auf den der Abhängigkeit an. `osgstyler`
in voller Funktion, und damit auch jedes Paket, das `osgstyler` zwingend
lädt, bleibt ohne Lua eingeschränkt – unabhängig davon, ob der eigene
Code je `\directlua` sieht. Konkret betrifft das `lttalk-themeengine`
(zwingend `osgstyler`) und darüber transitiv `lttalk-theme-tuc-2019`
(zwingend `lttalk-themeengine`): beide stehen trotz eigenem lua-freiem
Code als 🌓 im Register, nicht als 🌑 (s. Abschnitt 2, Fußnote ²; das
Register trägt diese Begründung als Kommentar bei den beiden Einträgen).
Eine rein optionale Integration (z. B. `semcat`s Umgang mit `osgstyler`)
zählt dagegen nicht mit – nur was ein Paket beim normalen Gebrauch
unbedingt mitzieht.

Technisch hängt `moduledir` an l3builds `bundle`-Variable
(`tdsroot/bundle/module`, l3build-variables.lua:69). Mit leerem `bundle`
entfällt das `osglecture`-Segment automatisch; `tdsroot` wird pro Modul aus
dem Register gesetzt statt der heutigen festen Zeile `tdsroot = "luatex"`
am Ende von `build.lua`.

## 7. Bundle-Mechanik in l3build

Geprüft an l3builds Quellcode (Release 2026-10-19): `main()` in
`l3build-stdmain.lua:161` entscheidet Root- vs. Modul-Verhalten einzig über
`module == ""`, nicht über `bundle`. Die Root-Orchestrierung für
`check`/`doc`/`install --full` bleibt also unabhängig davon funktionsfähig,
ob `bundle` gesetzt ist.

**Zwei getrennte Modullisten nötig:**

- `modules` (l3builds eigene globale Variable) = `{"osglecture",
  "osgdocmk"}` – ausschließlich die echten Bundle-Mitglieder. Diese Liste
  verwenden l3builds eingebaute `ctan()`/`upload()`-Funktionen intern für
  den Mehrmodul-Relay (`call(modules, "bundlecheck")` etc.).
- Eine neue, eigene Liste (z. B. `release_units`) mit allen zwölf
  Einheiten, für unsere eigenen `bundle_func`-Overrides von
  `install`/`tag`/`gittag` und eine neue Komfort-Schleife für „alles
  bauen" – unabhängig von l3builds `modules`-Konsum.

**`bundle` wird pro Modul gesetzt:** `"osglecture"` nur für `module ==
"osglecture"` oder `"osgdocmk"`, sonst `""`.

**Folge für `l3build ctan`/`upload` im Paketverzeichnis:** Mit `bundle ==
""` greift l3builds eingebauter Standalone-Pfad
(`l3build-ctan.lua:112`: `if bundle == "" then standalone = true end`) –
`install_files(tdsdir,true); copyctan()` direkt, ohne Relay über andere
Module. Das ist l3builds nativer Mechanismus für eigenständige Pakete im
Bundle-Repo; er wird heute nur durch das pauschal gesetzte
`bundle = "osglecture"` blockiert.

**Die heutigen Guards müssen selektiv werden**, nicht ersatzlos entfallen:

```lua
local BUNDLE_MEMBERS = { osglecture = true, osgdocmk = true }

if is_module and BUNDLE_MEMBERS[module] and target_list and target_list.ctan then
  target_list.ctan.func = function()
    print("'" .. module .. "' is packaged as part of the osglecture bundle: "
      .. "run 'l3build ctan' in the bundle root.")
    return 1
  end
end
-- analog für "upload"
```

Für die zehn eigenständigen Pakete entfällt der Guard – `l3build ctan`/
`upload` läuft dort nativ. Root-seitig müssen `ctan`/`upload` einen
expliziten `bundle_func` bekommen, der auf die neue `release_units`-Liste
fan-out't statt auf `modules` – ohne das würde l3build für den Root-Aufruf
selbst in den (jetzt global geltenden) Standalone-Modus fallen, da
`bundle == ""` dann auch dort zuträfe.

## 8. `ctan/`-Verzeichnisstruktur

Pro Paket eigene Textdateien statt einer sektionierten `note.txt`/
`announcement.txt` – aus zwei Gründen: l3builds eingebautes
`note_file`/`announcement_file` kann Sektionen nicht selbst parsen, und
getrennte Dateien lassen sich im CI byteweise gegen die Feldlimits linten
(`description` 4096, `note`/`announcement` 8192, `summary` 128 Byte, …)
bevor zwölf Uploads angestoßen werden.

```
ctan/
  upload.lua              -- baut uploadconfig aus Register + Dateien
  fragments/
    context-note.txt      -- Nachsatz "entwickelt im Rahmen von …"
    l3build-note.txt       -- die von TL akzeptierten Einschränkungen
  osglecture/
    summary.txt  description.html  announcement.txt  note.txt
  osgdocmk/        ... (geteilte Bundle-Submission mit osglecture)
  semcat/          ...
  lttalk-themeengine/  ...
  ... (je eine je Release-Einheit)
```

`version`/`update` pro Paket werden nicht mehr von Hand gepflegt, sondern
aus dem Register abgeleitet: `version` = die Modul-Tag-Version
(`<paket>/vX.Y.Z`), `update = (released.lua[pkg] ~= nil)` – die
Erstübermittlung ist dann automatisch die, die noch nicht in
`released.lua` steht.

## 9. Paket-Register als einzige Wahrheitsquelle

`tools/bundle-versions.lua` wird zu `tools/packages.lua` ausgebaut. Ein
Eintrag pro Release-Einheit trägt:

```lua
{
  dir      = "lttheme",                 -- heutiges Repo-Verzeichnis
  ctanpkg  = "lttalk-themeengine",      -- neuer CTAN-/TDS-Name
  tdsroot  = "latex",                   -- aus dem lua-Feld abgeleitet
  bundle   = nil,                       -- "osglecture" nur für osglecture/osgdocmk
  lua      = ":new_moon:",
  deps     = { run = {"osgstyler", "ltx-talk >= 0.5.3"}, doc = {"osgdoc","langselect"} },
  examples = { },                        -- s. Abschnitt 12
  ctan     = true,
}
```

Daraus speisen sich: `modules`/`release_units` in `build.lua`,
`checkdeps`/`typesetdeps` pro Modul, die Modultabelle in `README.md`, die
Abhängigkeitsabschnitte der Paket-READMEs (Abschnitt 10), die
`uploadconfig`-Felder pro Paket (Abschnitt 8) und die Eigentümerschaft
geteilter Hilfsdateien (Abschnitt 12).

Eine Umbenennung wird damit zu: Registerzeile ändern, ein
`tools/rename-package.lua` laufen lassen (`git mv` Verzeichnis + Dateien,
Vorkommen in `testfiles/`, `doc/`, `manual-src/` anpassen), Generatoren neu
laufen lassen. Bei fünf Umbenennungen in dieser Runde lohnt sich das Skript.

## 10. Paket-READMEs: generierter Abhängigkeitsabschnitt

Analog zu `tools/make-ctan-readme.lua` (gleiches Marker-Muster, gleicher
`--check`-Modus im CI):

```markdown
<!-- BEGIN DEPENDENCIES (generated by tools/make-package-readmes.lua) -->
## Dependencies

Required at run time: `osgstyler`, `ltx-talk` 0.5.3 or later
Required to build the documentation (`l3build doc`): `osgdoc`, `langselect`
Required to run the test suite (`l3build check`): `osgstyler`
<!-- END DEPENDENCIES -->
```

Zugleich entfallen die `README-<paket>.md`-Symlinks (`README.md →
README-<paket>.md`): Der Suffix existierte nur, weil der
Bundle-Install alle READMEs in ein gemeinsames Doc-Verzeichnis legte. Mit
eigenem `doc/<tdsroot>/<pkg>/` pro Paket kollidiert nichts mehr.

## 11. Dokumentations-Inversion: Bundle nur noch virtuell

Jedes Paket-README/CTAN-Text beginnt mit dem, was das Paket selbst tut, und
erwähnt den Projektzusammenhang erst am Ende, als Nutzungskontext, nicht
als Zugehörigkeit:

> *Statt:* „Teil des osglecture-Bundles, kann aber auch eigenständig
> genutzt werden."
> *Neu:* „… This package is used by, and developed alongside, the
> `osglecture` document class; see <https://github.com/werner-matthias/osglecture>
> for the lecture-generation project it grew out of."

Umgesetzt über `ctan/fragments/context-note.txt`, eingesetzt am **Ende**
jedes `note.txt`, nie am Anfang; ebenso der letzte Absatz im generierten
Abhängigkeitsblock (Abschnitt 10). Die Root-`README.md` bleibt die einzige
Stelle, die die volle Paketliste als Tabelle zeigt – das ist die laut
CTAN erlaubte virtuelle Erwähnung. Sie wird aber nicht mehr als
TDS/CTAN-Artefakt installiert (s. Abschnitt 12) – reine
GitHub-Dokumentation.

## 12. Export- vs. lokale/CI-Trennung

Betrifft ausschließlich `copyctan()` (CTAN-Export) – `checksuppfiles`/die
lokale Testausführung läuft über einen separaten l3build-Mechanismus und
bleibt unverändert; jedes Modul ist aus dem Repo heraus weiterhin einzeln
testbar.

Drei gefundene Dopplungsstellen in der heutigen `copyctan()`:

1. **`support/insert-pdf-tags.lua`** – reine Test-Hilfsdatei (vergleicht
   PDF-Tag-Bäume gegen `.tlg`-Referenzen), von sechs Modulen über
   `checksuppfiles` genutzt (`ansiterm`, `lttheme`, `tagdirtree`,
   `osgstyler`, `osglistings`, `tagbridge`→`semcat`), aber ohne Bezug zu
   einer der Paketfunktionalitäten. Heute blockweise in **jedes** Paket
   kopiert.
2. **`images/logos`** – laut `ARCHITECTURE.md`-Kommentar nur von
   `lttalk-theme-tuc-2019` gebraucht, aber ebenfalls blockweise an alle
   verteilt.
3. **`examples/`** – `osgstyler-article`/`-beamerlike`, `series-classic`/
   `-modern`, `tagdirtree-lines-skin` haben eindeutige Eigentümer am
   Namen erkennbar, werden aber an alle verteilt.

**Lösung:** Eigentümerschaft im Register (`shared_support_files`,
Abschnitt 9) statt Blockkopie:

- `insert-pdf-tags.lua`: auf **keinem** CTAN-Paket mitliefern (kein
  echter Eigentümer, reiner Testzeit-Bedarf). Jedes der sechs `note.txt`
  bekommt den Satz: „The PDF-tag comparison tests in testfiles/
  additionally need insert-pdf-tags.lua from the project's GitHub
  repository; this is a test-time convenience script, not required to
  use the package." – konsistent mit der bereits von TL akzeptierten
  Ausnahme, dass manche `l3build`-Ziele nicht ohne weitere Pakete
  funktionieren.
- `images/logos`, `examples/*`: nur an den im Register benannten
  Eigentümer kopieren.

Root-`build.lua` und `LICENSE` bleiben blockweise in jedem Paket – das ist
normale, erwartete CTAN-Praxis (jedes Paket braucht sein eigenes
`build.lua` und seine eigene Lizenzkopie), keine zu vermeidende Dopplung.

Mechanisch als Helper in `ctan/export.lua` (neu, analog zum bestehenden
`ctan/upload.lua`-Muster), von `copyctan()` nur konsultiert, wenn
`options["target"]` tatsächlich `ctan`/`upload` ist – keine zweite
`build.lua` pro Paket.

## 13. Offene Punkte

1. **Paketnamen-Liste** insgesamt steht noch unter Vorbehalt der
   schriftlichen TL-Bestätigung (s. Abschnitt 1).
2. **`\lttalkversion`**-Makroname bei Umsetzung von Abschnitt 5
   gegenprüfen.
3. Vollständige Perl-Namespace-Umbenennung (`OLLM::` → `OSGDocMk::`,
   Konfigurationsdateinamen) ist bewusst auf später verschoben
   (Abschnitt 3).

Geklärt und oben eingearbeitet: 🌓-Einordnung (Abschnitt 6), `manual-src`
(Abschnitt 2 – gehört in die Dokumentation von `osglecture`) und der
vorgeschlagene `ctanPath` für alle Pakete (Abschnitt 6) – für
`osglecture`+`osgdocmk` ohnehin kein offener Punkt, da dieses Bundle nur
aktualisiert wird und CTAN seinen bestehenden, gemischten `ctanPath`
(`/macros/luatex/latex/osglecture`, mit `osgdocmk` darunter im
`scripts`-Zweig) mit dem Release 2026-10-23 bereits akzeptiert hat; für
die zehn neuen Pakete ist es wie bei jeder Neueinreichung ein
Vorschlag, den CTAN ändern kann.
