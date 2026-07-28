# OLLM – Design

**Status:** Entwurf  
**Gegenstand:** Neuentwurf des OSG LaTeX Lecture Maker  
**Ausgangsbasis:** OLLM 0.11.1 und `osglecture` 0.6.0

## 1. Zweck dieses Dokuments

Dieses Dokument spezifiziert die geplante Verantwortung, die öffentliche
Schnittstelle und die Dateiverträge von OLLM. Es konsolidiert die bisher
getroffenen Designentscheidungen und hält verbleibende Detailfragen sichtbar.

OLLM ist Teil des `osglecture`-Bundles, aber nicht dessen Dokumentklasse. Die
Grenze ist bewusst:

- `osglecture` bestimmt Dokumentsemantik, Serienstruktur, Nummerierung,
  Darstellung und Referenzverhalten.
- OLLM wählt und orchestriert konkrete Builds.
- `latexmk` führt jeden einzelnen LaTeX-Build bis zum stabilen Ergebnis aus.
- Ein späteres Deploymentwerkzeug veröffentlicht geprüfte Artefakte.

Dieses Dokument beschreibt die Schnittstellen zu diesen Komponenten, nicht
deren vollständige interne Implementierung.

## 2. Ziele

OLLM soll:

1. die gewohnte kurze Bedienung der bisherigen Version bewahren;
2. LuaLaTeX-Builds zuverlässig über `latexmk` ausführen;
3. mehrere Dokumenttypen und Sprachvarianten eines Kapitels verwalten;
4. parallele Builds durch eindeutige Identitäten und getrennte
   Buildverzeichnisse ermöglichen;
5. einen normalisierten Buildauftrag für `osglecture` erzeugen;
6. Ergebnisse und dokumentübergreifende Inkonsistenzen auswerten;
7. Diagnose, Checks, Clean und Prune anbieten;
8. unter Unix, macOS und Windows installierbar sein;
9. mit `l3build` getestet und CTAN-/TeX-Live-tauglich paketiert werden können.

## 3. Nichtziele

OLLM soll nicht:

- die Wiederholungsläufe von LaTeX selbst steuern;
- Biber, Indexer oder ähnliche Werkzeuge an `latexmk` vorbei orchestrieren;
- die fachliche Serientopologie unabhängig von `osglecture` implementieren;
- TeX-Quellen nach Referenzen durchsuchen;
- Themes, Backends oder Nummerierung selbst interpretieren;
- die interne Datenbank `.fdb_latexmk` lesen oder erweitern;
- Deployment und Build dauerhaft in einer monolithischen Implementierung
  vermischen.

## 4. Systemgrenzen

```text
ollmconfig.toml
      |
      | Projektwerte, Profil, Buildmatrix
      v
     OLLM
      |
      | <jobname>.osgbuild.tex
      | jobname, Build- und Aux-Verzeichnis
      v
   latexmk
      |
      | LuaLaTeX, Biber, Indexer, Wiederholungsläufe
      v
  osglecture
      |
      | Serientopologie, Dokumentsemantik, Referenzen
      | <jobname>.osgresult.json
      | Referenzexporte
      v
     OLLM
      |
      | Check, Report, Status
      v
Deploymentwerkzeug
```

### 4.1 OLLM und latexmk

`latexmk` bleibt die Buildengine. Es besitzt insbesondere:

- die Analyse von `.log`, `.aux` und `.fls`;
- die interne Zustandsdatei `.fdb_latexmk`;
- die Entscheidung über weitere LaTeX-Läufe;
- Regeln für Biber, BibTeX, MakeIndex, Xindy oder spätere Lua-basierte
  Indexlösungen;
- Custom Dependencies;
- den kontinuierlichen Vorschaumodus;
- die gewöhnliche Bereinigung von Hilfsdateien.

**Rationale:** Die alte OLLM-Version wurde gerade deshalb als `latexmk`-RC-Datei
implementiert. Eine eigene Buildengine würde ausgereifte Funktionalität
duplizieren und wäre schlechter wartbar.

### 4.2 OLLM und osglecture

OLLM wählt einen Build aus; `osglecture` interpretiert ihn. OLLM übergibt unter
anderem Dokumenttyp und Sprache, kennt aber nicht die Bedeutung konkreter
Themes, Referenzbefehle oder Kapitelzähler.

Die Klasse liest nicht selbst `ollmconfig.toml`. OLLM ist der einzige Parser des
Projektmanifests und schreibt die für den konkreten Build benötigten effektiven
Werte in eine TeX-Auftragsdatei.

**Rationale:** Ein einziger Parser vermeidet unterschiedliche Merge-,
Validierungs- und Prioritätsregeln in Perl und LuaLaTeX. Gleichzeitig bleibt
die Klasse ohne TOML-Abhängigkeit.

### 4.3 OLLM und Nachbarpakete

- [`modeext`](../modeext/modeext.sty) stellt portable hierarchische
  Dokumentmodi bereit. OLLM wählt einen Dokumenttyp; die Zuordnung zu Modi und
  deren Hierarchie bleibt Aufgabe von `osglecture` und `modeext`.
- [`lttheme`](../lttheme/README.md) entwickelt Themes für `ltx-talk`.
  OLLM behandelt Beamer und `ltx-talk` normalerweise gleich, solange beide mit
  demselben LuaLaTeX-/latexmk-Verfahren gebaut werden.
- [`tagpax`](../tagpax/doc/ARCHITECTURE.md) ermöglicht die semantische
  Integration bereits erzeugter, getaggter PDFs. Ein Integrationsdokument kann
  damit Quellen oder fertige Kapitelartefakte kombinieren; OLLM verfolgt nur
  deren gemeldete Buildabhängigkeiten.
- [`langselect`](../langselect/README.md) implementiert sprachabhängigen Inhalt.
  OLLM wählt die konkrete Sprachvariante, während `langselect` und
  `osglecture` den Inhalt umsetzen.

## 5. Kontexte und Begriffe

### 5.1 Kontext

Der Kontext ist unabhängig vom Dokumenttyp:

```text
series
standalone
```

Im Serienkontext ist Verzeichnis-Discovery aktiviert. Im Standalone-Kontext
werden keine Annahmen über Eltern- oder Nachbarverzeichnisse getroffen.

### 5.2 Dokumenttyp

Dokumenttypen sind offen und registrierbar. Beispiele:

```text
slides
handout
script
book
web
```

Stabil ist der Registrierungs- und Adaptervertrag, nicht eine geschlossene
Liste von Typen.

### 5.3 Buildidentität

Ein Build wird mindestens durch folgende Werte identifiziert:

```text
context
series-id, falls vorhanden
unit-id
physische Einheitenkennung
doctype
language
variant, falls vorhanden
```

Die logische Kapitelnummer gehört nicht zur stabilen Identität. Sie ist ein
Ergebnis der für den konkreten Dokumenttyp gefilterten Serienfolge.

**Rationale:** Dieselbe Einheit kann in den Folien Kapitel 3, im Skript aber
Kapitel 2 sein. Außerdem soll eine Änderung der Reihenfolge Referenzen nicht als
Umbenennung der fachlichen Einheit erscheinen lassen.

## 6. Verzeichnisgrammatik

### 6.1 Form

```text
<nummer><profil>-<slug>
<nummer><profil>-<rolle>-<slug>
```

Dabei gilt:

- `nummer`: genau drei Dezimalziffern;
- `profil`: optional, ein oder zwei registrierte Buchstaben;
- `rolle`: optional, genau ein reserviertes Rollenzeichen;
- `slug`: nichtleer; er darf aus mehreren durch Bindestriche getrennten
  Wörtern bestehen.

Beispiele:

```text
020-processes
020a-processes
020as-detailed-processes
090a-a-posix-reference
015as-e-process-exercises
000a-i-script
```

### 6.2 Nummer

Die dreistellige Nummer ist ein Sortierschlüssel, keine sichtbare
Kapitelnummer.

**Rationale:** Umbenennen von `020-processes` nach `040-processes` ändert die
Reihenfolge, ohne die fachliche Identität `processes` zu ändern. Nach Filterung
für einen Dokumenttyp wird die logische Nummer neu berechnet.

### 6.3 Profile

Die bestehenden Profile bleiben kompatibel:

```text
leer   alle Dokumenttypen
a      Artikel-/Longform-Familie
b      Präsentationsfamilie
```

Ein zweites Zeichen darf ein Unterprofil bilden, beispielsweise:

```text
a
|- as  Skript
`- ab  Buch

b
|- bs  Vortragsfolien
`- bh  Handout
```

Die konkreten zweiten Zeichen werden mit der Dokumenttypenregistry
festgelegt. Unterprofile müssen eine Teilmenge ihres Oberprofils auswählen.

### 6.4 Rollen

Standardrollen:

```text
keine   content
a       appendix
e       excursus
i       integration
```

`content` ist der interne Default und wird im Verzeichnisnamen nicht als `c`
geschrieben.

Ein `excursus` ist geordnetes ergänzendes Material, erzeugt aber keine neue
Kapitelnummer. Er wird nach Filterung standardmäßig der vorhergehenden
sichtbaren Content-Einheit zugeordnet. Ohne vorhergehende Content-Einheit ist
er ungültig.

Ein `integration`-Verzeichnis baut ein Gesamtprodukt und ist selbst kein
nummeriertes Kapitel. Ein `appendix` gehört in einen eigenen strukturellen
Abschnitt und verwendet die Appendix-Nummerierung des jeweiligen Backends.

Weitere Rollen benötigen eine Schemaänderung und eine Kollisionsprüfung, da ein
einbuchstabiges Segment nach dem ersten Bindestrich als Rolle interpretiert
wird.

### 6.5 Identität bei Umbenennung

Der Slug ist standardmäßig die `unit-id`. Eine Änderung des Slugs invalidiert
die alte Identität und erzeugt eine neue Einheit. Alte Zustände werden durch
`prune` entfernt.

**Rationale:** Automatisches Umbenennungs-Tracking wäre mehrdeutig; beispielsweise
können `processes` und `process-management` gleichzeitig existieren. Sichtbar
brechende Referenzen sind robuster als heuristische Identitätsübernahme.

## 7. Projektmanifest

### 7.1 Name und Ort

Das Projektmanifest heißt:

```text
ollmconfig.toml
```

und liegt in der Serienwurzel. Es ist zugleich deren expliziter Marker.

`ollmconfig.pl` bezeichnet ausschließlich das Legacyformat. Sind altes und
neues Manifest gleichzeitig vorhanden, ist dies ein Fehler.

Ohne explizite Auswahl sucht OLLM vom Arbeitsverzeichnis aufwärts. `--config`
bezeichnet ausschließlich eine TOML-Datei; `--project-root` bezeichnet ein
Verzeichnis, das `ollmconfig.toml` enthalten muss. Explizite Angaben werden
nicht durch eine weitere Suche ergänzt.

### 7.2 Konfigurationsstufen

```text
eingebaute sichere Defaults
        <
ausgewähltes Projektprofil
        <
Projektmanifest
        <
lokale Maschinenkonfiguration
        <
konkrete CLI-Buildauswahl
```

Lokale Klassenoptionen werden erst in LaTeX verarbeitet. Für ausgewählte
LaTeX-Schlüssel existiert zusätzlich eine erzwungene Projektpolicy mit höherer
Priorität.

### 7.3 Projektprofil

Das Manifest wählt ein wiederverwendbares Profil:

```toml
schema = 1
profile = "OSG lecture/1"
```

Profilnamen sind deskriptive, nicht auf kurze technische Bezeichner beschränkte
Zeichenketten. Leerzeichen, Bindestriche und Schrägstriche sind zulässig. Name
und Hauptversion bilden zusammen die registrierte Identität eines Profils; OLLM
behandelt die Angabe als opake Kennung und leitet keine Semantik aus ihrer
Schreibweise ab.

Profile enthalten selten geänderte Defaults, etwa:

- Backendzuordnung;
- Corporate-Identity- und Themezuordnung;
- portable Projektpfade;
- Standardfeatures.

Profile werden zunächst mit dem Bundle ausgeliefert. Zusätzliche Suchpfade
können in der lokalen Konfiguration angegeben werden. Dort eingetragene relative
Pfade werden relativ zur Projektwurzel aufgelöst; absolute Pfade bleiben
zulässig. Die aufgelöste Profildefinition und ihre Version gehen in die
Konfigurationssignatur ein.

Das Projektmanifest enthält die tatsächlich projektspezifischen Angaben:

```toml
[project]
id = "bs"
title = "Betriebssysteme"

[languages]
available = ["de", "en"]
default = "de"

[languages.map]
de = "ngerman"
en = "british"

[targets.slides]
languages = ["de"]

[targets.handout]
languages = ["de"]

[targets.script]
languages = ["de", "en"]

[security]
shell_escape = "restricted"
```

Die auswählbaren Sprachen verwenden die kurzen BCP-47-Kennungen, die auch
`langselect` verwendet, beispielsweise `de`, `en` oder `ru`. Mit
`languages.map` kann optional die an die konkrete LaTeX-Sprachschicht
weiterzureichende Langform beziehungsweise Variante angegeben werden. So kann
etwa `en` auf `british` statt `english` abgebildet werden. OLLM prüft nur
Konsistenz und Eindeutigkeit der Kennungen. Ob eine Variante von Babel,
Polyglossia und `langselect` unterstützt wird, wird auf der LaTeX-Seite
validiert.

Targetnamen sind ebenfalls registrierte, erweiterbare Kennungen. OLLM besitzt
keine abgeschlossene Liste von Dokumenttypen. Ein Target wird durch das
gewählte Profil oder durch eine gefundene Targetdefinition registriert.
Zusätzliche Targetdefinitionen verwenden denselben Suchraum wie Profile.
Unbekannte Targetnamen sind ein Konfigurationsfehler.

Alle Targets einer Einheit verwenden dieselbe Quelldatei. Inhaltlich
auseinanderlaufende Fassungen werden durch getrennte Verzeichnisse und deren
Profil-/Rollenfilter modelliert, nicht durch unterschiedliche `source`-Angaben
im Projektmanifest.

Profil- und Targetdefinitionen besitzen zunächst nur eine kleine gemeinsame
Hülle:

```toml
schema = 1
kind = "profile"
name = "OSG lecture"
version = "1"
```

beziehungsweise:

```toml
schema = 1
kind = "target"
name = "slides"
version = "1.0"
doctype = "slides"
family = "presentation"
unit_profiles = ["b", "bs"]
```

Weitere fachliche Tabellen werden bei Bedarf ergänzt. Stabil sind zunächst
Schema, Art, registrierter Name, Version und die eindeutige Auflösung.
Definitionen gleichen Namens an mehreren Suchorten sind ein Fehler und werden
nicht stillschweigend überschrieben.

Targetdefinitionen nennen mit `unit_profiles` die ein- oder zweibuchstabigen
Einheitenprofile, auf die das Target eingeschränkt ist. Einheiten ohne Profil
bleiben für alle konfigurierten Targets gültig. Damit bleibt die Filterung von
`--all` erweiterbar und wird nicht aus Targetnamen abgeleitet.

### 7.4 Lokale Konfiguration

Maschinenabhängige Angaben gehören nicht in das versionierte Projektmanifest.
Eine optionale lokale Konfiguration darf insbesondere enthalten:

- Vieweradapter;
- lokale Such- und Installationspfade;
- UI-Defaults;
- private Deploymentziele oder Zugangsdaten.

Sie darf Projektsemantik wie Sprache, Dokumenttyp oder Nummerierung nicht
unbemerkt verändern.

Die projektlokale Datei heißt:

```text
.ollmconfig.local.toml
```

Der versteckte, eindeutige Name vermeidet zusätzliches Rauschen und
unterschiedliche Aliasnamen für dieselbe Konfigurationsstufe. Eine spätere
benutzerspezifische Konfiguration verwendet dasselbe Format an einem
plattformüblichen Konfigurationsort. Falls beide Ebenen vorhanden sind, wird
zuerst die benutzerspezifische und danach die projektspezifische lokale
Konfiguration angewandt.

Suchpfade für Profile und Targetdefinitionen dürfen relativ oder absolut sein.
Relative Pfade beziehen sich unabhängig vom Fundort der lokalen
Konfigurationsdatei immer auf die Projektwurzel. Damit bleibt eine lokale
Konfiguration zwischen Arbeitsrechnern verständlich und ein Projekt kann
portable, aber bewusst nicht global installierte Erweiterungen verwenden.

Der erste unterstützte Ausschnitt lautet:

```toml
schema = 1

[definitions]
paths = ["configuration", "/opt/osglecture/definitions"]
```

Lokale Suchpfade dürfen die Bedeutung eines Builds nicht unsichtbar machen:
Identität, Version und Inhalt der tatsächlich aufgelösten Profil- und
Targetdefinitionen gehen in Bericht und Konfigurationssignatur ein.

### 7.5 Strikte Schlüssel und Erweiterungen

Unbekannte Standardschlüssel, nicht auflösbare Profile oder Targets sowie
unbekannte Erweiterungsnamensräume sind Fehler. Diagnosen nennen mindestens
Datei, Quellzeile, betroffenen Schlüssel, tatsächliche Anforderung und die von
der installierten Fassung unterstützte Erwartung. Dazu führt der OLLM-Parser-
Wrapper zusätzlich zum TOML-Wertebaum einen Quellindex von Tabellenpfaden und
Schlüsseln.

Technische `schema`-Werte versionieren ausschließlich das jeweilige
Dateiformat. Sie sind nicht an die Bundle- oder OLLM-Version gekoppelt und
werden in normalen Ausgaben nicht hervorgehoben. Bei einem Konflikt nennt die
Fehlermeldung sowohl das gefundene als auch das unterstützte Schema. Profil-
und Targetversionen versionieren dagegen den fachlichen Inhalt der jeweiligen
Definition.

### 7.6 Erzwungene LaTeX-Policy

```toml
[latex.defaults]
theme = "osg"
numbering = "chapter"
references = "external-on-demand"

[latex.enforce]
theme = "osg-accessible"
numbering = "continuous"
```

`latex.enforce` überschreibt lokale Klassenoptionen. Zulässig sind nur
freigegebene LaTeX-Schlüssel, insbesondere:

- Nummerierungs- und Referenzpolicy;
- Theme oder Corporate-Identity-Profil;
- Backendauswahl;
- Barrierefreiheits- und zentrale Bibliografiepolicy.

Nicht erzwingbar sind Buildidentität, Dokumenttyp, Sprache, Titel, Rollen oder
abgeleitete Nummern.

Aktive Enforcement-Werte werden in Log und Report sichtbar gemacht.

### 7.7 TOML-Parser

Nur OLLM liest TOML. Ausgeliefert wird der reine Parserteil von
`TOML::Tiny` 0.22 (`Parser`, `Tokenizer`, `Grammar`) in unveränderter Form samt
Upstream-Lizenz. OLLM verwendet den strikten Lesemodus und benötigt weder den
TOML-Writer noch dessen zusätzliche Formatierungsabhängigkeiten.

Der Parser unterstützt TOML 1.0 und benötigt auf dem verwendeten Pfad nur
Perl-Core-Module. Name, Version und Herkunft erscheinen in `ollm doctor` und
in der normalisierten Konfigurationsinformation.

**Rationale:** TeX Live empfiehlt, Abhängigkeiten von Sprachmodulen für
ausgelieferte Skripte möglichst zu vermeiden, und garantiert insbesondere im
minimalen Windows-Perl keine CPAN-Drittmodule. Eine zwingende Abhängigkeit von
einer lokalen `TOML::Tiny`-Installation würde daher gerade das
Portabilitätsziel verletzen. Ein eigener Teilparser wäre dagegen semantisch
gefährlich. Die gebündelte, versionierte Upstream-Implementierung vermeidet
beide Probleme.

Eine separat per CPAN installierte Fassung ist nur für Entwicklung und
Vergleich vorgesehen; OLLM verwendet im Betrieb die mitgelieferte, getestete
Version.

## 8. BuildRequest und BuildSpec

### 8.1 BuildRequest

Der CLI-Parser normalisiert alte und neue Aufrufsyntax zunächst in einen
`BuildRequest`, beispielsweise:

```text
action      = build
context     = series
target      = script
language    = en
source      = main.tex
all         = false
resolve     = false
rebuild     = false
watch       = false
```

### 8.2 BuildSpec

Nach Manifest-, Profil- und Pfadauflösung entsteht pro konkretem Ziel ein
`BuildSpec`:

```text
job-id
context
project-root
series-id
physical-unit
unit-id
doctype
language
variant
source
build-directory
aux-directory
artifact
effective LaTeX configuration
enforced LaTeX configuration
shell-escape policy
config-signature
```

`--all` erzeugt ausschließlich die im Projektmanifest vorgesehenen Builds der
aktuellen Einheit, zusätzlich gefiltert durch deren Profil und Rolle.

## 9. Jobname und Verzeichnisse

### 9.1 Grammatik

```text
<series>-<physical-number>-<doctype>[+<variant>]-<language>-<slug>
```

Beispiele:

```text
bs-020-script-de-processes
bs-090-script-de-a-posix-reference
bs-020-handout+notes-en-detailed-processes
```

Die ersten vier mit `-` getrennten Felder werden von links gelesen. Der
gesamte verbleibende Rest ist der Slug; Bindestriche innerhalb des Slugs sind
daher eindeutig. Eine Variante wird mit `+` an den Dokumenttyp gebunden und
konkurriert ebenfalls nicht mit der Feldtrennung.

`physical-number` ist die dreistellige Ordnungsnummer des Verzeichnisses.
Profil und Rolle werden nicht nochmals im Jobnamen codiert. Sie stehen
zusammen mit dem vollständigen physischen Verzeichnisnamen im zugehörigen
Buildauftrag. Falls zwei ausgewählte Einheiten dadurch denselben Jobnamen
erhielten, ist das ein Konfigurationsfehler; OLLM muss die Kollision vor dem
Start von `latexmk` melden.

**Rationale:** Die Anordnung entspricht dem bisherigen OLLM-Modell mit dem
Thema am Ende. Sie erlaubt das Rücklesen von Dokumenttyp, Variante, Sprache und
Slug von links, ohne eine Suche von hinten oder Wissen über registrierte
Dokumenttypen zu verlangen. Die Zuordnung des Auftrags bleibt trotzdem durch
den Jobnamen abgesichert.

Serienkennung, Dokumenttyp und Sprache verwenden für den ersten Executor
ausschließlich ASCII-Buchstaben, Ziffern, Punkt und Unterstrich. Der Slug darf
zusätzlich einzelne Bindestriche als Segmenttrenner enthalten. Leere Segmente,
Pfadtrenner, Leerzeichen und sonstige Sonderzeichen sind unzulässig. Eine
spätere Erweiterung benötigt ein stabiles, reversibles Escapingverfahren.

Im Standalone-Kontext ist der Jobname opak. Dokumenttyp und Sprache werden dort
über Klassenoptionen beziehungsweise einen expliziten Buildauftrag bestimmt,
nicht aus dem Namen gelesen.

### 9.2 Buildname und Deploymentname

Der technische Buildname verwendet die vorab bekannte physische
Einheitenkennung:

```text
bs-020-script-de-processes.pdf
```

Ein späterer Deploymentname darf die erst von `osglecture` berechnete logische
Kapitelnummer enthalten:

```text
bs-02-script-de-processes.pdf
```

**Rationale:** OLLM soll die fachliche Kapitelnummer nicht vorab unabhängig von
der Klasse berechnen. Der Rückkanal vermeidet doppelte Discoverylogik.

### 9.3 Isolierte Builds

Jeder Build besitzt ein eigenes Build- beziehungsweise Aux-Verzeichnis. Der
erste Executor verwendet für Serienbuilds:

```text
<project-root>/.osglecture/build/
`- 020-processes/
   |- slides/de/
   |- handout/de/
   |- script/de/
   `- script/en/
```

Build- und Aux-Verzeichnis sind in dieser Stufe identisch; alle privaten
`latexmk`-, Recorder- und TeX-Ausgaben eines Builds bleiben dadurch gemeinsam
isoliert. `latexmk` wechselt mit `-cd` in das Quellverzeichnis, erhält aber
absolute Ausgabewege. Das Buildverzeichnis wird für den Prozess zusätzlich
über `TEXINPUTS` sichtbar gemacht, damit die Klasse die jobgebundene
Auftragsdatei findet. SyncTeX bleibt aktiviert. Ein später getrenntes
Artefaktverzeichnis darf diesen Vertrag erweitern, ohne die Buildidentität zu
ändern.

## 10. Buildauftragsdatei

### 10.1 Format

Die Auftragsdatei ist TeX:

```text
<jobname>.osgbuild.tex
```

Sie enthält ausschließlich generierte Konfigurationsanweisungen, weder
`\documentclass` noch das Hauptdokument.

Beispiel:

```tex
\OsgLectureBuildSetup{
  schema               = 1,
  job-id               = {bs-020-processes-slides-de},
  context              = series,
  series-id            = {bs},
  series-root          = {...},
  doctype              = slides,
  language             = de,
  available-languages  = {de,en},
  presentation-backend = beamer,
  identity-profile     = osg,
  theme                = osg,
  numbering            = chapter,
  references           = external-on-demand,
  config-signature     = {...}
}

\OsgLectureEnforceSetup{
  theme = osg-accessible
}
```

Die Klasse lädt im Serienmodus die durch `\jobname` bestimmte Datei. Sie prüft,
dass deren `job-id` mit `\jobname` übereinstimmt.

**Rationale:** Die Namensbindung verhindert, dass bei einem manuellen Aufruf
versehentlich der Jobname eines Builds mit dem Auftrag eines anderen kombiniert
wird.

Der erste implementierte Vertrag umfasst Schema, Job- und Serienidentität,
physische Einheit, Rolle und Profil der Einheit, Target, Dokumenttyp, Sprache,
Sprachmenge und -mapping, ausgewähltes Projektprofil sowie eine
Konfigurationssignatur. Der LaTeX-Leser liegt getrennt in
`osglecture-config.sty`, damit der Vertrag ohne die noch nicht vollständig
geschlossene Hauptklasse getestet werden kann. `osglecture.cls` lädt diesen
Baustein und bevorzugt eine passende Auftragsdatei gegenüber der bisherigen
Ableitung von Dokumenttyp und Sprache aus dem Jobnamen.

Die Konfigurationssignatur ist SHA-256 über das normalisierte Manifest, die
aufgelösten Profil- und Targetdefinitionen sowie die für den konkreten Build
relevante Einheit, Sprache und das Target. Rein lokale UI- oder
Deploymentwerte gehen nicht ein.

### 10.2 Aktualisierung

OLLM ersetzt die Auftragsdatei nur, wenn sich ihr effektiver Inhalt geändert
hat. Andernfalls würde ein reiner Zeitstempelwechsel unnötige Neubauten
auslösen.

## 11. Dateiabhängigkeiten und latexmk

### 11.1 `.fls`

LuaLaTeX erzeugt im Recorder-Modus eine `.fls`-Datei mit physischen Eingaben und
Ausgaben:

```text
PWD ...
INPUT .../main.tex
INPUT .../<jobname>.osgbuild.tex
OUTPUT .../<jobname>.aux
OUTPUT .../<jobname>.pdf
```

`.fls` bleibt autoritativ für konkrete Dateiabhängigkeiten. OLLM dupliziert
diese Liste nicht in eigenen JSON-Dateien.

### 11.2 `.fdb_latexmk`

`.fdb_latexmk` ist privater Zustand von `latexmk` und wird von OLLM weder
interpretiert noch erweitert.

### 11.3 Lua-gelesene und strukturelle Eingaben

Direkt durch Lua gelesene Dateien und Verzeichnisänderungen erscheinen nicht
zwangsläufig als normale Recorder-Eingaben. Die Implementierung muss deshalb
eine der folgenden Strategien verwenden:

- explizite Recorder-Registrierung;
- TeX-lesbare Snapshot-Datei;
- Struktursignatur in der Buildauftragsdatei.

Die endgültige Strategie ist offen. Sie muss sicherstellen, dass eine
Verzeichnisumordnung einen notwendigen LaTeX-Lauf auslöst.

## 12. Ergebnis- und Referenzdateien

### 12.1 Ergebnis

Nach einem erfolgreichen Lauf erzeugt die Klasse:

```text
<jobname>.osgresult.pending.json
```

Das Ergebnis enthält mindestens:

```text
schema
job-id
config-signature
context
series-id
unit-id
sort-key
role
doctype
language
logical-number
title
artifact
Seiten-/Folienzahl
Checks
verwendete semantische Abhängigkeiten
```

OLLM validiert die Pending-Datei nach erfolgreichem `latexmk` und veröffentlicht
sie atomar als:

```text
<jobname>.osgresult.json
```

### 12.2 LaTeX-naher Referenzexport

Der primäre Referenzexport ist eine dedizierte Aux-Datei:

```text
<doctype>-<language>.osgref.aux
```

Sie enthält ausschließlich die öffentliche Referenzoberfläche des Dokuments
und kann durch `xr`, `hyperref` oder eine L3-basierte Importschicht gelesen
werden.

Die normale Build-`.aux` wird nicht veröffentlicht, da sie backend- und
paketabhängiger privater Zustand ist.

### 12.3 Maschinenlesbarer Referenzindex

Zusätzlich entsteht:

```text
<doctype>-<language>.osgref.json
```

Er enthält Dokumentidentität, exportierte Properties und deren Signaturen.
OLLM verwendet ihn für Check, Report und Abhängigkeitsauflösung.

Aux- und JSON-Projektion entstehen aus demselben L3-Referenzmodell und tragen
dieselbe Generationskennung.

### 12.4 Semantische Abhängigkeiten

Semantische Abhängigkeiten werden zunächst in `.osgresult.json` gespeichert.
Beispiele:

```text
external-reference
continuation
artifact-name
logical-number
```

Eine Abhängigkeit nennt ausschließlich tatsächlich verwendete Eigenschaften.
So erzeugt eine durchlaufende Seitennummerierung eine Abhängigkeit von
`previous.last-page`, eine kapitelweise Nummerierung dagegen nicht.

### 12.5 Granularität

Die erste Version darf externe Referenzexports dokumentweise importieren. Dann
führt jede Änderung des tatsächlich importierten Exportdokuments zu einem
Neubau des Konsumenten. Später sind eigenschafts- oder
konsumentenspezifische Projektionen möglich.

**Rationale:** Dokumentgenaue Discovery verhindert bereits die meisten
Pseudoabhängigkeiten. Eine eigenschaftsgenaue Importdatei wäre präziser, würde
die erste Implementierung aber deutlich verkomplizieren.

## 13. Zustandslebenszyklus und Atomarität

### 13.1 Eigentum

Ein Build schreibt:

- ausschließlich in sein isoliertes Buildverzeichnis;
- zusätzlich nur in State-Dateien seiner stabilen Dokumentidentität.

Eine gemeinsam von mehreren Builds veränderte globale JSON-Registry ist
ausgeschlossen.

### 13.2 Promotion

LaTeX schreibt Pending-Dateien. OLLM:

1. wartet auf erfolgreichen Abschluss von `latexmk`;
2. validiert Syntax, Schema, Job-ID und Generationskennung;
3. prüft das erwartete Artefakt;
4. ersetzt den vorherigen gültigen Zustand atomar.

Temporär- und Zieldatei liegen auf demselben Dateisystem. Die
plattformabhängige Ersetzung wird in OLLM gekapselt.

### 13.3 Fehlgeschlagene Builds

Ein fehlgeschlagener Build darf einen vorherigen gültigen Export nicht
überschreiben. Report und Check müssen jedoch sichtbar machen, dass der letzte
Versuch fehlgeschlagen ist oder der bestehende Export nicht zur aktuellen
Konfiguration gehört.

### 13.4 Prune

`prune` entfernt Zustände, deren Dokumentidentität in der aktuellen
Projektstruktur nicht mehr existiert. Es unterstützt `--dry-run`.

## 14. Dokumentübergreifende Referenzen

Lokale Referenzen verwenden die normale LaTeX-/Hyperref-API. Externe
Referenzen erhalten eine eigene sichtbare API und adressieren:

```text
series-id
unit-id
doctype
language
label
```

Kapitelnummer, Jobname und physischer Aux-Pfad sind keine Bestandteile einer
externen Referenz.

`osglecture` registriert nur tatsächlich angeforderte externe Ziele. OLLM
interpretiert keine TeX-Befehle, sondern vergleicht gemeldete Abhängigkeiten
mit aktuellen Referenzexports.

Zyklen sind zulässig. `build --resolve` arbeitet deshalb gegebenenfalls in
Runden bis zu einem Fixpunkt oder einer konfigurierten Obergrenze.

Die genaue öffentliche Referenz-API wird in einem separaten
`osglecture`-Design spezifiziert.

## 15. CLI

### 15.1 Grundform

```text
ollm [globale Optionen] [Aktion] [Ziel] [Aktionsoptionen]
```

Aktionen:

```text
build      Defaultaktion
report
check
clean
prune
doctor
```

Ein eigener `plan`-Befehl ist nicht vorgesehen. Stattdessen:

```sh
ollm build --dry-run
```

### 15.2 Kompatibilität

Folgende Formen bleiben gültig:

```sh
ollm
ollm slides
ollm handout
ollm script
ollm lang=en script
ollm +lang=en +script
ollm debug slides
```

Aliase:

```text
beamer       -> slides
presentation -> slides
article      -> script
```

`debug` ohne Wert entspricht aus Kompatibilitätsgründen `debug=tex`.

### 15.3 Neue Optionen

Mindestens:

```text
--all
--language
--source
--resolve
--rebuild
--dry-run
--debug
--warnings
--color
--format
--config
--project-root
--non-interactive
```

`--all` bezeichnet nur die im Manifest vorgesehenen Builds der aktuellen
Einheit.

`--resolve` gehört zu `build`; `check` bleibt rein lesend.

### 15.4 OLLM- und latexmk-Argumente

Das historische `+`-Präfix für OLLM-Optionen bleibt unterstützt. Bekannte
nackte Wörter werden kompatibel als OLLM-Aktionen oder Dokumenttypen erkannt.
Normale unbekannte Minusoptionen werden an `latexmk` weitergereicht.

Die Durchreichung endet an den von OLLM kontrollierten Verträgen. Zusätzliche
RC-Dateien oder Perl-Startcode (`-r`, `-e`), andere Engines als LuaLaTeX,
alternative Ausgabeformate, `-out2dir`, indirekte Engineoptionen und
`-use-make` sind Fehler. OLLM besitzt Engine, Jobname, Recorder,
Arbeits-/Ausgabepfade, Shell-Escape-Policy und die Orchestration abhängiger
Builds. Diagnosen nennen den verletzten Vertrag und, soweit möglich, eine
eindeutige Alternative.

Eigenständige `latexmk`-Aktionen wie Clean, Help, Version oder
Konfigurationsauskunft dürfen durchgereicht werden. Nach ihnen erwartet OLLM
kein Buildartefakt. Widersprechen zusätzliche OLLM-Optionen der Aktion, etwa
`--rebuild` zusammen mit `latexmk -C` oder `--all` zusammen mit einer reinen
Informationsausgabe, wird der Aufruf vor dem Prozessstart abgewiesen. Das
spätere `ollm clean` darf die targetbezogene `latexmk`-Bereinigung in das
OLLM-Modell aus Level und Scope integrieren.

`--` behält seine Unix-Bedeutung als Ende der Optionsauswertung. Nachfolgende
Argumente sind Operanden, nicht pauschal `latexmk`-Optionen.

Bei tatsächlicher Mehrdeutigkeit warnt OLLM und nennt eine eindeutige
Schreibweise.

### 15.5 Quelle und Projekt

Defaultquelle:

```text
main.tex
```

Explizit:

```sh
ollm slides --source=talk.tex
```

Für Konfiguration und Projektwurzel existiert ausschließlich die neue Syntax:

```sh
ollm --config=/path/to/ollmconfig.toml
ollm --project-root=/path/to/project
```

Alte Spezialoptionen für alternative Konfigurationspfade werden nicht
weitergeführt.

### 15.6 Ausgabe

```text
--format=text
--format=json
```

`text` ist der menschenlesbare Default. Bei JSON-Ausgabe enthält `stdout`
ausschließlich versioniertes JSON; Diagnosen gehen nach `stderr`.

```text
--color=auto
--color=always
--color=never
```

`auto` aktiviert Farbe an einem geeigneten interaktiven Terminal und
deaktiviert sie bei Umleitung.

### 15.7 Debug und Warnungen

```text
--debug=tex
--debug=ollm
--debug=tex+ollm

--warnings=all
--warnings=important
--warnings=none
```

Integritätsfehler sind nicht unterdrückbar. Projektweite Checkpolicy und lokale
UI-Defaults werden getrennt konfiguriert.

### 15.8 Nichtinteraktiver Betrieb

```text
--non-interactive
```

verhindert Rückfragen, Viewerstarts und andere interaktive Aktionen. Explizit
vollständig beschriebene Clean-Aktionen benötigen dann keine zusätzliche
`--yes`-Option.

### 15.9 Exitcodes

Eine kleine stabile Menge unterscheidet mindestens:

- Erfolg;
- Build-/Checkfehler;
- ungültigen Aufruf oder ungültige Konfiguration;
- inkonsistente Dokumentabhängigkeiten;
- fehlende Werkzeuge oder ungeeignete Umgebung.

Die numerischen Werte werden vor Implementierung festgelegt und anschließend
als öffentliche API behandelt.

## 16. Report, Check und Doctor

### 16.1 Report

`report` beschreibt vorhandene Builds:

```text
Status
logische Kapitelnummer
Artefakt
Konfigurationsherkunft
aktive Enforcement-Werte
externe Abhängigkeiten
letzter gültiger Export
```

### 16.2 Check

`check` baut nichts. Es prüft mindestens:

- Auftrag, Jobname und Ergebnis stimmen überein;
- Artefakt vorhanden;
- Profile und Rollen gültig;
- Exkurs besitzt ein Vorgängerkapitel;
- externe Referenzen vorhanden und aktuell;
- Generationskennungen konsistent;
- erzwungene Optionen sichtbar;
- vorgesehene Sprach-/Zielkombination zulässig.

Ein späteres Deployment ruft `check` auf. Qualitätsprobleme dürfen mit einer
expliziten Force-Option übergangen werden; Integritäts- und Sicherheitsfehler
nicht.

### 16.3 Doctor

`doctor` prüft die Umgebung. Immer relevant sind:

- `latexmk`;
- LuaLaTeX und Mindestversion;
- OLLM und TOML-Parser;
- Auffindbarkeit des Bundles;
- Manifest und Schreibrechte;
- Shell-Escape-Policy.

Optionale Werkzeuge werden nur geprüft, wenn das effektive Projekt oder Backend
sie deklariert. Xindy ist daher keine feste Voraussetzung; eine Lua-basierte
Indexsortierung kann es ersetzen.

## 17. Clean und Prune

`clean` besitzt Level und Scope.

Level:

```text
aux      latexmk-Hilfsdateien
build    isoliertes Buildverzeichnis einschließlich lokalem Artefakt
state    veröffentlichte Resultat- und Referenzzustände
all      build + state
```

Scope:

```text
current
unit
series
```

Default:

```text
level = aux
scope = current
```

Deploymentartefakte werden nie durch OLLM-Clean entfernt.

`prune` entfernt ausschließlich verwaiste Zustände nach der aktuellen
Projektstruktur.

## 18. Sicherheit

Das Projektmanifest ist deklaratives TOML. Es ersetzt die Ausführung von
`ollmconfig.pl` mittels Perl-`eval`.

Shell-Escape ist projektseitig:

```text
off
restricted
full
```

Der Default des neuen Executors ist `restricted`. Die Policies werden explizit
auf `--no-shell-escape`, `--shell-restricted` beziehungsweise
`--shell-escape` abgebildet. OLLM ändert keine globale Allowlist. `doctor` prüft, ob
erforderliche Programme in der jeweiligen TeX-Distribution zulässig sind.

Vollständiges Shell-Escape muss ausdrücklich aktiviert werden.

Projekt- und lokale Pfade werden normalisiert und hinsichtlich erlaubter
Schreibziele validiert. Zugangsdaten gehören nicht in das versionierte
Projektmanifest.

## 19. Watch und Viewer

`latexmk` bleibt Eigentümer des Watch-Modus. OLLM kann zusätzlich nach einem
erfolgreichen Build einen konfigurierbaren Vieweradapter benachrichtigen.

Der Adapter darf den Buildkern nicht voraussetzen und muss unter
`--non-interactive` deaktiviert sein.

Der erste Executor reicht die Watch- und Vieweroptionen von `latexmk` durch.
Kontinuierlicher Betrieb ist auf genau einen konkreten BuildSpec beschränkt;
mit `--all` wäre der erste dauerhafte Prozess andernfalls ein Blocker für alle
folgenden Builds. Unter `--non-interactive` sind Viewer- und Druckaktionen
unzulässig, während kontinuierliches Bauen mit `-view=none` zulässig bleibt.

Projektmanifest, lokale Konfiguration sowie Profil- und Targetdefinitionen
werden vor dem Start von `latexmk` normalisiert. Änderungen an diesen Dateien
erfordern einen Neustart von OLLM. OLLM implementiert hierfür keinen zweiten
Dateiwächter neben `latexmk`.

Signalbedingte Prozessabbrüche werden von normalen Buildfehlern unterschieden.
Auf Systemen mit POSIX-Waitstatus wird insbesondere ein Abbruch mit Ctrl-C als
Exitcode 130 weitergegeben.

Getrennte Buildverzeichnisse müssen SyncTeX und Vorwärts-/Rückwärtssuche
erhalten. Dies ist ein Abnahmekriterium, kein optionales Komfortmerkmal.

## 20. Deployment

Deployment wird aus dem OLLM-Buildkern ausgelagert. Die endgültige API bleibt
offen.

Die Legacyform `ollm publish ...` kann später an das separate Werkzeug
delegieren. Das Deployment konsumiert geprüfte Resultat- und
Referenzinformationen und darf Dateinamen mit tatsächlichen logischen
Kapitelnummern bilden.

## 21. Implementierung und Portabilität

OLLM bleibt aus Nutzersicht selbststartend:

```sh
ollm slides
```

OLLM verwendet einen Perl-Launcher und eine getrennte `latexmk`-RC-Datei.
Unter Windows stellt ein dünner `ollm.cmd`-Wrapper denselben Perl-Aufruf
bereit. Während der Migration kann der Launcher kompatible Builds an
`ollm-legacy.rc` delegieren; neue Fachlogik gehört nicht in diese Legacy-Datei.

**Rationale:** Der Launcher kann CLI und Portabilität unabhängig von den
globalen Variablen einer `latexmk`-RC-Datei testen. Die RC-Datei bleibt ein
Buildadapter und muss nicht zugleich Unix-Programm, Windows-Einstieg und
Konfigurationsdatei sein.

Dabei gilt:

- eine gemeinsame CLI- und BuildSpec-Implementierung;
- keine duplizierte Fachlogik;
- Argumentlisten statt zusammengesetzter Shellbefehle;
- plattformneutrale Pfadbehandlung;
- keine Abhängigkeit von `tput` oder anderen Unix-Hilfsprogrammen.

## 22. Packaging

Das Bundle soll mit `l3build` test-, dokumentier-, installier- und
CTAN-paketierbar sein.

Für ausführbare Skripte gelten die TDS-/TeX-Live-Konventionen:

```text
scripts/osglecture/
```

Perl oder TeXLua sind bevorzugt, weil TeX Live sie auch unter Windows
bereitstellt. Benutzerkommandos benötigen global eindeutige Namen und werden
von der Distribution über Links beziehungsweise Windows-Wrapper exponiert.

CTAN-Aufnahme und TeX-Live-Aufnahme sind getrennte Schritte. Laufzeitabhängigkeiten
müssen eine kompatible Lizenz besitzen und in den Zieldistributionen verfügbar
oder zulässig mitgeliefert sein.

## 23. Tests

### 23.1 CLI

Parser-Tests normalisieren insbesondere:

- alte Syntax mit und ohne `+`;
- Aliase;
- Sprachen;
- registrierte Dokumenttypen;
- Mehrdeutigkeiten;
- Quell- und Projektpfade;
- Windows-Pfade mit Leerzeichen;
- unbekannte `latexmk`-Optionen.

### 23.2 Discovery

Tests decken ab:

- dreistellige Sortierung;
- Profile und Unterprofile;
- Rollen;
- unterschiedliche Folgen pro Dokumenttyp;
- Exkurse;
- Anhänge und Integrationsdokumente;
- Umbenennen und Prune.

### 23.3 Zustände

Tests decken ab:

- atomare Promotion;
- fehlgeschlagene Builds;
- parallele Schreiber unterschiedlicher Identitäten;
- beschädigte oder alte Schema-Versionen;
- veraltete Referenzen;
- zyklische Abhängigkeiten;
- Fixpunkt und Nichtkonvergenz.

### 23.4 Integration

Reale alte Vorlesungskapitel dienen als Akzeptanztests. Zusätzlich werden
Beamer- und später `ltx-talk`-Builds, Skript, Handout, Sprachen und
Standalone geprüft.

`lttheme` besitzt bereits visuelle Regressionstests; `tagpax` verwendet
mehrphasige Roundtrip- und Semantiktests. Diese Nachbarpakete zeigen die
gewünschte Trennung zwischen schnellen Schnittstellentests und aufwendigeren
End-to-End-Tests.

## 24. Migration

Die häufige CLI bleibt kompatibel. Gezielte Brüche:

- neues Manifest `ollmconfig.toml` statt ausführbarem `ollmconfig.pl`;
- alternative Konfiguration nur über `--config`;
- Projektwurzel nur über `--project-root`.

Ein Migrationswerkzeug oder Report soll alte Perl-Konfigurationen analysieren
und einen TOML-Entwurf erzeugen, soweit die Werte deklarativ erkennbar sind.
Beliebiger Perl-Code kann nicht automatisch migriert werden.

Alte Verzeichnisnamen bleiben gültig:

```text
NNN-slug
NNNa-slug
NNNb-slug
```

## 25. Offene Entscheidungen

Vor der Implementierung sind noch festzulegen:

1. konkrete zweiten Profilzeichen und eventuelle weitere Standardrollen;
2. genaue Profilfundorte;
3. vollständiges Schema von `ollmconfig.toml` über den implementierten Kern
   hinaus;
4. Strategie für Struktur- und Lua-Dateiabhängigkeiten;
5. JSON- und Aux-Schemata einschließlich Generationsmodell;
6. numerische Exitcodes;
7. genaue Clean-Levelnamen;
8. Benutzerkonfiguration zusätzlich zur projektlokalen Konfiguration;
9. Deploymentvertrag.

Diese Punkte dürfen die in diesem Dokument festgelegten Verantwortungsgrenzen
und Invarianten nicht aufweichen.
