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

Die präklassische Targetpolicy `document_metadata=required|disabled` ist davon
getrennt. Das Profil beschreibt seine tatsächliche Fähigkeit mit
`document-metadata=required|supported|forbidden`; osglecture validiert beide.

- TeX-Projektkonfiguration:
  `presentation-profile`, `longform-profile`
- BuildSpec und Auftragsdatei transportieren die abstrakte `profile_class`
  beziehungsweise `profile-class` sowie getrennt die effektive
  `document-metadata-policy`
- Standalone-Klassenoption: `profile`
- Profildatei: `osglecture-profile-<name>.def`
- Zuständig: osglecture wählt, validiert und lädt; OLLM übermittelt nur die
  Profilklasse des Targets

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
TeX-lesbarer Form. Sie wählt keine Konfiguration neu aus. Ein Serienprozess
erhält ihren konkreten Pfad vor `\documentclass` im Symbol
`\OSGLectureJobFile`; der Dateiname wird nicht heuristisch gesucht.

### Gemeinsames TeX-Verzeichnis

Das **gemeinsame TeX-Verzeichnis** enthält projektweites TeX-Material wie
Konfigurationsdaten und projektlokale Pakete. Es heißt standardmäßig
`Include`, ist über `project.tex.directory` konfigurierbar und wird von OLLM
kontrolliert in `TEXINPUTS` aufgenommen.

### Projektkonfiguration

Die **Projektkonfiguration** ist die standardmäßig
`Include/projectconfig.tex` genannte TeX-Datei für gemeinsame Autoren- und
Metadatenkonfiguration. Ihr Dateiname ist über `project.tex.config`
konfigurierbar. `osglecture-project` liest sie vor der Basisklasse deklarativ;
frühe Optionen werden sofort berücksichtigt, mode-spezifische Metadaten erst
nach Finalisierung des Modusgraphen materialisiert. Sie ist nicht mit dem
TOML-Projektmanifest oder der jobgebundenen Auftragsdatei identisch.

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

### Unit, Lecture und Kapitel

**Unit**, **Lecture** und **Kapitel** sind Projekt-, Autoren- und
Langformperspektive derselben fachlichen Struktureinheit.

- `unit-id` ist ihre stabile, vom sichtbaren Titel unabhängige Identität.
- `physical-unit` bezeichnet das physische Quellverzeichnis.
- `physical-number` beschreibt die Sortierung.
- Die vorgesehene Autorenoberfläche ist `\lecture[Kurz]{Lang}`.
- Ein Präsentationsadapter realisiert daraus Unit-Titel und native
  Lecture-Information; ein Langformadapter eine Kapitelüberschrift.

Die Autorenoberfläche ist noch nicht implementiert. Bis dahin sind konkrete
Backendzähler und sichtbare Titel keine bundleweite Unit-Identität.

### Kerndienst

Ein **Kerndienst** implementiert einen obligatorischen Teil des gemeinsamen
Dokumentmodells, insbesondere Identität, Grundstruktur oder deren universelle
Projektion. Er kann als eigenes technisches Paket vorliegen, gehört
konzeptionell aber zu `osglecture`.

### Fachpaket

Ein **Fachpaket** implementiert einen optionalen, in sich kohärenten
semantischen Gegenstand, beispielsweise Terminaldarstellungen. Es darf
doctype-abhängige Semantik besitzen, verwendet dafür aber die stabilen
Modus- und Verhaltenscontracts und bleibt unabhängig von konkreten
Dokumentprofilen. Doctype-Abhängigkeit allein macht ein Fachpaket nicht zum
Kerndienst.

### Standalone

**Standalone** bezeichnet einen Build ohne vorausgesetztes Projektmanifest und
ohne festgelegte Serienverzeichnisstruktur. Die Klasse verwendet dabei
eingebaute Defaults oder explizite lokale Klassenoptionen.

Standalone muss mit der Klassenoption `standalone` ausdrücklich gewählt
werden. Ohne diese Option verlangt osglecture die vom Runner gesetzten Zeiger
auf Projektmanifest und Auftragsdatei. Standalone zusammen mit einem solchen
Zeiger ist ein Fehler.

### Legacyzweig

Der **Legacyzweig** ist die explizit aktivierte, konservierte historische
Implementierung. Bei `osglecture` wird er mit der Klassenoption `osgbeamer`
gewählt. Er ist keine Grundlage für neue Schnittstellen.
