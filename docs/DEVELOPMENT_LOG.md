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

## Abbruch beim Gerätetest und Audio-Player (19.11.2026)

- Meldung vom Gerätetest: Bild friert bei Höhe 18 mitten in einer Drehung ein, Konsole zeigt „Could not acquire current drawable“ und „Lost connection to device“.
- Befund: Auf dem iPhone liegt für diesen Zeitpunkt weder ein Absturzbericht der App noch ein Speicherbericht (Jetsam) vor, und die Konsole zeigt keinen Dart-Fehler. Die App lief im Debug-Modus über eine kabellose Verbindung; ein Debug-Build läuft auf iOS nur, solange die Verbindung zum Mac steht. Wahrscheinlichste Ursache ist deshalb die abgerissene Verbindung, nicht das Spiel. Bewiesen ist das nicht.
- Beim Suchen gefunden und behoben: Jeder Ton erzeugte über `FlameAudio.play` einen neuen Audio-Player, der nie freigegeben wurde. Jetzt gibt es je Klang eine feste Zahl vorbereiteter Player (insgesamt 25), die reihum verwendet werden.
- Geprüft im Simulator mit `--dart-define=FS_AUDIO_STRESS=n` (spielt n Klänge beim Start): Klänge werden zu Ende gespielt, kein Fehler im Protokoll. Der Speicherverlauf unterscheidet sich im Simulator nicht messbar von vorher.
- Nicht geprüft: Ton auf dem Gerät mit der neuen Lösung, eine lange Runde im Release-Build.

## Paket 1: Münze und Oberfläche (19.11.2026)

- Münze als Blender-Sprite, überall statt der flachen Scheibe.
- Shop neu: Tafel mit Reitern, Anprobe am Beispielturm, ein Aktionsknopf. Kauf weiter mit Rückfrage.
- Aufgabenblatt in drei Karten mit „neu in …“; Erfolge zeigen die drei nächsten, der Rest ist eingeklappt.
- Hauptmenü: Aufgaben-Knopf zeigt erledigte Tagesaufgaben, Shop-Knopf einen Punkt, wenn etwas bezahlbar ist.
- Ergebnis: niedrigere Karte, Münzen zählen hoch, höchstens zwei Zeilen für Erfülltes, Hauptmenü als runder Knopf neben „Nochmal“.
- Geprüft im iOS-Simulator: Hauptmenü, alle Zustände der Shop-Karten (ausgewählt, im Besitz, Preis), Anprobe von Plattform und Hintergrund, Kauf, Aufgabenblatt, Ergebnis. 70 Tests, Analyse ohne Befund.
- Nicht geprüft: Reiter „Blöcke“ und „Effekte“ im neuen Shop, „Alle zeigen“ bei den Erfolgen, kleine Displays, Android (dort fehlt noch das Schließen des Shops über die Zurück-Taste).

## Paket 2: Block-Materialien und Splitter (19.11.2026)

- Neue Kategorie „Material“ mit Kiesel, Planke, Facette und Eis; kombinierbar mit jeder Farbpalette. Im Shop stehen Material und Farben im Reiter „Blöcke“ untereinander.
- Effekt „Splitter“: kleine Dreiecke in der Farbe des abgelegten Bausteins.
- Testschalter `--dart-define=FS_LOOK=mat_ice,blocks_arctic` zeigt Freischaltungen ohne Kauf.
- Abweichung vom Vorschlag: Planke hat eine Nut statt drei, Eis nur einen schwachen Glanzstreifen. Beides war am hohen Turm sonst zu unruhig. Die Oberseite der Planke trägt eine Kassette statt Längsnuten, weil die Form drehsymmetrisch sein muss.
- Geprüft im iOS-Simulator: alle vier Materialien an einem Turm der Höhe 13, Eis zusätzlich mit Arctic und Mist, Anprobe und Karten im Shop. 70 Tests, Analyse ohne Befund.
- Nicht geprüft: Splitter im Spiel gesehen (nur gebaut), Materialien während der Drehung im Bewegtbild, Leistung auf dem Gerät mit der zweiten Bildebene bei Eis, Kauf eines Materials bis zum Neustart.

## Fugenfüllung bei Kiesel und Facette (19.11.2026)

- Meldung vom Gerätetest: Um Kiesel- und Facetten-Würfel stand ein Rand im abgedunkelten Eigenton, der die Form verdeckte.
- Ursache: Die Fugenfüllung zeichnete immer die Silhouette des vollen Würfels. Bei stark gebrochenen Kanten ragt sie darüber hinaus.
- Erster Versuch (verworfen): die Silhouette an Kanten mit Nachbar voll lassen. Die gemeinsame Hülle zog dunkle Keile quer über die Würfel und sah schlechter aus als vorher.
- Lösung: Unter Kiesel und Facette liegt nur noch der Würfel mit zurückgenommenen Kanten, vollständig hinter dem Sprite. Zusätzlich gibt es je anliegendem Nachbarn eine flache Scheibe an der gemeinsamen Fläche, die nur dort bis zur vollen Kante reicht, wo auch quer dazu ein Nachbar anliegt. Sie füllt die Lücke, an der mehrere Würfel zusammenstoßen. Matt, Planke und Eis sind unverändert.
- Geprüft im Simulator: Kiesel in vier Spielständen bis Höhe 3, Facette in einem. Nicht geprüft: während der Drehung, hohe Türme, auf dem Gerät.
- Bekannt: Die Schatten auf den Oberseiten sind weiter eckig und passen nicht ganz zur gerundeten Fläche.

## Material „Noppe“ (19.11.2026)

- Auf Wunsch: Klemmbaustein mit runder Noppe oben, teuerstes Stück (1800). Eigene, generische Form ohne Marke oder Schriftzug.
- Die Noppe bleibt innerhalb der Würfel-Silhouette, der Würfel darüber verdeckt sie. Fugenfüllung wie beim Standardwürfel.
- Geprüft im Simulator: ein Spielstand bis Höhe 2. Nicht geprüft: Drehung, hohe Türme, Gerät.

## Paket 3: Plattformen (19.11.2026)

- Vier neue Plattformen mit eigener Form: Eiche, Marmor, Gletscher, Insel. Der Shop zeigt alle Plattformen als Rendering.
- Sprite-Sätze werden beim Wechsel geladen und der vorherige freigegeben; die Bildmitte je Plattform steht in `assets/sprites/platforms.json`.
- Abweichung vom Vorschlag: Gletscher und Insel laufen nicht spitz zu. Eine Spitze ist aus der Spielkamera nicht zu sehen (erste Fassung: Unterseite komplett verdeckt), deshalb gestufte Stümpfe.
- Größe: `assets/sprites` wächst von 9 auf 32 MB.
- Geprüft im iOS-Simulator: alle vier im Spiel bei ruhender Plattform mit Würfeln, Karten im Shop, Anprobe der Insel. 70 Tests, Analyse ohne Befund.
- Nicht geprüft: Drehung im Bewegtbild, Ladezeit und Speicher auf dem Gerät, Lesbarkeit von Schatten und markierten Feldern auf den hellen Plattformen (Marmor, Gletscher) bei hohem Turm, Insel und Gletscher hinter den Bedienknöpfen bei Rundenbeginn.

## Paket 4: Hintergründe (19.11.2026)

- Vier neue Hintergründe mit gerenderter Szenerie: Wald, Herbst, Winter, Weltraum. Der Shop zeigt sie als Bild, die Anprobe legt die Szenerie über die Shop-Tafel.
- Helles Schriftschema für den dunklen Weltraum (Schrift, Drehknöpfe, Combo-Anzeige, Einblendungen, Statusleiste).
- Erste Fassung der Szenerien war im Querformat gerendert; im Hochformat lagen die Bäume fast ganz hinter den Knöpfen. Neu gerendert mit höherem Ausschnitt.
- Größe: `assets/backgrounds` rund 2 MB. Im Speicher liegt nur die gewählte Szenerie (etwa 5,5 MB).
- Geprüft im iOS-Simulator: alle vier im Spiel bei Höhe 1, Hauptmenü mit Weltraum, Shop-Karten, Anprobe des Waldes. 70 Tests, Analyse ohne Befund.
- Nicht geprüft: Weltraum im Spiel nach der Korrektur von Drehknöpfen und Combo-Anzeige, Tutorial, Pause und Hinweise auf dunklem Hintergrund, hohe Türme vor den Szenerien, andere Seitenverhältnisse, Leistung der Teilchen auf dem Gerät.
- Bekannt: Die Schiefer-Plattform hebt sich vom Weltraum nur schwach ab.

## Sieben weitere Stücke auf Wunsch (19.11.2026)

- Materialien: Beton, Stoff, Vulkan, Neonglas. Welten: Unterwasser, Neonstadt (dunkel). Plattform: Futuristisch.
- Vulkan und Neonglas nutzen die Einfärbung umgekehrt: Der Körper ist im Atlas dunkel, Risse und Kanten sind hell und tragen die Blockfarbe.
- Vulkan nach dem ersten Blick am Turm vereinfacht: Stein heller, ein Riss je Seite weniger. Vorher waren die Farben kaum zu unterscheiden.
- Geprüft im iOS-Simulator: alle vier Materialien an einem Turm der Höhe 6, beide Welten, die Plattform im Hauptmenü. 70 Tests, Analyse ohne Befund.
- Nicht geprüft: Drehung, hohe Türme mit Vulkan und Stoff, Shop-Karten der neuen Stücke, Leistung auf dem Gerät, Farbsehschwäche bei Vulkan und Neonglas.

## Preise, Sortierung und vier Farbpaletten (20.11.2026)

- Shop zeigt jede Kategorie vom günstigsten zum teuersten (`Cosmetics.of`), per Test abgesichert.
- Preise neu gestaffelt nach Aufwand: Umfärbungen 250–600, eigene Formen und Szenerien 700–1300, Spitzenstücke 1400–1800. Vorgaben: Kiesel und Facette 700, Planke und Beton 800.
- Vier vorgegebene Farbpaletten: Sunset, Lagoon, Lavender, Volcano. Sie bleiben je in einer Farbfamilie; in Sunset liegen sechs Farbpaare, in Lavender zwei und in Lagoon eines unter dem Abstand 45, den die eigenen Paletten einhalten. Der Test verlangt für sie nur 25.
- Geprüft im Simulator: alle vier Paletten an einem Turm der Höhe 6. Nicht geprüft: Shop-Reihenfolge am Bildschirm, Gerät.

## Rand beim Aufprall und Stoff ohne Rand (20.11.2026)

- Meldung: Bei Materialien mit Rand (Matt, Planke, Eis und weitere) verschwand der Rand kurz, wenn ein Stein landete. Ursache: Gestauchte Würfel wurden ohne Fugenfüllung gezeichnet. Jetzt wird die Füllung mit derselben Stauchung gezeichnet wie der Würfel.
- Stoff nutzt auf Wunsch die Fugenfüllung von Kiesel und Facette (kein Rand an freien Kanten).
- Geprüft im Simulator: Video eines Aufpralls mit dem Standardwürfel, Bild für Bild; der Rand bleibt durchgehend sichtbar. Nicht geprüft: andere Materialien, Gerät.

## Phase 6, Teil 6a: Werberegeln und belohnte Angebote (20.11.2026)

- Plan und Aufteilung in `docs/PHASE_6_MONETARISIERUNG.md`.
- `AdPolicy` (Regeln für Vollbildwerbung), `AdsService` mit `NoAds` und `FakeAds`, zweite Chance (`GameSession.revive`), Münzen verdoppeln.
- Ohne Schalter ändert sich für Spieler nichts: Es ist kein Werbe-SDK eingebunden, die Angebote erscheinen nicht.
- Geprüft im iOS-Simulator mit `FS_ADS=fake`: Angebote im Ergebnis, Verdopplung, zweite Chance mit fortgesetzter Runde. 80 Tests, Analyse ohne Befund.
- Nicht geprüft: Vollbild-Platzhalter zwischen Runden im Simulator (nur per Test), Verdopplung gefolgt von zweiter Chance, Abbruch der Testwerbung.

## Phase 6, Teil 6b: Google-Werbe-SDK und Einwilligung (20.11.2026)

- `google_mobile_ads` 9.2.0 und `url_launcher` 6.3.3 eingebunden. `AdMobAds` lädt je eine belohnte und eine Vollbildanzeige vor, `ConsentManager` fragt die Einwilligung über Googles User Messaging Platform ab.
- Alle Builds nutzen Googles Testanzeigen; echte Anzeigenblöcke nur mit `FS_ADS=live`.
- Kennung der App auf `com.floebn.flipstack` umgestellt (iOS und Android).
- **Befund:** In AdMob ist noch keine Einwilligungsabfrage veröffentlicht. Der Abruf schlägt fehl (Fehler 4, „no form(s) configured“), und `canRequestAds` lieferte trotzdem `true`. Die App hätte Werbung ohne Abfrage geladen. Korrigiert: Ein fehlgeschlagener Abruf gilt als „nicht erlaubt“.
- Geprüft im iOS-Simulator: ohne Abfrage in AdMob keine Werbung (Protokoll). Mit `FS_SKIP_CONSENT` im Debug-Build: belohnte Testanzeige von Google läuft, Belohnung wird nach dem Schließen gutgeschrieben, nächste Anzeige ist vorgeladen. 80 Tests, Analyse ohne Befund.
- Nicht geprüft: die Einwilligungsabfrage selbst und Apples Tracking-Dialog (beides braucht die Mitteilungen in AdMob), Vollbildanzeige zwischen Runden mit echtem SDK, vorzeitig geschlossene belohnte Anzeige, Ton nach einer Anzeige, das neue Einstellungsblatt am Bildschirm, echtes Gerät, Android-Build.

## Einwilligung im Simulator geprüft (20.11.2026)

- Nach Veröffentlichung der beiden Mitteilungen in AdMob: DSGVO-Abfrage erscheint beim Start auf Deutsch, danach Apples Tracking-Dialog mit dem Text aus dem Projekt, danach startet das Werbe-SDK und lädt beide Anzeigen. Der Eintrag „Datenschutz-Einstellungen“ erscheint und öffnet die Abfrage erneut.
- Anzeigename der App auf „FlipStack“ korrigiert (vorher „Flipstack“, sichtbar in beiden Dialogen).
- Offen: Die Abfrage zeigt das Standard-Symbol von Flutter, weil die App noch kein eigenes Symbol hat (Phase 7). Nicht geprüft: Ablehnen über „Optionen verwalten“ und was Google danach ausliefert, echtes Gerät.

## Phase 6, Teil 6c: Kauf „Werbefrei“ (20.11.2026)

- `in_app_purchase` 3.3.1 eingebunden. `PurchaseService` mit `StorePurchases`, `FakePurchases`, `NoPurchases`; Kaufblatt mit Preis aus dem Store und „Käufe wiederherstellen“.
- Nach dem Kauf zeigt `AdPolicy` keine Vollbildwerbung mehr; belohnte Angebote bleiben. Diese Entscheidung habe ich so getroffen, weil sie offen war; sie steht im Kaufblatt und lässt sich ändern.
- Geprüft im iOS-Simulator: mit `FS_IAP=fake` Eintrag in den Einstellungen, Kaufblatt, Testkauf mit Rückmeldung. Mit echtem Store: Produkt wird nicht gefunden (bei Apple noch nicht angelegt), die App meldet es im Protokoll und zeigt „Derzeit nicht verfügbar“. 83 Tests, Analyse ohne Befund.
- Nicht geprüft: echter Kauf, Abbruch, ausstehender Kauf, Wiederherstellen nach Neuinstallation, Link „Werbung entfernen“ im Ergebnis am Bildschirm. Das geht erst mit angelegtem Produkt und Sandbox-Konto auf einem echten Gerät.

## Werberegeln überarbeitet, Einstellungen und Ergebnis neu gestaltet (20.11.2026)

- Vollbildwerbung: erste nach 3 Runden, danach jede 2. Runde mit mindestens 4 Minuten Abstand; frühestens 60 s nach dem Öffnen. Zählerstand wird gespeichert und übersteht Neustarts.
- Einstellungen in Karten: hervorgehobene Karte „Werbefrei“ mit Preis, Spiel, Statistik als Kacheln, Rechtliches.
- Ergebnis: Etikett (Neuer Bestwert / Runde beendet), große hochzählende Punktzahl, Kennzahlen als Kacheln, auffällige Angebote gegen Werbung (Weiterspielen in Bernstein mit Puls, Münzen in Navy, je mit Schild „Werbung“), Aktionen unten fest.
- Geprüft im iOS-Simulator: drei Runden gespielt, nach der dritten erscheint Googles Vollbild-Testanzeige beim Tippen auf „Nochmal“; neues Ergebnis und neue Einstellungen angesehen. 84 Tests, Analyse ohne Befund.
- Nicht geprüft: Neustart der App zwischen den Runden am Gerät (nur per Test), „jede 2. Runde“ und der Abstand am Gerät, Ergebnis auf kleinen Displays, Zustand „gekauft“ in den Einstellungen.

## Schwierigkeitskurve über Höhe 30 hinaus (21.11.2026)

- Anlass: Runden wurden zu lang, Höhe 60 war für den Auftraggeber die Regel. Ursache: Ab Höhe 30 stieg die Schwierigkeit nicht mehr.
- `DifficultyCurve`: Fünfer ab 15 und 25, Einzelwürfel weg ab 30, Doppelblock weg ab 35, Fünfer doppelt ab 40, danach bis 60 alle 5 Ebenen ein einfacher Stein weniger. Fünf Varianten simuliert, Zahlen in `GAME_DESIGN.md` Abschnitt 1a.
- Ansage für Änderungen zwischen den Etappen („Höhe 15 · …“), Rahmen in Coral auf der bisherigen Rekordhöhe, Ansage „Neue Rekordhöhe“.
- Geprüft: 86 Tests (Kurve, Ansagen, Spielbarkeit mit kleinstem Beutel), Analyse ohne Befund, Simulation.
- Nicht geprüft: Ansage bei Höhe 15 und Rekordrahmen am Bildschirm (im Simulator-Lauf nicht erreicht), Spielgefühl ab Höhe 30 mit Menschen.

## Kurve entschärft: ab 60 keine Verschärfung mehr (21.11.2026)

- Auf Wunsch: Höhe 60 soll ab und zu erreichbar sein, und danach soll nichts mehr schwerer werden. Neu: Fünfer doppelt erst ab 45, Ecke weg ab 55, danach nichts (`DifficultyCurve.maxLateDrops = 1`).
- Simulation (Planer, 150 Runden): Endhöhe 30 / 48 / 63, Höhe 60 in 15 %, Höhe 80 in 1 %, höchste Runde 86.
- 86 Tests, Analyse ohne Befund. Am Bildschirm nicht geprüft.

## Ebenen-Bonus, Auflage der Stufe, Runde fortsetzen (22.11.2026)

- **Fehler behoben:** Volle Ebenen wurden nur von unten lückenlos gezählt. Blieb unter einem Überhang ein Feld leer, gab es für alle Ebenen darüber nie wieder den Bonus (gemeldet bei Höhe 50). Jetzt zählt jede Ebene einmal, sobald sie voll ist.
- **Regel geändert:** Die Auflage zählt Würfel statt Felder. Die Stufe konnte mit dem einzelnen Würfel aufliegen, während die Säule aus zwei Würfeln frei hing. Das war regelkonform, aber unlogisch. Flache Bausteine sind unverändert.
- **Runde fortsetzen:** Die Runde wird nach jedem Zug, bei Pause und beim Verlassen der App gespeichert. Das Hauptmenü zeigt dann „Runde fortsetzen“ mit Höhe und Punkten, darunter „Neue Runde“. Der Beutel mischt jetzt je Beutel aus (Startwert, Nummer), damit die Folge nach dem Fortsetzen dieselbe ist. Das Tutorial wird nicht gespeichert.
- Einstellungsblatt bleibt unter Statusleiste und Dynamic Island.
- Geprüft: 94 Tests. Im Simulator: Runde begonnen, App beendet, neu gestartet, fortgesetzt (Punkte, Turm und Steine stimmen).
- Nicht geprüft: Einstellungsblatt auf dem Gerät des Auftraggebers, Fortsetzen nach zweiter Chance und mit gedrehter Plattform am Bildschirm. Die Simulation der Schwierigkeit ist mit der geänderten Auflage und dem neuen Beutel nicht neu gelaufen.
