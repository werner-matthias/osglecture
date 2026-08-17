# osglecture – Grundideen und Leitlinien für eine Überarbeitung

**Arbeitsdokument · Stand 29. Juli 2026, ergänzt um Abschnitt 12 am 17. August 2026**

## Zweck und Einordnung

Dieses Dokument beschreibt die grundsätzlichen Ideen der Klasse `osglecture` in ihrer gegenwärtigen Form. Es ist bewusst weder Benutzerhandbuch noch vollständige API-Referenz. Sein Zweck ist, das fachliche Modell, die tragenden Entwurfsentscheidungen und die derzeitigen Spannungsfelder sichtbar zu machen. Nach fachlicher Überarbeitung soll es als Ausgangspunkt für eine Neustrukturierung der Klasse dienen.

Die bundleweit verbindlichen Kurzdefinitionen stehen im
[`GLOSSARY.md`](./GLOSSARY.md).

Die Aussagen beziehen sich auf die laufende Neustrukturierung von
`osglecture/osglecture.cls` und die begleitenden Dateien im Repository. Seit
Version 0.7.0 ist die Klasse standardmäßig ein schlanker Orchestrator. Die
unveröffentlichte historische Implementierung bleibt während der Migration nur
noch über die explizite Klassenoption `osgbeamer` erreichbar.

> **Kernaussage:** `osglecture` soll eine gemeinsame fachliche Quelle in mehrere didaktische Darstellungen überführen. Die Klasse sollte deshalb künftig primär Moduswahl und Integration koordinieren; fachlich unabhängige Dienste und Darstellungsdetails sollten in getrennten Paketen liegen.

### Gegenwärtige Migrationsgrenze

Der Standardpfad von `osglecture.cls` enthält nur noch Engineprüfung,
Auftragsdatei- und Optionsauswertung, Basisklassenwahl sowie die Initialisierung
von `osglecture-modes`, Dokumentprofil und generischer Metadatenhaltung. Er
lädt insbesondere keine historische Typografie, Farben, Themes, Literatur-
oder Referenzpakete.

Mit `\documentclass[osgbeamer,...]{osglecture}` wird stattdessen
`osglecture-osgbeamer.code.tex` geladen. Diese Datei kapselt den bisherigen
Gesamtstand einschließlich seiner Formatierungen und seiner Abhängigkeiten.
Die Option ist eine bewusst explizite Migrationsbrücke, kein Bestandteil des
neuen Kerns. Eine weitere Zerlegung dieses konservierten Codes kann später
entlang fachlicher Paketgrenzen erfolgen, ohne den Standardpfad erneut zu
belasten.

### Dokumentprofile

`bundle_preset` in der OLLM-Konfiguration bezeichnet das versionierte
Bundle-Preset, beispielsweise `OSG lecture/1`. Davon getrennt bezeichnet ein
Dokumentprofil die konkrete TeX-Integration. Die Targetdefinition liefert nur
`profile-class`; die Klasse wählt damit in `projectconfig.tex`
`presentation-profile` oder `longform-profile`. Eine Auswahl durch
`\LectureTargetSetup{<target>}{profile=...}` ist spezifischer. Für
TeX-Konfiguration gilt:

```text
eingebauter Fallback (0)
    < Profil-Setup (10)
    < projectconfig.tex (20)
    < Unit-Quelle/Klassenoption (30)
    < erzwungene Projektkonfiguration (40)
```

Der konkrete Profilname wird nicht in den BuildSpec geschrieben und kann nicht
durch die CLI ausgewählt werden.

Die Klasse lädt Profildeskriptoren vor der Basisklasse. Ein Deskriptor
deklariert Engine, Fähigkeiten, unterstützte Dokumenttypen, Backend, Basisklasse,
dokumenttypspezifische Klassenoptionen und optional eine Setup-Datei. Diese
Setup-Datei wird erst nach Basisklasse und Moduskern geladen. Damit können
weitere Profile ergänzt werden, ohne die Kernklasse um Backendfälle zu
erweitern.

Der stabile Deskriptorvertrag umfasst `engine`, `capabilities`, `backend`, `class`, `doctypes`,
`adapter`, `class-options`, `document-metadata`, `modes`, `mode-setup-file`,
`setup-file`, `course-target` und `event-target`.
`engine` ist derzeit auf `lualatex` beschränkt. `capabilities` beschreibt
fachliche Fähigkeiten wie `presentation`, `longform` und `print`, aber keine
externen Programme. Eine spätere tex4ht- oder Pandoc-Pipeline bleibt ein vom
TeX-Profil getrennter Buildvertrag.
`mode-setup-file` wird vor Aktivierung und Finalisierung des Modusgraphen
geladen; `setup-file` danach. Nur die erste Datei darf den Graphen erweitern.
`backend` bezeichnet die technische Backendfamilie, `adapter` die konkrete
Abbildung der osglecture-Semantik. Fehlt `adapter`, gilt aus
Kompatibilitätsgründen zunächst der Backendname. Mitgelieferte Profile nennen
beide Werte ausdrücklich. Der ausgewählte Adapter wird nach Basisklasse und
finalisiertem Modusgraphen, aber vor der Installation der öffentlichen
Strukturwrapper geladen; dadurch kann er native Befehle sichern, ohne den
Framebody an sich zu ziehen.

Mitgeliefert werden zunächst:

- `beamer` für `slides` und `handout`,
- `ltx-talk` für `slides` und `handout`,
- `book` als Standard für `script` und `article`,
- `scrbook` als alternativer KOMA-Script-Adapter für `script` und `article`.

Die gegenwärtige Version von `ltx-talk` verlangt `\DocumentMetadata{}` vor
`\documentclass`, Beamer verbietet es. Ein Wrapper kann diese Initialisierung
technisch nicht nachholen. Deshalb löst OLLM pro Target
`document_metadata=required|disabled` auf und liest die nutzereditierbare Datei
nur bei `required`. Zuvor definiert es Symbole für Target, Doctype,
Profilklasse, Policy und Sprache. Der Profildeskriptor deklariert unabhängig
`document-metadata=required|supported|forbidden`; die Klasse validiert beide
Seiten nach ihrer eigenen Auswahl des konkreten Profils. OLLM
untersucht `main.tex` nicht; ein zusätzlicher `\DocumentMetadata`-Aufruf bleibt
ein sichtbarer LaTeX-Konflikt.

Im Standalone-Betrieb kann `profile=...` als Klassenoption verwendet werden.
Auch bei einer OLLM-Auftragsdatei kann sie einen normalen Projektwert für
Diagnosezwecke überschreiben. Ein Widerspruch zu einem mit
`\LectureProjectEnforce` erzwungenen Profil ist ein Fehler.

Die beiden Startwege sind explizit und disjunkt. `standalone` wählt den lokalen
Konfigurationsweg. Andernfalls muss der Runner vor der Hauptdatei
`\OSGLectureProjectManifestFile` und `\OSGLectureJobFile` definieren. Die Klasse
prüft zunächst nur die Existenz des bezeichneten TOML-Manifests, ohne es zu
lesen, und lädt danach ausschließlich die bezeichnete Auftragsdatei. Sie sucht
weder nach `<jobname>.osgbuild.tex` noch nach der jüngsten Auftragsdatei.
Fehlt einer der beiden Zeiger, fehlt eine bezeichnete Datei oder sind
`standalone` und ein Runner-Zeiger gleichzeitig aktiv, bricht die Klasse ab.

Die Zeiger sind Pfad-Locators, keine portablen Projektmetadaten. Relative und
absolute TeX-auflösbare Pfade sind zulässig. OLLM erzeugt normalisierte absolute
Pfade, weil latexmks `-cd`, verschiedene Buildverzeichnisse und parallele
Prozesse dann keinen Einfluss auf ihre Auflösung haben. Die Pfade werden nur
in flüchtigen Buildkommandos verwendet und nicht in transportierbare
Projektdateien geschrieben.

### Vertragsstatus für Folgearbeiten

Als stabil und implementiert gelten derzeit:

- Auftragsdatei, Jobbindung und Klassenoptionen für Doctype, Sprache, Profil
  und Standalone,
- der offene Dokumentprofilvertrag einschließlich der beiden Setup-Phasen,
- Doctype als Blattmodus, Modusgraph und portable Modusabfragen,
- die drei Standard-Verhaltensklassen und die Vollständigkeitsprüfung
  semantischer Befehle,
- die generische Titelmetadaten-API und ihre Profilabbildung.

Als stabil und implementiert gilt außerdem der explizite
Unit-/Lecture-Vertrag aus Abschnitt 3.6. Die dort beschriebene optionale
`\chapter`-plus-`\label`-Kurzform bleibt eine Zukunftsidee.

Noch nicht als stabiler Autorenvertrag festgelegt sind insbesondere:

- die konkrete gemeinsame Bild- und Tabellen-API,
- Notizen und Zweitbildschirmdarstellung,
- spezialisierte optionale Fachpakete und deren jeweilige Autorenbefehle.

Der Autoren- und Dateivertrag für Referenzen über Unitgrenzen ist inzwischen
in Abschnitt 3.9 festgelegt. Seine OLLM-seitige atomare Promotion und der
jobgebundene Registry-Snapshot sind implementiert; Check/Report und
Fixpunktauflösung bleiben noch zu implementieren.

Folgearbeiten dürfen auf den stabilen Contracts aufbauen. Bei den zuletzt
genannten Bereichen muss der jeweilige Thread zuerst seinen fachlichen Vertrag
festlegen; er darf dabei weder Modusnamen, Verhaltensklassen noch
Profil-Ladereihenfolge nebenbei verändern.

## 1. Das fachliche Problem

Eine Vorlesung besteht nicht aus voneinander unabhängigen Folien und Skriptseiten. Beide Darstellungen teilen Gliederung, Begriffe, Abbildungen, Quellen, Metadaten und Referenzen, unterscheiden sich aber in ihrem Gebrauch:

- **Folien** unterstützen den Vortrag: knapp, visuell, schrittweise aufdeckbar und auf eine Projektionsfläche optimiert.
- **Handouts** verdichten Folien für Ausdruck oder Nachbereitung.
- **Skriptkapitel** sind eigenständig lesbar, ausführlicher, fortlaufend paginiert und in eine Vorlesungsreihe eingebettet.
- **Standalone-Dokumente** sollen ohne die Infrastruktur einer Vorlesungsreihe funktionieren.
- **Vortragsansichten** können zusätzliche Notizen oder eine zweite Anzeige benötigen.

Die zentrale Idee von `osglecture` ist deshalb **Single Source, Multiple Representations**: Ein gemeinsamer LaTeX-Inhalt soll abhängig vom Ausgabemodus passend interpretiert werden, ohne dass Autorinnen und Autoren dieselbe fachliche Aussage mehrfach pflegen müssen.

## 2. Das konzeptionelle Modell

Die Klasse verarbeitet vier Arten von Eingaben und erzeugt daraus eine konkrete Dokumentkonfiguration:

```text
                         Vorlesungsquelle
                               │
              ┌────────────────┼────────────────┐
              │                │                │
        Klassenoptionen   Serienkonfiguration  Buildauftrag
              │               (OLLM)            │
              └────────────────┼────────────────┘
                               ▼
                    osglecture – Orchestrator
                 Modus · Sprache · Metadaten · Pfade
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
    Präsentation           Handout              Skript
  beamer/ltx-talk      beamer/ltx-talk          book/scrbook
          │                    │                    │
          └────────────────────┼────────────────────┘
                               ▼
             gemeinsame Dienste und Darstellungsbausteine
       Referenzen · Sprache · Bibliografie · Theme · Inhaltsmakros
```

Die Klasse übernimmt derzeit fünf Rollen:

1. **Konfiguration ermitteln:** Klassenoptionen und den normalisierten,
   jobgebundenen OLLM-Buildauftrag auswerten.
2. **Ausgabemodus wählen:** Präsentations- oder Langformprofil mit seiner Basisklasse laden.
3. **Serienkontext integrieren:** kapitelübergreifende Metadaten, Referenzen, Bibliografie und Nummerierung einbinden.
4. **Darstellung konfigurieren:** Theme, Schriften, Farben und Handout-Layout festlegen.
5. **Autoren-API anbieten:** modusabhängige Textauszeichnung, Spalten, Bilder, Notizen und Kompatibilitätsmakros definieren.

Diese Rollen erklären den heutigen Umfang der Klasse, markieren aber zugleich natürliche Modulgrenzen.

### 2.1 Vereinbartes Auswahlmodell

Target, Dokumenttyp, Modus und Backend bilden keine vier unabhängigen
Auswahldimensionen.

```text
BuildRequest wählt Target
        │
        ▼
Targetdefinition liefert kanonischen Dokumenttyp
und Profilklasse
        │
        ▼
Profil-/Projektpolicy wählt ein Dokumentprofil
        │
        │
        ▼
Profildeskriptor deklariert Backend und Modusgraph
        │
        ▼
aktiver Blattmodus ist der Dokumenttyp;
der Graph liefert transitive Obermodi
```

Target und Dokumenttyp sind zwei Perspektiven derselben fachlichen Auswahl:
OLLM spricht von einem Target, die Klasse von einem Dokumenttyp. Nach
Normalisierung von CLI-Aliasen gilt für den gewöhnlichen Build:

```text
target = doctype = aktiver Blattmodus
```

Eine Abweichung zwischen Targetname und Dokumenttyp benötigt einen
ausdrücklich registrierten, versionierten Adaptervertrag. Sie ist kein
gewöhnlicher Alias und darf nicht stillschweigend entstehen.

Die Modusmatrix ergänzt den aktiven Dokumenttyp um allgemeinere
Zugehörigkeiten. Sie ist ein gerichteter azyklischer Graph und darf mehrere
Eltern pro Modus enthalten:

```text
slides  -> presentation
handout -> presentation, print
script  -> longform, print
article -> longform, print
```

Bei einem Handout sind damit `handout`, `presentation` und `print` aktiv.
Abstrakte Obermodi müssen keine baubaren Dokumenttypen sein. `osglecture-modes`
übernimmt die portable Auswertung der Matrix. Der ausgewählte
Profildeskriptor beziehungsweise dessen `mode-setup-file` registriert sie auf
der TeX-Seite; `osglecture` setzt anschließend den Dokumenttyp als Blattmodus,
bevor modusabhängige Projektmetadaten verarbeitet werden. OLLM transportiert
keine Modusmatrix.

`osglecture-modes` bildet diesen Vertrag als Menge aktiver Blattmodi mit transitiver
Elternhülle ab. Ein Modus kann mehrere Eltern besitzen. Aliase werden transitiv
aufgelöst; unbekannte Modi und Eltern sowie Alias- und Elternzyklen sind
Fehler. Nach `\FinalizeLectureModes` ist der Graph unveränderlich. Die zentrale
Schnittstelle lautet:

```tex
\DeclareLectureMode{script}
\DeclareLectureModeParents{script}{longform,print}
\DeclareLectureModeAlias{reader}{script}
\SetLectureModes{script}              % ersetzt die Blattmenge
\AddLectureModes{backend-mode}        % ergänzt sie
\FinalizeLectureModes
```

`\lecturemode<script|handout>{...}` und `\IfLectureModeTF` sind die garantiert
portable Oberfläche. Bei einer generischen Basisklasse stellt `osglecture-modes`
zusätzlich die entsprechende Inlineform von `\mode` bereit. Definiert ein
Backend bereits `\mode`, übernimmt `osglecture-modes` nur Inlineausdrücke, die
ausschließlich registrierte portable Modi enthalten; unbekannte Ausdrücke,
Beamers ungebundene Modusschalter und `\mode*` werden unverändert an das
Backend delegiert. Damit zieht sich die Erweiterung automatisch zurück, sobald
ein Backend die betreffende Syntax selbst verwaltet. Eine Erweiterung aller
Overlaybefehle um frei registrierte Modi ist damit ausdrücklich nicht
versprochen.

Die automatische Moduserkennung dient nur der Standalone-Kompatibilität und
geschieht bereits beim Laden des Pakets. `osglecture` registriert und aktiviert
die vom Dokumentprofil deklarierte Matrix dagegen ausdrücklich vor dem
Einlesen projektweiter Metadaten. Der `ltx-talk`-Scanner bleibt ein
Backendadapter und ist nicht Teil des allgemeinen Moduskerns.

Bis zu einer fachlichen Aufspaltung aktiviert `osglecture` für `script` und
`article` beide Blattmodi gemeinsam. Das ist absichtlich kein Graphalias und
verbaut daher keine spätere getrennte Semantik. Vor dem Finalisieren kann das
Dokumentprofil den Graphen über `mode-setup-file` erweitern; `modes` ergänzt
weitere aktive Modi. Ein Bundle-Preset beeinflusst die Matrix nur mittelbar
durch die Auswahl eines Dokumentprofils, nicht durch einen zweiten von OLLM
zusammengeführten Graphen.

Explizite Klassenoptionen für `doctype` und `lang` dürfen einen BuildSpec zu
Debugzwecken übersteuern. Bei einer Abweichung warnt die Klasse und weist
darauf hin, dass der jobgebundene BuildSpec unverändert bleibt. Ein
widersprechendes `profile` bleibt dagegen ein Fehler.

### 2.2 Verhaltensklassen und vollständige Befehlssemantik

„Vom Backend nicht nativ unterstützt“ darf nicht „ohne definierte Semantik“
bedeuten. `osglecture-modes` stellt deshalb eine vom konkreten Dokumentmodell
unabhängige Registry bereit:

```tex
\DeclareModeBehaviorClass{presentation-dynamic}
\DeclareModeBehaviorClass{presentation-static}
\DeclareModeBehaviorClass{longform}

\AssignLectureModeBehavior{slides}{presentation-dynamic}
\AssignLectureModeBehavior{handout}{presentation-static}
\AssignLectureModeBehavior{script,article}{longform}
```

Ein semantischer öffentlicher Befehl nennt alle Verhaltensklassen seines
Vertrags und erhält für jede Klasse ein Implementierungsmakro:

```tex
\DeclareModeAwareCommand
  {\OsgSemanticCommand}
  {presentation-dynamic,presentation-static,longform}
\DeclareModeAwareCommandImplementation
  {\OsgSemanticCommand}{longform}{\osg_semantic_longform:n}
```

Die Registry prüft alle versprochenen Klassen, nicht nur den aktuellen Build.
Beim ersten Gebrauch oder spätestens vor Dokumentbeginn bindet sie den
öffentlichen Befehl direkt an die ausgewählte Implementierung. Deren eigene
Signatur verarbeitet die Argumente; die Registry muss daher keine
Argumentlisten duplizieren. Ein neues Profil darf eine generische
Implementierung übernehmen oder gezielt ersetzen, aber keine Vertragslücke
offenlassen.

Für vorhandene LaTeX-Befehle stellt `\MakeOverlayAwareCommand` einen engeren
Overlayadapter bereit. Portable
Modusspezifikationen werden durch die Modusmatrix ausgewertet; echte
Overlayspezifikationen gehen an ein natives `\only`. Ohne Overlaybackend muss
die Deklaration mit `fallback=flatten`, `omit` oder `error` eine ausdrückliche
Semantik besitzen. Dies ersetzt den experimentellen Legacy-Helfer
`\osgmakeselectable`, ohne Overlay- und Dokumentmodussemantik gleichzusetzen.
Der Schlüssel `arguments` beschreibt die nach `<...>` verbleibende
`xparse`-Signatur. Dadurch kann etwa
`\\<slides>[3ex]` entweder den ursprünglichen Zeilenumbruch samt Abstand
ausführen oder sowohl Stern- als auch Abstandsargument korrekt konsumieren.
Die Sicherung des Originalbefehls benutzt die LaTeX-Kernel-Kopierschnittstelle
und bleibt lokal, damit umgebungsabhängig neu definierte Befehle wie `\\`
innerhalb ihres jeweiligen Kontexts adaptiert werden können.

Das Backend ist die technische Realisierung des Dokumenttyps:

```text
backend = adapter(doctype, document-profile, project-policy)
```

Insbesondere darf derselbe Dokumenttyp `slides` durch Beamer oder `ltx-talk`
realisiert werden. Autoreninhalte und Metadaten selektieren deshalb nach
Dokumenttyp oder Obermodus, nicht nach Backendnamen. Ein Backendadapter muss
ausdrücklich erklären, welche Dokumenttypen er unterstützt.

## 3. Tragende Ideen

### 3.1 Gemeinsame Quelle als oberstes Ziel

Präsentation und Skript sind keine getrennten Produkte, sondern Projektionen derselben semantischen Quelle. Die portable Modusmatrix dient als fachlicher Selektionsmechanismus; Overlay-Spezifikationen bleiben eine zusätzliche Fähigkeit geeigneter Präsentationsbackends. Befehle wie `\osgpresart`, selektierbare Abstände, modusabhängige Fußnoten, `\stress`, `\outline`, `\centerpic` und `twocolumns` versuchen, Unterschiede lokal auszudrücken.

Für eine Überarbeitung folgt daraus:

- Semantische Autorenbefehle sind wertvoll, wenn sie eine didaktische Absicht benennen.
- Reine Layout-Abkürzungen sollten nicht Teil der Kernklasse sein.
- Präsentationsspezifische Overlay-Syntax darf im Skriptmodus weder Fehler noch unbeabsichtigte Leerräume erzeugen.
- Die gemeinsame Quelle bleibt der Normalfall; explizite Modusvarianten sind ein kontrollierter Ausweg.

### 3.2 Dokumenttyp ist eine fachliche Entscheidung

Der Schlüssel `doctype` bezeichnet die fachliche Ausgabe und ist zugleich der
aktive Blattmodus. Er bestimmt die benötigte Semantik und schränkt die
zulässigen Backendadapter ein; die konkrete Basisklasse folgt jedoch zusätzlich
aus Profil- und Projektpolicy. `slides`, `handout`, `script` und `article`
besitzen eingebaute Defaults, bilden aber keine geschlossene Liste.

Die derzeitigen Typen sind unterschiedlich reif:

- `slides`: Präsentationsausgabe, derzeit regulär über Beamer.
- `handout`: Präsentations-/Druckausgabe, derzeit über Beamer und `pgfpages`.
- `script` und `article`: Longform-Ausgabe standardmäßig über `book`; `scrbook`
  bleibt als alternativer Adapter verfügbar.
- `screen`: experimentelle Zweitbildschirm-Konfiguration.
- `web`: ausdrücklich nicht unterstützt.

Ein zusätzlicher Dokumenttyp benötigt eine registrierte Targetdefinition, ein
ausdrücklich gewähltes Dokumentprofil, einen vor der Aktivierung geladenen
Blattmodus und eine vollständige Verhaltenszuordnung. Aliasnamen werden vor
Eintritt in die Klasse normalisiert. Ein zusätzliches Backend ist dagegen nur
ein weiterer Adapter eines Dokumenttyps und verändert dessen Autorenmodus
nicht.

### 3.3 Serie und Standalone sind zwei gleichwertige Kontexte

Im Serienbetrieb liefert OLLM Informationen über Verzeichnisstruktur, Kapitel,
Sprache, Dokumenttyp und gemeinsame Daten. Ein Serienbetrieb verlangt immer
ein vorhandenes TOML-Projektmanifest und einen durch den Runner eindeutig
bezeichneten Auftrag. Ohne diesen Kontext bricht die Klasse ab. Der lokale
Betrieb muss mit der Klassenoption `standalone` ausdrücklich gewählt werden;
Runner-Zeiger und `standalone` gleichzeitig sind ein Fehler.

Das ist fachlich sinnvoll: Autoreninhalte sollen sowohl als Teil einer Vorlesungsreihe als auch isoliert übersetzbar sein. Der heutige Code behandelt Standalone jedoch teilweise als Rückfallpfad. Künftig sollten beide Kontexte klar spezifizierte, getestete Betriebsarten sein:

- **Standalone:** alle erforderlichen Angaben kommen aus Dokumentoptionen und lokalen Metadaten.
- **Serie:** eine externe Konfigurationsquelle ergänzt Defaults, Pfade und Kapitelkontext.

Eine nicht vorhandene Serienkonfiguration führt insbesondere nicht zu einer
impliziten Umschaltung auf Standalone.

### 3.4 Konfiguration besitzt Herkunft und Priorität

Im neuen Kern werden Doctype und Sprache zunächst aus expliziten
Klassenoptionen übernommen. Eine geladene Auftragsdatei füllt nicht explizit
gesetzte Werte. Explizite Abweichungen sind zu Debugzwecken erlaubt und
erzeugen eine Warnung; der BuildSpec selbst bleibt unverändert.

Das Dokumentprofil löst osglecture aus der Profilklasse des Targets und der
TeX-Projektpolicy auf. Eine explizite Klassenoption darf einen normalen
Projektwert zu Diagnosezwecken überschreiben, nicht jedoch einen erzwungenen
Wert. Ein solcher Widerspruch ist ein Fehler.

### 3.5 Metadaten gehören zum Dokumentmodell

Titel, Autor, Datum, Veranstaltung, Institution, URL und Logo werden teilweise
sehr früh benötigt, obwohl ihre endgültigen Backendbefehle erst nach dem Laden
der Basisklasse existieren. `osglecture-project` erfasst sie deshalb generisch
als Daten aus Feldname, Modusselektor, Kurz- und Langwert sowie
Herkunftspriorität. `osglecture-metadata` wertet die Datensätze später aus;
die Projektdatei wird weder erneut gelesen noch als Hook wiederholt.

Die zugrunde liegende Idee ist richtig: Metadaten sind Daten, keine
unmittelbaren Layoutaktionen. `osglecture-metadata` realisiert dafür den
gemeinsamen Kern:

- Metadaten werden zunächst gespeichert.
- Validierung erfolgt unabhängig vom Ausgabemodus.
- Beamer- und Skriptadapter übertragen die Werte in die jeweilige Basisklasse.
- Kurz- und Langformen sowie modusspezifische Varianten haben eine einheitliche Syntax.
- Weitere Felder lassen sich mit `\DeclareOsgLectureMetadataField` registrieren
  und über generische Wertzugriffe auslesen.

Die öffentliche Oberfläche bleibt dabei bewusst LaTeX-typisch. Etablierte
Befehle wie `\title`, `\author`, `\date` und `\institute` werden nicht durch
einen umfassenden Metadaten-KV-Befehl ersetzt. `osglecture` fängt ihre Werte
backendneutral ab; eigene semantische Befehle ergänzen nur Metadaten, für die
keine etablierte Oberfläche existiert.

Der Kern umfasst derzeit:

```tex
\title[Kurz]{Lang}
\subtitle[Kurz]{Lang}
\author[Kurz]{Lang}
\institute[Kurz]{Lang}
\date[Kurz]{Lang}
\course[Kurz]{Lang}
\event[Kurz]{Lang}
```

Ohne optionale Angabe wird die Langform zugleich als Kurzform gespeichert.
Jeder Befehl akzeptiert außerdem vor der Kurzform eine portable
Modusspezifikation, beispielsweise
`\title<slides>[BS]{Betriebssysteme}`. Die expandierbaren Abfragen heißen
entsprechend `\OsgLectureTitle`, `\OsgLectureShortTitle` und analog für die
übrigen Felder. `\lehrveranstaltung` ist ein Kompatibilitätsalias für
`\course`, `\conference` ein sprechender Alias für `\event`.

`course` und `event` bleiben semantische Angaben und sind keine festen Aliase
für `title` oder `subtitle`. Das Dokumentprofil legt mit `course-target` und
`event-target` deren Darstellung als `title`, `subtitle` oder `none` fest. Die
Standardprofile bilden sie wie folgt ab:

| Profil | `course` | `event` |
|---|---|---|
| Beamer | Untertitel | Untertitel |
| ltx-talk | Untertitel | Untertitel |
| book | keine native Abbildung | keine native Abbildung |
| scrbook | Titel | Untertitel |

Damit bleibt das osgbeamer-Modell in den entsprechenden Adaptern erhalten. Das
neue Standardprofil `book` speichert alle semantischen Werte, bildet zusätzliche
Felder aber bis zur eigenen osglecture-Titelseite nicht auf Klassenbefehle ab.
Eine Unit wird in der Langform strukturell als Kapitel realisiert. Im
Standalone-Fall kann `title` den Vortrag und
`event` die Konferenz bezeichnen. Treffen mehrere Angaben auf dasselbe native
Zielfeld, gilt wie bei gewöhnlichen LaTeX-Titelbefehlen die zuletzt
ausgeführte Angabe.

Der Blattmodus und seine Modusmatrix stehen bereits beim Einlesen
projektweiter Metadaten fest. Targetabhängige Angaben verwenden daher dieselbe
portable Moduslogik wie Autoreninhalte:

```tex
\title{Betriebssysteme}

\lecturemode<presentation>{
  \title[BS]{Betriebssysteme}
}

\lecturemode<script>{
  \title{Betriebssysteme -- Vorlesungsskript}
}
```

Diese Auswahl wirkt ausschließlich auf Metadaten und Inhalt. Sie darf weder
Dokumenttyp noch Backend nachträglich ändern. Eine spätere lokale
Metadatenangabe im Hauptdokument überschreibt die projektweite Vorgabe aufgrund
der expliziten Herkunftspriorität `Profil < Projekt < Unit < Enforcement`, nicht lediglich
aufgrund der Lesereihenfolge.

Damit entfällt ein großer Teil des temporären Überschreibens und Wiederherstellens fremder Befehle.

### 3.6 Kapitel sind die gemeinsame Struktureinheit

Eine Unit, eine Lecture und ein Kapitel sind drei Perspektiven derselben
fachlichen Struktureinheit:

- **Unit:** Projekt- und Buildperspektive,
- **Lecture:** Autoren- und Präsentationsperspektive,
- **Kapitel:** Langformperspektive.

Die kanonische Autorenoberfläche lautet
`\lecture[Kurz]{Lang}{unit-id}`. Sie beginnt nicht mehrere unabhängige Strukturen,
sondern beschreibt die aktuelle Unit. Im Präsentationsprofil liefert sie den
Unit-Titel und die native Lecture-Information; im Langformprofil erzeugt sie
die Kapitelüberschrift. Das Backendkommando `\chapter` beziehungsweise Beamers
native `\lecture` bleibt dabei ein internes Adapterdetail, nicht die
bundleweite Semantik.

Die Identität ist vom sichtbaren Titel getrennt. Die stabile Unit-ID stammt aus
dem obligatorischen letzten Argument von `\lecture`; `physical-unit`,
`physical-number` und Verzeichnisslug beschreiben Verzeichnis und Sortierung,
sind aber keine Ersatz-ID. Ein Backendadapter darf aus der Unit-ID interne
Labels ableiten. Standalone setzt weder Manifest noch Serienverzeichnis voraus,
verwendet aber für eine mit `\lecture` deklarierte Unit dieselbe explizite
logische ID.

Der Schema-1-BuildSpec enthält `unit-id` nur, wenn ein früherer validierter
Zustand die Zuordnung bereits kennt. Der LaTeX-Lauf meldet die deklarierte ID
im Ergebnis; ein späterer Build erhält diesen Wert ausschließlich zur
Konsistenzprüfung.

Eine kanonische `structure-signature` im BuildSpec bildet ausschließlich die
sortierte physische Unit-Struktur relativ zur Serienwurzel ab. Sie sorgt dafür,
dass Umbenennung und Umordnung einen später angeforderten Serienbuild
invalidieren, ohne daraus eine logische ID abzuleiten. Absolute Projektpfade
und Zeitstempel gehören nicht in diese Signatur.

Für eine noch nie erfolgreich gebaute Unit existiert zunächst keine Zuordnung
zwischen logischer ID und physischem Build. Diese Bootstrap-Lücke wird bewusst
LaTeX-typisch behandelt: osglecture leitet die ID nicht aus Slug, Nummer,
Jobname oder Nachbarverzeichnis ab, und OLLM durchsucht die Quelle nicht nach
`\lecture`. Eine darauf gerichtete Referenz bleibt `??` und erzeugt eine
Warnung. Erst ein erfolgreicher direkter Build der Ziel-Unit veröffentlicht
ihre Zuordnung.

Für den Strukturvertrag gelten folgende Invarianten:

- Eine Unit besitzt genau eine stabile Unit-ID und beliebig übersetzte oder
  gekürzte sichtbare Titel.
- `\lecture[Kurz]{Lang}{unit-id}` ändert weder Doctype noch Dokumentprofil.
- Präsentation und Langform verwenden dieselbe Unit-ID für Referenzen.
- Abschnitts- und Objekt-IDs werden aus Unit-ID und lokaler Identität
  abgeleitet, nicht aus sichtbaren Zählerständen.
- Nummerierung und sichtbare Überschriften dürfen profilabhängig sein; die
  Identität bleibt es nicht.
- Im Standalone-Betrieb bleiben lokale Nummern und Referenzen ohne
  übergeordnetes Serienverzeichnis funktionsfähig.

Zähler-Aliase sind lediglich eine mögliche Backendimplementierung. Kein Paket
darf konkrete Beamer- oder KOMA-Zähler als bundleweite Unit-Identität
voraussetzen.

Die profilunabhängigen Gliederungsbefehle dürfen im optionalen Argument neben
einem schlüssellosen Kurztitel die getrennten Titelprojektionen `shorttitle`,
`toc`, `bookmark`, `running` und `nameref` sowie `label` und die native
Nummerierungswahl führen. `subtitle` ist eine optionale semantische Ergänzung
desselben Headings. Er eröffnet keine weitere Gliederungsebene, verbraucht
keinen zusätzlichen Zähler und wird bei der automatischen Projektion eines
Gliederungstitels auf den folgenden Präsentationsframe nicht als weiterer
Frame-Titelslot gezählt. Ein Adapter beziehungsweise Design darf ihn als
zweite Zeile desselben Headings darstellen; TOC-, Bookmark-, Running- und
Nameref-Titel ändern sich dadurch nur bei ausdrücklicher Angabe.

Der im entstehenden LaTeX-Heading-Vertrag vorgesehene Schlüssel `quote` wird
nicht mit einer abweichenden osglecture-Semantik belegt. Der Kern darf ihn als
Standardfeld transportieren, verspricht aber zunächst weder Darstellung noch
portable Autorensemantik. Ein fachlich bestimmtes Epigraph aus Zitattext,
Urheber und Quelle gehört in ein registriertes Projekt- oder Fachpaket. Ein
solches Paket darf die Ausgabe beispielsweise auf `longform` beschränken,
ohne daraus eine weitere Gliederungsebene zu machen.

### 3.7 Modusabhängigkeit soll semantisch bleiben

Die Klasse macht zahlreiche Standardbefehle overlay-fähig und ändert Verhalten in `presentation` und `article`. Das erleichtert bestehende Quellen, greift aber tief in Kern- und Beamerbefehle ein. Besonders globale Änderungen an `\footnote`, `\vspace`, Schriftgrößen oder `\Roman` bergen Kompatibilitätsrisiken.

Für die Überarbeitung sollte gelten:

- Eigene semantische Befehle vor globalen Patches bevorzugen.
- Patches nur in einem klar abgegrenzten Adapter und mit Tests einsetzen.
- Der Artikelmodus muss auch ohne visuelle Beamer-Annahmen verständlich bleiben.
- Gleiche Eingabe soll in jedem unterstützten Modus deterministisch sein.

Ein implementiertes Beispiel ist das obligatorische, von der Kernklasse
automatisch geladene Klassenpaket `osglecture-presitemize.sty`. Es hängt auf
Paketebene nur von `osglecture-modes` ab; die Kernklasse bleibt Eigentümerin
des Dienstes, obwohl dessen Implementation eine eigene Styledatei besitzt.
Die Umgebung `presitemize` beschreibt eine
flache Folge präsentationsgeeigneter Aussagen semantisch. Im
Präsentationsmodus projiziert sie diese auf eine gewöhnliche Liste, in der
Verhaltensklasse `longform` auf verbundenen Fließtext. Die kompakte
Autorenoberfläche (`\anditem`, `\butitem`, `\thereforeitem`) und die
gleichwertige Key-Oberfläche
(`\presitem[relation=sentence|and|but|therefore,...]`) bilden denselben
internen Vertrag ab.

Die semantische Projektion umfasst die Tagstruktur: Präsentationsmodi verwenden
die native, vom jeweiligen Backend beziehungsweise LaTeX getaggte
`itemize`-Umgebung. `longform` erzeugt unmittelbar Absatzinhalt und baut keine
unsichtbare Inline-Liste auf. Dadurch entspricht der Strukturbaum der jeweils
sichtbaren Textform und bleibt unabhängig von `enumitem`-Kompatibilität.

Die Sprachprofile `de`, `en` und `fr` besitzen Konnektoren,
Interpunktion und die Stellung des markierten finiten Verbs. Die
Sprachauflösung erfolgt lokal in der Reihenfolge explizite Umgebungsoption,
Babel, Polyglossia, `langselect`, Klassenkonfiguration. Damit bleibt
Sprachauswahl eine dokumentsemantische Entscheidung; sie wird nicht aus einem
Backendnamen abgeleitet. Die Umgebung ist bewusst keine allgemeine
Grammatikengine und kein verschachtelbares Listenmodell. Nicht reguläre Fälle
bleiben über explizite Langform-/Präsentationsvarianten ausdrückbar.

Ein künftiger proseartiger Doctype integriert sich ohne Änderung dieses
Kerndienstes, indem sein Profil ihn vor Aktivierung des Blattmodus mit
`\AssignLectureModeBehavior{<doctype>}{longform}` der bestehenden
Verhaltensklasse zuordnet. Er erbt damit dieselbe `presitemize`-Projektion wie
`script` und `article`. Eine Ausgabeform mit fachlich anderer
Listensemantik darf nicht allein wegen ihres Umfangs `longform` heißen; dafür
ist eine neue Verhaltensklasse samt expliziter Implementierung und Tests
einzuführen.

Das ebenfalls obligatorische Klassenpaket `osglecture-twocolumns.sty`
projiziert zwei mit `\nextcolumn` getrennte Inhalte entweder auf echte Spalten
oder auf eine lineare Folge. Die Modusauswahl gehört zu dieser Semantik, die
Box- und Ausrichtungslogik zum Paket. Ohne expliziten Ausdruck ist
`presentation` der Selektor; ein Winkelausdruck ersetzt diesen Default.
Dadurch bleiben Langformen grundsätzlich linear, können aber mit
`<longform>`, `<presentation|longform>` oder `<all>` ausdrücklich
zweispaltig gesetzt werden. Das Paket hängt direkt von `osglecture-modes` ab;
es besitzt kein zweites, von der Ladereihenfolge abhängiges Verhalten ohne
Modussystem.

### 3.8 Paketgrenzen folgen semantischer Eigentümerschaft

Doctype-Abhängigkeit entscheidet nicht, ob eine Funktion zur Kernklasse oder
in ein eigenes Paket gehört. Sie ist für gemeinsame Quellen normal. Die
verbindliche Abgrenzung lautet:

> `osglecture` besitzt das gemeinsame Dokumentmodell. Ein Einzelpaket besitzt
> eine optionale fachliche Funktion.

Zum Kern beziehungsweise zu einem obligatorischen Kerndienst gehört eine
Funktion, wenn sie Dokumentidentität, Grundstruktur oder die universelle
Projektion derselben Quelle bestimmt. Dazu zählen insbesondere:

- Doctype-, Profil- und Modusauswahl,
- Metadaten und Dokumentidentität,
- Unit-/Lecture-/Chapter-Struktur,
- grundlegende Bild- und Tabellenstruktur einschließlich Beschriftung, Label
  und Referenzidentität,
- stabile Integrationshooks für andere Komponenten.

Ein eigenes Paket ist angezeigt, wenn die Funktion einen abgrenzbaren,
optionalen semantischen Gegenstand besitzt, unabhängig dokumentiert und
getestet werden kann oder wesentliche eigene Abhängigkeiten mitbringt. Das gilt
beispielsweise für Terminaldarstellungen, komplexe Bildraster,
Messdatendiagramme oder spezielle Tabellenmodelle. Ein solches Paket darf
doctype-abhängige Implementierungen besitzen; es wird dadurch nicht zum
Bestandteil der Kernklasse.

Für Grenzfälle werden die folgenden Fragen in dieser Reihenfolge beantwortet:

1. Verliert das Dokument ohne die Funktion seine Identität oder
   Grundstruktur? Dann gehört der Vertrag in den Kern.
2. Ist der Gegenstand für viele Dokumente vollständig entbehrlich und dennoch
   in sich kohärent? Dann gehört er in ein eigenes Paket.
3. Sind nur Layout oder Branding betroffen? Dann gehört die Entscheidung in
   Theme oder Profiladapter.
4. Bestehen umfangreiche optionale Abhängigkeiten? Dann bleibt deren
   Implementierung außerhalb des Kerns, auch wenn ein kleiner semantischer
   Integrationshook im Kern erforderlich ist.

„Bilder und Tabellen gehören zum Kern“ meint daher nur ihre grundlegende
Dokumentsemantik. Galerien, annotierte Medien, Datenimport oder
Tabellenautomatisierung bleiben eigenständige Fachpakete.

### 3.9 Referenzen über Unitgrenzen

Der obligatorische, separat testbare Kerndienst
`osglecture-references.sty` besitzt die Referenzsemantik. Hyperref erzeugt
lokale Ziele und sichtbare Links; `xr` ist ein austauschbares internes
Importdetail. Autoren verwenden weder physische Aux-Pfade noch Importpräfixe.

Die kurze API lautet:

```tex
\olref{label}
\olref[unit-label]{label}
\olref[unit-label,type=script,lang=en]{label}
```

Ein schlüsselloser Eintrag der optionalen Liste ist stets die Unit; die
expliziten Schlüssel heißen `unit`, `type` und `lang`. Ihre Reihenfolge ist
beliebig und die letzte Mehrfachangabe zählt. Ohne Unit ist die Referenz lokal,
ohne `type` oder `lang` gelten aktueller Dokumenttyp und aktuelle Sprache. Es
gibt keinen stillen Sprach- oder Doctype-Fallback. Die parallelen Befehle
`\olpageref`, `\olnameref` und `\olautoref` besitzen dieselbe Adresse.
Sternvarianten geben wie bei Hyperref denselben Text ohne Link aus.

Die Optionen

```tex
\usepackage[legacy,replace={ref,pageref}]{osglecture-references}
```

beziehungsweise `\OsgLectureReferencesSetup` konfigurieren ausschließlich die
LaTeX-Oberfläche. `legacy` ist standardmäßig falsch und aktiviert
Kompatibilitätsadapter für den alten xref-Befehlssatz. `replace` ist
standardmäßig `none`, ohne Wert `all`, und akzeptiert `ref`, `pageref`,
`nameref`, `autoref`, `all` und `none`. Projektweiter Shared Code darf dieselben
Schlüssel setzen; sie gehören nicht in TOML.

Für lokale, positionsabhängige Seitenverweise lädt das Modul außerdem
`varioref` mit `nospace`. Dessen Befehle bleiben die öffentliche API; nur
`\xrefdist` wird optional als Legacy-Adapter implementiert. Deutsche und
englische `varioref`-Texte werden registriert und können über Babel gewechselt
werden. Solche Distanzverweise werden nicht auf andere Units oder Doctypes
ausgedehnt, weil ihre Aussage nach Einzelbuild und PDF-Komposition nicht
dieselbe Bedeutung hätte.

Alle gewöhnlichen Labels werden in eine kontrollierte `.osgref.aux` gespiegelt.
Nur tatsächlich adressierte Fremddokumente werden importiert. Ein
OLLM-generierter Snapshot bildet die logische Adresse aus Serie, Unit,
Dokumenttyp und Sprache auf den letzten validen Export und dessen Artefakt ab.
Fehlende Ziele ergeben `??` und eine Warnung; `ollm check` bleibt für
Integritätsprüfungen streng.

`build --resolve` arbeitet nur mit bereits bekannten Zuordnungen. Es darf eine
unbekannte logische Unit weder heuristisch einem Verzeichnis zuordnen noch
TeX-Quellen durchsuchen. `ollm check` listet unbekannte Unit-IDs, fehlende
Doctype-/Sprachprojektionen und fehlende Labels vollständig als
Serieninkonsistenzen auf.

Der stabile Propertyvertrag unterscheidet `page`, die physische Seite des
konkreten PDFs, und `slide`, die Frame-Nummer einer Präsentation. Damit kann
ein Handout die ursprüngliche Foliennummer referenzieren, obwohl mehrere
Folien auf einer physischen Seite liegen.

Für Einzelprodukte können Links als `GoToR` auf ein auffindbares Serien-PDF
zeigen. Nicht gemeinsam veröffentlichte Doctypes dürfen nur den Referenztext
ausgeben. Ein Integrationsprodukt wählt Units mit `\includeunit` oder
`\includeunits`; `...` bezeichnet einen inklusiven Bereich der logischen
Serienfolge und ist deshalb in Unit-IDs verboten. `tagpax` internalisiert Links
zwischen enthaltenen Units als `GoTo`, erhält dabei aber das vorhandene
getaggte Link-Strukturelement und dessen OBJR. Das Integrationsprodukt
reexportiert in der ersten Version keine Unitreferenzen.

Die Integration verarbeitet ausschließlich bereits gebaute, getaggte
Unit-PDFs; eine alternative Quellintegration gehört nicht zu diesem Vertrag.
Aus OLLM-Sicht ist das Integrationsverzeichnis eine gewöhnlich übersetzte Unit
mit Rolle `i` (`integration`). OLLM soll den Snapshot der promotierten
Artefakte, Rollen und Serienreihenfolge liefern, interpretiert aber weder
`\includeunit(s)` noch komponiert es PDFs. Auswahl, Bereichsauswertung und
tagpax-Import gehören in einen osglecture-Integrationsdienst. Dieser bildet den
logischen, pfadunabhängigen Ersatz für das frühere `osgcombinescript`.

Bei der künftigen Implementierung schreibt `\includeunit` beziehungsweise
`\includeunits` für jede nach Bereichsexpansion tatsächlich ausgewählte
Unitprojektion einen kontrollierten Abhängigkeitsrecord mit Unit-ID, Doctype,
Sprache und verwendeter Zielgeneration. OLLM leitet die Auswahl nicht durch
Quelltextsuche her. Nur diese gemeldeten Integrationen machen ein
Unit-Artefakt für `check` und `build --resolve` erforderlich; eine bloß
entdeckte, unreferenzierte und nicht integrierte Unit darf ungebaut bleiben.

Mit aktivem `\DocumentMetadata` erzeugt der Dienst Links ausschließlich über
Hyperref und LaTeX PDF Management. Er besitzt weder eine eigene
Tagginginitialisierung noch direkte PDF-Linkprimitiven. Sternvarianten und
fehlende Ziele erzeugen keine Annotation.

## 4. Aktuelle öffentliche Oberfläche

Die folgende Gruppierung beschreibt die heute sichtbaren Konzepte, nicht notwendigerweise die künftig zu bewahrende API.

### Konfiguration

- `doctype`, `lang`, `standalone`
- Weitergabe über `beamer`, `book`, `tuc`, `bib`
- `aspectratio`, `handout format`, `continuation`, `docid`
- `legacy`, `nobib`, `noforcetoc`, `osgdefaults`, `final`
- `\SetGlobalClassOptions`, `\EnforceGlobalClassOptions`

### Metadaten und Lebenszyklus

- `\SetLogo`
- verzögerte Titelbefehle wie `\author`, `\date`, `\course`, `\event`, `\institute`
- `\AfterTitle`

### Gemeinsamer Autoreninhalt

- `\osgpresart{Präsentation}{Artikel}`
- `presitemize` mit kompakter Item-Syntax und äquivalenter
  `\presitem`-Key-Syntax
- `\longform`, `\slides`, `\longslides`, `\prescase`, `\preskeepcase` und
  `\finite` für semantische Varianten innerhalb von `presitemize`
- `\sbf`, `\newdef`, `\stress`, `\outline`
- modusfähige Fußnoten und ausgewählte Abstands- und Schriftgrößenbefehle
- `\sourceref`

### Layout und Medien

- mode-aware Umgebung `twocolumns` mit Defaultselector `presentation` und
  expliziter Spaltenauswahl für `longform`
- `\centerpic`
- `\markword`
- Pfeile und Smileys

### Notizen und Hilfen

- `specialitemize`, `noteitemize`
- `\DebugFont`
- Legacy-Kommandos mit Deprecation-Warnungen

Ein wesentlicher Schritt der Überarbeitung ist die Entscheidung, welche dieser Gruppen zur Klasse, zu einem Autorenpaket, zu einem Theme oder ausschließlich in einen Kompatibilitätslayer gehören.

## 5. Heutige Kopplungen und Risiken

### 5.1 Normalisierte OLLM-Grenze

Der neue Kern liest ausschließlich die jobgebundene
`<jobname>.osgbuild.tex`. OLLM besitzt Manifest-Parsing, Discovery und
Prioritätsauflösung; die Klasse validiert Schema und Jobbindung und übernimmt
die normalisierten Werte. Damit setzt sie weder ein bestimmtes
Arbeitsverzeichnis noch eine externe Konfigurationssyntax voraus.

Zu diesen normalisierten Werten gehören `shared-tex-directory` und
`project-config-file`. OLLM löst das im Projektmanifest standardmäßig als
`Include/projectconfig.tex` beschriebene Paar auf, setzt den absoluten
Verzeichnispfad in `TEXINPUTS` und transportiert ihn jobgebunden. Die Klasse
liest weder TOML noch sucht sie selbst nach dem Projektroot. Sie liest die
Projektkonfiguration jedoch bereits vor `\LoadClass` durch die
basisklassenunabhängige Bootstrap-Schicht `osglecture-project`. Deklarationen
werden dabei gespeichert und erst in ihrer zulässigen Phase materialisiert.
So können `class-options` früh wirken, während mode-spezifische Metadaten erst
nach Finalisierung des Modusgraphen ausgewählt und an das Backend übertragen
werden.

### 5.2 Frühe und späte Optionen sind vermischt

Optionen für die Basisklasse müssen vor `\LoadClass` feststehen; andere Optionen könnten später verarbeitet werden. Aktuell laufen Weitergabe, Defaultsetzung, Konfigurationseinlesen und Schlüsselverarbeitung durch mehrere Mechanismen aus LaTeX2e, expl3 und `etoolbox`.

**Leitlinie:** Eine frühe Konfigurationsphase bestimmt ausschließlich Backend und früh benötigte Optionen. Nach dem Laden des Backends folgt eine zweite, klar benannte Initialisierungsphase.

### 5.3 Die Klasse setzt nicht vorhandene Nachbarpakete voraus

Die aktuelle Datei lädt unter anderem `osgbeamerref`, `osgbeamerlanguage`, `osgbeamerbib`, `beamerarticleosg` und das Theme `osg`. Ein Teil davon liegt nur unter `oldcode`, anderes ist im sichtbaren Baum nicht vorhanden. Dadurch ist die Klasse im aktuellen Repositoryzustand nicht als geschlossenes Produkt testbar.

**Leitlinie:** Jede Abhängigkeit benötigt einen eindeutigen Besitzer, eine installierbare Quelle, eine minimale Versionsanforderung und einen Test. Optionale Funktionen müssen auch technisch optional sein.

### 5.4 Kern, Theme und Komfortmakros sind nicht getrennt

Schriftwahl, Farben, Emojis, Markierungen, zweispaltige Layouts, Quellenformatierung und Notiztransformation stehen neben Moduswahl und Klassenladen. Das erschwert Austauschbarkeit und Tests.

**Leitlinie:** Die Kernklasse enthält nur Bootstrapping, Konfigurationsmodell, Backendwahl und stabile Integrationshooks. Visuelle Entscheidungen gehören in Themes; Autorenkomfort in ein unabhängiges Paket.

### 5.5 Globale Patches erhöhen die Überraschung

Mehrere Standardbefehle werden global umdefiniert. Besonders die Änderung von `\Roman` für den Zählerstand null ist fachlich sehr speziell, wirkt aber dokumentweit. Ähnliches gilt für `\footnote`, vertikale Abstände und Schriftgrößen.

**Leitlinie:** Keine globale Änderung ohne eng formulierte Invariante, dokumentierte Motivation und Regressionstest. Wo möglich, neue Namen oder lokale Umgebungen verwenden.

### 5.6 Unterstützungsstatus und API sind nicht eindeutig

Kommentare nennen experimentelle oder nicht unterstützte Modi; `script` und `article` sind faktisch Aliase; `legacy` wird zugleich als noch ungenutzt und als umfangreicher Kompatibilitätszweig beschrieben. Einzelne Schlüsseldefinitionen wirken unfertig. Das bestehende Beispiel und die Bundle-README verweisen noch auf den Vorgänger.

**Leitlinie:** Eine veröffentlichte Kompatibilitätsmatrix trennt stabil, experimentell, deprecated und entfernt. Nur stabile Funktionen prägen den Kernentwurf.

## 6. Zielbild für die Architektur

Die Klasse sollte langfristig eine dünne Fassade über klaren Komponenten sein:

```text
osglecture.cls
│
├── Konfigurationskern
│   ├── Schlüssel, Defaults und Prioritäten
│   ├── normalisierte OLLM-Eingabe
│   └── Diagnose und Validierung
│
├── Dokumenttyp- und Moduskern
│   ├── kanonischer Dokumenttyp als Blattmodus
│   ├── validierte Modusmatrix
│   └── portable Modusabfragen über osglecture-modes
│
├── Backendadapter
│   ├── slides  → beamer oder ltx-talk
│   ├── handout → beamer oder ltx-talk
│   └── script  → book (alternativ scrbook)
│
├── Domänendienste
│   ├── Metadaten und Dokumentidentität
│   ├── Kapitel- und Referenzmodell
│   ├── Sprache
│   └── Bibliografie
│
├── Darstellung
│   ├── austauschbares Theme
│   └── Artikel-/Skriptstil
│
└── optionale Pakete
    ├── Autorenkomfort und didaktische Makros
    ├── Notizen
    └── Legacy-Kompatibilität
```

### Verantwortlichkeit der Kernklasse

Die Kernklasse sollte:

- den minimalen LaTeX- und Engine-Vertrag prüfen,
- Konfiguration normalisieren,
- genau einen Dokumenttyp auswählen,
- diesen Dokumenttyp als aktiven Blattmodus setzen,
- die azyklische Modusmatrix validieren und registrieren,
- die passende Basisklasse laden,
- standardisierte Hooks für Komponenten bereitstellen,
- erforderliche Kerndienste initialisieren,
- die universelle Listen-/Fließtext-Projektion `presitemize` initialisieren,
- die Spalten-/Folge-Projektion `twocolumns` initialisieren,
- verständliche Diagnosen ausgeben.

Sie sollte nicht:

- externe Konfigurationssprachen parsen,
- konkrete Logos, Farben oder Schriften fest verdrahten,
- allgemeine Layouthelfer sammeln,
- Standardbefehle ohne zwingenden Grund global verändern,
- nicht unterstützte Backends als scheinbar wählbare Optionen anbieten.

### Stabiler Erweiterungsvertrag

Folgende Namen und Phasen sind die öffentlichen Anknüpfungspunkte für
Dokumentprofile und eigenständige Fachpakete:

1. Auftrag und Dokumentprofil werden ausgewählt; der Profildeskriptor liefert
   frühe Defaults.
2. `osglecture-project` liest `projectconfig.tex` deklarativ und speichert
   frühe Optionen sowie noch nicht ausgewertete Metadaten.
3. Profil-, Projekt- und explizite Unit-Klassenoptionen werden zusammengeführt;
   danach wird die Basisklasse genau einmal geladen.
4. `osglecture-modes` deklariert die portable Grundmatrix.
5. `osglecture` deklariert die stabilen Verhaltensklassen
   `presentation-dynamic`, `presentation-static` und `longform`.
6. `mode-setup-file` darf vor Aktivierung des Blattmodus zusätzliche Modi,
   Elternkanten, Aliase und Verhaltenszuordnungen deklarieren.
7. Die Klasse aktiviert den Doctype als Blattmodus, ergänzt Profilmodi und
   finalisiert den Modusgraphen.
8. `osglecture-metadata` wertet die gespeicherten Selektoren aus und bindet die
   zutreffenden Metadaten an die nativen Backendbefehle.
9. Die Klassenpakete `osglecture-presitemize` und
   `osglecture-twocolumns` binden ihre Projektionen an den finalisierten
   Modusgraphen, nicht an konkrete Profile oder Backends.
10. `setup-file` darf Backendadapter, Formatierung und Implementierungen
   semantischer Befehle registrieren. Der Modusgraph ist zu diesem Zeitpunkt
   bereits unveränderlich.
11. Spätestens zu `\begin{document}` prüft
   `\FinalizeModeAwareCommands` die vollständigen Befehlsverträge.

Für ein eigenständiges Fachpaket folgt daraus:

- Es darf direkt von `osglecture-modes`, aber nicht von
  `osglecture.cls` abhängen, sofern es keine Klassenintegration benötigt.
- Es selektiert Autorenverhalten nach Doctype, Obermodus oder stabiler
  Verhaltensklasse, nicht nach Profil- oder Backendnamen.
- Es deklariert seine semantischen Autorenbefehle selbst und implementiert
  jede versprochene Verhaltensklasse vollständig.
- Backendspezifische Optimierungen liegen in einem schmalen Adapter und
  besitzen eine portable Fallbacksemantik.
- Der Kern kennt keine Liste optionaler Fachpakete. Integration geschieht
  durch deren Registrierung an den öffentlichen Contracts.
- Ein Paket mit unabhängiger Nutzung dokumentiert den Betrieb ohne
  `osglecture.cls`; die automatische Moduserkennung ist dort lediglich ein
  Default, explizite Moduswahl bleibt möglich.

Die Abhängigkeitsrichtung ist damit:

```text
osglecture-modes
      ↑
Fachpaket ──→ optionaler Backendadapter
      ↑
osglecture-Integration beziehungsweise Dokumentprofil
```

Dieser Vertrag erlaubt doctype-abhängige Fachpakete, ohne den Kern von ihnen
abhängig zu machen. Neue öffentliche Verhaltensklassen oder Änderungen der
Ladereihenfolge sind deshalb API-Änderungen und müssen zusammen mit
Profil- und Pakettests erfolgen.

## 7. Entwurfsprinzipien für die Überarbeitung

1. **Semantik vor Layout.** Die API beschreibt didaktische Bedeutung; Themes entscheiden über Darstellung.
2. **Explizite Zustände.** Dokumenttyp, Serienkontext und Sprache sind validierte Werte, keine lose Kombination von Booleans.
3. **Eine fachliche Typachse.** Target und Dokumenttyp sind Build- und Dokumentperspektive derselben kanonischen Auswahl; der Blattmodus ist keine zusätzliche unabhängige Dimension.
4. **Eine Konfigurationssprache.** Neue öffentliche Schlüssel werden konsistent mit expl3/L3Keys implementiert.
5. **Deterministische Prioritäten.** Jeder effektive Wert hat eine nachvollziehbare Herkunft.
6. **Lose Kopplung an OLLM.** OLLM liefert Daten; die Klasse kennt nicht dessen interne Dateien oder Parser.
7. **Austauschbare Darstellung.** TUC-/OSG-Branding ist ein Standardtheme, aber keine Voraussetzung der Kernklasse.
8. **Optionale Dienste bleiben optional.** Bibliografie, Notizen und Komfortpakete dürfen den Minimalfall nicht belasten.
9. **Keine stillen Rückfälle.** Ungültige Werte, fehlende Pflichtdaten und inkonsistente Kombinationen führen zu klaren Meldungen.
10. **Migration ist ein eigenes Produktmerkmal.** Kompatibilität wird in einem abgegrenzten Layer mit Warnungen und Entfernungshorizont umgesetzt.
11. **Testbarkeit prägt den Schnitt.** Komponenten müssen mit kleinen Beispielen isoliert testbar sein; visuelle Tests ergänzen semantische Logtests.

## 8. Invarianten

Eine spätere Implementierung sollte mindestens folgende Aussagen garantieren:

- Genau ein unterstützter Dokumenttyp ist aktiv.
- Der aktive Blattmodus ist mit diesem Dokumenttyp identisch.
- Alle aktiven Obermodi folgen ausschließlich aus der validierten azyklischen Modusmatrix.
- Backendnamen sind keine Autorenmodi.
- `script` und Präsentationsmodi erhalten dieselben fachlichen Metadaten.
- Standalone benötigt keine Datei oberhalb des Dokumentverzeichnisses.
- Der Serienmodus kann vollständig durch explizite Eingaben simuliert werden.
- Lokale Dokumentoptionen und erzwungene Serienrichtlinien haben dokumentierte Priorität.
- Fehlende optionale Pakete beeinträchtigen nur die zugehörige Funktion.
- Kapitel-, Abschnitts- und Dokument-IDs sind in allen Modi stabil ableitbar.
- Jede öffentliche Autorenfunktion ist für alle unterstützten Modi definiert oder weist den nicht unterstützten Modus ausdrücklich zurück.
- Die Minimaldatei jedes stabilen Dokumenttyps übersetzt ohne Legacy-Layer.
- Deprecated APIs erzeugen eine maschinenprüfbare Warnung und besitzen einen Migrationshinweis.

## 9. Offene Entwurfsentscheidungen

Vor einer Implementierung sollten folgende Fragen entschieden werden:

### Produktumfang

- Nach welchen Tests und Dokumentationsanforderungen wird ein zusätzlich
  registrierter Dokumenttyp als stabil erklärt?
- Ist `screen` weiterhin ein Ziel oder Aufgabe eines externen Präsentationswerkzeugs?
- Soll eine Webausgabe Teil dieser Klasse sein oder ein separater Konverter?

### Basisklassen und Theme

- Welche zusätzlichen Fähigkeiten soll der optionale `scrbook`-Adapter über
  das Standardprofil `book` hinaus dauerhaft anbieten?
- Welche gemeinsame Semantik müssen Beamer- und `ltx-talk`-Adapter für
  `slides` garantieren?
- Welche Teile des TUC-/OSG-Designs sind Default, welche Voraussetzung?

### Konfiguration

- Dürfen erzwungene globale Optionen lokale Dokumentoptionen überschreiben?
- Welche Werte müssen vor dem Laden der Basisklasse feststehen?
- Welche Profildeskriptoren und `mode-setup-file`s bilden die stabile
  Standardmatrix vollständig ab?

### Autoren-API

- Welche Makros drücken echte didaktische Semantik aus?
- Sollen `\stress`, `\outline` und `\sourceref` Teil eines Autorenpakets werden?
- Wie werden Notizen semantisch erfasst, ohne `itemize` umzudefinieren?

### Kompatibilität

- Welche reale Quellbasis muss ohne Änderungen weiter funktionieren?
- Wird der alte Klassenname als Wrapper beibehalten?
- Welche Übergangsfrist und welche automatisierbaren Migrationen sind vorgesehen?

## 10. Vorgeschlagene Reihenfolge der Überarbeitung

1. **Vertrag festlegen.** Stabile Dokumenttypen, unterstützte Engine, Minimalbeispiele und Kompatibilitätsziel definieren.
2. **Konfigurationsmodell extrahieren.** Werte, Typen, Defaults, Prioritäten und Diagnoseausgabe spezifizieren.
3. **OLLM-Grenze normalisieren.** Parsing aus der Klasse entfernen und eine kleine Eingabeschnittstelle schaffen.
4. **Backendadapter isolieren.** Präsentation, Handout und Skript mit je einem minimalen Test aufbauen.
5. **Metadaten- und Strukturmodell etablieren.** Titel, Kapitelidentität, Nummerierung und Referenzziele vereinheitlichen.
6. **Dienste modularisieren.** Sprache, Referenzen und Bibliografie als getrennte Pakete mit expliziten Abhängigkeiten führen.
7. **Darstellung auslagern.** Theme, Schriften, Farben und Skriptstil von der Kernklasse trennen.
8. **Autorenkomfort sichten.** Nur semantisch tragfähige Befehle bewahren; Layouthelfer auslagern oder streichen.
9. **Legacy-Layer bauen.** Alte Namen abbilden, Warnungen testen und einen Migrationsleitfaden erstellen.
10. **Integration und visuelle Regression.** Reale Kapitel in allen stabilen Modi übersetzen und Ausgaben vergleichen.

## 11. Prüfkriterien für den neuen Entwurf

Die Architektur ist ausreichend klar, wenn sich folgende Fragen jeweils mit einem Satz beantworten lassen:

- Wer entscheidet den Dokumenttyp?
- Woher stammt jede Option und wer darf sie überschreiben?
- Welche Komponente besitzt Metadaten, Kapitelidentität, Sprache und Referenzen?
- Was ist die minimale installierbare Einheit?
- Wie wird ein neues Theme ergänzt?
- Wie wird ein weiterer Dokumenttyp ergänzt?
- Welche öffentlichen Befehle dürfen Autoren verwenden?
- Welche Abhängigkeiten sind für welchen Modus erforderlich?
- Wie wird eine alte Quelle migriert?
- Welche Tests beweisen semantische und visuelle Gleichwertigkeit?

## 12. Die OLLM-Grenze

OLLM hat genau zwei Aufgaben: sicherzustellen, dass die korrekte Projektion
gebaut wird, und das Deployment der Ergebnisse. Warum ältere Codeteile darüber
hinausgehen, steht gesammelt in [`HISTORY.md`](./HISTORY.md); dieser Abschnitt
beschreibt nur das verbindliche Zieldesign.

**Leitlinie:** Jede OLLM-Verantwortlichkeit wird gegen genau zwei Fragen
geprüft: Ist sie nötig, um zu entscheiden, *was* gebaut werden soll, und den
Bau *korrekt* durchzuführen (Auftrag)? Oder ist sie nötig, um ein bereits
validiertes Ergebnis an seinen Zielort zu bringen (Deployment)? Trifft keine
der beiden Fragen zu, gehört die Verantwortlichkeit nicht zu OLLM.

### Ein gemeinsames Modul für Projektinhalt und Discovery

Projektinhalt -- Serienstruktur, Verzeichnisgrammatik, verfügbare Sprachen,
Bundle-Preset-Inhalt -- wird von einem gemeinsamen Lua-Modul gelesen, nicht
von OLLM. Dieses Modul ist:

- über `\directlua` aus einem echten Kompilierlauf aufrufbar: `osglecture`
  liest sein eigenes Projektumfeld selbst, das ist der primäre Verbraucher;
- über `texlua` eigenständig aufrufbar, ohne einen vollständigen LaTeX-Lauf
  zu benötigen.

OLLM ist Nutzer dieses Moduls, nicht Parallelimplementierer. Wo OLLM
Projektinhalt für eigene Aufgaben braucht -- Serien-Discovery für
`build --all`, eine schnelle Konsistenzprüfung in `ollm check`/`ollm doctor`
ohne vollständigen Kompilierlauf --, ruft es dasselbe Modul über `texlua` auf,
statt eine zweite, unabhängige Interpretation in Perl zu pflegen. Damit gibt
es weiterhin genau einen Parser und eine Merge-/Prioritätslogik; nur die
Sprache dieser einen Implementierung ist Lua, nicht Perl.

Für Manifestinhalt, der Teil der Auftragsentscheidung ist (siehe unten),
bleibt der schmale, als `TOML::Tiny` vendorierte Perl-Parser in OLLM
maßgeblich -- mit derselben Portabilitätsbegründung, mit der auch das
gemeinsame Lua-Modul einen vendorierten, reinen Lua-TOML-Leser ohne externe
Abhängigkeit benötigt: LuaLaTeX und das minimale Windows-Perl garantieren
beide keine zusätzlich installierten Bibliotheken.

### Was strukturell bei OLLM bleibt

Drei Gründe binden Verantwortlichkeit zwingend an OLLM als externen Prozess,
unabhängig vom gemeinsamen Modul:

- **Entscheidung vor dem Start.** Der Aufruf des Backends (Jobname, Engine-
  Flags, Shell-Escape-Modus) muss feststehen, bevor die Engine läuft. Ein
  laufender TeX-Lauf kann seine eigenen Aufrufparameter nicht rückwirkend
  bestimmen.
- **Transaktionale Zustandsführung.** Eine Generation gilt erst nach
  erfolgreichem Bau als gültig und wird atomar veröffentlicht, ohne den
  vorherigen guten Zustand zu gefährden; Sperren verhindern nebenläufige
  Bauversuche. Das erfordert einen Supervisor außerhalb der Engine, da TeX
  sich selbst nicht zurückrollen kann.
- **Deployment.** Das Kopieren validierter Artefakte an ihren Zielort ist per
  Definition ein Schritt nach dem TeX-Lauf.

Ein minimales Artefaktregister (welche Unit hat aktuell eine gültige,
veröffentlichte Generation, und wo liegt sie) gehört ebenfalls hierher: Es
trägt sowohl zur Korrektheit bei (eine Unit, die auf eine veraltete
Nachbar-Generation verweist, ist nicht korrekt gebaut) als auch zum
Deployment.

### Klassifikation der Auftragsdatei-Schlüssel

| Schlüssel | Ziel | Begründung |
|---|---|---|
| `schema` | OLLM | Vertrag zwischen OLLM und Klasse, kein Projektinhalt |
| `job-id` | OLLM | Identität des Auftrags |
| `context` | OLLM | Art des Auftrags |
| `series-id` | OLLM | Registrierschlüssel für Artefaktregister/Generationen |
| `physical-unit` | gemeinsames Modul | aus dem Verzeichnisnamen ableitbar (`lfs.currentdir()`) |
| `physical-number` | gemeinsames Modul | aus `physical-unit` regelbasiert ableitbar |
| `logical-ordinal` | gemeinsames Modul | Ergebnis von Serien-Discovery |
| `unit-scope` | gemeinsames Modul | aus `physical-unit` regelbasiert ableitbar |
| `unit-role` | gemeinsames Modul | aus `physical-unit` regelbasiert ableitbar |
| `unit-id` | OLLM | stammt aus einem früheren validierten Lauf, ist ein Registerwert |
| `generation-id` | OLLM | reine Build-Zustandsführung |
| `target` | OLLM | Kern der Auftragsentscheidung |
| `profile-class` | Grenzfall | folgt aus der Zielregistrierung von `target`; siehe unten |
| `document-metadata-policy` | Grenzfall | folgt ebenso aus der Zielregistrierung |
| `doctype` | OLLM | Kern der Auftragsentscheidung |
| `applicable-unit-scopes` | Grenzfall | Wert aus der Zielregistrierung, konsumiert von der Serienlogik im gemeinsamen Modul |
| `language` | OLLM | Kern der Auftragsentscheidung |
| `available-languages` | gemeinsames Modul | Projektinhalt, keine Auftragsentscheidung |
| `bundle-preset` | gemeinsames Modul | Projektinhalt (Feature-/Theme-Vorgabe) |
| `shared-tex-directory` | gemeinsames Modul | konventionsbasiert relativ zum Manifest auflösbar |
| `source-directory` | gemeinsames Modul | redundant zu `lfs.currentdir()` |
| `project-config-file` | gemeinsames Modul | konventionsbasiert relativ zum Manifest auflösbar |
| `shell-escape` | OLLM | bestimmt die Engine-Aufrufparameter |
| `structure-signature` | OLLM | Invalidierung von Generationen, reine Build-Zustandsführung |
| `config-signature` | OLLM | dieselbe Begründung |

„Gemeinsames Modul" heißt: Die Klasse liest den Wert direkt selbst; die
Auftragsdatei transportiert ihn nicht mehr. Braucht OLLM denselben Wert für
eigene Zwecke (siehe oben), bezieht es ihn bei Bedarf über `texlua` aus
demselben Modul, statt ihn selbst zu parsen.

Die drei mit „Grenzfall" markierten Schlüssel hängen an der Zielregistrierung
(welches `target` welchen `doctype`, welche `profile-class` und welche
`applicable-unit-scopes` besitzt). Ob diese Registrierung langfristig
ebenfalls in das gemeinsame Modul wandert, ist eine eigene, hier nicht
entschiedene Frage (siehe „Offene Fragen").

### Schritt 1: verifizierter Schlüsselsatz (17. August 2026, abgeschlossen)

Die Klassifikation oben stand bereits fest; Schritt 1 hat sie gegen jeden
tatsächlichen Verbraucher in `osglecture/*.sty` und `osglecture.cls` geprüft
(vollständige Suche nach `\OsgLectureBuildValue{<jeder „gemeinsames
Modul"-Schlüssel>}`). Zwei Ergebnisse verfeinern die Klassifikation, ohne sie
zu ändern:

- **`physical-unit`, `unit-role` und `logical-ordinal` sind nicht nur
  Eingabe, sondern auch Ausgabe.** `osglecture-structure.sty`
  (`__osglecture_result_write:`) schreibt alle drei zusammen mit `unit-id` in
  `<jobname>.osgresult.aux` zurück an OLLM. Das ist bereits der etablierte
  Mechanismus für `unit-id` (ein Wert, den die Klasse liefert, nicht
  empfängt); er trägt ohne Änderung auch die drei jetzt migrierenden Werte.
  Zusätzlich entscheidet `unit-role` in `osglecture.cls:364`, ob
  `osglecture-integration` geladen wird -- eine echte Bootstrap-Entscheidung,
  nicht nur Berichtsdaten. Schritt 5 muss diese Stellen auf das gemeinsame
  Modul umstellen, nicht nur auf Wegfall der Eingabe prüfen.
- **`shared-tex-directory` und `project-config-file` werden vor `\LoadClass`
  gelesen** (`osglecture.cls`, direkt nach der Doctype-/Profilklassen-
  Standardsetzung, vor der Basisklassenwahl). Das gemeinsame Modul muss also
  an diesem frühen Punkt aufrufbar sein -- vor jeder anderen Paketladung,
  ausschließlich auf `\directlua` und `lfs` gestützt. Das ist technisch
  unproblematisch (`\directlua` funktioniert ab Formatstart), aber eine
  konkrete Anforderung an den Zuschnitt des Moduls in Schritt 2.

Ebenfalls bestätigt: `unit-scope`, `physical-number`, `available-languages`
und `bundle-preset` werden heute zwar als Pflichtschlüssel validiert, aber von
keiner Stelle in `osglecture` je gelesen. Ihr Wegfall aus der Auftragsdatei
(Schritt 4) hat damit keine Verhaltensauswirkung auf die Klasse; er verlangt
lediglich, sie aus der Pflichtschlüsselliste in
`__osglecture_build_validate:` (`osglecture-config.sty`) zu entfernen.

Der minimale Schlüsselsatz aus der Tabelle oben ist damit bestätigt und bereit
für Schritt 2.

### Erster Migrationsschritt

`OLLM::Config.pm` (`_series_units`) und `osglecture-series-index.lua`
(`parse_unit_name`) implementieren heute unabhängig voneinander denselben
Verzeichnisnamens-Vertrag, in zwei Sprachen. Der naheliegendste erste Schritt
entfernt `physical-number`/`unit-scope`/`unit-role` aus der Auftragsdatei und
lässt sowohl die Klasse als auch OLLM (über `texlua`) dieselbe
`osglecture-series-index.lua`-Logik nutzen -- er verringert bestehende
Duplikation, statt neue Komplexität einzuführen.

### Schrittfolge

1. [x] Den minimalen Schlüsselsatz festlegen, den OLLM zur Auftragsentscheidung
   tatsächlich braucht (im Kern: `target`/`doctype`/`language`-Auflösung samt
   der drei Grenzfälle) -- verifiziert gegen alle tatsächlichen Verbraucher,
   siehe „Schritt 1: verifizierter Schlüsselsatz" oben.
2. [x] Das gemeinsame Modul (TOML-Lesen, Discovery, Namensinterpretation)
   aufbauen -- `osglecture-manifest.lua`, mit vendoriertem TOML-1.0-Leser
   `osglecture-toml.lua` (siehe `osglecture/THIRD_PARTY.md`), Discovery
   durch Wiederverwendung von `osglecture-series-index.lua` (dessen
   Pfad-Grundfunktionen dafür jetzt exportiert sind). Getestet über
   `testfiles/manifest.lvt` mit derselben Testdisziplin wie
   `series-index.lvt`; verifiziert sowohl über `\directlua` innerhalb eines
   echten Laufs als auch eigenständig über `texlua`. Zum Zeitpunkt dieses
   Schritts noch nicht angebunden; `osglecture.cls` ist es weiterhin nicht
   (Schritt 5), OLLM inzwischen teilweise (siehe Schritt 3).
3. [x] `ollm check`/`ollm doctor` rufen das Modul über `texlua` auf --
   `OLLM::LuaManifest` (Perl-Bridge) und `osglecture-manifest-cli.lua`
   (Lua-seitiger, zeilenorientierter Einstiegspunkt). `ollm doctor` meldet
   zusätzlich zum Perl-Parser den Lua-seitigen (`osglecture-toml.lua`),
   informativ, ohne Voraussetzung zu sein. `ollm check` vergleicht bei jedem
   Lauf `OLLM::Config::structure_snapshot`s eigene Discovery gegen die des
   Moduls und meldet eine Abweichung als Warnung (`lua-discovery-drift`).
   Getestet in `testfiles/lua-manifest.t` (16 Assertions, inklusive
   Cross-Check gegen `structure_snapshot` an einem echten Fixture) und
   `testfiles/cli.t` (Vergleichslogik isoliert).

   Bewusst *nicht* migriert: `structure_snapshot` selbst bleibt
   Perl-implementiert und bleibt die für `resolve_request` (den heißen Pfad
   jedes gewöhnlichen Builds, nicht nur `check`/`doctor`) maßgebliche
   Quelle. Sie global auf `texlua` umzustellen hätte jedem Build einen
   Unterprozessaufruf aufgezwungen -- ein größerer Eingriff, als „check/
   doctor umstellen" hergibt. Ebenso migriert diese Umstellung nicht die
   Manifestvalidierung selbst (Zieldefaults, Sprachabgleich, erzwungene
   Konfiguration): Das gemeinsame Modul liest bewusst nur Rohwerte, ohne
   OLLMs eigene Regeln nachzubilden. `check`s neuer Vergleich ist deshalb
   eine echte, wertvolle Zusatzprüfung (sie hätte die in Abschnitt „Bereits
   vorhandene Duplikation" beschriebene Divergenz sofort gemeldet), aber
   noch kein Ersatz der Perl-Implementierung -- der bleibt Schritt 6
   vorbehalten.
4. [x] Die Auftragsdatei auf den in Schritt 1 festgelegten minimalen
   Schlüsselsatz verkleinert -- `BuildFile.pm::render` emittiert nur noch die
   als „OLLM"/„Grenzfall" klassifizierten Schlüssel;
   `osglecture-config.sty`s `.code:n`-Einträge und Pflichtschlüsselliste für
   die zehn „gemeinsames Modul"-Schlüssel entfernt, sodass eine ältere OLLM,
   die sie noch sendet, einen klaren „unknown key"-Fehler erzeugt statt
   stillschweigend ignoriert zu werden. `$spec` (OLLMs interne
   Repräsentation) behält alle Werte weiterhin.
5. [x] Bootstrapping der Klasse erweitert -- **vor** Schritt 4 umgesetzt, da
   Schritt 1 bereits zeigte, dass die Klasse `physical-unit`, `unit-role`,
   `logical-ordinal`, `shared-tex-directory` und `project-config-file`
   aktiv konsumiert (nicht nur weiterreicht); die Reihenfolge aus diesem
   Abschnitt beschreibt die Zielarchitektur, nicht zwingend sichere
   Ausführungsreihenfolge.
   - `osglecture.cls` liest `shared-tex-directory`/`project-config-file`
     jetzt über `osglecture-manifest.lua`s `manifest.load_tex` (neue Makros
     `\OsgLectureManifest...`, Defaults in `osglecture-config.sty`).
   - `osglecture-series.sty`s Serieninitialisierung braucht `source-directory`
     nicht mehr; ein Vorabtest mit `series_index.locate_unit_ancestor`
     ersetzt den früheren Leer-Test und bewahrt dieselbe stille
     Nicht-Verfügbarkeit ohne passendes Vorfahrenverzeichnis.
   - `osglecture.cls`s Entscheidung, `osglecture-integration` zu laden, und
     `osglecture-structure.sty`s `osgresult.aux`-Schreibfunktion lesen
     `physical-unit`/`unit-role` jetzt über die neue, robustere
     `series_index.current_unit` (reine Namensinterpretation des aktuellen
     Verzeichnisses, ohne auf einen Serienwurzel-Fund angewiesen zu sein)
     statt über die Auftragsdatei; `logical-ordinal` kommt über
     `\OsgLectureSeriesPosition`, dieselbe Größe, die die Serienanzeige
     bereits berechnet.
   - **Dabei gefunden und behoben:** `\ExplSyntaxOn` setzt Leerzeichen auf
     Katcode~9 (ignoriert), nicht Katcode~10 wie normales LaTeX. Lua-Code mit
     mehreren Anweisungen (`local x = ...`, `if ... then`) direkt im
     `\directlua`-Quelltext verliert dadurch beim Tokenisieren seine
     trennenden Leerzeichen vollständig (`local x` wird zu `localx`) und ist
     kein gültiges Lua mehr -- ein einzeiliger, verketteter Aufruf wie
     `require(...).funktion(...)` bleibt dagegen sicher, da er keine
     Leerzeichen zur Token-Trennung braucht. Betroffen war die erste Fassung
     der neuen Serieninitialisierung; sichtbar wurde es nicht durch einen der
     `l3build`-Tests (die laufen nie mit einem tatsächlich
     serieneinheit-förmigen Arbeitsverzeichnis), sondern durch
     `ollm/testfiles/reference-lifecycle.t`, den einzigen Test mit einem
     echten OLLM-erzeugten Build und echtem LuaLaTeX-Lauf. Die Funktion
     `series_index.initialize_tex_csv_if_available` kapselt Vorabtest und
     bedingten Aufruf jetzt vollständig in der `.lua`-Datei, sodass der
     `\directlua`-Aufruf wieder ein sicherer Einzeiler ist.
   - Getestet über `testfiles/series-index.lvt` (neue Assertions für
     `current_unit`/`current_unit_tex`, einschließlich des
     `role=i`-Falls), `testfiles/project-config.lvt` (Projektkonfiguration
     jetzt über ein echtes `ollmconfig.toml`-Fixture gefunden, nicht über
     die Auftragsdatei) und `ollm/testfiles/reference-lifecycle.t` (echter
     Kompilierlauf, s.o.). Weiterhin nicht abgedeckt: ein `l3build`-Test mit
     tatsächlich serieneinheit-förmigem Arbeitsverzeichnis für
     `osglecture-series.sty`s Erfolgspfad -- `l3build`s Testverzeichnis
     heißt nie so; diese Lücke schließt derzeit nur
     `reference-lifecycle.t`.
6. Nach hergestellter Testparität den entsprechenden Perl-Code in
   `Config.pm` entfernen.
7. Bei jedem Schritt Tests und Dokumentation gemeinsam mit dem Code ändern,
   nicht nachträglich; `HISTORY.md` entsprechend kürzen.

### Offene Fragen

- Heute kann OLLM eine ungültige Konfiguration ablehnen, bevor die Engine
  überhaupt startet. Wandert Validierung in den TeX-Lauf, verschiebt sich
  dieser Fehlerzeitpunkt nach hinten. Das ist vermutlich vertretbar, sollte
  aber als bewusste Entscheidung getroffen werden, nicht als Nebenwirkung.
- Ob die drei „Grenzfall"-Schlüssel (und damit die Zielregistrierung selbst)
  langfristig ebenfalls in das gemeinsame Modul wandern, ist bewusst
  offengelassen und sollte erst nach Abschluss der
  Verzeichnis-Discovery-Migration erneut bewertet werden.
- Die projektübergreifende Referenzregistrierung (Abschnitt 3.9) bleibt
  vorerst unangetastet: Sie spannt sich über mehrere TeX-Läufe und mehrere
  Units und bleibt damit ein genuines Supervisor-Thema, unabhängig vom
  Ausgang dieser Neuausrichtung.

## Schlussfolgerung

Die wertvollste Idee von `osglecture` ist nicht ein bestimmtes Theme oder eine Sammlung praktischer Makros, sondern das gemeinsame Dokumentmodell für eine Vorlesungsreihe: dieselbe fachliche Quelle, mehrere zielgerechte Darstellungen, stabile Kapitelidentität und serienweite Dienste.

Die heutige Klasse beweist die Machbarkeit dieses Ansatzes, bündelt jedoch zu viele Verantwortlichkeiten. Die Überarbeitung sollte deshalb nicht mit einzelnen Makros beginnen, sondern mit einem expliziten Vertrag zwischen Konfiguration, Dokumentmodell, Backend, Diensten und Darstellung. Eine dünne Kernklasse mit klaren Adaptern bewahrt die Grundidee und schafft zugleich die Voraussetzung für Austauschbarkeit, Testbarkeit und schrittweise Migration.
