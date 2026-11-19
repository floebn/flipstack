# FLIPSTACK – Gestaltungsrichtlinien

Stand: Phase 3 · verbindlich für alle Spielobjekte und die Oberfläche

Übersicht aller Bausteine: `docs/img/phase3_bausteine.png` · Spielbild: `docs/img/phase3_spiel.png`

## 1. Stil

Modernes Low Poly mit Premium-Anmutung: klare Würfelformen mit weicher Fase, matte Oberflächen, weiches Licht von links oben, ruhiger heller Hintergrund. Keine Texturen, keine Umrisslinien, keine Glanzeffekte.

## 2. Farbsystem

Quelle im Code: `lib/shared/theme/fs_colors.dart`. Die Blender-Skripte lesen dieselben Werte aus `tools/blender/config.json`; ein Test stellt sicher, dass beide übereinstimmen.

### Grundfarben (aus dem Masterbrief)

| Name | Wert | Verwendung |
|---|---|---|
| Navy | `#202B38` | Plattform, Schrift, Bedienknöpfe |
| Cream | `#F2EEE5` | Karten, Schrift auf dunklem Grund |
| Mint | `#35B6A4` | Hauptaktion, Erfolg, „hier auffüllen“ |
| Coral | `#F27C65` | Akzent: Orientierungsmarke, Bestwert |
| Amber | `#F1BD58` | Belohnung, Combo, Vorwarnung, Höhengrenze |

### Ergänzungen

| Name | Wert | Verwendung |
|---|---|---|
| Sky | `#5FA8D8` | Blockfarbe |
| Plum | `#9585CC` | Blockfarbe |
| Leaf | `#8CBF6B` | Blockfarbe |
| Rose | `#E88CA3` | Blockfarbe |
| Block-Creme | `#E6DFCF` | Creme für Würfel, etwas dunkler, damit die Oberseite nicht ausbrennt |
| Fehler-Rot | `#E5484D` | ausschließlich ungültige Position |
| Plattform-Oberseite | `#2C3A4B` | Kacheln |
| Fuß | `#161E28` | zurückgesetzter Sockelfuß |

### Bedeutungen in der Oberfläche

| Bedeutung | Farbe |
|---|---|
| Hauptaktion, Erfolg | Mint |
| Ungültig | Fehler-Rot |
| Vorwarnung, Grenze | Amber |
| Belohnung, Combo | Amber auf Navy |
| Hervorhebung, Bestwert | Coral |
| Deaktiviert | `#B9C4C0` |

Regel: Rot bedeutet immer „geht nicht“. Coral ist Akzent und nie eine Fehlermeldung.

### Blockfarben

Jede Bausteinform hat eine feste Farbe, damit sie auf einen Blick erkennbar ist. Ähnliche Formen teilen sich nie eine Farbe mit ihrem Spiegelbild.

| Form | Farbe | Form | Farbe |
|---|---|---|---|
| Einzelwürfel | Block-Creme | Vierer | Mint |
| Doppelblock | Amber | L | Rose |
| Dreier | Mint | gespiegeltes L | Sky |
| Ecke | Coral | S | Coral |
| 2×2 | Sky | Z | Plum |
| T | Plum | Stufe | Amber |
| stehender Doppelblock | Leaf | | |

## 3. Kamera, Licht, Material (Blender)

Festgelegt in `tools/blender/config.json` und `fs_scene.py`. Alle Assets entstehen mit denselben Werten.

- **Kamera:** orthografisch, echte Isometrie (Neigung 54,736°, Azimut 45°), 128 Pixel je Würfelkante.
- **Licht:** eine weiche Sonne von links oben (Richtung 0,15 / −0,75 / 1,0, Stärke 3,2, 18° Öffnung) plus warmes Umgebungslicht. Das Licht ist kamerafest und dreht sich nie mit der Plattform.
- **Material:** matt (Rauheit 0,65), geringer Glanz (0,25).
- **Würfel:** Kantenlänge 1, Fase 7 % mit 3 Segmenten.
- **Farbdarstellung:** „Standard“, damit die Palettenwerte unverfälscht bleiben.

## 4. Einfärbbare Würfel

Es gibt ein einziges graues Würfel-Sprite (`cube.png`, Grauwert 200). Die Blockfarbe entsteht im Spiel durch Skalieren der Farbkanäle. Ein Vergleich mit echt gerenderten farbigen Würfeln zeigte kaum sichtbare Unterschiede. Vorteile: beliebig viele Blockfarben ohne zusätzlichen Bildspeicher, Grundlage für freischaltbare Farbthemen in Phase 5.

Grenze des Verfahrens: Es bildet nur einfarbige matte Würfel ab. Besondere Materialien brauchen eigene Sprites.

### Block-Materialien (freischaltbar)

Jedes Material ist ein eigener grauer Atlas (`tools/blender/render_materials.py`) und wird wie der Standardwürfel eingefärbt. Geladen ist immer nur der gewählte Atlas.

| Material | Form |
|---|---|
| Kiesel | stark gerundete Kanten |
| Planke | zwei Lagen mit einer Nut, erhabene Kassette oben |
| Facette | breite, hart geschliffene Fasen |
| Noppe | Klemmbaustein: kantiger Körper, eine runde Noppe auf der Oberseite. Die Öffnung an der Unterseite ist aus der Spielkamera nie sichtbar und deshalb nicht modelliert |
| Eis | glatter Würfel plus Glanz-Atlas (dünne Lichtkanten, ein schwacher Streifen je Seite, helle Oberseite), der uneingefärbt darüber liegt |

Regeln:
- Jede Form ist um die Hochachse vierfach symmetrisch, weil die Drehbilder 0–87° für jede Vierteldrehung wiederverwendet werden.
- Details entstehen durch Geometrie, nicht durch Texturen.
- **Glanz ist nur bei gekauften Materialien erlaubt** (Ausnahme zu Abschnitt 1) und muss an einem Turm ab Höhe 12 ruhig bleiben. Erste Fassungen von Planke (zwei Nuten) und Eis (zwei Streifen, breite Kanten) waren dafür zu unruhig und wurden vereinfacht.

## 5. Plattform

- quadratische Platte in Navy mit 25 leicht erhabenen Kacheln, dezente Fugen
- abgerundete Kanten, sichtbare Materialstärke, zurückgesetzter dunkler Fuß
- **Orientierungsmarke:** eine Eckkachel in Coral und ein runder Eckpfosten in Coral. Der Pfosten bleibt sichtbar, wenn die Kachel überbaut ist. Liegt die Ecke hinten, verdeckt ihn der Turm; das ist beabsichtigt.

## 6. Tiefe ohne Echtzeit-3D

| Effekt | Umsetzung |
|---|---|
| Schlagschatten höherer Säulen | weiche Flächen auf Oberseiten und Plattformfeldern, passend zur Lichtrichtung |
| Schattierung in Innenecken | Verläufe entlang höherer Wände und am Fuß sichtbarer Seitenflächen |
| Fugen zwischen Würfeln | Silhouette im leicht abgedunkelten Eigenton unter jedem Würfel |
| Bodenkontakt | weicher Schatten der Plattform auf dem Hintergrund |

## 7. Hintergründe

Vier ruhige, helle Farbstimmungen (Sand, Dawn, Mist, Dusk), prozedural gezeichnet: senkrechter Verlauf, Lichtschein hinter dem Turm, vier große Rauten im Seitenverhältnis der Isometrie, die sich kaum merklich bewegen. Die Stimmung wechselt mit jeder Runde.

Regeln: Der Hintergrund ist immer heller und blasser als jeder Würfel. Dunkle Schrift muss überall lesbar bleiben. Dunkle Themen (Midnight, Neon) brauchen ein eigenes Schriftschema und folgen in Phase 5.

Abweichung vom Brief: Die Hintergründe sind nicht in Blender gerendert. Prozedurale Verläufe sind auflösungsunabhängig, brauchen keine Bilddateien und lassen sich je Thema umfärben.

## 7a. Münze und Shop

- **Münze:** in Blender gerendert (`tools/blender/render_coin.py`), mit Licht und Material der Würfel: dicke Scheibe, Randwulst, dunkleres Feld, erhabene Raute als Zeichen für die Würfel-Oberseite. Zwei Bilder in `assets/ui/`: `coin.png` (144 px) und `coin_small.png` (60 px, gröbere Prägung für 16–24 pt). Überall dasselbe Widget `CoinIcon`.
- **Shop:** Tafel in den unteren 60 % des Bildschirms mit vier Reitern (Plattformen, Blöcke, Hintergründe, Effekte) und zweispaltigem Raster. Darüber steht der Beispielturm als Bühne. Ein angetipptes Stück wird dort sofort gezeigt („Anprobe“), auch ungekauft. Ein einziger Knopf unter dem Raster: Auswählen, Freischalten mit Preis oder „Es fehlen N Münzen“.
- **Karten:** Radius 20, Vorschau mit Radius 13, Name 16 pt, darunter Preis mit Münze, „Im Besitz“ oder „Ausgewählt“. Das angesehene Stück hat einen Navy-Rahmen, das ausgewählte einen Mint-Haken.
- **Abstände:** 16 außen, 12 zwischen Karten.

## 8. Arbeitsablauf für Assets

1. Formen ändern in `lib/game/core/piece.dart`, dann `dart run tool/export_pieces.dart`.
2. Farben ändern in `fs_colors.dart` **und** `tools/blender/config.json` (Test prüft Gleichheit).
3. `Blender -b --python tools/blender/render_sprites.py` erzeugt alle Spiel-Sprites.
4. `Blender -b --python tools/blender/build_project.py` erzeugt das zentrale Projekt `assets_src/blender/flipstack.blend` und das Übersichtsblatt.
5. Übersichtsblatt und Spielbild ansehen, erst dann übernehmen.
