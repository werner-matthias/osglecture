# osglecture

`osglecture` ist die LuaLaTeX-Kernklasse des Bundles. Sie projiziert eine
gemeinsame Lehrquelle auf Präsentationen und Langformen. Der aktuelle
Architekturvertrag ist in `ARCHITECTURE.md` beschrieben.

## Präsentationslisten in gemeinsamer Quelle

Die Umgebung `presitemize` setzt ihre Einträge in Präsentationen als normale
Liste und verbindet sie in der Verhaltensklasse `longform` zu Fließtext. Sie
gehört als interner Kerndienst zur Klasse und wird nicht als separates Paket
geladen.

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

Alle gewöhnlichen Labels werden in `<jobname>.osgref.aux` gespiegelt. Der
derzeitige erste Implementierungsschnitt erwartet, dass ein von OLLM später
generierter Snapshot externe Exporte mit
`\OsgLectureReferenceDocument{unit=...,type=...,lang=...,aux=...,pdf=...}`
registriert. Promotion, Snapshot-Erzeugung, Fixpunktauflösung und die
`tagpax`-Integrationsbefehle sind noch nicht implementiert.
