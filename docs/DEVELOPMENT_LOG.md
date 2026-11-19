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

## 19.11.2026 – Phase 2: Kernspiel

**Umgesetzt:**
- 13 Bausteinformen in vier Stufen, darunter zwei mit Höhe (stehender Doppelblock, Stufe)
- Punktesystem: saubere Ablage, Combo-Multiplikator, volle Ebene, Höhenmeilenstein; jeder Posten wird eingeblendet
- Statistik (Bestwert, Höhe, Runden, Durchschnitt, beste Combo, Bausteine) dauerhaft lokal gespeichert
- Vorwarnung bei weniger als 4 gültigen Ablagen
- Spielgefühl: Staub beim Aufprall, Bausteine darunter federn leicht mit, am Spielende fährt die Kamera zurück und zeigt den ganzen Turm, Ergebnis mit Statistik darunter
- Plattform-Drehbilder in halber Auflösung (Sprites auf der Platte 7 MB statt 16 MB)

**Geprüft:**
- 34 Unit-Tests bestanden, `flutter analyze` ohne Befund
- Bot-Simulation mit allen Formen: Planer im Median 57 Steine
- Autoplay-Lauf im iOS-Simulator bis zum Spielende (49 Steine, Höhe 8, 3135 Punkte), Ergebnisbildschirm geprüft
- Bestwert nach Beenden und Neustart der App weiterhin vorhanden

**Im Lauf gefunden und behoben:**
- Punkte-Einblendungen überlappten sich
- Combo erreichte nach wenigen Zügen das Maximum; Kurve abgeflacht (0,1 je Ablage, höchstens ×2,0)

**Nicht geprüft / offen:**
- Echte Geräte und Android; Vibration; Speicherverbrauch auf dem Gerät
- Die Formen S/Z/Stufe erscheinen erst ab Baustein 37 und waren im Simulatorlauf kaum zu sehen
- Pause-Knopf und Wiederaufnahme einer Runde nach App-Neustart (Phase 4)
- Schatten auf Seitenflächen (Phase 3)
- Bei hohen Türmen liegt der Sockel während des Spiels hinter den Knöpfen

## 19.11.2026 – Spielende verständlich machen (nach Spieltest)

**Anlass:** Der Nutzer erreichte auf einem echten iPhone 4392 Punkte (77 Steine, Höhe 12) und konnte nicht erkennen, warum „Kein Platz mehr“ erschien.

**Umgesetzt:**
- Logik ermittelt, woran der letzte Stein scheitert (`Rules.blockers`, `GameSession.blockCause`)
- Rahmen zeigt die Höhengrenze, die tiefsten Felder pulsieren, Hinweistext umformuliert
- Ergebnis zeigt den gescheiterten Stein mit Begründung; die Kamera lässt Platz für die höhere Karte
- Autoplay-Testläufe schreiben nicht mehr in die gespeicherte Statistik

**Geprüft:** 38 Unit-Tests bestanden, Autoplay-Lauf im iOS-Simulator bis zum Spielende, Bild in `docs/img/phase2_spielende_erklaert.png`.

**Hinweis:** Ein früherer Autoplay-Lauf hat den Bestwert im Simulator überschrieben (vorher 1500, jetzt 3810). Das iPhone ist davon nicht betroffen.

**Offen:** Ob die Regel damit für Menschen verständlich ist, muss ein weiterer Spieltest zeigen.
