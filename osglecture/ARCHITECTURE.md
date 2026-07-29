# osglecture – Grundideen und Leitlinien für eine Überarbeitung

**Arbeitsdokument · Stand 29. Juli 2026**

## Zweck und Einordnung

Dieses Dokument beschreibt die grundsätzlichen Ideen der Klasse `osglecture` in ihrer gegenwärtigen Form. Es ist bewusst weder Benutzerhandbuch noch vollständige API-Referenz. Sein Zweck ist, das fachliche Modell, die tragenden Entwurfsentscheidungen und die derzeitigen Spannungsfelder sichtbar zu machen. Nach fachlicher Überarbeitung soll es als Ausgangspunkt für eine Neustrukturierung der Klasse dienen.

Die bundleweit verbindlichen Kurzdefinitionen stehen im
[`GLOSSARY.md`](../GLOSSARY.md).

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
Bundle-Preset, beispielsweise `OSG lecture/1`. Davon getrennt bezeichnet
`document-profile` die konkrete TeX-Integration. OLLM wählt sie aus
Nutzerdefaults und einem möglichen Projekt-Override aus und schreibt das
aufgelöste Ergebnis in den BuildSpec.

Die Klasse lädt Profildeskriptoren vor der Basisklasse. Ein Deskriptor
deklariert unterstützte Dokumenttypen, Backend, Basisklasse,
dokumenttypspezifische Klassenoptionen und optional eine Setup-Datei. Diese
Setup-Datei wird erst nach Basisklasse und Moduskern geladen. Damit können
weitere Profile ergänzt werden, ohne die Kernklasse um Backendfälle zu
erweitern.

Der stabile Deskriptorvertrag umfasst `backend`, `class`, `doctypes`,
`class-options`, `document-metadata`, `modes`, `mode-setup-file`,
`setup-file`, `course-target` und `event-target`.
`mode-setup-file` wird vor Aktivierung und Finalisierung des Modusgraphen
geladen; `setup-file` danach. Nur die erste Datei darf den Graphen erweitern.

Mitgeliefert werden zunächst:

- `beamer` für `slides` und `handout`,
- `ltx-talk` für `slides` und `handout`,
- `scrbook` für `script` und `article`.

Die gegenwärtige Version von `ltx-talk` verlangt `\DocumentMetadata{}` vor
`\documentclass`. Ein Wrapper kann diese Initialisierung technisch nicht
nachholen. Sie darf im Autorenmodell weiterhin in der Quelle oder gemeinsamem
Projektcode stehen. Alternativ erzwingt das Projekt mit
`latex.document_metadata.policy = "enforce"` eine gemeinsame Datei: OLLM
definiert vor dem Hauptdokument `\OsgLectureRequestedLanguage` und liest die
Datei über latexmks kontrollierten PreTeX-Mechanismus ein. OLLM untersucht
`main.tex` nicht; ein zusätzlicher Aufruf bleibt ein sichtbarer LaTeX-Konflikt.

Im Standalone-Betrieb kann `profile=...` als Klassenoption verwendet werden.
Bei einer OLLM-Auftragsdatei ist die Klassenoption nur zulässig, wenn sie dem
aufgelösten `document-profile` entspricht; ein Widerspruch ist ein Fehler.

Die Klassenoption `standalone` erzwingt den lokalen Konfigurationsweg. Existiert
für den tatsächlichen Jobnamen eine Auftragsdatei, wird sie bewusst nicht
geladen und eine Warnung ausgegeben. Ohne Auftragsdatei bleibt Standalone der
implizite Zustand; die Option ist dann lediglich eine ausdrückliche
Zusicherung.

### Vertragsstatus für Folgearbeiten

Als stabil und implementiert gelten derzeit:

- Auftragsdatei, Jobbindung und Klassenoptionen für Doctype, Sprache, Profil
  und Standalone,
- der offene Dokumentprofilvertrag einschließlich der beiden Setup-Phasen,
- Doctype als Blattmodus, Modusgraph und portable Modusabfragen,
- die drei Standard-Verhaltensklassen und die Vollständigkeitsprüfung
  semantischer Befehle,
- die generische Titelmetadaten-API und ihre Profilabbildung.

Als fachlich festgelegt, aber noch nicht implementiert gilt:

- der Unit-/Lecture-/Chapter-Vertrag aus Abschnitt 3.6.

Noch nicht als stabiler Autorenvertrag festgelegt sind insbesondere:

- Referenzauflösung über Unitgrenzen,
- die konkrete gemeinsame Bild- und Tabellen-API,
- Notizen und Zweitbildschirmdarstellung,
- spezialisierte optionale Fachpakete und deren jeweilige Autorenbefehle.

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
        Klassenoptionen   Serienkonfiguration   Jobname
              │          (OLLM / lectdates)     │
              └────────────────┼────────────────┘
                               ▼
                    osglecture – Orchestrator
                 Modus · Sprache · Metadaten · Pfade
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
    Präsentation           Handout              Skript
  beamer/ltx-talk      beamer/ltx-talk          scrbook
          │                    │                    │
          └────────────────────┼────────────────────┘
                               ▼
             gemeinsame Dienste und Darstellungsbausteine
       Referenzen · Sprache · Bibliografie · Theme · Inhaltsmakros
```

Die Klasse übernimmt derzeit fünf Rollen:

1. **Konfiguration ermitteln:** OLLM-Verzeichnisstruktur erkennen, Konfigurationsdatei auswerten und Informationen aus dem Jobnamen ableiten.
2. **Ausgabemodus wählen:** `beamer` oder `scrbook` mit `beamerarticle` als Basisklasse laden.
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
        │
        ▼
aktiver Blattmodus ist dieser Dokumenttyp
        │
        ├── Modusmatrix liefert transitive Obermodi
        │
        ▼
Profil-/Projektpolicy wählt einen Backendadapter
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
übernimmt die portable Auswertung der Matrix; `osglecture` registriert die
aufgelöste Matrix und setzt den Blattmodus ausdrücklich, bevor
modusabhängige Projektmetadaten verarbeitet werden.

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
die aufgelöste Matrix dagegen ausdrücklich vor dem Einlesen projektweiter
Metadaten. Der `ltx-talk`-Scanner bleibt ein Backendadapter und ist nicht Teil
des allgemeinen Moduskerns.

Bis zu einer fachlichen Aufspaltung aktiviert `osglecture` für `script` und
`article` beide Blattmodi gemeinsam. Das ist absichtlich kein Graphalias und
verbaut daher keine spätere getrennte Semantik. Vor dem Finalisieren kann ein
Dokumentprofil oder Bundle-Preset den Graphen über `mode-setup-file` erweitern;
`modes` ergänzt weitere aktive Modi.

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
- `script` und `article`: Longform-Ausgabe, derzeit über `scrbook` und `beamerarticle`.
- `screen`: experimentelle Zweitbildschirm-Konfiguration.
- `web`: ausdrücklich nicht unterstützt.

Ein zusätzlicher Dokumenttyp benötigt eine registrierte Targetdefinition, ein
ausdrücklich gewähltes Dokumentprofil, einen vor der Aktivierung geladenen
Blattmodus und eine vollständige Verhaltenszuordnung. Aliasnamen werden vor
Eintritt in die Klasse normalisiert. Ein zusätzliches Backend ist dagegen nur
ein weiterer Adapter eines Dokumenttyps und verändert dessen Autorenmodus
nicht.

### 3.3 Serie und Standalone sind zwei gleichwertige Kontexte

Im Serienbetrieb liefert OLLM Informationen über Verzeichnisstruktur, Kapitel, Sprache, Dokumenttyp und gemeinsame Daten. Ohne erkannte OLLM-Konfiguration schaltet die Klasse automatisch in den Standalone-Modus. Die Option `noollm` erzwingt diesen Zustand.

Das ist fachlich sinnvoll: Autoreninhalte sollen sowohl als Teil einer Vorlesungsreihe als auch isoliert übersetzbar sein. Der heutige Code behandelt Standalone jedoch teilweise als Rückfallpfad. Künftig sollten beide Kontexte klar spezifizierte, getestete Betriebsarten sein:

- **Standalone:** alle erforderlichen Angaben kommen aus Dokumentoptionen und lokalen Metadaten.
- **Serie:** eine externe Konfigurationsquelle ergänzt Defaults, Pfade und Kapitelkontext.

Eine nicht vorhandene Serienkonfiguration darf keine impliziten Seiteneffekte außerhalb dieser Umschaltung haben.

### 3.4 Konfiguration besitzt Herkunft und Priorität

Die Klasse kennt drei Prioritätsstufen:

1. globale Optionen aus der Vorlesungskonfiguration,
2. lokale Klassenoptionen eines Kapitels,
3. erzwungene globale Optionen.

Daneben werden Sprache und Dokumenttyp bei Bedarf aus dem Jobnamen abgeleitet. Dieses Modell ist mächtig, aber nur dann beherrschbar, wenn Herkunft, Zeitpunkt und Priorität jedes Werts transparent sind.

Für eine Neufassung bietet sich folgende Reihenfolge an:

```text
eingebaute Defaults
    < Serienkonfiguration
    < aus Jobname abgeleitete Werte
    < lokale Dokumentoptionen
    < ausdrücklich erzwungene Serienrichtlinien
```

Abweichungen von dieser Reihenfolge sollten nur für technisch frühe Optionen erlaubt und dokumentiert werden. Eine Diagnosefunktion sollte die effektive Konfiguration einschließlich ihrer Herkunft ausgeben können.

### 3.5 Metadaten gehören zum Dokumentmodell

Titel, Autor, Datum, Veranstaltung, Institution, URL und Logo werden teilweise sehr früh benötigt, obwohl ihre endgültigen Befehle erst nach dem Laden der Basisklasse existieren. Die Klasse löst dies durch verzögerte Ausführung: Sie sammelt Titelbefehle aus der Serienkonfiguration in einem Hook und führt sie später erneut aus.

Die zugrunde liegende Idee ist richtig: Metadaten sind Daten, keine
unmittelbaren Layoutaktionen. `osglecture-metadata` realisiert dafür den
gemeinsamen Kern:

- Metadaten werden zunächst gespeichert.
- Validierung erfolgt unabhängig vom Ausgabemodus.
- Beamer- und Skriptadapter übertragen die Werte in die jeweilige Basisklasse.
- Kurz- und Langformen sowie modusspezifische Varianten haben eine einheitliche Syntax.

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
| scrbook | Titel | Untertitel |

Damit bleibt das osgbeamer-Modell erhalten: In einer Präsentation bezeichnet
der Titel die einzelne Unit und der Kurs erscheint als Kontext; in der
Langform ist der Kurs der Dokumenttitel und eine Unit wird später strukturell
als Kapitel realisiert. Im Standalone-Fall kann `title` den Vortrag und
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
Metadatenangabe im Hauptdokument überschreibt die projektweite Vorgabe nach der
üblichen LaTeX-Reihenfolge.

Damit entfällt ein großer Teil des temporären Überschreibens und Wiederherstellens fremder Befehle.

### 3.6 Kapitel sind die gemeinsame Struktureinheit

Eine Unit, eine Lecture und ein Kapitel sind drei Perspektiven derselben
fachlichen Struktureinheit:

- **Unit:** Projekt- und Buildperspektive,
- **Lecture:** Autoren- und Präsentationsperspektive,
- **Kapitel:** Langformperspektive.

Die kanonische künftige Autorenoberfläche lautet
`\lecture[Kurz]{Lang}`. Sie beginnt nicht mehrere unabhängige Strukturen,
sondern beschreibt die aktuelle Unit. Im Präsentationsprofil liefert sie den
Unit-Titel und die native Lecture-Information; im Langformprofil erzeugt sie
die Kapitelüberschrift. Das Backendkommando `\chapter` beziehungsweise Beamers
native `\lecture` ist Implementierungsziel, nicht die bundleweite Semantik.

Die Identität ist vom sichtbaren Titel getrennt. Im Serienbetrieb stammt die
stabile Unit-ID aus `unit-id` des BuildSpec; `physical-unit` und
`physical-number` beschreiben Verzeichnis und Sortierung, sind aber keine
Ersatz-ID. Ein Backendadapter darf aus der Unit-ID interne Labels ableiten.
Standalone setzt weder Manifest noch Serienverzeichnis voraus; dort wird eine
lokale Dokumentidentität verwendet, bis der Autor ausdrücklich eine Unit-ID
angibt.

Für den Strukturvertrag gelten folgende Invarianten:

- Eine Unit besitzt genau eine stabile Unit-ID und beliebig übersetzte oder
  gekürzte sichtbare Titel.
- `\lecture[Kurz]{Lang}` ändert weder Doctype noch Dokumentprofil.
- Präsentation und Langform verwenden dieselbe Unit-ID für Referenzen.
- Abschnitts- und Objekt-IDs werden aus Unit-ID und lokaler Identität
  abgeleitet, nicht aus sichtbaren Zählerständen.
- Nummerierung und sichtbare Überschriften dürfen profilabhängig sein; die
  Identität bleibt es nicht.
- Im Standalone-Betrieb bleiben lokale Nummern und Referenzen ohne
  übergeordnetes Serienverzeichnis funktionsfähig.

Zähler-Aliase sind lediglich eine mögliche Backendimplementierung. Die
Autorenoberfläche und die Adapter dieses Vertrags sind noch nicht
implementiert; bis dahin darf kein Paket konkrete Beamer- oder KOMA-Zähler als
bundleweite Unit-Identität voraussetzen.

### 3.7 Modusabhängigkeit soll semantisch bleiben

Die Klasse macht zahlreiche Standardbefehle overlay-fähig und ändert Verhalten in `presentation` und `article`. Das erleichtert bestehende Quellen, greift aber tief in Kern- und Beamerbefehle ein. Besonders globale Änderungen an `\footnote`, `\vspace`, Schriftgrößen oder `\Roman` bergen Kompatibilitätsrisiken.

Für die Überarbeitung sollte gelten:

- Eigene semantische Befehle vor globalen Patches bevorzugen.
- Patches nur in einem klar abgegrenzten Adapter und mit Tests einsetzen.
- Der Artikelmodus muss auch ohne visuelle Beamer-Annahmen verständlich bleiben.
- Gleiche Eingabe soll in jedem unterstützten Modus deterministisch sein.

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

## 4. Aktuelle öffentliche Oberfläche

Die folgende Gruppierung beschreibt die heute sichtbaren Konzepte, nicht notwendigerweise die künftig zu bewahrende API.

### Konfiguration

- `doctype`, `lang`, `standalone`, `noollm`
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
- `\sbf`, `\newdef`, `\stress`, `\outline`
- modusfähige Fußnoten und ausgewählte Abstands- und Schriftgrößenbefehle
- `\sourceref`

### Layout und Medien

- Umgebung `twocolumns`
- `\centerpic`
- `\markword`
- Pfeile und Smileys

### Notizen und Hilfen

- `specialitemize`, `noteitemize`
- `\DebugFont`
- Legacy-Kommandos mit Deprecation-Warnungen

Ein wesentlicher Schritt der Überarbeitung ist die Entscheidung, welche dieser Gruppen zur Klasse, zu einem Autorenpaket, zu einem Theme oder ausschließlich in einen Kompatibilitätslayer gehören.

## 5. Heutige Kopplungen und Risiken

### 5.1 Konfiguration ist an Dateisystem und Perl-Syntax gekoppelt

Lua-Code prüft einen festen relativen Pfad `../ollmconfig.pl` und extrahiert ausgewählte Perl-Zuweisungen mit regulären Ausdrücken. Damit sind Konfigurationsmodell, Dateiformat, Arbeitsverzeichnis und Ausführung eng gekoppelt. Fehlerhafte oder ungewöhnlich formatierte Konfigurationen können stillschweigend zu Defaults führen.

**Leitlinie:** OLLM sollte die normalisierten Werte über eine kleine, dokumentierte Schnittstelle an LaTeX übergeben. Die Klasse sollte weder Perl parsen noch ein bestimmtes Arbeitsverzeichnis voraussetzen.

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
│   └── script  → scrbook
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

1. Das Dokumentprofil wird ausgewählt und lädt die Basisklasse.
2. `osglecture-modes` deklariert die portable Grundmatrix.
3. `osglecture` deklariert die stabilen Verhaltensklassen
   `presentation-dynamic`, `presentation-static` und `longform`.
4. `mode-setup-file` darf vor Aktivierung des Blattmodus zusätzliche Modi,
   Elternkanten, Aliase und Verhaltenszuordnungen deklarieren.
5. Die Klasse aktiviert den Doctype als Blattmodus, ergänzt Profilmodi und
   finalisiert den Modusgraphen.
6. `osglecture-metadata` bindet die Titelmetadaten an die nativen
   Backendbefehle.
7. `setup-file` darf Backendadapter, Formatierung und Implementierungen
   semantischer Befehle registrieren. Der Modusgraph ist zu diesem Zeitpunkt
   bereits unveränderlich.
8. Spätestens zu `\begin{document}` prüft
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

- Bleibt `scrbook` das Standardbackend für die Langform?
- Welche gemeinsame Semantik müssen Beamer- und `ltx-talk`-Adapter für
  `slides` garantieren?
- Welche Teile des TUC-/OSG-Designs sind Default, welche Voraussetzung?

### Konfiguration

- Dürfen erzwungene globale Optionen lokale Dokumentoptionen überschreiben?
- Welche Werte müssen vor dem Laden der Basisklasse feststehen?
- Welches Schema transportiert die allgemeine Modusmatrix in der generierten
  TeX-Auftragsdatei?

### Autoren-API

- Welche Makros drücken echte didaktische Semantik aus?
- Soll `twocolumns` in ein allgemeines Moduspaket verschoben werden?
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

## Schlussfolgerung

Die wertvollste Idee von `osglecture` ist nicht ein bestimmtes Theme oder eine Sammlung praktischer Makros, sondern das gemeinsame Dokumentmodell für eine Vorlesungsreihe: dieselbe fachliche Quelle, mehrere zielgerechte Darstellungen, stabile Kapitelidentität und serienweite Dienste.

Die heutige Klasse beweist die Machbarkeit dieses Ansatzes, bündelt jedoch zu viele Verantwortlichkeiten. Die Überarbeitung sollte deshalb nicht mit einzelnen Makros beginnen, sondern mit einem expliziten Vertrag zwischen Konfiguration, Dokumentmodell, Backend, Diensten und Darstellung. Eine dünne Kernklasse mit klaren Adaptern bewahrt die Grundidee und schafft zugleich die Voraussetzung für Austauschbarkeit, Testbarkeit und schrittweise Migration.
