# FLIPSTACK – Phase 0: Analyse und Planung

Stand: 18.11.2026 · Grundlage: `MASTER_BRIEF.md`

Dieses Dokument enthält die sechs im Brief (Abschnitt 19) geforderten Ergebnisse:

1. Bestandsaufnahme
2. Architekturvorschlag (Kurzfassung, Details in `TECHNICAL_ARCHITECTURE.md`)
3. Technische Risiken
4. Plan für den Blender-Workflow
5. Plan für die Plattformrotation
6. Entwicklungsplan

Alle Angaben unten wurden auf dieser Maschine tatsächlich geprüft, sofern nicht ausdrücklich als „ungeprüft“ markiert.

---

## 1. Bestandsaufnahme

### 1.1 Repository

| Punkt | Befund |
|---|---|
| Inhalt | nur `MASTER_BRIEF.md`; ein Commit („Erster Commit“), Branch `main` |
| Flutter-Projekt | noch nicht vorhanden |
| Assets, Blender-Dateien | noch nicht vorhanden |
| `.gitignore` | fehlt, kommt mit dem Flutter-Projekt in Phase 1 |

Das Projekt beginnt also bei null. Es gibt keine Altlasten, die berücksichtigt werden müssen.

### 1.2 Entwicklungsumgebung

| Werkzeug | Version / Status | Bewertung |
|---|---|---|
| macOS | 27.0.1, Apple M4 Max (arm64) | ✅ sehr leistungsfähig, auch für Blender-Renderings |
| Flutter | 3.47.9 stable (Engine 2026-10-27) | ✅ aktuell genug für alle geplanten Pakete; `flutter upgrade` bietet eine neuere Version an, nicht nötig |
| Dart | 3.13.7 | ✅ |
| Xcode | 27.1, CocoaPods 1.16.2 | ✅ iOS-Builds möglich |
| iOS-Simulator | iPhone 17 (iOS 27) verfügbar | ✅ |
| Android SDK | Platform 36, Build-Tools 36.1.0-rc1, Emulator 36.3 | ⚠️ siehe unten |
| Java | OpenJDK 21 (Android Studio JBR) | ✅ |
| Python | 3.14.6 | ✅ |
| Node | 25.2.1 | ✅ (nur für Hilfswerkzeuge) |
| Blender | 5.3.0 (Build 10.11.2026) unter `/Applications/Blender.app` | ✅ |
| `blender` im PATH | nein | unkritisch, wird über den vollen Pfad aufgerufen |

**Offene Punkte der Umgebung (nicht blockierend für Phase 1):**

- Android-Lizenzen sind nicht vollständig akzeptiert. Behebung durch dich: `flutter doctor --android-licenses`.
- Zwei `adb`-Installationen (Android SDK und Homebrew) können sich bei der Geräteerkennung stören. Empfehlung: Homebrew-Version entfernen (`brew uninstall android-platform-tools`).
- Dein iPhone und iPad sind sichtbar, aber nicht verbunden: Developer Mode ist aus bzw. die Geräte waren gesperrt. Für Tests auf echter Hardware (Pflicht laut Definition of Done) muss der Developer Mode aktiviert werden.

### 1.3 Blender und Blender MCP

| Prüfpunkt (Brief 9.1) | Ergebnis |
|---|---|
| Blender installiert | ✅ ja |
| Blender-Version | ✅ 5.3.0 |
| Blender MCP installiert | ✅ ja (vom Nutzer am 18.11.2026 nachinstalliert, MCP-Server „Blender“) |
| Verbindung zu Claude Code | ✅ ja, getestet: Szenenübersicht gelesen, Python-Code in der laufenden Blender-Instanz ausgeführt, Fenster-Screenshot abgerufen |
| Szenen erstellen | ✅ ja, sowohl über MCP als auch headless über `Blender -b --python skript.py` |
| Renderings exportieren | ✅ ja, headless: Testrender (orthografische Kamera, transparenter Hintergrund) mit Eevee in 2,3 s als PNG; über MCP: Vorschau-Render erfolgreich |

**Einschränkung:** Das MCP-Werkzeug für Vorschau-Renders ignoriert den angegebenen Zielpfad und schreibt in ein temporäres Verzeichnis. Für die Asset-Ausgabe werden die Pfade deshalb im Render-Skript selbst gesetzt.

**Konsequenz:** Es gibt zwei Wege, die sich ergänzen. Blender MCP dient dem interaktiven Gestalten und der visuellen Kontrolle in der geöffneten Blender-Oberfläche. Versionierte Python-Skripte erzeugen die endgültigen Assets reproduzierbar (siehe Abschnitt 4).

### 1.4 Paketlage (pub.dev, Stand heute)

Alle Versionen sind mit Flutter 3.47.9 / Dart 3.13.7 kompatibel (laut `environment`-Angaben der Pakete).

| Zweck | Paket | Version | Einsatz |
|---|---|---|---|
| Game Engine | `flame` | 1.38.2 | Kern ab Phase 1 |
| Physik | `flame_forge2d` | 0.20.0 | voraussichtlich **nicht** nötig, siehe 3.6 |
| Echtzeit-3D (Option D) | `flutter_scene` | 0.24.3 | nur Vergleichs-Spike |
| Echtzeit-3D (Option D) | `flame_3d` | 0.3.2 | nur Vergleichs-Spike, Version 0.x = experimentell |
| Audio | `flutter_soloud` 5.3.0 / `flame_audio` 2.12.2 | – | Phase 4, Auswahl dort |
| Speicherung | `shared_preferences` 2.5.6 / `hive_ce` 2.23.3 | – | Phase 2 |
| Werbung | `google_mobile_ads` | 9.2.0 | Phase 6 |
| Käufe | `in_app_purchase` | 3.3.1 | Phase 6 |
| Haptik | `haptic_feedback` | 0.9.0 | Phase 4, alternativ `HapticFeedback` aus dem Flutter SDK |

### 1.5 Verfügbare Werkzeuge in dieser Arbeitsumgebung

- Shell, Dateisystem, Git: voll nutzbar
- Blender headless über Skripte: nutzbar
- iOS-Simulator: steuerbar (Screenshots, Tippen) → visuelle Selbstkontrolle der App möglich
- Browser: nutzbar (Flutter-Web als schneller Vorschaukanal)
- Blender MCP: verfügbar und getestet (siehe 1.3)

---

## 2. Architekturvorschlag (Kurzfassung)

Details: `docs/TECHNICAL_ARCHITECTURE.md`.

- **Flutter + Flame** als Grundlage. Flame übernimmt Game Loop, Rendering und Eingabe. Flutter-Widgets übernehmen Menüs, HUD und Overlays.
- **Reine Dart-Spiellogik ohne Flame-Abhängigkeit** (`lib/game/core/`): Raster, Bausteine, Platzierungsregeln, Rotation, Punkte und Zustandsautomat. Damit ist die Logik vollständig per Unit-Test prüfbar und deterministisch.
- **Eine zentrale Projektionsklasse** `IsoProjection`: wandelt Weltkoordinaten (x, y, z) und den aktuellen Plattformwinkel θ in Bildschirmkoordinaten und Tiefenwerte um. Sie ist die einzige Stelle mit Projektionsmathematik.
- **Darstellung (Entscheidung nach Spike, siehe 5):** Favorit ist die Komposition aus in Blender gerenderten Einheitswürfel- und Plattform-Sprites in feinen Winkelschritten.
- **Keine Forge2D-Physik für das Kernspiel.** Fallen, Federn und Impuls auf Nachbarn werden als deterministische Animationen (Kurven/Federmodell) umgesetzt. Begründung: Der Brief verlangt „keine zufälligen Einstürze“. Platzierung ist rasterbasiert. Eine echte 2D-Physik passt außerdem nicht zu einer 3D-Szene in isometrischer Ansicht.
- **Dienste hinter Schnittstellen** (Speicherung, Werbung, Käufe, Analytics, Audio), jeweils mit einer No-op-Implementierung. Damit läuft das Spiel offline und ohne Einwilligung vollständig.
- **State-Management:** schlank. Spielzustand im Flame-Game plus `ValueNotifier`/`ChangeNotifier` für die UI. Riverpod nur, falls der Meta-Bereich (Shop, Aufgaben) es später rechtfertigt.

---

## 3. Technische Risiken

| # | Risiko | Wahrscheinlichkeit / Auswirkung | Gegenmaßnahme |
|---|---|---|---|
| R1 | **Plattformrotation wirkt mit Sprites flach oder ruckelig** (Kernrisiko laut Brief 3.5) | mittel / hoch | Blender-Referenzanimation als Zielbild, Vergleichs-Spike von zwei Darstellungsarten, Entscheidung nach Augenschein im Simulator (Abschnitt 5) |
| R2 | **Tiefensortierung** bei Zwischenwinkeln, schwebendem Vorschaubaustein und Fallanimation fehlerhaft (Überlappungsartefakte) | mittel / hoch | Sortierung nach projizierter Tiefe pro Einheitswürfel (gleich große Würfel im Raster → Painter-Algorithmus korrekt); gezielte Tests für Grenzfälle |
| R3 | **Kontaktschatten/Ambient Occlusion fehlen** bei einzeln gerenderten Würfeln → wirkt billig | hoch / mittel | Schatten und AO programmatisch als weiche Overlays ergänzen; Bewertung gegen Blender-Referenz |
| R4 | **Kernregeln machen keinen Spaß** (zu leicht, zu schnell vorbei oder Rotation strategisch bedeutungslos) | mittel / sehr hoch | Regelwerk früh spielbar machen (Phase 1/2), Parameter zentral konfigurierbar, mehrere Varianten testen (siehe `GAME_DESIGN.md`) |
| R5 | **Hohe Türme:** Kamera-/Zoomführung, Lesbarkeit und Performance bei vielen Würfeln | mittel / mittel | Kamera folgt der Bauhöhe; verdeckte Würfel nicht zeichnen; Sprite-Batching (`drawAtlas`); Stresstest mit 1.000 Würfeln |
| R6 | **Speicherbedarf der Sprite-Atlanten** (Farben × Winkel × Auflösung) | niedrig / mittel | Einheitswürfel statt ganzer Formen rendern; ein Atlas pro Theme; Winkelschritte und Auflösung messen und begrenzen |
| R7 | **Echtzeit-3D-Pakete experimentell** (`flame_3d` 0.x, `flutter_scene` benötigt Flutter GPU/Impeller) | hoch / mittel | nur als Vergleichs-Spike; keine Abhängigkeit des Kernspiels davon; Android-Unterstützung ungeprüft |
| R8 | **Blender MCP und Skripte laufen auseinander** (Änderungen nur interaktiv gemacht, nicht im Skript) | mittel / mittel | Regel: Jede per MCP gefundene Einstellung wird ins Skript übernommen; Assets nur per Skript exportieren |
| R9 | **Werbung/Consent (DSGVO, UMP, ATT)** fehlerhaft → Store-Ablehnung oder Rechtsrisiko | mittel / hoch | erst Phase 6; nur Test-IDs; Consent-Flow vor jeder Ad-Initialisierung; Spiel ohne Consent voll spielbar |
| R10 | **Geräte-Tests** nicht möglich (Developer Mode aus, Android-Lizenzen) | sicher / mittel | Simulator für Phase 1–2; Geräte bis Phase 4 einrichten (deine Aufgabe, siehe 6.3) |
| R11 | **Name „FLIPSTACK“** markenrechtlich oder im Store belegt | unbekannt / mittel | vor Phase 7 prüfen; Name nur an einer Konstante im Code verankern |
| R12 | **Audio:** Es steht kein Werkzeug zur Klangerzeugung bereit | sicher / mittel | Synthese per Skript (z. B. Python/NumPy) oder lizenzfreie Bibliotheken mit sauberer Lizenzdokumentation; Entscheidung in Phase 4 |

---

## 4. Plan für den Blender-Workflow

### 4.1 Grundsatz

Alle Assets entstehen **aus Code**. Blender-Szenen werden von versionierten Python-Skripten aufgebaut und gerendert. Ein einziger Befehl erzeugt alle Sprites neu, wenn Kamera, Licht oder Material sich ändern. Damit ist die Konsistenz gesichert, die der Brief verlangt („Kamera darf nicht zwischen Assets verändert werden“).

```
tools/blender/
  flipstack_scene.py     # baut die zentrale Szene: Kamera, Licht, Materialien, Collections
  build_assets.py        # modelliert Einheitswürfel, Plattform, Hintergrundobjekte
  render_sprites.py      # rendert alle Winkelschritte und Varianten → PNG-Atlanten
  render_reference.py    # rendert die Referenzanimation der Rotation (MP4/PNG-Sequenz)
  config.json            # Winkelschritte, Auflösung, Farbpalette, Kameraparameter
assets/blender/flipstack.blend   # zentrales Projekt, wird vom Skript erzeugt/aktualisiert
```

Aufruf: `/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/render_sprites.py`

### 4.2 Szenenstandard

- **Kamera:** orthografisch, echte Isometrie (Neigung 54,736°, Azimut 45°). Die Parameter liegen einmalig in `config.json`, und die Flutter-Projektion liest dieselben Werte.
- **Licht:** Hauptlicht (Area, groß, weich) von links oben, schwaches Fülllicht, Umgebungslicht über eine neutrale Welt. **Das Licht ist an die Kamera gebunden, nicht an die Plattform.** Nur so bleibt die Beleuchtung beim Drehen konsistent.
- **Materialien:** matt (Roughness ~0,6–0,7), leichte Farbverläufe über Ambient Occlusion und Höhe, Palette aus dem Brief (Navy, Cream, Mint, Coral, Amber) plus abgeleitete Töne.
- **Geometrie:** Einheitswürfel mit Bevel (ca. 6–8 % der Kantenlänge, 3 Segmente); Plattform mit sichtbarer Stärke, abgeschrägten Kanten, dezenten Rasterfugen und einer **asymmetrischen Ecken-Markierung** als Orientierungshilfe.
- **Renderer:** Eevee für Sprites (getestet, schnell); Cycles optional für Referenz- und Store-Renderings.
- **Collections:** `Camera_Light`, `Materials`, `Platform`, `Grid`, `Pieces`, `Background`, `Particles_Ref`, `Export`.

### 4.3 Visuelle Selbstkontrolle

Nach jeder Änderung rendert das Skript zusätzlich ein **Kontaktblatt**: alle Varianten in einem Bild sowie eine Testszene mit Plattform, Turm und drei Formen. Ich prüfe es selbst als Bild auf Perspektive, Kanten, Schatten, Farben und Lesbarkeit und bessere nach, bevor Assets ins Spiel übernommen werden.

### 4.4 Blender MCP im Ablauf

Blender MCP ist eingerichtet und getestet. Ablauf:

1. **Gestalten per MCP:** Szene in der offenen Blender-Oberfläche aufbauen und verändern, Screenshots und Vorschau-Renders sofort prüfen.
2. **Übernehmen ins Skript:** Gefundene Werte (Licht, Materialien, Bevel, Kamera) wandern in `tools/blender/` und `config.json`.
3. **Exportieren per Skript:** Die endgültigen Sprites erzeugt immer das Skript, damit jeder Export reproduzierbar ist.

Voraussetzung für den MCP-Weg: Blender muss geöffnet sein und das Addon verbunden.

---

## 5. Plan für die Plattformrotation

### 5.1 Logisches Modell (unabhängig von der Darstellung)

- Platzierte Würfel werden in **Plattformkoordinaten** gespeichert (x, y ∈ 0..N-1, z = Höhe). Eine Rotation verändert diese Daten **nie**. Damit ist Brief 3.4 („Rotation darf logische Positionen nicht verändern“) per Konstruktion erfüllt.
- Die Plattform hat eine Orientierung `r ∈ {0, 1, 2, 3}` (Vielfache von 90°).
- Der **Vorschaubaustein ist kamerafest**: Seine Form dreht sich nicht mit. Beim Ablegen wird seine Bildschirm-Ausrichtung über `r` in Plattformkoordinaten umgerechnet. Dadurch wird die Plattformrotation zum einzigen Mittel, die relative Ausrichtung eines Bausteins zu ändern, und das ist genau der strategische Kern des Spiels.
- Eingaben (Verschieben nach links/rechts/vorne/hinten) erfolgen in Bildschirmrichtung und werden über `r` auf die Rasterachsen abgebildet.
- Während der Animation lautet der Zustand `rotating`. Platzieren und weitere Eingaben sind gesperrt. Eine zweite Drehung wird höchstens als eine Eingabe gepuffert.

### 5.2 Vier Darstellungsoptionen (Brief 3.5)

| Option | Idee | Erwartete Qualität | Aufwand / Risiko |
|---|---|---|---|
| **A** Blender-Rotationsanimation als Ganzes | ganze Szene je Turm-Zustand vorrendern | sehr hoch | **nicht machbar**: Der Turm entsteht erst zur Laufzeit |
| **B** Nur 4 Ansichten | Sprites für 0/90/180/270°, dazwischen Überblendung oder Skalierung | gut im Stand, **schwach in der Bewegung** (kein räumliches Drehen) | gering; erfüllt die Qualitätsforderung voraussichtlich nicht |
| **C1** **Sprite-Komposition in Winkelschritten** | Einheitswürfel (je Farbe/Material) in z. B. 3°-Schritten über 0–90° rendern (wegen Würfelsymmetrie genügen 90°), Plattform in 3°-Schritten über 360°; zur Laufzeit jede Würfelposition mit `IsoProjection(θ)` setzen, nach Tiefe sortieren, passendes Winkel-Sprite zeichnen | **hoch**: echte Blender-Materialien und -Beleuchtung bei jedem Winkel, Licht bleibt korrekt kamerafest | mittel; Risiken R2, R3, R6 |
| **C2** Prozedurales 3D im Canvas | Würfel und Plattform als 3D-Polygone mit Fasen projizieren und flach schattieren | mittel bis gut; exakt, sehr leicht, aber ohne echte Material- und AO-Qualität | mittel; Gefahr „Entwicklergrafik“ |
| **D** Echtzeit-3D | `flutter_scene` oder `flame_3d` mit glTF-Modellen aus Blender | potenziell sehr hoch (echte Schatten) | **hoch**: experimentelle Pakete, Plattformunterstützung ungeprüft |

### 5.3 Vorgehen zur Entscheidung (Beginn von Phase 1)

1. **Blender-Referenz:** Plattform 5×5 mit kleinem Turm, Drehung um 90° in 300 ms, sauber gerendert. Das ist das **Zielbild**.
2. **Spike C1** im Flutter-Prototyp: Würfel- und Plattform-Sprites aus derselben Szene, Rotation über `IsoProjection(θ)`.
3. **Kurzer Spike D**, zeitlich begrenzt: Prüfen, ob `flutter_scene` auf iOS-Simulator und Android-Emulator überhaupt sauber läuft und Schatten liefert.
4. **Vergleich** per Video/Screenshots im Simulator gegen die Referenz: räumliche Wirkung, Konsistenz der Beleuchtung, Flüssigkeit, Frame-Zeit.
5. **Entscheidung dokumentieren** in `TECHNICAL_ARCHITECTURE.md`.

**Meine Erwartung:** C1 wird gewinnen. Es liefert Blender-Qualität bei jedem Winkel, läuft bei wenigen hundert Sprites problemlos mit 60 FPS und hat keine Abhängigkeit von experimentellen Paketen. Schatten zwischen Würfeln (R3) werden als weiche Overlays ergänzt. D bleibt die Ausweichlösung, falls C1 die Referenz sichtbar verfehlt.

### 5.4 Animationsdetails

- Dauer ca. 300 ms, Kurve `easeInOutCubic` mit minimalem Nachschwingen (≤ 2°).
- Eine 90°-Drehung in 300 ms umfasst 18 Frames bei 60 Hz (ca. 5° pro Frame) bzw. 36 Frames bei 120 Hz (ca. 2,5°). 3°-Sprite-Schritte sind daher auch auf 120-Hz-Displays fein genug. Positionen werden kontinuierlich berechnet, nur die Würfelschattierung wechselt in 3°-Stufen (praktisch unsichtbar). Die Schrittweite wird im Spike validiert.
- Die Ecken-Markierung der Plattform und ein kurzer Schatten-Schwenk machen die Drehrichtung eindeutig lesbar.

---

## 6. Entwicklungsplan

### 6.1 Phasen und Meilensteine

| Phase | Inhalt | Abnahmekriterium |
|---|---|---|
| **0** Analyse | dieses Dokument, Architektur, Spielregel-Entwurf | ✅ abgeschlossen mit diesem Stand |
| **1a** Rotations-Spike | Blender-Referenz, Spike C1 (+ kurz D), Entscheidung | Vergleichsvideo, dokumentierte Entscheidung |
| **1b** Prototyp | Flutter-Projekt, 5×5-Plattform, 3–4 Bausteinformen, Verschieben, Ablegen mit Fallanimation, Drehen, einfacher Punktestand | spielbar im iOS-Simulator, Screenshot/Video, Unit-Tests für Raster/Projektion/Rotation grün |
| **2** Kernspiel | alle Formen, endgültige Regeln, Game-over, Highscore lokal, Neustart, kontrollierte Aufprall-Effekte, Kamera für hohe Türme | vollständiger Endless Mode spielbar, Tests laut Brief 14 Punkte 1–6 und 10 |
| **3** Visuelle Produktion | Blender-Projekt final, Materialbibliothek, Plattform-Feinschliff, 2–3 Hintergründe, Partikel | Kontaktblätter, Vorher/Nachher-Screenshots |
| **4** UI und Spielgefühl | Hauptmenü, HUD, Ergebnisbildschirm, Tutorial (≤ 45 s), Audio, Haptik | Tests auf echtem iPhone und Android-Gerät |
| **5** Belohnungen | Coins, Tages-/Wochenaufgaben, Achievements, Kosmetik-Freischaltungen, Shop (ohne Echtgeld) | alles offline funktionsfähig, Tests |
| **6** Monetarisierung | Consent (UMP/ATT), Rewarded und Interstitial mit Test-IDs, werbefreier Kauf (Sandbox) | Frequenzregeln getestet, Spiel ohne Consent voll spielbar |
| **7** Release | Performance, Icon, Store-Texte und -Screenshots, Datenschutz, Release-Builds | Definition of Done (Brief 18) erfüllt |

Phase 1 wird bewusst in den **Rotations-Spike (1a)** und den **spielbaren Prototyp (1b)** geteilt, weil die Rotation das größte Qualitätsrisiko ist und alle späteren Asset-Entscheidungen davon abhängen.

### 6.2 Arbeitsweise je Phase

Implementieren → `flutter analyze` und `flutter test` → App im Simulator starten → Screenshots prüfen → Mängel beheben → Eintrag in `docs/DEVELOPMENT_LOG.md`.

### 6.3 Was ich von dir brauche (nicht sofort, aber vor den genannten Phasen)

| Wann | Was |
|---|---|
| bei Blender-Arbeit | Blender geöffnet lassen, MCP-Addon verbunden |
| vor Phase 4 | Developer Mode auf iPhone aktivieren; Android-Lizenzen akzeptieren (`flutter doctor --android-licenses`) |
| vor Phase 6 | Google-AdMob-Konto, Apple-Developer- und Google-Play-Console-Konto |
| vor Phase 7 | Marken-/Namensprüfung „FLIPSTACK“, Impressum-/Datenschutzangaben, Preise |
