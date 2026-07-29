# Glossar der osglecture-Entwurfskonzepte

Dieses Glossar legt die bundleweit verwendeten Begriffe verbindlich fest. Die
ausführlichen Entwurfsentscheidungen und Rationales stehen weiterhin in
`ollm/DESIGN.md` und `osglecture/ARCHITECTURE.md`; dieses Dokument definiert
dagegen die gemeinsame Sprache beider Komponenten.

## Konfiguration und Auswahl

### Bundle-Preset

Ein **Bundle-Preset** ist ein benannter und versionierter Ausgangssatz von
OLLM-Konfiguration, LaTeX-Defaults und Projektpolicy. Es beschreibt eine
Kompatibilitätsgeneration, nicht die installierte Paketversion und nicht die
konkrete Dokumentdarstellung.

- TOML-Manifest und Nutzerdefaults: `bundle_preset = "OSG lecture/1"`
- Definitionsart: `kind = "bundle-preset"`
- BuildSpec: `bundle_preset`
- Auftragsdatei: `bundle-preset`
- Zuständig: OLLM

Name und Hauptversion bilden zusammen die opake Identität. `/1` ist somit die
Generation des Presets. Ein Bundle-Preset darf Dokumentprofil-Defaults
festlegen, wählt aber keinen einzelnen Buildauftrag.

### Nutzerdefaults

**Nutzerdefaults** sind persönliche, projektübergreifende Vorgaben. Sie werden
nach den eingebauten Defaults und dem Bundle-Preset, aber vor dem
Projektmanifest angewendet. Sie dürfen insbesondere das Standard-Bundle-Preset
und die Dokumentprofile für Präsentation und Skript festlegen.

- Datei: plattformabhängige OLLM-Nutzerkonfiguration
- Zuständig: OLLM
- Nicht zu verwechseln mit `.ollmconfig.local.toml`; diese Datei erweitert
  gegenwärtig projektbezogen die Definitionssuchpfade.

### Projektmanifest

Das **Projektmanifest** ist `ollmconfig.toml` an der Projektwurzel. Es beschreibt
Projektidentität, Sprachen, Targets, Sicherheitsrichtlinie und gezielte
Projekt-Overrides. Es markiert zugleich die Projektwurzel.

### Projektpolicy

Eine **Projektpolicy** ist eine vom Projekt erzwungene Konfiguration, die nicht
durch lokale LaTeX-Optionen abgeschwächt werden darf. Sie wird im BuildSpec
gesondert von normalen effektiven Defaults transportiert.

## Dokumentmodell

### Target

Ein **Target** ist der von OLLM auswählbare, registrierte Name eines
Ausgabeziels, beispielsweise `slides`, `handout` oder `script`. Targetnamen
können erweitert werden.

- BuildRequest: angeforderte Auswahl
- Targetdefinition: Zuordnung zu Doctype, Obermodi und Unit-Scopes
- BuildSpec: normalisierter Targetname
- Zuständig: OLLM

### Doctype

Der **Doctype** ist die Dokumentperspektive eines konkreten Builds und zugleich
sein aktiver Blattmodus. Im gegenwärtigen Modell werden Target und Doctype bei
der Normalisierung synchron gehalten, bleiben aber als prüfbare Schnittstellen
beide explizit.

- BuildSpec und Auftragsdatei: `doctype`
- Zuständig: OLLM normalisiert; osglecture interpretiert

### Dokumentprofil

Ein **Dokumentprofil** beschreibt die konkrete TeX-Integration eines oder
mehrerer Doctypes: Backend, Basisklasse, dokumenttypspezifische
Basisklassenoptionen, Metadatenvoraussetzungen und optionales Setup.

- Nutzer-/Projektkonfiguration:
  `presentation_profile`, `script_profile`
- BuildSpec: `document_profile`
- Auftragsdatei: `document-profile`
- Standalone-Klassenoption: `profile`
- Profildatei: `osglecture-profile-<name>.def`
- Zuständig: OLLM wählt; osglecture validiert und lädt

Ein Dokumentprofil ist weder ein Bundle-Preset noch ein Unit-Scope.

### Identitätsprofil

Ein **Identitätsprofil** bezeichnet eine Auswahl visueller
Corporate-Identity-Vorgaben, derzeit über `identity_profile` beziehungsweise
`identity-profile`. Es beeinflusst die Darstellung, aber weder Basisklasse noch
Backend. Der Begriff ist vom Dokumentprofil getrennt und bleibt vorerst Teil
der effektiven LaTeX-Konfiguration.

### Backend

Das **Backend** ist die technische Implementierung der
Dokumenttypssemantik. Es wird vom Dokumentprofil deklariert und muss nicht mit
dessen Namen oder mit der Basisklasse identisch sein.

### Basisklasse

Die **Basisklasse** ist die von `osglecture.cls` über `\LoadClass` geladene
LaTeX-Klasse, gegenwärtig `beamer`, `ltx-talk` oder `scrbook`. Sie ist ein
Implementierungsdetail des Dokumentprofils.

### Mode

Ein **Mode** ist ein semantischer Selektor im gemeinsamen LaTeX-Quelltext.
Der Doctype ist der aktive Blattmodus; eine azyklische Modusmatrix kann daraus
transitiv Obermodi wie `presentation` oder `print` aktivieren.
`osglecture-modes` stellt dafür die portable Syntax bereit.

### Unit-Scope

Der **Unit-Scope** ist der Geltungsbereich einer Serieneinheit. Sein kurzer
Scope-Code im Verzeichnisnamen, beispielsweise `a`, `as`, `b` oder `bh`,
bestimmt, für welche Targets die Einheit in `--all` berücksichtigt wird.

- Verzeichnisname: `<Nummer><Scope-Code>-<Slug>`
- Targetdefinition: `unit_scopes`
- BuildSpec und Auftragsdatei: `unit_scope` beziehungsweise `unit-scope`

Die vorhandenen Scope-Codes bleiben aus Kompatibilitätsgründen bestehen. Der
Unit-Scope hat keine Beziehung zum Dokumentprofil oder Bundle-Preset.

### Rolle

Die **Rolle** beschreibt die strukturelle Aufgabe einer Serieneinheit,
beispielsweise `content`, `appendix`, `excursus` oder `integration`.

### Edition

Eine **Edition** wäre eine zusätzliche, gleichzeitig baubare inhaltliche
Ausprägung desselben Targets, Doctypes und Dokumentprofils, beispielsweise
`student` und `instructor`. Dafür besteht derzeit kein implementierter Bedarf.
Es sind deshalb weder CLI-Optionen noch Schema-, BuildSpec-, Jobname- oder
Auftragsdateifelder reserviert. Falls der konkrete Bedarf entsteht, wird
`edition` als neue orthogonale Builddimension entworfen.

## Buildmodell

### BuildRequest

Ein **BuildRequest** ist die normalisierte Benutzerabsicht nach dem CLI-Parsing.
Er darf noch Auswahlspielräume wie `--all` enthalten und ist noch nicht
ausführbar.

### BuildSpec

Ein **BuildSpec** ist die vollständig normalisierte, konkrete und ausführbare
Beschreibung genau eines Builds. Er enthält unter anderem Job-ID, Target,
Doctype, Dokumentprofil, Pfade, Sprache, Sicherheitsrichtlinie und
Konfigurationssignatur.

### Job-ID

Die **Job-ID** ist die portable Identität eines konkreten Builds und zugleich
der von OLLM gesetzte TeX-Jobname. Sie bindet die Auftragsdatei an genau diesen
Build.

### Auftragsdatei

Die **Auftragsdatei** ist die von OLLM atomar erzeugte Datei
`<job-id>.osgbuild.tex`. Sie transportiert den BuildSpec in validierter,
TeX-lesbarer Form. Sie wählt keine Konfiguration neu aus.

### Buildverzeichnis

Das **Buildverzeichnis** ist der für genau einen BuildSpec isolierte Ort für
PDF, Recorderdatei, latexmk-Zustand und Aux-Dateien. Verschiedene BuildSpecs
dürfen dort keinen schreibbaren Zustand teilen.

## Struktur und Kompatibilität

### Projekt

Ein **Projekt** ist der durch ein Projektmanifest begrenzte Verzeichnisbaum.
OLLM darf projektbezogene Buildzustände nur innerhalb dieser kanonischen
Projektwurzel erzeugen.

### Serie

Eine **Serie** ist ein Projekt aus geordneten Einheiten, die gemeinsame
Metadaten, Referenzen und Ausgabedefinitionen verwenden.

### Einheit

Eine **Einheit** ist ein Quellverzeichnis innerhalb einer Serie. Ihr
Verzeichnisname kodiert Sortiernummer, optionalen Scope-Code, optionale Rolle
und stabilen Slug.

### Standalone

**Standalone** bezeichnet einen Build ohne vorausgesetztes Projektmanifest und
ohne festgelegte Serienverzeichnisstruktur. Die Klasse verwendet dabei
eingebaute Defaults oder explizite lokale Klassenoptionen.

Ohne Auftragsdatei ist der Zustand implizit. Die Klassenoption `standalone`
erzwingt ihn auch dann, wenn eine jobgebundene Auftragsdatei vorhanden ist;
osglecture ignoriert diese Datei in diesem Fall mit einer Warnung.

### Legacyzweig

Der **Legacyzweig** ist die explizit aktivierte, konservierte historische
Implementierung. Bei `osglecture` wird er mit der Klassenoption `osgbeamer`
gewählt. Er ist keine Grundlage für neue Schnittstellen.
