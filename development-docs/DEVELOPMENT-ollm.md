# OLLM entwickeln und prüfen

Dieses Dokument sammelt die aus dem früher gemischten OLLM-Handbuch
ausgelagerten Hinweise für Entwicklung und Paketierung. Die öffentliche
Bedienung und die TOML-Referenz stehen in `ollm/ollm.tex`; Architektur und
Rationales stehen in `DESIGN.md`.

## Standardprüfungen

Die üblichen Befehle werden im Verzeichnis `ollm` ausgeführt:

```sh
l3build check
l3build doc
l3build install
```

`l3build check` prüft die Perl-Syntax, die CLI- und Konfigurationsverträge,
Zustand, Deployment, Maintenance und -- sofern die TeX-Werkzeuge verfügbar
sind -- den realen LuaLaTeX-Referenzlebenszyklus. Die Perl-Tests können direkt
ausgeführt werden:

```sh
prove -Iscripts/lib -Iscripts/vendor/TOML-Tiny-0.22/lib testfiles/*.t
```

`l3build doc` erzeugt die installierbaren OLLM-Handbuch-PDFs. Benötigt
LuaLaTeX in einer eingeschränkten Umgebung einen ausdrücklich schreibbaren
Fontcache, kann `TEXMFVAR` auf ein temporäres Verzeichnis zeigen.

## Relevante Entwicklungsdokumente

- `DESIGN.md`: Systemgrenzen, Datenverträge, Zustandsmodell und Rationales;
- `ARCHITECTURE.md`: osglecture-Klassenarchitektur sowie, in Abschnitt 12,
  die verbindliche Zielaufteilung der Verantwortung zwischen OLLM und
  `osglecture`;
- `GLOSSARY.md`: bundleweit verbindliche Terminologie;
- `DEPENDENCIES-ollm.md`: Laufzeitabhängigkeiten, gebündelte TOML-Parser und
  Windows-Hinweise;
- `HISTORY.md`: warum einzelne Codestellen dem in den übrigen Dokumenten
  beschriebenen Zieldesign noch nicht entsprechen;
- `ToDo.md`: noch offene Funktionen und längerfristige Ideen.
