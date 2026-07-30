# OLLM – Design

**Status:** Entwurf  
**Gegenstand:** Neuentwurf des OSG LaTeX Lecture Maker  
**Ausgangsbasis:** OLLM 0.11.1 und `osglecture` 0.6.0

## 1. Zweck dieses Dokuments

Dieses Dokument spezifiziert die geplante Verantwortung, die öffentliche
Schnittstelle und die Dateiverträge von OLLM. Es konsolidiert die bisher
getroffenen Designentscheidungen und hält verbleibende Detailfragen sichtbar.

Die bundleweit verbindlichen Kurzdefinitionen stehen im
[`GLOSSARY.md`](../GLOSSARY.md). Dieses Dokument verwendet die dort
festgelegten Begriffe und ergänzt ihre Rationales.

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

### 2.1 Implementierungsstatus und TODO

Der neue Executor implementiert derzeit normale und kontinuierliche Builds,
`build --all`, `build --dry-run`, Standalone-Builds sowie die grundlegende
Werkzeugprüfung durch `doctor`. Native Clean- und Informationsaktionen von
`latexmk` können für einen aufgelösten Build durchgereicht werden.

Folgende von der CLI bereits erkannte OLLM-Funktionen sind noch nicht
implementiert und enden mit Exitcode 69:

- **TODO:** `report`;
- **TODO:** das rein lesende `check`;
- **TODO:** OLLM-spezifisches `clean` mit Level und Scope;
- **TODO:** `prune`;
- **TODO:** Fixpunkt-Builds mit `build --resolve`.

Implementiert sind inzwischen der LaTeX-nahe Ergebnisrückkanal, atomare
Resultat-/Referenzpromotion und der jobgebundene Snapshot der zuletzt
promotierten Referenzexports. TODO bleiben deren Auswertung durch `check` und
`report`, Fixpunktrunden sowie die vollständigen projekt- und
backendabhängigen `doctor`-Prüfungen.

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
      | <jobname>.osgresult.aux
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

- [`osglecture-modes`](../osglecture-modes/osglecture-modes.dtx) stellt
  portable hierarchische
  Dokumentmodi bereit. Der kanonische Dokumenttyp ist zugleich der aktive
  Blattmodus. OLLM transportiert diesen Blattmodus, aber keine Modusmatrix.
  Dokumentprofile registrieren den Graphen auf der TeX-Seite; seine
  Validierung, transitive Auswertung und die bedingte Verarbeitung bleiben
  Aufgabe von `osglecture` und `osglecture-modes`.
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
werden keine Annahmen über Eltern- oder Nachbarverzeichnisse getroffen. Der
neue Executor baut dort standardmäßig `main.tex` im Quellverzeichnis, erzeugt
keine Auftragsdatei und erzwingt weder Serienjobnamen noch OLLM-Ausgabepfade.
Normale latexmk-Optionen für `outdir`, `auxdir` und `out2dir` bleiben zulässig;
Dokumenttyp, Sprache und Dokumentprofil werden ausschließlich als
Klassenoptionen angegeben.

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

### 5.3 Target, Dokumenttyp, Modus und Backend

Target und Dokumenttyp beschreiben dieselbe fachliche Auswahl an zwei
Systemgrenzen:

- `target` ist die Buildperspektive und wird von CLI, Manifest und OLLM
  verwendet;
- `doctype` ist die Dokumentperspektive und wird von `osglecture` verwendet.

Für einen normalisierten konkreten Build gilt:

```text
target = doctype = aktiver Blattmodus
```

CLI-Aliase wie `presentation`, `beamer` oder `article` werden vor der
BuildSpec-Erzeugung auf den kanonischen Targetnamen normalisiert und erscheinen
nicht als abweichende Dokumenttypen im Auftrag. Targetdefinitionen führen
`name` und `doctype` weiterhin explizit, damit beide Schnittstellen prüfbar
bleiben; eine Abweichung benötigt einen ausdrücklich versionierten
Adaptervertrag und ist kein gewöhnlicher Alias.

Der Modus ist keine weitere unabhängige Builddimension. Er ergänzt den aktiven
Dokumenttyp um dessen transitive Zugehörigkeit zu allgemeineren Modi. Die
Modusmatrix ist ein gerichteter azyklischer Graph und darf mehrere Eltern
enthalten:

```text
slides  -> presentation
handout -> presentation, print
script  -> longform, print
article -> longform, print
```

Damit ist bei `doctype = handout` sowohl `handout` als auch `presentation` und
`print` aktiv. Die Matrix darf abstrakte Modi enthalten, die selbst kein
baubares Target sind. Namen, Elternbeziehungen und Aliase werden strukturell
validiert; unbekannte Knoten, unbekannte Eltern, Aliaszyklen und
Hierarchiezyklen sind Fehler.

Das Backend ist die technische Realisierung eines Dokumenttyps und wird aus
dem Dokumenttyp sowie der effektiven Dokumentprofil-/Projektpolicy gewählt:

```text
backend = adapter(doctype, document-profile, project-policy)
```

So darf beispielsweise `slides` durch `beamer` oder `ltx-talk` realisiert
werden, ohne Target, Dokumenttyp oder Autorenmodus zu ändern. OLLM übergibt
Dokumenttyp und effektives Dokumentprofil. Dessen Deskriptor registriert vor
der Aktivierung des Blattmodus die benötigte Modusmatrix und deklariert den
Backendadapter. `osglecture` prüft, dass der gewählte Adapter den Dokumenttyp
unterstützt, und lädt ihn. Autorenquellen wählen Inhalte nach Dokumenttyp oder
Obermodus, nicht nach Backendnamen.

### 5.4 Buildidentität

Vor dem ersten erfolgreichen LaTeX-Lauf wird ein konkreter Buildauftrag durch
folgende bereits auflösbare Werte identifiziert:

```text
context
series-id, falls vorhanden
physische Einheitenkennung
doctype
language
```

Der veröffentlichte Dokument- und Referenzzustand verwendet dagegen die von
`\lecture` deklarierte logische `unit-id`:

```text
series-id
unit-id
doctype
language
```

Die physische Einheitenkennung bleibt Eigentümer von Buildverzeichnis und
Lock, ist aber kein Bestandteil einer externen Referenz. Die logische
Kapitelnummer gehört zu keiner der beiden stabilen Identitäten. Sie ist ein
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

### 6.3 Unit-Scopes

Die bestehenden Scope-Codes bleiben kompatibel:

```text
leer   alle Dokumenttypen
a      Artikel-/Longform-Familie
b      Präsentationsfamilie
```

Ein zweites Zeichen darf einen engeren Subscope bilden, beispielsweise:

```text
a
|- as  Skript
`- ab  Buch

b
|- bs  Vortragsfolien
`- bh  Handout
```

Die konkreten zweiten Zeichen werden mit der Dokumenttypenregistry
festgelegt. Subscopes müssen eine Teilmenge ihres übergeordneten Scopes
auswählen.

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

Der Verzeichnisslug ist keine logische `unit-id`. Die kanonische ID wird
ausdrücklich durch die Lecture-/Kapitelstruktur in der Quelle deklariert. Eine
Umbenennung oder Umordnung des Verzeichnisses verändert daher die öffentliche
Dokument- und Referenzidentität nicht.

Der physische Buildzustand darf nach einer Verzeichnisumbenennung neu angelegt
werden; `prune` entfernt den verwaisten alten physischen Zustand. OLLM versucht
keine heuristische Zuordnung alter und neuer Verzeichnisse. Der letzte
promotete logische Referenzzustand bleibt davon getrennt und wird durch einen
erfolgreichen Build derselben logischen Unit-ID ersetzt.

Eine logische Unit-ID, für die noch kein erfolgreich promotierter Zustand
existiert, wird nicht ersatzweise aus Slug, physischer Nummer, Jobname oder
Verzeichnisnachbarschaft abgeleitet. OLLM durchsucht auch keine TeX-Quelle nach
`\lecture`. Die Zuordnung wird erst durch einen erfolgreichen LaTeX-Lauf der
betreffenden Unit bekannt.

OLLM darf komfortable, Cargo-artige Verwaltungsbefehle wie `init`,
`unit new`, `unit move` und `unit remove` später ergänzen. Sie können Gerüste
erzeugen, Manifest- und Integrationsangaben konsistent ändern sowie gezielte
Neubauten oder Prune-Schritte anbieten. Diese Befehle sind reine
Komfortfunktionen: Umbenennen und Verschieben mit gewöhnlichen
Dateisystemwerkzeugen muss korrekt bleiben. Eine physische UUID-Markierung
kann später ergänzt werden, ist aber weder Bestandteil der logischen
Unit-ID noch Voraussetzung der ersten Version.

## 7. Projektmanifest

### 7.1 Name und Ort

Das Projektmanifest heißt:

```text
ollmconfig.toml
```

und liegt in der Serienwurzel. Es ist zugleich deren expliziter Marker.

Ohne explizite Auswahl sucht OLLM vom Arbeitsverzeichnis aufwärts. `--config`
bezeichnet ausschließlich eine TOML-Datei; `--project-root` bezeichnet ein
Verzeichnis, das `ollmconfig.toml` enthalten muss. Explizite Angaben werden
nicht durch eine weitere Suche ergänzt.

### 7.2 Konfigurationsstufen

```text
eingebaute sichere Defaults und ausgewähltes Bundle-Preset
        <
Nutzerdefaults
        <
Projektmanifest
        <
konkrete CLI-Buildauswahl
```

Lokale Klassenoptionen werden erst in LaTeX verarbeitet. Für ausgewählte
LaTeX-Schlüssel existiert zusätzlich eine erzwungene Projektpolicy mit höherer
Priorität.

Die Dokumentprofilauswahl bildet eine Ausnahme von der allgemeinen
CLI-Buildauswahl: Sie darf nicht pro Auftrag überschrieben werden. Die
Profilklasse des Targets wählt `presentation_profile` oder `script_profile`.
Für diesen Schlüssel gilt die implementierte Priorität:

```text
eingebauter Fallback
        <
Defaults des Bundle-Presets
        <
Nutzerdefaults
        <
latex.defaults des Projektmanifests
        <
effektives Enforcement
```

Beim Enforcement werden zuerst Werte des Bundle-Presets und danach
`latex.enforce` des Projektmanifests zusammengeführt. Der aufgelöste Wert wird
als `document-profile` im BuildSpec transportiert. Eine CLI-Buildauswahl kann
ihn nicht ändern. Eine explizite TeX-Klassenoption `profile=...` muss bei
geladener Auftragsdatei mit ihm übereinstimmen.

### 7.3 Bundle-Preset

Das Manifest kann ein wiederverwendbares, versioniertes Bundle-Preset wählen:

```toml
schema = 1
bundle_preset = "OSG lecture/1"
```

Presetnamen sind deskriptive, nicht auf kurze technische Bezeichner beschränkte
Zeichenketten. Leerzeichen, Bindestriche und Schrägstriche sind zulässig. Name
und Hauptversion bilden zusammen die registrierte Identität eines Presets; OLLM
behandelt die Angabe als opake Kennung und leitet keine Semantik aus ihrer
Schreibweise ab.

Bundle-Presets enthalten selten geänderte Defaults, etwa:

- Backendzuordnung;
- Corporate-Identity- und Themezuordnung;
- portable Projektpfade;
- Standardfeatures.

Bundle-Presets werden zunächst mit dem Bundle ausgeliefert. Zusätzliche Suchpfade
können in der lokalen Konfiguration angegeben werden. Dort eingetragene relative
Pfade werden relativ zur Projektwurzel aufgelöst; absolute Pfade bleiben
zulässig. Die aufgelöste Presetdefinition und ihre Version gehen in die
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
gewählte Bundle-Preset oder durch eine gefundene Targetdefinition registriert.
Zusätzliche Targetdefinitionen verwenden denselben Suchraum wie Bundle-Presets.
Unbekannte Targetnamen sind ein Konfigurationsfehler.

Alle Targets einer Einheit verwenden dieselbe Quelldatei. Inhaltlich
auseinanderlaufende Fassungen werden durch getrennte Verzeichnisse und deren
Scope-/Rollenfilter modelliert, nicht durch unterschiedliche `source`-Angaben
im Projektmanifest.

Bundle-Preset- und Targetdefinitionen besitzen zunächst nur eine kleine gemeinsame
Hülle:

```toml
schema = 1
kind = "bundle-preset"
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
profile_class = "presentation"
unit_scopes = ["b", "bs"]
```

Weitere fachliche Tabellen werden bei Bedarf ergänzt. Stabil sind zunächst
Schema, Art, registrierter Name, Version und die eindeutige Auflösung.
Definitionen gleichen Namens an mehreren Suchorten sind ein Fehler und werden
nicht stillschweigend überschrieben.

Targetdefinitionen nennen mit `unit_scopes` die ein- oder zweibuchstabigen
Unit-Scopes, auf die das Target eingeschränkt ist. Einheiten ohne Scope-Code
bleiben für alle konfigurierten Targets gültig. Damit bleibt die Filterung von
`--all` erweiterbar und wird nicht aus Targetnamen abgeleitet.

`profile_class` wählt ausschließlich den projektweiten Profilschlüssel. Schema
1 kennt `presentation` und `longform`; daraus folgen
`presentation_profile` beziehungsweise `script_profile`. Der Wert ist keine
Moduskante und aktiviert keinen Autorenmodus.

Die Modusmatrix ist kein Bestandteil einer Targetdefinition oder des
BuildSpec. Sie gehört zum TeX-Integrationsvertrag des ausgewählten
Dokumentprofils. Dessen `mode-setup-file` deklariert Blattmodus, Elternkanten
und abstrakte Modi, bevor `osglecture` den kanonischen Dokumenttyp aktiviert
und den Graphen finalisiert. Damit existiert für die Modussemantik nur eine
Quelle und OLLM muss weder Graphen zusammenführen noch interpretieren.

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

Suchpfade für Bundle-Presets und Targetdefinitionen dürfen relativ oder absolut sein.
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
Identität, Version und Inhalt der tatsächlich aufgelösten Bundle-Preset- und
Targetdefinitionen gehen in Bericht und Konfigurationssignatur ein.

### 7.5 Strikte Schlüssel und Erweiterungen

Unbekannte Standardschlüssel, nicht auflösbare Bundle-Presets oder Targets sowie
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

Eine Ausnahme ist die zeitlich vor `\documentclass` benötigte
LaTeX-Kernel-Metadateninitialisierung:

```toml
[latex.document_metadata]
policy = "enforce"
file = "shared/document-metadata.tex"
```

OLLM prüft, dass die Datei innerhalb des Projektroots liegt, nimmt ihren Inhalt
in die Konfigurationssignatur auf und liest sie über latexmks kontrollierten
PreTeX-Mechanismus ein. Zuvor definiert es
`\OsgLectureRequestedLanguage` aus der normalisierten Buildsprache. OLLM
untersucht `main.tex` nicht; ein konkurrierender `\DocumentMetadata`-Aufruf ist
bewusst ein vom Nutzer aufzulösender LaTeX-Fehler. Daher sind benutzerseitige
`-pretex`- und `-usepretex`-Optionen reserviert.

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

Nach Manifest-, Bundle-Preset- und Pfadauflösung entsteht pro konkretem Ziel ein
`BuildSpec`:

```text
job-id
context
project-root
series-id
physical-unit
unit-scope
unit-id, sobald vorab aus einem validierten Zustand bekannt
target
doctype
profile class
bundle preset
document profile
language
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

Der BuildSpec enthält Target, Dokumenttyp, Profilklasse und das aufgelöste
Dokumentprofil. Modusmatrix und Backendadapter sind bewusst keine
OLLM-Builddimensionen: Beide werden durch den installierten
Profildeskriptor auf der TeX-Seite festgelegt und dort gegen den Dokumenttyp
validiert.

Der Schema-1-Auftrag enthält `unit-id` nur, wenn sie bereits aus einem
validierten, promotierten Zustand bekannt ist. Beim ersten Build wird sie nicht
aus dem Verzeichnisslug erfunden. Die Klasse meldet die durch `\lecture`
deklarierte ID im Ergebnis zurück; nachfolgende Builds erhalten den bekannten
Wert zur Konsistenzprüfung.

## 9. Jobname und Verzeichnisse

### 9.1 Grammatik

```text
<series>-<physical-number>-<doctype>-<language>-<slug>
```

Beispiele:

```text
bs-020-script-de-processes
bs-090-script-de-a-posix-reference
```

Die ersten vier mit `-` getrennten Felder werden von links gelesen. Der
gesamte verbleibende Rest ist der Slug; Bindestriche innerhalb des Slugs sind
daher eindeutig.

`physical-number` ist die dreistellige Ordnungsnummer des Verzeichnisses.
Profil und Rolle werden nicht nochmals im Jobnamen codiert. Sie stehen
zusammen mit dem vollständigen physischen Verzeichnisnamen im zugehörigen
Buildauftrag. Falls zwei ausgewählte Einheiten dadurch denselben Jobnamen
erhielten, ist das ein Konfigurationsfehler; OLLM muss die Kollision vor dem
Start von `latexmk` melden.

**Rationale:** Die Anordnung entspricht dem bisherigen OLLM-Modell mit dem
Thema am Ende. Sie erlaubt das Rücklesen von Dokumenttyp, Sprache und Slug von
links, ohne eine Suche von hinten oder Wissen über registrierte
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
  job-id               = {bs-020-slides-de-processes},
  context              = series,
  series-id            = {bs},
  series-root          = {...},
  unit-scope           = b,
  doctype              = slides,
  language             = de,
  available-languages  = {de,en},
  bundle-preset        = {OSG lecture/1},
  document-profile     = beamer,
  presentation-profile = beamer,
  script-profile       = scrbook,
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
Sprachmenge und -mapping, ausgewähltes Bundle-Preset sowie eine
Konfigurationssignatur. Der LaTeX-Leser liegt getrennt in
`osglecture-config.sty`, damit der Vertrag ohne die noch nicht vollständig
geschlossene Hauptklasse getestet werden kann. `osglecture.cls` lädt diesen
Baustein und bevorzugt eine passende Auftragsdatei gegenüber der bisherigen
Ableitung von Dokumenttyp und Sprache aus dem Jobnamen.

Die Konfigurationssignatur ist SHA-256 über das normalisierte Manifest, die
aufgelösten Bundle-Preset- und Targetdefinitionen sowie die für den konkreten Build
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
zwangsläufig als normale Recorder-Eingaben. OLLM berechnet deshalb bei jeder
Serienauflösung eine kanonische Struktursignatur. Ihre Eingabe ist die nach
physischem Unit-Namen sortierte Liste der unmittelbar unter der Serienwurzel
erkannten Units mit:

```text
physical-unit
physical-number
unit-scope
unit-role
slug
```

Absolute Projektpfade, Zeitstempel und Dateisystem-Reihenfolge gehen nicht in
die Signatur ein. Nicht als Unit benannte Nachbarverzeichnisse werden
ignoriert. Die Signatur steht als `structure-signature` in jedem
Serien-BuildSpec und geht zusätzlich in dessen `config-signature` ein. Dadurch
verändert eine Umbenennung oder Umordnung die TeX-lesbare Buildauftragsdatei
und wird für `latexmk` zu einer gewöhnlichen Dateiänderung.

Nach einer Strukturänderung führt OLLM die Discovery vollständig neu aus.
Eine unbekannte Zuordnung wird nicht heuristisch rekonstruiert; im Zweifel
werden alle davon abhängigen Serienbuilds bei ihrem nächsten Auftrag
invalidiert. Der separat promotierte logische Zustand bleibt bis zu einem
erfolgreichen Ersatzbuild verfügbar. Ein Umzug der gesamten Serienwurzel bei
identischer relativer Struktur ändert die Struktursignatur nicht. Die
Behandlung weiterer direkt durch Lua gelesener Dateien bleibt separat
festzulegen.

## 12. Ergebnis- und Referenzdateien

### 12.1 Ergebnis

Für jeden Buildversuch erzeugt OLLM eine `generation-id` und übergibt sie in
der Auftragsdatei. Nach einem erfolgreichen LaTeX-Lauf erzeugt die Klasse einen
strikten, LaTeX-nahen Ergebnisumschlag:

```text
<jobname>.osgresult.aux
```

Er enthält in Schema 1:

```text
schema
generation-id
job-id
series-id
unit-id
physical-unit
unit-role
doctype
language
```

Die LaTeX-Datei ist der normative Rückkanal. OLLM validiert sie zusammen mit
Artefakt und Referenzexport und erzeugt daraus intern ein abgeleitetes
`result.json`. Dieses JSON ist Zustand für Check, Report und Debugging, aber
kein LaTeX-Laufzeitvertrag und keine zweite fachliche Quelle.

Normale Units der Rollen Inhalt, Anhang und Exkurs müssen genau ein
`\lecture[short]{title}{unit-id}` deklarieren. Integrationsunits (`unit-role =
i`) sind davon ausgenommen und veröffentlichen zunächst keinen eigenen
Referenzzustand.

### 12.2 LaTeX-naher Referenzexport

Der primäre Referenzexport ist eine dedizierte Aux-Datei im isolierten
Buildverzeichnis:

```text
<jobname>.osgref.aux
```

Sie enthält ausschließlich die öffentliche Referenzoberfläche des Dokuments
und kann durch `xr`, `hyperref` oder eine L3-basierte Importschicht gelesen
werden.

Die normale Build-`.aux` wird nicht veröffentlicht, da sie backend- und
paketabhängiger privater Zustand ist.

Der Export trägt einen Umschlag mit Schema, Generation und vollständiger
Dokumentidentität. Bei der Promotion wird er unverändert als
`reference.osgref.aux` in die Generation kopiert.

### 12.3 Jobgebundener Referenzsnapshot

Vor jedem Build erzeugt OLLM `<jobname>.osgrefs.tex`. Diese nur gelesene
Registry bildet alle aktuell promotierten logischen Dokumentidentitäten auf
ihren Referenzexport und ihr PDF ab. Sie ist ein Snapshot, keine gemeinsam
veränderte globale Datenbank. Noch nie gebaute Ziele fehlen und bleiben beim
Import als gewöhnliche nicht auflösbare Referenzen sichtbar.

### 12.4 Semantische Abhängigkeiten

Tatsächliche externe Imports schreibt LaTeX kontrolliert nach
`<jobname>.osgref-used.aux`. OLLM validiert die Generationskennung und
übernimmt die Records in das abgeleitete `result.json`.
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
- bei erfolgreicher Promotion zusätzlich nur in State-Dateien seiner stabilen
  Dokumentidentität.

Eine gemeinsam von mehreren Builds veränderte globale JSON-Registry ist
ausgeschlossen.

### 13.2 Promotion

OLLM:

1. wartet auf erfolgreichen Abschluss von `latexmk`;
2. validiert Ergebnisumschlag, Referenzumschlag, Schema, Identitäten und
   Generationskennung;
3. prüft das erwartete PDF-Artefakt;
4. schreibt eine unveränderliche Generation;
5. ersetzt ausschließlich den kleinen Zeiger `current.tex` atomar.

Der Zustand ist für jedes Tupel `(series-id, unit-id, doctype, language)`
getrennt. Generation und Zeiger liegen auf demselben Dateisystem. Damit kann
ein beschädigter oder abgebrochener Versuch die letzte gültige Generation
nicht teilweise überschreiben.

### 13.3 Fehlgeschlagene Builds

Ein fehlgeschlagener Build darf einen vorherigen gültigen Export nicht
überschreiben. Report und Check müssen jedoch sichtbar machen, dass der letzte
Versuch fehlgeschlagen ist oder der bestehende Export nicht zur aktuellen
Konfiguration gehört.

### 13.4 Sichtbarkeit und Recovery

`.osglecture` ist OLLM-eigener, nicht von Autoren zu editierender Zustand, aber
bewusst kein opakes Binärformat. Zeiger sind kleine TeX-Dateien, abgeleitete
Records lesbares JSON und Referenzexports lesbare Aux-Dateien.

Der gesamte Zustand ist aus Quellen und direkten Builds rekonstruierbar. Wenn
kein OLLM-/latexmk-Prozess läuft, ist deshalb das Löschen von `.osglecture` eine
unterstützte radikale Recovery-Maßnahme. Dabei gehen Buildcaches und alle
promotierten Zuordnungen verloren; Ziel-Units müssen zuerst direkt neu gebaut
werden, und bis dahin erscheinen externe Referenzen als `??` mit Warnung.
Normale Nutzerwege bleiben `check`, `clean`, `prune` und später eine gezielte
`doctor`-Reparatur.

### 13.5 Prune

`prune` entfernt Zustände, deren Dokumentidentität in der aktuellen
Projektstruktur nicht mehr existiert. Es unterstützt `--dry-run`.

## 14. Dokumentübergreifende Referenzen (TODO)

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

### 14.1 Festgelegter Autorenvertrag

Der Referenzdienst liegt in `osglecture-references.sty`. Sein kurzer
Kernbefehl ist `\olref`. Ohne Dokumentadresse verhält er sich wie `\ref`;
mit einer optionalen Adresse referenziert er ein Label einer anderen Unit
derselben Serie:

```tex
\olref{sec:scheduling}
\olref[processes]{sec:scheduling}
\olref[processes,type=script,lang=en]{sec:scheduling}
```

In der optionalen kommagetrennten Liste gilt ein Eintrag ohne Schlüssel
unabhängig von seiner Position als `unit`. Die gleichwertige explizite Form
lautet `unit=processes`. `type` und `lang` überschreiben Dokumenttyp und
Sprache; ohne Angabe gelten die Werte des aktuellen Builds. Die Reihenfolge ist
beliebig, bei Wiederholung zählt der letzte Wert. Leerzeichen, Komma,
Gleichheitszeichen und die für Integrationsbereiche reservierte Folge `...`
sind in logischen Unit-IDs unzulässig.

Die Befehlsfamilie umfasst zunächst `\olref`, `\olpageref`, `\olnameref` und
`\olautoref`. Ihre Sternvarianten besitzen genau die Hyperref-Semantik: Sie
erzeugen denselben Referenztext, aber keinen Hyperlink.

Die rein LaTeX-seitige Paketkonfiguration kennt:

```tex
\OsgLectureReferencesSetup{
  legacy = true,
  replace = {ref,pageref}
}
```

`legacy` ist boolesch, ohne Wert wahr und standardmäßig falsch. Es stellt den
alten Autorenbefehlssatz einschließlich `\xref`, `\xrefchap`, `\xrefsmart`,
`\xrefdist`, `\xarticleref` und `\xpresentationref` über Adapter bereit, nicht
dessen alte zref-/Lua-Implementierung. `replace` akzeptiert die Symbolmenge
`ref`, `pageref`, `nameref`, `autoref`, `all` und `none`; ohne Wert bedeutet
es `all`, Default ist `none`. Sternvarianten werden nicht gesondert genannt.
Dieselben Schlüssel stehen als Paketoptionen und für gemeinsamen Projektcode
zur Verfügung; OLLM und TOML interpretieren sie nicht.

Für positionsabhängige Seitenverweise lädt der Referenzdienst `varioref` mit
`nospace` und stellt dessen öffentliche API unverändert zur Verfügung. Ein
zusätzlicher osglecture-Wrapper ist nicht vorgesehen. Deutsch und Englisch
werden als `varioref`-Sprachen registriert; bei Babel-Sprachwechseln folgen die
Ausgabetexte der aktuellen Sprache. `\xrefdist` bleibt ausschließlich ein
optionaler Legacy-Adapter auf `\vpageref`.

Positionsabhängige Aussagen wie „auf der nächsten Seite“ sind nur für lokale
Labels zulässig. Zwischen Units oder Doctypes besitzen Seitenabstände keine
stabile Semantik und können insbesondere nach der PDF-Komposition nicht
nachträglich neu berechnet werden. Eine spätere semantische Referenz-API muss
Unit und Doctype ausdrücklich auswerten; `cleveref` beziehungsweise
`zref-clever` sind dafür zunächst keine Kernabhängigkeiten.

### 14.2 Logische Unit- und Labelidentität

Die kanonische gemeinsame Strukturform lautet:

```tex
\lecture[Kurztitel]{Langer Titel}{processes}
```

Der letzte Parameter ist eine obligatorische logische Unit-ID. Sie stammt aus
der Lecture-/Kapitelstruktur und wird weder aus Verzeichnisname, physischer
Nummer noch Jobname abgeleitet. Präsentation und Langform derselben Unit
verwenden dieselbe ID. Eine spätere optionale Longform-Kurzform darf
`\chapter` erkennen, wenn unmittelbar, abgesehen von Whitespace, ein `\label`
folgt. Sie ist nicht Teil der ersten Implementierungsstufe.

Gewöhnliche `\label`-Befehle werden ohne besondere Autorenmarkierung in den
dedizierten Referenzexport gespiegelt. Die normale Build-`.aux` bleibt privat.
Externe Dokumente werden dagegen dokumentweise und erst bei tatsächlicher
Anforderung importiert. Interne Importpräfixe und physische Exportpfade sind
keine Autorenoberfläche.

Lokale doppelte Labels bleiben gewöhnliche LaTeX-Warnungen. Mehrdeutige
logische Unit-IDs oder mehrere gültige Exporte derselben vollständigen
Dokumentidentität sind Serieninkonsistenzen und müssen spätestens durch
`ollm check` erkannt werden.

### 14.3 Fehler-, Link- und Propertyvertrag

Ein fehlendes Dokument, Label oder nicht vorgesehener Doctype-/Sprachbuild
erzeugt `??` und eine Warnung; es gibt keinen automatischen Fallback auf eine
andere Sprache oder Projektion. Ein normaler Autorenbuild darf den letzten
erfolgreich promoteten Export verwenden und bei erkennbarer Veraltung warnen.
`ollm check` bewertet fehlende, mehrdeutige oder nachweislich inkonsistente
Ziele streng.

Dies gilt ausdrücklich auch für das Bootstrap-Problem einer noch nie
erfolgreich gebauten Unit: Ist ihre explizite logische ID keinem physischen
Build bekannt, bleibt die Referenz im LaTeX-Dokument als `??` sichtbar und
erzeugt eine Warnung. `build --resolve` darf eine solche Zuordnung weder raten
noch durch Quelltextsuche herstellen. Erst ein erfolgreicher direkter Build
der Ziel-Unit veröffentlicht die Zuordnung. `ollm check` listet alle
unbekannten logischen Units, fehlenden Doctype-/Sprachprojektionen und
fehlenden Labels vollständig als Inkonsistenzen auf.

Der Export führt mindestens Referenzwert, Name, physische PDF-Seite,
stabile PDF-Destination und die optionale Property `slide`. Dabei ist `slide`
in Präsentationsprodukten die Frame-Nummer, während `page` stets die physische
Seite des konkreten PDFs bezeichnet. Ein Handout behält damit die ursprüngliche
Foliennummer unabhängig von seiner Ausschießung.

Die Linkpolicy unterscheidet:

```text
external      Link auf ein auffindbares einzelnes PDF
internalized  Link auf die importierte Destination eines Gesamt-PDFs
none          Referenztext ohne externen Link
```

Der endgültige Deploymentname ist noch offen. Referenzen melden deshalb die
verwendete Property `artifact-name` als semantische Abhängigkeit. Langfristig
ist ein von der physischen Nummer unabhängiger stabiler Referenzartefaktname
anzustreben.

### 14.4 Auflösung und Integration

OLLM erzeugt aus den einzeln promoteten Resultat- und Referenzdateien einen
jobgebundenen, nur lesbaren Snapshot, der logische Dokumentidentitäten auf
validierte Exporte abbildet. Builds schreiben keine gemeinsame globale
Registry. `build --resolve` stabilisiert Referenz-, Continuation- und andere
semantische Abhängigkeiten in Runden. Die lokale Obergrenze lautet:

```toml
[build.resolve]
max_rounds = 8
```

Der konkrete Default bleibt bei der Implementierung festzulegen. Der Name
`max_rounds` bezeichnet bewusst Fixpunktrunden und nicht Graphentiefe.

Integrationsverzeichnisse wählen ihre Quellen auf der LaTeX-Ebene nach
logischen Unit-IDs:

```tex
\includeunit{processes}
\includeunits{introduction,processes,appendix-posix}
\includeunits{introduction...scheduling,appendix-posix}
```

`...` bezeichnet einen inklusiven Bereich in der logischen Serienreihenfolge.
Anhänge und andere Rollen können ausdrücklich genannt werden. Die vollständige
Integrationsmenge wird vor dem Schreiben der Seiten normalisiert. `tagpax`
importiert Struktur, Seiten, Destinationen und Linkannotation; serieninterne
`GoToR`-Aktionen zwischen enthaltenen Units werden auf namespacete interne
`GoTo`-Ziele umgeschrieben, ohne Annotation oder zugehörigen OBJR zu ersetzen.
Integrationsprodukte reexportieren in der ersten Version keine Unitreferenzen
und dürfen nicht rekursiv als Unitquelle dienen.

### 14.5 Tagged PDF

`\DocumentMetadata` bleibt eine vor `\documentclass` auszuführende
Projektinitialisierung. Der Referenzdienst setzt keine eigene PDF-Version oder
Taggingpolicy. Sichtbare Links werden ausschließlich über Hyperref und LaTeX
PDF Management erzeugt. Dadurch besitzen sie im Tagged PDF ein reguläres
`Link`-Strukturelement samt OBJR. Sternvarianten und fehlende Ziele erzeugen
keine Linkannotation. `tagpax` erhält bei der Integration die vorhandene
Strukturzuordnung und ändert nur das Navigationsziel.

## 15. CLI

### 15.1 Grundform

```text
ollm [globale Optionen] [Aktion] [Ziel] [Aktionsoptionen]
```

Aktionen:

```text
build      implementierte Defaultaktion
report     TODO
check      TODO
clean      TODO
prune      TODO
doctor     grundlegende Werkzeugprüfung implementiert; Projekttests TODO
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
--target
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

`--resolve` gehört zu `build`, ist aber noch TODO; `check` bleibt im
spezifizierten Zielverhalten rein lesend.

### 15.4 OLLM- und latexmk-Argumente

Das historische `+`-Präfix für OLLM-Optionen bleibt unterstützt. Bekannte
nackte Wörter werden kompatibel als OLLM-Aktionen oder Dokumenttypen erkannt.
Normale unbekannte Minusoptionen werden an `latexmk` weitergereicht.

Die Durchreichung endet an den von OLLM kontrollierten Verträgen. Zusätzliche
RC-Dateien oder Perl-Startcode (`-r`, `-e`), andere Engines als LuaLaTeX,
alternative Ausgabeformate, indirekte Engineoptionen und `-use-make` sind
Fehler. In Serienbuilds ist außerdem `-out2dir` unzulässig, weil OLLM den
Artefaktpfad besitzt. Nur im Standalone-Kontext bleiben `outdir`, `auxdir` und
`out2dir` normale latexmk-Optionen. OLLM besitzt im Serienkontext Engine,
Jobname, Recorder, Arbeits-/Ausgabepfade, Shell-Escape-Policy und die
Orchestration abhängiger Builds. Diagnosen nennen den verletzten Vertrag und,
soweit möglich, eine eindeutige Alternative.

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

Die stabile Grundmenge lautet:

```text
0    Erfolg
1    Build-, Check- oder Doctor-Fehler
2    ungültiger Aufruf oder ungültige Konfiguration
3    inkonsistente Dokumentabhängigkeiten (für den späteren Check reserviert)
69   fehlendes Werkzeug, nicht implementierte Aktion oder ungeeignete Umgebung
```

Signalbedingte Abbrüche verwenden auf Plattformen mit POSIX-Waitstatus
`128 + Signalnummer`, insbesondere `130` für Ctrl-C. Der vorläufige
Legacy-Execpfad bleibt hinsichtlich fremder Exitcodes kompatibel; der neue
Executor normalisiert dagegen einen von `latexmk` gemeldeten Buildfehler auf
Exitcode 1.

## 16. Report, Check und Doctor

### 16.1 Report (TODO)

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

### 16.2 Check (TODO)

`check` baut nichts. Es prüft mindestens:

- Auftrag, Jobname und Ergebnis stimmen überein;
- Artefakt vorhanden;
- Unit-Scopes und Rollen gültig;
- Exkurs besitzt ein Vorgängerkapitel;
- externe Referenzen vorhanden und aktuell;
- Generationskennungen konsistent;
- erzwungene Optionen sichtbar;
- vorgesehene Sprach-/Zielkombination zulässig.

Ein späteres Deployment ruft `check` auf. Qualitätsprobleme dürfen mit einer
expliziten Force-Option übergangen werden; Integritäts- und Sicherheitsfehler
nicht.

### 16.3 Doctor

`doctor` prüft derzeit die Auffindbarkeit von Perl, `latexmk` und LuaLaTeX
sowie Verfügbarkeit, Version und Herkunft des TOML-Parsers. **TODO:** Die
projekt- und backendabhängige Prüfung soll zusätzlich umfassen:

- `latexmk`;
- LuaLaTeX und Mindestversion;
- OLLM und TOML-Parser;
- Auffindbarkeit des Bundles;
- Manifest und Schreibrechte;
- Shell-Escape-Policy.

Optionale Werkzeuge werden nur geprüft, wenn das effektive Projekt oder Backend
sie deklariert. Xindy ist daher keine feste Voraussetzung; eine Lua-basierte
Indexsortierung kann es ersetzen.

## 17. Clean und Prune (TODO)

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

Das Projektmanifest ist deklaratives TOML und führt keinen Konfigurationscode
aus.

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

Projektmanifest, lokale Konfiguration sowie Bundle-Preset- und Targetdefinitionen
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

Projektwurzel, Einheit und Quelle werden vor dem Build kanonisiert. Eine
Serieneinheit muss innerhalb ihrer Projektwurzel liegen. Vor dem Anlegen des
Buildverzeichnisses werden vorhandene Pfadvorfahren aufgelöst; insbesondere
darf ein symbolischer Link den `.osglecture`-Zustand nicht unbemerkt aus der
Projektwurzel herausleiten. Pfade mit Leerzeichen bleiben einzelne
Prozessargumente. Ein im Buildpfad enthaltener `TEXINPUTS`-Listentrenner ist
nicht eindeutig darstellbar und deshalb ein Fehler.

Identitäten und Buildpfade werden vorsorglich auch nach
case-insensitiver Faltung auf Kollisionen geprüft. Damit erzeugt ein unter Unix
gültiges Projekt beim späteren Wechsel auf ein verbreitetes Windows- oder
macOS-Dateisystem keinen überlappenden Zustand.

Jeder konkrete BuildSpec hält während der vollständigen `latexmk`-Laufzeit
eine exklusive `.ollm.lock` in seinem Buildverzeichnis. Verschiedene Specs
besitzen keine gemeinsam beschriebene Registry und dürfen später parallel
ausgeführt werden; zwei Prozesse derselben Identität werden dagegen vor jedem
Schreibzugriff abgewiesen. Diese Eigentumsregel ist Voraussetzung für eine
spätere Parallelisierung, ohne sie bereits zu implementieren.

Unix und macOS sind die Referenzplattformen für Prozess- und
Dateisystemverhalten. Windows verwendet denselben argumentlistenbasierten
Vertrag, den `ollm.cmd`-Einstieg, den plattformspezifischen `TEXINPUTS`-
Listentrenner und den gekapselten atomaren Dateiersatz. Wo eine Plattform den
vollen Vertrag nicht zuverlässig anbieten kann, wird die Einschränkung
diagnostiziert, statt das Unix-/macOS-Verhalten abzuschwächen.

### 21.1 Spätere Editionen

Eine künftig benötigte parallele Inhaltsausgabe desselben Targets, Doctypes
und Dokumentprofils wird **Edition** genannt, beispielsweise `student` und
`instructor`. Sie wäre eine orthogonale Builddimension und müsste daher in
Buildidentität, Job-ID, Verzeichnissen, `--all` und Artefaktnamen gemeinsam
eingeführt werden.

Der aktuelle Entwurf reserviert dafür bewusst weder den früher erwogenen Namen
`variant` noch ein CLI-, Schema-, BuildSpec- oder Auftragsdateifeld.
Dokumentprofile sind kein Ersatz für Editionen: Sie beschreiben die technische
TeX-Integration und werden projektweit gewählt, während mehrere Editionen
desselben Dokumentprofils gleichzeitig baubar sein müssten. Solange kein
konkreter Editionsbedarf vorliegt, bleibt diese Dimension unimplementiert.

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
- Unit-Scopes und Subscopes;
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

Die häufige CLI bleibt kompatibel. Für alternative Konfigurationsorte und
Projektwurzeln gelten ausschließlich `--config` beziehungsweise
`--project-root`.

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
4. Behandlung weiterer direkt durch Lua gelesener Dateien;
5. JSON- und Aux-Schemata einschließlich Generationsmodell;
6. genaue Clean-Levelnamen;
7. Benutzerkonfiguration zusätzlich zur projektlokalen Konfiguration;
8. Deploymentvertrag.

Diese Punkte dürfen die in diesem Dokument festgelegten Verantwortungsgrenzen
und Invarianten nicht aufweichen.
