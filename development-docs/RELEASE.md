# Release-Ablauf

Wie ein Release entsteht, von der Versionsnummer bis zur CTAN-Einreichung.
Hintergrund der Aufteilung und aller Namen: `CTAN-SPLIT.md`.

## Release-Einheiten

Es gibt zwölf Einheiten, die CTAN einzeln erhält:

- das **Bundle** `osglecture`: Klasse `osglecture`, Build-Manager `osgdocmk`
  und das Handbuch aus `manual-src` (eine Einreichung);
- elf **eigenständige Pakete**: `osgmodes`, `tagpax`, `tagdirtree`,
  `langselect`, `osgstyler`, `lttalk-themeengine`, `lttalk-theme-tuc-2019`,
  `ansiterm`, `osglistings`, `semcat`, `osgdoc`.

`texlua tools/make-ctan-metadata.lua --list` nennt sie; die Quelle ist das
Register `tools/packages.lua`.

## Versionen

| Was | Versionsschema | Wo gepflegt |
|---|---|---|
| eigenständiges Paket | `vX.Y.Z` | `\ProvidesExplPackage{…}{Datum}{vX.Y.Z}` in der `.dtx` |
| Klasse `osglecture` | `vX.Y.Z` | `osglecture/*.dtx` |
| `osgdocmk` | `vX.Y.Z` | `$VERSION` in `osgdocmk/scripts/lib/OLLM/Version.pm` |
| Bundle als Ganzes | Datum `YYYY-MM-DD` | Marker `BUNDLE RELEASE DATE` in `README.md` |

Die CTAN-Version eines eigenständigen Pakets ist seine `vX.Y.Z`, die des
Bundles sein Datum; beides wird beim Upload aus den Quellen gelesen
(`make-ctan-metadata.lua --show <einheit>` zeigt `version`).

## Ablauf

1. **Änderungen fertigstellen und testen** (`l3build check` im Modul, bei
   Änderungen am Build-Manager `prove` in `osgdocmk/`).
2. **Version setzen**
   - Paket oder Modul: im Modulverzeichnis `l3build tag vX.Y.Z`. Das setzt
     Version und Datum in den Quellen und erneuert danach die
     Modultabelle in `README.md`, den CTAN-Schnappschuss `ctan/README.md` und
     die Abhängigkeitsabschnitte der Paket-READMEs.
   - Bundle: im Wurzelverzeichnis `l3build tag` (Datum heute) oder
     `l3build tag --date=YYYY-MM-DD`. Das Bundle wird nur getaggt, wenn sich
     Klasse, `osgdocmk` oder Handbuch geändert haben.
3. **Committen.** Ein Commit darf mehrere Module weiterstufen.
4. **Git-Tags setzen:** im Wurzelverzeichnis `l3build gittag`
   (`--dry-run` zeigt nur, was fehlt), danach `git push --follow-tags`.
   Tags entstehen aus den Quellen (`<modul>/vX.Y.Z`, Bundle: `YYYY-MM-DD`),
   nie umgekehrt. Der Hook `.githooks/pre-push` warnt, wenn Tags fehlen.
5. **CTAN-Daten prüfen:** `texlua tools/make-ctan-metadata.lua --check`
   (alle Einheiten) meldet fehlende Texte in `ctan/<paket>/`, überschrittene
   Feldlängen, Abweichungen zwischen Register und `build.lua` und
   Unstimmigkeiten der Abhängigkeitsmatrix. `--show <einheit>` zeigt die
   Felder, wie sie hochgeladen werden.
6. **ZIP bauen**
   - eine Einheit: im Modulverzeichnis `l3build ctan`; für das Bundle im
     Wurzelverzeichnis `l3build ctan`;
   - alle: im Wurzelverzeichnis `l3build ctanall`.
   Jeder Lauf führt zuerst die Tests aus und bricht ab, wenn sie scheitern
   oder eine generierte README (`CTAN`-Schnappschuss, Abhängigkeitsabschnitt)
   nicht zum Stand passt.
7. **Hochladen:** `l3build upload --email=<adresse> --dry-run` lässt CTAN nur
   validieren, ohne `--dry-run` wird eingereicht (im Modulverzeichnis für ein
   Paket, im Wurzelverzeichnis für das Bundle). Eine Version auf der
   Kommandozeile hat Vorrang vor der aus den Quellen.
8. **Nach der Annahme** den Eintrag in `ctan/released.lua` ergänzen. Danach ist
   die Einheit ein Update (`update = true`).

## Wo was steht

| Datei | Inhalt |
|---|---|
| `tools/packages.lua` | Register: Module, Versionsquellen, Abhängigkeitsmatrix, Lizenz, Themen, Beispiele |
| `ctan/<paket>/` | handgeschriebene Texte: `summary.txt`, `description.html`, `announcement.txt`, `note.txt` |
| `ctan/fragments/` | Absätze, die an jede Notiz angehängt werden (Kontext, Testhilfsskript) |
| `ctan/released.lua` | bereits akzeptierte Pakete |
| `ctan/upload.lua` | setzt die `uploadconfig` einer Einheit aus Register und Texten zusammen |
| `<paket>/README.md` | Paket-README mit generiertem Abschnitt „Dependencies“ |

Generiert, nicht von Hand zu pflegen: Abhängigkeitsabsatz in der CTAN-Beschreibung,
Kontext- und Dokumentations-Absatz der Notiz, Abschnitt „Dependencies“ der
Paket-READMEs, Modultabelle in `README.md`, `ctan/README.md`.

## Neue Abhängigkeit oder neues Paket

- **Abhängigkeit:** eine Zeile in `dependencies` (Module dieses Repositories)
  oder `external_dependencies` (Fremdpakete) in `tools/packages.lua`; danach
  `texlua tools/make-package-readmes.lua` und `make-ctan-metadata.lua --check`.
  `texlua tools/make-ctan-metadata.lua --matrix` zeigt das Ergebnis.
- **Paket:** Eintrag im Register, `bundle = ""` und `tdsroot` in der
  `build.lua` des Moduls passend zum `lua`-Marker (wird geprüft), Texte in
  `ctan/<paket>/`.
