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

Die in `ARCHITECTURE.md` Abschnitt 12 festgehaltene Schrittfolge (Schritte 1
bis 6) ist seit dem 17. August 2026 vollständig umgesetzt: Das gemeinsame
Lua-Modul existiert und ist getestet, `osglecture.cls` liest Projektinhalt
(Manifest, Serienstruktur, `physical-unit`/`unit-role`/`logical-ordinal`)
selbst darüber, die Auftragsdatei transportiert nur noch die in der
Klassifikationstabelle als „OLLM"/„Grenzfall" markierten Schlüssel, und
`OLLM::Config::structure_snapshot` delegiert die Verzeichnis-Discovery an
dasselbe Modul statt an eine eigene Parsung. Was in Abschnitt 12 als
strukturell bei OLLM verbleibend beschrieben ist (Auftragsentscheidung,
Zustandsführung, Deployment, sowie die eigene Manifestvalidierung mit
OLLM-Regeln) bleibt bewusst so -- das ist Zieldesign, keine Lücke.

Damit ist diese Liste leer: Code und Entwicklungsdokumente stimmen an
diesem Punkt überein. Dieser Abschnitt bleibt für den nächsten Fall stehen,
in dem eine neue Design-Entscheidung der Umsetzung vorausläuft.
