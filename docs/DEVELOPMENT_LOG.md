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

## 19.11.2026 – Phase 3: Visuelles Produktionssystem

**Umgesetzt:**
- Einfärbbare Würfel: ein graues Sprite für alle Farben (vorher vier Atlanten). Vergleich mit echt gerenderten Würfeln vorab durchgeführt
- Farbsystem mit 8 Blockfarben, feste Farbe je Bausteinform, Bedeutungsfarben der Oberfläche (`fs_colors.dart`)
- Plattform überarbeitet: zurückgesetzter Fuß, runder Eckpfosten als zweite Orientierungsmarke
- Tiefe: Verläufe in Innenecken und am Fuß von Seitenflächen, weicher Bodenschatten der Plattform
- Vier Hintergrund-Stimmungen, prozedural gezeichnet, wechseln je Runde
- Zentrales Blender-Projekt `assets_src/blender/flipstack.blend` mit Collections (Camera_Light, Platform, Grid, Pieces, Background, Particles_Ref, Export), Materialbibliothek und allen 13 Bausteinen; Übersichtsblatt wird mitgerendert
- Bausteinformen werden aus dem Dart-Code nach Blender exportiert (`tool/export_pieces.dart`)
- `docs/ART_GUIDELINES.md`

**Geprüft:**
- 41 Unit-Tests bestanden (neu: Palette und Formen in App und Blender stimmen überein), `flutter analyze` ohne Befund
- Autoplay-Lauf im iOS-Simulator bis zum Spielende, Bilder in `docs/img/phase3_spiel.png`
- Übersichtsblatt zweimal nachgebessert (Bausteine waren abgeschnitten bzw. überlappten)

**Abweichungen vom Brief / offen:**
- Hintergründe sind prozedural statt in Blender gerendert (Begründung in ART_GUIDELINES)
- Blender MCP wurde nicht verwendet; alles läuft über Skripte im Hintergrundmodus
- Keine dunklen Themen (Midnight, Neon), keine besonderen Blockmaterialien: Phase 5
- Echte Schlagschatten auf Seitenflächen fehlen weiterhin
- Sprites auf der Platte: 5,9 MB. Bildspeicher und Bildrate auf echten Geräten sind nicht gemessen
- Ob 8 Farben für Menschen mit Farbsehschwäche unterscheidbar sind, ist nicht geprüft

## 19.11.2026 – Phase 4: Oberfläche und Spielgefühl

**Umgesetzt:**
- Hauptmenü über einem Beispielturm, der sich dreht; Spielen, Bestwert, Einstellungen
- Interaktives Tutorial in vier Schritten (Verschieben, Ablegen, Drehen, Punkte), überspringbar, erscheint nur beim ersten Start
- Pause mit Weiter, Neu starten, Ton, Vibration, Menü; automatische Pause, wenn die App den Vordergrund verlässt
- Einstellungen mit Ton, Vibration, Tutorial und Statistik
- 20 Klänge per Synthese erzeugt (904 KB), Abspielen über `flame_audio`
- Ergebnis zeigt die Spielzeit und führt zurück ins Hauptmenü
- App-Zustände mit fester Übergangstabelle; Oberfläche in eigene Dateien aufgeteilt

**Geprüft:**
- 49 Unit-Tests bestanden, `flutter analyze` ohne Befund
- Im iOS-Simulator von Hand: Menü, Tutorial Schritt 1 bis 4, Pause und Fortsetzen, App-Wechsel (pausiert automatisch), zurück ins Menü, Einstellungen
- Simulator-Protokoll: Audio-Sitzung startet ohne Fehlermeldung

**Im Lauf gefunden und behoben:**
- Tutorial-Karte verdeckte den schwebenden Stein; liegt jetzt über den Knöpfen
- Dreh-Geräusch enthielt zu viel hohes Rauschen (im Spektrogramm sichtbar); stärker gefiltert

**Nicht geprüft / offen:**
- **Die Klänge habe ich nicht gehört.** Lautstärke, Klangfarbe und ob sie angenehm sind, kann nur ein Test am Gerät zeigen
- Vibration, echte Geräte, Android, andere Displaygrößen
- Keine eigene Schrift; es wird die Systemschrift verwendet
- Spielende-Regeln unverändert (Gipfel bei 30); die Umstellung auf Endlos ist besprochen, aber zurückgestellt
- Wird die App beendet, geht die laufende Runde verloren

## 19.11.2026 – Fehlerbehebung: kein Ton

**Befund des Nutzers:** Auf dem iPhone war kein Ton zu hören, die Vibration funktionierte.

**Ursache:** Die Audio-Konfiguration kombinierte „Stummschalter beachten“ mit „mit anderen Apps mischen“. Die Bibliothek `audioplayers` lehnt diese Kombination auf iOS ab und bricht ab. Der Fehler wurde im Code abgefangen und nicht gemeldet, daher blieb der Ton dauerhaft aus. Meine Aussage in Phase 4, die Audio-Sitzung starte ohne Fehler, war dadurch irreführend: Das Protokoll zeigte keinen Fehler, weil er verschluckt wurde.

**Behebung:**
- iOS nutzt jetzt ausdrücklich die Kategorie „ambient“ (beachtet den Stummschalter, lässt andere Musik laufen); Android spielt ohne Audiofokus
- Dieselbe Konfiguration wird bei jedem Abspielen mitgegeben, sonst setzt `flame_audio` eine eigene
- Audiofehler werden im Debug-Protokoll ausgegeben statt verschluckt

**Geprüft:** Im iOS-Simulator meldet das Protokoll „audio: bereit (20 Klänge)“; bei Tippen, Drehen und Ablegen keine Fehlermeldung. **Gehört habe ich weiterhin nichts**, der Nachweis am Gerät steht aus.

**Hinweis:** Ist das iPhone stummgeschaltet, bleibt das Spiel absichtlich still.

## Endlosspiel mit Etappen (19.11.2026, vor Phase 5)

- Obergrenze bei Höhe 30 entfernt. Etappen bei 10, 20, 30 … mit +500 und Ansage.
- Höhenunterschied 3 ab Höhe 10. Die Regel prüft jetzt nur den abgelegten Baustein gegen das tiefste Feld; bei gleichbleibendem Wert ist das dasselbe wie vorher.
- Vier Formen aus fünf Würfeln, je zwei ab Höhe 20 und 30.
- Neue Bots in `tool/balance_sim.dart` (Flächenbot, Planer). Unterschied 2 ab Höhe 30 simuliert und verworfen. Zahlen in `GAME_DESIGN.md`, Abschnitt 1a.
- Testschalter `--dart-define=FS_START_HEIGHT=n` startet mit n vollen Ebenen.
- Geprüft: 52 Tests, `flutter analyze` ohne Befund, im iOS-Simulator die Ansagen bei Etappe 10 und 20 und ein Spielende mit einem Fünfer.
- Nicht geprüft: Spielgefühl und Rundenlänge mit Menschen, Darstellung von U-Form und Kreuz im Spiel, die Blender-Übersicht der Bausteine (nicht neu gerendert).

## Phase 5 – Belohnungssystem (19.11.2026)

- Münzen, drei Tages- und drei Wochenaufgaben, zwölf Erfolge, Shop mit zehn kaufbaren Freischaltungen in vier Kategorien.
- Hauptmenü mit Kontostand, Aufgaben und Shop; Ergebnis mit Münzen, Erfülltem und Fortschritt zur nächsten Freischaltung.
- Testschalter `--dart-define=FS_COINS=n`: Testkonto mit n Münzen, wird nicht gespeichert.
- **Fehler gefunden und behoben:** Beim App-Start meldet das System „im Vordergrund“, bevor der Stand geladen ist. Das Erneuern der Aufgaben hat dann einen leeren Stand gespeichert und den vorhandenen überschrieben. Aufgefallen im Simulator (Testkonto zeigte 0 statt 3000 Münzen), jetzt per Test abgesichert.
- Geprüft: 70 Tests, `flutter analyze` ohne Befund. Im iOS-Simulator: Hauptmenü, Aufgabenblatt, Shop, Kauf mit Rückfrage, Wechsel von Blockfarben, Hintergrund und Plattform, Ergebnis mit Münzen und Aufgaben.
- Nicht geprüft: Konfetti-Effekt im Spiel, Plattform „Moos“, Paletten „Forest“ und „Candy“ im Spiel, Tages- und Wochenwechsel auf dem Gerät (nur per Test), Unterscheidbarkeit der Paletten bei Farbsehschwäche, Android.
- Bekannt: Auf dem Ergebnisbildschirm verdeckt die Karte jetzt mehr vom Turm.
