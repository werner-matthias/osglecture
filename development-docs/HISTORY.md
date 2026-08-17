# Warum Design und Implementierung auseinanderlaufen können

Dieses Dokument ist die einzige Stelle im Bundle, die erklärt, *warum* die
übrigen Entwicklungsdokumente an einzelnen Punkten weiter sind als der
tatsächliche Code. Alle anderen Dokumente (`DESIGN.md`, `GLOSSARY.md`,
`DEPENDENCIES-ollm.md`, `ARCHITECTURE.md`, `README-cls.md`) beschreiben das
**Zieldesign** direkt, ohne diese Geschichte jeweils selbst zu wiederholen.

## Die OLLM/osglecture-Grenze

In der Vorgängerarchitektur (`osgbeamer` mit dem alten OLLM) hatte OLLM genau
zwei Aufgaben: sicherstellen, dass die korrekte Projektion gebaut wurde, und
das Deployment der Ergebnisse. `osglecture` soll insgesamt robuster und
flexibler als `osgbeamer` sein, ohne dass OLLM dafür mehr können muss als
damals.

OLLM wurde jedoch vor den heutigen Lua-Fähigkeiten der Klasse (`\directlua`,
`lfs`) implementiert. Solange die Klasse zur Kompilierzeit weder das
Dateisystem noch TOML lesen konnte, war OLLM die einzige Stelle, an der sich
Projektmanifest-Parsing, Verzeichnis-Discovery und Serientopologie überhaupt
implementieren ließen. Diese Verantwortlichkeiten wanderten dorthin, nicht
weil sie fachlich zu OLLM gehören, sondern weil OLLM zuerst existierte und
zuerst die nötigen Fähigkeiten besaß.

`osglecture-series-index.lua` (August 2026) hat gezeigt, dass
Verzeichnis-Discovery und Namensinterpretation auch kompilierzeitseitig in Lua
zuverlässig funktionieren -- teilweise sogar redundant zu bereits vorhandenem
OLLM-Code (`OLLM::Config.pm::_series_units` und
`osglecture-series-index.lua::parse_unit_name` parsen unabhängig voneinander
dieselbe Verzeichnisgrammatik). Das war der unmittelbare Anlass, am 17. August
2026 zu entscheiden, OLLM wieder auf seine ursprünglichen zwei Aufgaben
zurückzuführen: Auftragsentscheidung und Ausführung (inklusive
Zustandsführung) sowie Deployment. Alles, was Projektinhalt statt
Auftragsentscheidung ist, soll künftig von einem gemeinsamen Lua-Modul
gelesen werden -- kompilierzeitseitig direkt aus `osglecture`, eigenständig
aus OLLM über `texlua`.

Diese Entscheidung ist in `ARCHITECTURE.md` Abschnitt 12 festgehalten:
Leitlinie (die Zwei-Fragen-Prüfung), was strukturell bei OLLM bleiben muss,
die vollständige Klassifikation aller heutigen Auftragsdatei-Schlüssel und die
geplante Schrittfolge.

## Stand der Umsetzung

Die Entwicklungsdokumente beschreiben dieses Zieldesign bereits vollständig.
Der Code setzt es erst teilweise um. Konkret zum Zeitpunkt dieses Eintrags
(17. August 2026):

- Es existiert noch kein gemeinsames Lua-Modul für Manifestinhalt und
  Verzeichnis-Discovery. `osglecture-series-index.lua` deckt nur die
  Verzeichnis-Discovery ab, nicht das TOML-Manifest.
- `OLLM::Config.pm` liest weiterhin das vollständige Projektmanifest und
  löst Serienstruktur, Sprachliste und Bundle-Preset-Inhalt selbst auf, statt
  dafür das gemeinsame Modul zu nutzen.
- Die generierte Auftragsdatei (`<jobname>.osgbuild.tex`) enthält weiterhin
  den vollständigen, in `ARCHITECTURE.md` Abschnitt 12 klassifizierten
  Schlüsselsatz, nicht nur den für die Auftragsentscheidung nötigen
  Ausschnitt.
- `ollm check`/`ollm doctor` parsen das Manifest weiterhin direkt in Perl,
  nicht über `texlua` und das gemeinsame Modul.

Dieser Abschnitt wird bei jedem Migrationsschritt aus `ARCHITECTURE.md`
Abschnitt 12 aktualisiert, bis die Liste leer ist. Wer wissen will, ob eine
konkrete Codestelle dem beschriebenen Design bereits entspricht, prüft diese
Liste -- nicht die übrigen Dokumente, die bewusst nur das Zieldesign zeigen.
