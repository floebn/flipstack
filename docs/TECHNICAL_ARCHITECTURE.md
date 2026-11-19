# FLIPSTACK – Technische Architektur

Stand: Phase 5 · Darstellungsentscheidung in Abschnitt 6

## 1. Stack

| Bereich | Wahl | Begründung |
|---|---|---|
| App | Flutter 3.47 / Dart 3.13 | Vorgabe; installiert und geprüft |
| Spiel | Flame 1.38 | Game Loop, Sprite-Batching, Eingabe, Overlays |
| Physik | **keine Physik-Engine**, deterministische Animationen | Brief 3.6: kontrolliert, fair, vorhersehbar |
| Assets | Blender 5.3, headless per Python-Skript | reproduzierbar, eine Kamera für alles |
| Speicherung | `shared_preferences` 2.5.6, Statistik als JSON hinter der Schnittstelle `StatsStore` | Datenumfang ist klein; ein Wechsel ist ohne Änderung am Spiel möglich |
| Werbung / Käufe | `google_mobile_ads`, `in_app_purchase` | Phase 6, hinter Schnittstellen |

## 2. Schichten

```
UI (Flutter-Widgets: Menüs, HUD, Overlays)
        │  liest Zustand, sendet Befehle
Spielsteuerung (Flame Game: Eingabe → Befehle, Zustandsautomat, Animationen)
        │
Darstellung (Renderer: IsoProjection, Sprite-Atlas, Tiefensortierung, Effekte)
        │  liest nur
Spiellogik (reines Dart: Board, Piece, Rules, Scoring, RNG) ← vollständig unit-getestet
        │
Dienste (Storage, Audio, Haptics, Ads, Purchases, Analytics) – Schnittstellen + No-op-Varianten
```

Regel: Die Spiellogik kennt weder Flame noch Flutter. Die Darstellung verändert nie den Spielzustand.

## 3. Projektstruktur (Startpunkt)

Bewusst schlanker als das Beispiel im Brief. Ordner entstehen erst, wenn sie gebraucht werden.

```
lib/
  main.dart
  app/                    # App-Widget, Routing, Theme
  game/
    core/                 # reines Dart: board.dart, piece.dart, piece_library.dart,
                          # rules.dart, scoring.dart, game_state.dart, orientation.dart
    projection/           # iso_projection.dart (EINZIGE Projektionsmathematik)
    render/               # Atlas-Laden, Würfel-/Plattform-Renderer, Tiefensortierung
    animation/            # Fall-, Feder-, Rotationsanimation (deterministisch)
    input/                # Gesten → Befehle
    flipstack_game.dart   # FlameGame, verbindet alles
  features/               # ab Phase 4/5: home, gameplay_hud, results, shop, tasks, settings
  services/               # ab Phase 2: storage, audio, haptics; später ads, purchases, analytics
  shared/                 # Theme-Farben, gemeinsame Widgets
assets/
  sprites/                # gerenderte Atlanten (PNG + JSON-Metadaten)
  backgrounds/
  audio/
  fonts/
assets_src/               # Referenz-Renderings und .blend-Dateien (nicht im App-Bundle)
tools/blender/            # Render- und Build-Skripte
test/                     # spiegelt lib/game/core und projection
docs/
```

## 4. Kernmodelle

- `GridPos(x, y, z)`: Plattformkoordinaten, unveränderlich.
- `Orientation` (0–3): Drehzustand der Plattform. Liefert die Abbildung Bildschirmrichtung ↔ Rasterachse und die Transformation des kamerafesten Bausteins in Plattformkoordinaten.
- `PieceShape`: Menge relativer Zellen (Polycube) in **Kamera-Ausrichtung**.
- `Board`: belegte Zellen → Farbe/Bausteinkennung, Höhe je Säule, Abfragen für Auflage und Kollision.
- `Rules`: `canPlace`, `landingHeight`, `hasAnyValidPlacement(shape)` (für Game-over; prüft alle Positionen und alle 4 Orientierungen).
- `GameStateMachine`: Zustände laut Brief 10.3 (`loading`, `mainMenu`, `tutorial`, `playing`, `piecePreview`, `placing`, `rotating`, `gameOver`, `reward`, `paused`) mit expliziter Tabelle erlaubter Übergänge. Ungültige Übergänge werfen im Debug-Modus einen Fehler und werden im Release ignoriert und protokolliert.
- `Rng`: seedbarer Zufall für die Bausteinfolge, damit Tests und spätere Herausforderungen reproduzierbar sind.

## 5. IsoProjection

```
screen = project(worldX, worldY, worldZ, theta)
  1. Rotation um die Plattformmitte:  (x', y') = R(theta) · (x - c, y - c)
  2. Isometrie:  sx = (x' - y') · tileW/2
                 sy = (x' + y') · tileH/2 - z · cubeH
  3. depth = x' + y' + z·ε   (Painter-Sortierung, größere Tiefe = später zeichnen)
```

`tileW`, `tileH` und `cubeH` werden aus den Blender-Kameraparametern (`tools/blender/config.json`) abgeleitet, damit Sprites und Projektion pixelgenau übereinstimmen. Die Rotation des Turms ist **nur** ein Parameter `theta` dieser Funktion. Die Logikdaten bleiben unverändert.

## 6. Darstellung – Entscheidung: Sprite-Komposition (Option C1)

**Entschieden am 18.11.2026 nach dem Rotations-Spike (Phase 1a).**

### Was verglichen wurde

| Variante | Ergebnis im Spike |
|---|---|
| **Blender-Referenz** (echte 3D-Szene, Eevee) | Zielbild, siehe `docs/img/phase1a_blender_referenz.png` und `assets_src/reference/reference.mp4` |
| **C1 Sprite-Komposition** (Flame, Sprites aus Blender in 3°-Schritten) | Geometrie deckt sich bei 0°, 45° und in Zwischenwinkeln mit der Referenz. Material, Fasen und Flächenhelligkeit sind identisch zur Referenz, weil es dieselben Renderings sind. Tiefensortierung ohne Fehler. Siehe `docs/img/phase1a_c1_sprites_zwischenwinkel.png` |
| **D Echtzeit-3D** (`flutter_scene` 0.24.3) | Läuft im iOS-Simulator auf Anhieb: orthografische Kamera, echte Schlagschatten, flüssige Drehung. Mit eingebauten Würfeln ohne Fasen wirkt es hart und flach. Siehe `docs/img/phase1a_d_flutter_scene.png` |

### Begründung für C1

- **Qualität:** C1 erreicht die Materialqualität der Referenz sofort. D bräuchte dafür glTF-Modelle mit Fasen und deutliche Arbeit an Licht, Ambient Occlusion und weichen Schatten. Ob D die Referenz dann erreicht, ist offen.
- **Risiko:** `flutter_scene` setzt Flutter GPU voraus, das in Flutter 3.47 standardmäßig ausgeschaltet ist und je Plattform eigens aktiviert werden muss. Auf Android und auf echten Geräten habe ich es nicht geprüft. C1 nutzt nur gewöhnliches Canvas-Zeichnen.
- **Leistung:** C1 zeichnet 500 Würfel im iOS-Simulator (Debug-Build) mit 60 FPS. Eine Messung auf echten Geräten steht noch aus.

### Bekannte Schwächen von C1 und geplante Abhilfe

| Schwäche | Abhilfe (Phase 1b/2) |
|---|---|
| Würfel werfen keine echten Schlagschatten auf **Seitenflächen** | Seit Phase 3 erhalten Seitenflächen eine Schattierung am Fuß und Oberseiten Verläufe entlang höherer Wände. Echte Schlagschatten auf Seitenflächen gibt es weiterhin nicht |
| ~~Bodenschatten laufen über die Plattformkante~~ | **Erledigt in Phase 1b:** Schatten werden je Feld beschnitten |
| ~~Plattform-Sprites belegen ca. 80 MB Bildspeicher~~ | **Erledigt in Phase 2:** Drehbilder in halber Auflösung, Standbild in voller. Rechnerisch ca. 22 MB statt 79 MB; auf dem Gerät noch nicht gemessen |
| Jeder Würfel ist ein eigener Zeichenaufruf | Seit Phase 3 gibt es nur noch ein graues Würfel-Sprite, das eingefärbt wird (ein Atlas statt vier). Bündeln der Aufrufe bleibt offen, bis eine Messung auf dem Gerät es nötig macht |

### Rückfallweg

Spiellogik und `IsoProjection` hängen nicht von der Darstellung ab. Falls C1 bei den Würfel-Schatten nicht überzeugt, kann der Renderer gegen eine `flutter_scene`-Variante getauscht werden, ohne die Logik anzufassen.

### Ablauf je Bild

1. Hintergrund (Verlauf, Rauten, Lichtschein) und Bodenschatten der Plattform.
2. Plattform-Sprite für den aktuellen Winkel, Eckkachel und Eckpfosten (je nach Lage vor oder hinter der Plattform).
3. Freie Plattformfelder: Schlagschatten, Eck-Schattierung, gegebenenfalls Hervorhebung.
4. Alle Würfel mit `IsoProjection` projizieren, nach Tiefe sortieren. Je Würfel: Fugenfüllung, eingefärbtes Sprite, Schattierung der Seiten, Schatten auf der Oberseite.
5. Höhengrenze, Staub, Punkte-Einblendungen.

## 7. Physik und Animation

- Fallen: Höhe folgt einer Beschleunigungskurve und endet exakt auf der Rasterhöhe.
- Aufprall: gedämpfte Feder auf die Skalierung (Squash & Stretch, ≤ 8 %) und kurzer Partikelimpuls.
- Nachbarn: kleiner gedämpfter Versatz (≤ 2 px) bei direkt angrenzenden Würfeln, kehrt immer exakt zurück.
- Kein Zustand der Logik hängt von Animationen ab. Animationen sind reine Darstellung.

## 8. Dienste und App-Ablauf

**Ein Bildschirm, mehrere Zustände.** `GameScreen` zeigt immer das Spiel und legt je nach Zustand eine Oberfläche darüber: Hauptmenü, Spielanzeige, Tutorial, Pause, Ergebnis. Zwischen den Zuständen wird nichts geladen. Im Hauptmenü zeigt das Spiel einen Beispielturm, der sich alle paar Sekunden dreht.

**Zustände** (`lib/app/app_flow.dart`): `loading`, `mainMenu`, `tutorial`, `playing`, `paused`, `gameOver`, mit fester Tabelle erlaubter Übergänge. Die feineren Zustände einer Runde (`preview`, `placing`, `rotating`) liegen in `GameSession`. Der Zustand `reward` aus dem Brief folgt mit Phase 5.

**Dienste hinter Schnittstellen:**

| Dienst | Schnittstelle | Umsetzungen |
|---|---|---|
| Statistik | `StatsStore` | lokal (`shared_preferences`), im Speicher |
| Einstellungen | `Settings` | lokal |
| Belohnungsstand | `ProfileStore`, `ProfileController` | lokal (`shared_preferences`, JSON), im Speicher |
| Ton und Vibration | `GameFeedback` | Gerät (`flame_audio` 2.12.2, Plattform-Haptik), stumm |

Schlägt Laden, Speichern oder Abspielen fehl, läuft das Spiel ohne diese Funktion weiter. Die App nutzt bisher kein Netz. Werbung und Analytics kommen in Phase 6 und werden erst nach Einwilligung gestartet.

**Belohnungen:** Die Regeln (Münzen, Aufgaben, Erfolge, Kauf) liegen als reines Dart in `lib/game/meta/rewards.dart`; `Profile` ist unveränderlich, jede Aktion liefert einen neuen Stand. Das Aussehen der Freischaltungen steht in `lib/game/render/looks.dart`. Blockfarben wechseln über den Farbfilter des grauen Würfel-Sprites, die Plattform über einen Farbfilter auf ihrem Sprite, beides ohne zusätzliche Bilder. Vor dem Laden speichert der Controller nichts, damit ein leerer Stand den gespeicherten nicht überschreibt.

**Ton:** Alle Klänge entstehen durch Synthese (`tools/audio/make_sounds.py`), es gibt keine fremden Aufnahmen. Der Stummschalter wird respektiert, Musik anderer Apps läuft weiter.

## 9. Qualitätssicherung

- Unit-Tests: Raster, Orientierung, Projektion (Referenzwerte), Regeln, Punkte, Zustandsübergänge.
- Golden-/Screenshot-Prüfung: Renderer bei θ = 0°, 45°, 90° gegen Blender-Referenz (visuell durch mich).
- Performance: Stresstest mit 1.000 Würfeln, Frame-Zeit im Profiler.
- `flutter analyze` mit `flutter_lints` ohne Warnungen.
