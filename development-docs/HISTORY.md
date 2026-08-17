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

- Das gemeinsame Lua-Modul (`osglecture-manifest.lua`, mit vendoriertem
  TOML-1.0-Leser `osglecture-toml.lua`, siehe `osglecture/THIRD_PARTY.md`)
  existiert und ist getestet (`testfiles/manifest.lvt`). `osglecture.cls`
  liest `shared-tex-directory`/`project-config-file` jetzt über das Modul
  (`manifest.load_tex`); `osglecture-series.sty` und die
  `physical-unit`/`unit-role`-Konsumenten (`osglecture.cls`,
  `osglecture-structure.sty`) über `series_index.current_unit`/
  `initialize_tex_csv_if_available`. Die Auftragsdatei enthält diese Werte
  nicht mehr (Schritte 4 und 5 sind abgeschlossen, siehe `ARCHITECTURE.md`
  Abschnitt 12).
- OLLM ruft das Modul jetzt über `texlua` auf (`OLLM::LuaManifest`,
  `osglecture-manifest-cli.lua`): `ollm doctor` meldet den Lua-seitigen
  TOML-Parser zusätzlich zum Perl-seitigen (informativ, nicht
  Voraussetzung); `ollm check` vergleicht bei jedem Lauf die eigene
  Verzeichnis-Discovery gegen die des Moduls und meldet eine Abweichung als
  Warnung; und seit Schritt 6 delegiert auch `OLLM::Config::structure_snapshot`
  selbst -- der heiße Pfad jedes gewöhnlichen Builds über `resolve_request`
  -- an `OLLM::LuaManifest::discover_units` statt an eine frühere lokale
  `opendir`/Regex-Parsung der Verzeichnisgrammatik. Jeder
  `structure_snapshot`-Aufruf löst dadurch einen `texlua`-Unterprozess aus;
  bei `--all` mit vielen Einheiten ist das öfter als strukturell nötig (die
  Verzeichnisstruktur ändert sich innerhalb eines Laufs normalerweise
  nicht), aber ein früherer Memoisierungsversuch erwies sich als unsicher
  (er brach den Vertrag, dass Umbenennen/Umordnen einer Einheit die
  Struktursignatur ändert) und wurde zugunsten von Korrektheit wieder
  entfernt, siehe Schritt 6 in `ARCHITECTURE.md` Abschnitt 12. `OLLM::Config`
  validiert und mergt Manifestinhalt weiterhin mit OLLM-eigenen Regeln
  (Zieldefaults, Sprachabgleich), die das bewusst minimale gemeinsame Modul
  nicht nachbildet; das bleibt eigenständiger Perl-Code.

Dieser Abschnitt wird bei jedem Migrationsschritt aus `ARCHITECTURE.md`
Abschnitt 12 aktualisiert, bis die Liste leer ist. Wer wissen will, ob eine
konkrete Codestelle dem beschriebenen Design bereits entspricht, prüft diese
Liste -- nicht die übrigen Dokumente, die bewusst nur das Zieldesign zeigen.
