# FLIPSTACK – Testplan

Stand: Phase 4

## Automatische Tests (`flutter test`, 49 Tests)

| Bereich (Brief Abschnitt 14) | Datei | Abgedeckt |
|---|---|---|
| Rasterkoordinaten, isometrische Projektion | `test/game/iso_projection_test.dart` | ja |
| Plattformrotation, Orientierung | `test/game/core_test.dart` | ja |
| Platzierungsvalidierung, Kollisionen | `test/game/core_test.dart` | ja |
| Punktesystem, Combo, Meilensteine | `test/game/scoring_test.dart` | ja |
| Spielende und seine Ursache | `test/game/scoring_test.dart` | ja |
| Speicherung der Statistik (Hin- und Rückwandlung, fehlerhafte Daten) | `test/game/scoring_test.dart` | ja, ohne echten Gerätespeicher |
| Zustandsübergänge in der Runde | `test/game/core_test.dart` | ja |
| Zustandsübergänge der App, Pause, Tutorial-Schritte | `test/app/app_flow_test.dart` | ja |
| Farben und Formen in App und Blender gleich | `test/game/palette_test.dart` | ja |
| Belohnungen, Tagesaufgaben | – | Phase 5 |

## Die zehn Prüffälle aus dem Brief

| Nr. | Fall | Stand |
|---|---|---|
| 1 | Drehen bei leerem Spielfeld | Test + im Simulator geprüft |
| 2 | Drehen mit mehreren Bausteinen | Test + im Simulator geprüft |
| 3 | Mehrere Drehungen nacheinander | Test (vier Drehungen = Ausgangslage) + Simulator |
| 4 | Platzierung nach einer Drehung | Test + Simulator |
| 5 | Platzierung an ungültigen Positionen | Test + Simulator |
| 6 | Erreichen der maximalen Höhe | Test; vom Nutzer auf dem iPhone erreicht |
| 7 | Wiederaufnahme nach einer Pause | Test + Simulator |
| 8 | App-Wechsel während einer Runde | Simulator: Runde pausiert automatisch und bleibt erhalten |
| 9 | Offline-Betrieb | nicht eigens geprüft; die App nutzt bisher kein Netz |
| 10 | Wiederholtes Neustarten | Simulator, wenige Male; kein Dauertest |

## Nicht automatisiert geprüft

- Darstellung (Sprites, Schatten, Animationen): nur durch Ansehen von Bildschirmfotos
- Ton: Dateien und Abspielaufrufe geprüft, **nicht gehört**
- Vibration: im Simulator nicht prüfbar
- Bildrate und Speicher auf echten Geräten
- Android insgesamt
- Unterschiedliche Displaygrößen: nur iPhone 17
- Wird die App beendet, geht die laufende Runde verloren (kein Zwischenspeichern)

## Werkzeuge

- `flutter analyze` – statische Prüfung
- `dart run tool/balance_sim.dart` – Bot-Simulation der Regeln
- `--dart-define=FS_AUTOPLAY=true` – das Spiel spielt selbst, ohne Ton und ohne die gespeicherte Statistik zu ändern
- `--dart-define=FS_SEED=7` – feste Bausteinfolge, `--dart-define=FS_FPS=true` – Bildrate anzeigen
