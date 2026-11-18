# FLIPSTACK – Entwicklungslog

## 18.11.2026 – Phase 0: Analyse und Planung

**Geprüft (tatsächlich ausgeführt):**
- `flutter doctor -v`: Flutter 3.47.9, Dart 3.13.7, Xcode 27.1, Android SDK 36, iPhone-17-Simulator verfügbar
- Blender 5.3.0 headless: Szene mit orthografischer Kamera per Python aufgebaut und mit Eevee als transparentes PNG gerendert (2,3 s)
- Paketversionen über die pub.dev-API abgefragt (Flame 1.38.2 u. a.)

**Befunde:**
- Repository enthält nur den Masterbrief, es existiert noch kein Flutter-Projekt.
- Blender MCP ist **nicht** installiert oder konfiguriert. Ersatz ist eine Headless-Skriptpipeline.
- Android-Lizenzen fehlen teilweise, es gibt zwei `adb`-Installationen, und die echten Geräte sind nicht im Developer Mode.

**Ergebnisse:**
- `docs/PHASE_0_ANALYSE.md`: Bestandsaufnahme, Risiken, Blender-Workflow, Rotationsplan, Entwicklungsplan
- `docs/TECHNICAL_ARCHITECTURE.md`: Architekturentwurf
- `docs/GAME_DESIGN.md`: Entwurf der Kernregeln und des Punktesystems

**Nächster Schritt:** Phase 1a, der Rotations-Spike (Blender-Referenz und Sprite-Komposition C1).

## 18.11.2026 – Nachtrag: Blender MCP

Blender MCP wurde vom Nutzer installiert. Tatsächlich getestet:
- Szenenübersicht gelesen (Standardszene: Camera, Cube, Light)
- Python-Code in der laufenden Blender-Instanz ausgeführt (Blender 5.3.0, Eevee, kein Background-Modus)
- Vorschau-Render erzeugt; das Werkzeug schreibt allerdings in ein temporäres Verzeichnis statt in den angegebenen Pfad
- Screenshot des Blender-Fensters abgerufen

Die Szene wurde dabei nicht verändert. `docs/PHASE_0_ANALYSE.md` ist entsprechend aktualisiert.

## 18.11.2026 – Phase 1a: Rotations-Spike

**Umgesetzt und geprüft:**
- Blender-Szene als Skript (`tools/blender/fs_scene.py`): isometrische Kamera, kamerafestes Licht, Materialien, Plattform mit Kacheln und Eck-Markierung, Würfel mit Fase
- Referenzanimation 0–90° in 5°-Schritten (`assets_src/reference/`)
- Sprites: 4 Würfelfarben, Markierung und Plattform in 3°-Schritten (`assets/sprites/`, 16 MB)
- Flutter-Projekt mit Flame 1.38.2, `IsoProjection`, `TowerRenderer`, Drehung in 300 ms mit Eingabepuffer
- 6 Unit-Tests für die Projektion bestanden, `flutter analyze` ohne Befund
- Im iOS-Simulator (iPhone 17) geprüft: Standbild bei 45° gegen die Referenz, Videoaufnahme der Drehung, Lasttest mit 500 Würfeln (60 FPS im Debug-Build)
- Vergleichsversuch mit `flutter_scene` 0.24.3 in einem Wegwerfprojekt: baut und läuft im Simulator

**Entscheidung:** Sprite-Komposition (C1). Begründung und bekannte Schwächen stehen in `TECHNICAL_ARCHITECTURE.md`, Abschnitt 6.

**Nicht geprüft:** echte Geräte, Android, Speicherverbrauch auf dem Gerät.

**Anmerkung:** Die Assets wurden über Blender im Hintergrundmodus per Skript erzeugt, nicht über Blender MCP.

**Nächster Schritt:** Phase 1b, spielbarer Prototyp (Baustein verschieben, ablegen, Fallanimation, Punktestand) und Würfel-Schatten.

## 18.11.2026 – Phase 1b: Spielbarer Prototyp

**Umgesetzt:**
- Spiellogik ohne Flutter-Abhängigkeit (`lib/game/core/`): Brett, 6 Bausteinformen, Orientierung, Regeln, faire Bausteinfolge, Spielrunde mit Zuständen `preview`, `placing`, `rotating`, `gameOver`
- Steuerung: Ziehen verschiebt den Baustein rasterweise, Tippen oder „Ablegen“ lässt ihn fallen, zwei Knöpfe drehen die Plattform. Der schwebende Baustein dreht sich nie mit.
- Vorschau der Landeposition, rot bei ungültiger Position, mit Texthinweis zum Grund
- Fallanimation mit Stauchung beim Aufprall, Punkte-Einblendung, haptische Rückmeldung
- Punkte (10 je Würfel, 100 je voller Ebene), Höhe, Bestwert (nur für die Sitzung), Anzeige des nächsten Bausteins, Ergebnisbildschirm mit Neustart
- Schatten höherer Säulen auf Würfel-Oberseiten und Plattformfeldern; Fugen zwischen Würfeln geschlossen
- Drehrichtung der Knöpfe korrigiert (rechter Knopf dreht im Uhrzeigersinn)

**Geprüft:**
- 24 Unit-Tests bestanden (Projektion, Orientierung, Regeln, Punkte, Zustände, Spielende), `flutter analyze` ohne Befund
- Im iOS-Simulator von Hand: Ablegen, Verschieben, Drehen, ungültige Position, Neustart
- Autoplay-Lauf (`--dart-define=FS_AUTOPLAY=true`) bis zum Spielende: 1420 Punkte, Höhe 7, Ergebnisbildschirm erscheint
- Bot-Simulation der Regeln, Ergebnis in `GAME_DESIGN.md`

**Bekannte Lücken:**
- Kein Test auf echten Geräten oder Android; Haptik im Simulator nicht prüfbar
- Bestwert wird noch nicht gespeichert (Phase 2)
- Bei hohen Türmen wandert der Sockel hinter die Knöpfe; die Kameraführung braucht Feinschliff
- Seitenflächen der Würfel erhalten keine Schatten von Nachbarn
- Plattform-Sprites belegen weiterhin ca. 80 MB Bildspeicher
- Kein Ton, kein Tutorial, kein Hauptmenü (Phase 4)

**Nächster Schritt:** Spieltest durch den Nutzer, danach Phase 2.
