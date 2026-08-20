# osglecture

`osglecture` ist die LuaLaTeX-Kernklasse des Bundles. Sie projiziert eine
gemeinsame Lehrquelle auf Präsentationen und Langformen. Der aktuelle
Architekturvertrag ist in `ARCHITECTURE.md` beschrieben.

## Projektweite TeX-Konfiguration

Bei einem OLLM-Serienbuild prüft die Klasse zunächst das durch
`\OSGLectureProjectManifestFile` bezeichnete TOML-Manifest auf Existenz und
lädt die durch `\OSGLectureJobFile` bezeichnete Auftragsdatei. Diese
transportiert nur den zur Auftragsentscheidung gehörenden Teil des BuildSpec
(Target, Doctype, Sprache und verwandte Werte, siehe `ARCHITECTURE.md`
Abschnitt 12). Projektinhalt -- darunter Ort und Name der Projektkonfiguration
-- liest die Klasse über das gemeinsame Lua-Modul direkt aus dem
Projektmanifest. Standardmäßig ist dies
`Include/projectconfig.tex`; Verzeichnis und Dateiname werden im
Projektmanifest konfiguriert:

```toml
[project.tex]
directory = "Include"
config = "projectconfig.tex"
```

Bei `document_metadata="required"` für das konkrete Target schaltet OLLM die
daneben liegende `documentmetadata.tex` vor die Hauptquelle; bei `disabled`
nicht. Die nutzereditierbare Datei enthält selbst den frühen
`\DocumentMetadata{...}`-Aufruf und kann die von OLLM definierten
`\OsgLectureRequested...`-Symbole verwenden.

Die Datei wird vor dem Laden der Basisklasse durch eine deklarative
Bootstrap-Schicht gelesen. Frühe Werte wie Basisklassenoptionen wirken vor
`\LoadClass`; mode-spezifische Metadaten werden zunächst gespeichert und erst
nach Finalisierung des Modusgraphen angewendet:

```latex
\author<presentation>[M.~M.]{Max Mustermann}
\author<longform>[Mustermann]{Max Mustermann}
```

Profile und targetspezifische Profilausnahmen werden gesondert ausgewählt:

```latex
\LectureProjectSetup{
  presentation-profile=beamer,
  longform-profile=book
}
\LectureTargetSetup{slides}{profile=beamer}
\LectureTargetSetup{handout}{profile=ltx-talk}
```

Frühe Klassenoptionen und modeabhängige osglecture-Dienste verwenden
absichtlich getrennte Namensräume:

```latex
\OsgLectureSetup{
  class/scrbook = {twoside, open=right, 11pt},
  class/beamer = {framefootnotes, aspectratio=43},
  mode/longform = {
    continuation = {
      counters = {page, chapter, section, figure, table, equation}
    }
  },
  mode/script = {
    continuation = {
      counters = {section, figure, table, equation}
    }
  }
}
```

`class/<name>` enthält unveränderte Optionen für die tatsächliche Basisklasse
und wird vor `\LoadClass` ausgewertet. `mode/<name>` wird nach Finalisierung
des Mode-Graphen in der Reihenfolge allgemein nach spezifisch verarbeitet.
Darum überschreibt im Beispiel `mode/script` die Zählerliste aus
`mode/longform`. Nackte Schlüssel wie `article` oder `beamer` sind nicht
zulässig, weil dieselben Namen Klassen und Modes bezeichnen können.

Weitere Kernmodule können mit `\DeclareOsgLectureModeSetupArea` einen eigenen
Unterschlüssel in den Mode-Blöcken registrieren, ohne den äußeren
`\OsgLectureSetup`-Parser zu verändern.

Der Bereich `continuation` übernimmt die aufgelisteten LaTeX-Zähler aus der
vorherigen normalen Unit der Serie. Integrationsunits werden bei der Suche nach
dem Vorgänger übersprungen. Die Werte stammen aus deren promotiertem
Referenzexport für denselben Doctype und dieselbe Sprache und werden nach
`\lecture` angewandt, damit eine Basisklasse sie nicht beim Anlegen des Kapitels
wieder zurücksetzt. `continuation={none}` schaltet die Übernahme für einen
spezifischeren Mode aus. Ist die Vorgänger-Unit oder ihre Projektion noch nicht
gebaut, warnt LaTeX und verwendet die normalen Anfangswerte.

Es können beliebige bereits definierte LaTeX-Counter angegeben werden, etwa
`footnote`, `theorem` oder projektspezifische Zähler. `page` ist ausdrücklich
unterstützt: Da der Export nach dem letzten Shipout erfolgt, enthält der
LaTeX-Counter dort die Nummer der zuletzt ausgelieferten Seite. Für `page` wird
daher ausdrücklich der um eins erhöhte Wert exportiert; bei einer einseitigen
ersten Unit beginnt die zweite Unit auf Seite 2. Bei Theoremumgebungen ist der
tatsächlich besitzende Counter anzugeben, falls mehrere Umgebungen eine
Nummerierung teilen.

Der Targetvertrag liefert nur `profile-class=presentation|longform`. Die Klasse
wählt damit zunächst einen der beiden Profilschlüssel; eine targetspezifische
Auswahl hat Vorrang. Die ältere Projektpolicy-Schnittstelle bleibt vorerst zur
Kompatibilität bestehen; Referenzoptionen wie `legacy` und `replace` gehören
jedoch weiterhin unmittelbar zu `\OsgLectureReferencesSetup` und nicht in die
neue allgemeine Setup-Hierarchie.

Metadatenfelder sind generisch erweiterbar:

```latex
\DeclareOsgLectureMetadataField{supervisor}
\supervisor<longform>[A.~Prof.]{Ada Professor}
```

Später stehen `\OsgLectureMetadataValue{supervisor}` und
`\OsgLectureMetadataShortValue{supervisor}` zur Verfügung. Eine Metadatenvorgabe
kann mit `\EnforceLectureProjectConfiguration{...}` verbindlich gemacht werden.
Die Priorität lautet `Fallback < Profil < Projekt < Unit < Enforcement`.

Frei programmierbare Präambelfragmente werden beim frühen Lesen lediglich
registriert und nach dem Laden der Basisklasse, der Modes und des Adapters in
Deklarationsreihenfolge ausgeführt:

```latex
\IncludeOsgLecturePreamble{common}
\IncludeOsgLecturePreamble<projector>{presentation}
\IncludeOsgLecturePreamble[class=beamer]{beamer-adjustments}
```

Das Winkelargument ist stets ein Ausdruck des Mode-Graphen; insbesondere ist
`<beamer>` ein Modus und keine Klassenbedingung. Die tatsächliche
Basisklasse wird ausschließlich mit `class=...` ausgewählt. Beide Bedingungen
können kombiniert werden.

Für `\IncludeOsgLecturePreamble{name}` sucht die Klasse zuerst nach `name.tex`
im konfigurierten Shared-TeX-Verzeichnis, also normalerweise neben
`projectconfig.tex`. Anschließend sucht sie
`osglecture-preamble-name.tex` über den normalen TeX-Suchpfad. Dadurch können
Nutzer und das Bundle wiederverwendbare Standardfragmente bereitstellen,
während eine projektlokale Datei stets Vorrang hat. Die Fragmente dürfen
gewöhnliche Präambelbefehle einschließlich `\usepackage` enthalten.

## Präsentationslisten in gemeinsamer Quelle

Die Umgebung `presitemize` setzt ihre Einträge in Präsentationen als normale
Liste und verbindet sie in der Verhaltensklasse `longform` zu Fließtext. Sie
ist im obligatorischen Klassenpaket `osglecture-presitemize.sty`
implementiert. `osglecture.cls` lädt dieses Paket automatisch; Autoren müssen
es bei Verwendung der Klasse nicht zusätzlich laden. Das Stylefile hängt nur
von `osglecture-modes` ab und kann von einer anderen Klasse direkt geladen
werden, wenn diese zuvor ihre Blattmodi und Verhaltensklassen konfiguriert.

Diese Projektion gilt auch für Tagged PDF: In Präsentationsmodi bleibt die
native `itemize`-Umgebung erhalten und wird als Liste getaggt. In der Langform
erzeugt `presitemize` direkt Absatzinhalt und damit keine irreführende
Listenstruktur. Die Langform hängt deshalb nicht von `enumitem` oder dessen
Inline-Listen ab.

Die kompakte Schreibweise ist für häufige Fälle gedacht:

```latex
\begin{presitemize}
  \item Die Übersetzung \finite{funktioniert}
  \anditem Das Programm \finite{liefert} das erwartete Ergebnis
  \butitem Wir \finite{haben} etwas vereinfacht
  \thereforeitem Wir \finite{müssen} den Ausgabetext untersuchen
\end{presitemize}
```

In der Langform entsteht daraus sinngemäß:

```text
Die Übersetzung funktioniert und das Programm liefert das erwartete Ergebnis,
aber wir haben etwas vereinfacht, weshalb wir den Ausgabetext untersuchen
müssen.
```

`\item`, `\anditem`, `\butitem` und `\thereforeitem` sind
delimiterartige Befehle; der Inhalt steht ohne zusätzliches Argument bis zum
nächsten Eintrag. Alle akzeptieren die Beamer-Overlay-Syntax und ein
optionales Item-Label. In der Langform werden Overlays ignoriert, in
Präsentationen an `itemize` weitergereicht.

Die gleichwertige, explizite Key-Syntax lautet:

```latex
\begin{presitemize}
  \presitem[relation=sentence] Die Übersetzung \finite{funktioniert}
  \presitem[relation=and] Das Programm \finite{liefert} das Ergebnis
  \presitem[relation=but] Wir \finite{haben} vereinfacht
  \presitem[relation=therefore] Wir \finite{müssen} nachsehen
\end{presitemize}
```

`relation` erlaubt `sentence`, `and`, `but` und `therefore`. Bei verbindenden
Relationen wird der erste Buchstabe für den Fließtext automatisch
kleingeschrieben. `initial=keep`, `\preskeepcase{...}` oder
`\prescase{Präsentation}{Langform}` unterdrücken beziehungsweise steuern diese
Anpassung. Für allgemein modusabhängigen Inhalt stehen außerdem
`\longform{...}`, `\slides{...}` und
`\longslides{Langform}{Präsentation}` bereit.

`\finite{...}` markiert das finite Verb. Im Deutschen verschiebt
`therefore` dieses Verb an das Ende des Nebensatzes; in allen übrigen
unterstützten Konstruktionen bleibt es an Ort und Stelle. Ein mehrteiliges
Verb wird gemeinsam markiert.

Die Umgebung kennt die Optionen:

- `language=de|en|fr` überschreibt die automatisch bestimmte Sprache.
- `punctuation=auto|manual` schaltet die automatisch eingefügten
  Konnektoren und Satzpunkte ein oder aus.

Ohne `language` gilt die Reihenfolge Babel, Polyglossia, `langselect`,
Klassenoption `lang`. Unterstützt sind deutsche, englische und französische
Sprachnamen und gebräuchliche regionale Varianten; unbekannte Werte erzeugen
eine Warnung und fallen auf Englisch zurück.

`presitemize` modelliert eine flache Folge von Aussagen und wird nicht in sich
verschachtelt. Es ist keine allgemeine Grammatikengine: Abweichende
Satzstrukturen werden mit `\longslides`, `\prescase` oder gewöhnlicher
Moduslogik ausdrücklich formuliert.

Neue proseartige Doctypes ordnet ihr Profil mit
`\AssignLectureModeBehavior{<doctype>}{longform}` ein; sie erhalten dann ohne
Sonderfall in `presitemize` dieselbe Fließtextprojektion. Benötigt eine
künftige Ausgabeform eine andere Semantik, wird dafür eine eigene
Verhaltensklasse definiert, statt `presitemize` an konkrete Doctype-Namen zu
koppeln.

## Zwei Inhalte als Spalten oder Folge

Das obligatorische Klassenpaket `osglecture-twocolumns.sty` stellt die
Umgebung `twocolumns` bereit. Die Klasse lädt es automatisch. Ohne
Modusausdruck werden echte Spalten nur in Präsentationsmodi gesetzt; in allen
anderen Modi erscheinen die mit `\nextcolumn` getrennten Inhalte
untereinander:

```latex
\begin{twocolumns}[t,.4]
  Linker Inhalt
  \nextcolumn
  Rechter Inhalt
\end{twocolumns}
```

Der Winkelausdruck ersetzt den Default `presentation`. Zweispaltige Ausgabe
nur in Langformen beziehungsweise in beiden Modusfamilien wird daher so
gewählt:

```latex
\begin{twocolumns}<longform>[t,.4]
  ... \nextcolumn ...
\end{twocolumns}

\begin{twocolumns}<presentation|longform>[t,.4]
  ... \nextcolumn ...
\end{twocolumns}
```

`<all>` erzwingt die Spaltendarstellung in jedem Modus. Das optionale Argument
behält die bisherige kompakte Syntax: eine Zahl zwischen null und eins legt
den Anteil der ersten Spalte fest, ein oder zwei Werte aus `t`, `c` und `b`
bestimmen die vertikale Ausrichtung. Das Paket kann mit einem zuvor
konfigurierten `osglecture-modes` auch ohne die Klasse geladen werden.

## Build

Das Modul gehört zu `installfiles` und `sourcefiles`. Die üblichen Befehle
lauten:

```sh
l3build check
l3build install
```

## Referenzen

`osglecture-references` ist der obligatorische Kerndienst für lokale und
serieninterne Referenzen. Ohne optionale Dokumentadresse entsprechen seine
Befehle den Hyperref-Befehlen:

```latex
\olref{sec:local}
\olpageref{sec:local}
```

Eine Adresse wählt eine andere logische Unit derselben Serie:

```latex
\olref[processes]{sec:scheduling}
\olautoref[processes,type=script,lang=en]{sec:scheduling}
```

Ein schlüsselloser Eintrag ist stets `unit`; `type` und `lang` übernehmen ohne
Angabe den aktuellen Buildwert. Sternvarianten geben denselben Text ohne Link
aus. Gemeinsamer Projektcode kann die optionale Kompatibilitätsoberfläche
aktivieren:

```latex
\OsgLectureReferencesSetup{
  legacy,
  replace={ref,pageref}
}
```

Das Modul lädt `varioref` mit der empfohlenen Option `nospace`; dessen
öffentliche Befehle wie `\vref` und `\vpageref` können direkt verwendet werden.
Deutsche und englische Texte werden registriert und folgen bei Verwendung von
Babel der jeweils ausgewählten Sprache. Entfernungsabhängige Seitenangaben
sind ausschließlich innerhalb des aktuellen Dokuments sinnvoll. Der alte
Befehl `\xrefdist` ist ein Adapter auf `\vpageref` und wird nur durch
`legacy=true` bereitgestellt.

Alle gewöhnlichen Labels und die konfigurierten abschließenden Zählerstände
werden in `<jobname>.osgref.aux` gespiegelt. Der von OLLM erzeugte Snapshot
registriert externe Exporte mit
`\OsgLectureReferenceDocument{unit=...,type=...,lang=...,aux=...,pdf=...}`
und wird sowohl von expliziten Querreferenzen als auch von der Continuation
gelesen. Promotion, Snapshot-Erzeugung und die Fixpunktauflösung externer
Referenzen sind implementiert.

## Dokumentintegration

In einer durch ihre Verzeichnisrolle `i` gekennzeichneten Integrationsunit lädt
die Klasse automatisch `osglecture-integration`. Beispielsweise importiert

```latex
\includeunit{introduction}
\includeunit{application}
```

die beiden passenden Projektionen genau in Befehlsreihenfolge. Die logischen
Unit-IDs werden gegen den jobgebundenen Snapshot für den aktuellen Doctype und
die aktuelle Sprache aufgelöst. `tagpax` übernimmt Seiten, Struktur,
Destinationen, Links, Inhaltsverzeichniseinträge und Outlines. Jeder Import
wird mit seiner tatsächlich verwendeten Generation als Integrationsabhängigkeit
protokolliert.

Dieser Pfad setzt derzeit ein Tagged PDF mit `StructTreeRoot` voraus. `tagpax`
weist ein ungetaggtes PDF momentan zurück. Ein expliziter Fallback auf
`pdfpages` plus `newpax` ist daher noch als eigener Robustheitsmodus zu
implementieren; er kann naturgemäß keine fehlende Dokumentstruktur herstellen.
