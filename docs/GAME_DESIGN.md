# FLIPSTACK – Game Design

Stand: nach Phase 4 · Endlosspiel mit Etappen, Regeln und Punkte per Bot-Simulation eingestellt

Der Brief legt Rotation, Rasterplatzierung und faire Physik fest. Offen lässt er, **warum ein Turm irgendwann nicht mehr weiterwächst**. Das ist die wichtigste Designfrage. Hier ist mein Vorschlag, mit Stellschrauben für die Tests.

## 1. Grundregeln (Stand Prototyp, in `lib/game/core/rules.dart`)

1. **Fallen wie in Säulen:** Ein abgelegter Baustein fällt senkrecht, bis eine seiner Zellen auf der Plattform oder einem Würfel aufliegt.
2. **Auflage:** Mindestens die Hälfte der Säulen eines Bausteins muss aufliegen (`minSupport` = 0,5). Überhänge sind also begrenzt erlaubt und überbrücken Lücken.
3. **Gleichmäßig bauen:** Nach dem Ablegen darf die höchste Säule höchstens 4 Ebenen über der niedrigsten liegen (`maxSpread` = 4). Diese Regel ist neu gegenüber dem ersten Entwurf. Ohne sie ließe sich für jede Form ein eigener Stapel bauen, und die Runde würde nie enden. **Ab Turmhöhe 10 sinkt der Wert auf 3.** Geprüft wird nur der neu abgelegte Baustein: Er darf höchstens so weit über das tiefste Feld ragen. Was schon steht, bleibt gültig, der Übergang kann also niemanden festsetzen.
4. **Kein Überstand über den Rand.**
5. **Bausteine drehen sich nie selbst.** Ihre Ausrichtung zum Turm ändert sich nur durch die Plattformrotation.
6. **Spielende**, sobald der aktuelle Baustein in keiner Position und keiner der vier Orientierungen regelkonform passt.
7. **Endlos:** Es gibt keine Obergrenze mehr. Die Höhen 10, 20, 30 … sind Etappen mit Bonus und Ansage (siehe Abschnitt 1a). Die frühere Grenze bei Höhe 30 entfiel, nachdem ein Spieltest sie mit 191 Steinen erreicht hatte.

## 1a. So steigt die Schwierigkeit (`DifficultyCurve` in `lib/game/core/piece.dart`)

Grundsatz: kein Zeitdruck, keine neue Regel in großer Höhe. Erst kommen sperrige Formen dazu, danach fallen die einfachen Lückenfüller nach und nach weg. Jede Änderung wird angesagt und wirkt mit dem nächsten Beutel.

| Turmhöhe | Änderung |
|---|---|
| 10 | Höhenunterschied höchstens 3 statt 4 |
| 15 | zwei Formen aus fünf Würfeln (P-Form, langer Haken); der zweite Einzelwürfel entfällt |
| 25 | zwei weitere Fünfer (U-Form, Kreuz) |
| 30 | der Einzelwürfel fällt ganz weg |
| 35 | der Doppelblock fällt weg |
| 45 | alle Fünfer sind doppelt im Beutel |
| 55 | die Ecke fällt weg |
| ab 60 | nichts mehr: Wer so weit kommt, wird nicht zusätzlich gebremst |

Etappen mit +500 bleiben bei 10, 20, 30 …

### Simulation (`dart run tool/balance_sim.dart`, 21.11.2026)

Höhe am Rundenende als 10 % / Median / 90 %, dahinter die Dauer der mittleren Runde bei 3,5 s je Zug. 150 Runden je Zeile.

| Bot | vorher (Fünfer 20/30, danach nichts) | **gewählt** | höchste Runde (gewählt) |
|---|---|---|---|
| Gierig | 6 / 8 / 12 · 3 min | 6 / 8 / 12 · 3 min | 18 |
| Fläche mit vielen Fehlern | 10 / 18 / 31 · 8 min | 10 / 17 / 27 · 7 min | 51 |
| Fläche mit Fehlern | 12 / 24 / 34 · 10 min | 12 / 22 / 31 · 10 min | 45 |
| Fläche fehlerfrei | 14 / 30 / 40 · 13 min | 14 / 25 / 35 · 11 min | 44 |
| Planer fehlerfrei | 37 / 57 / 147 · 23 min | 30 / 48 / 63 · 19 min | 86 |

Planer mit der gewählten Kurve: Höhe 60 in 15 % der Runden, Höhe 80 in 1 %, Höhe 100 nie.

Verglichene Varianten (Planer, Anteil der Runden mit Höhe 60 oder mehr):

| Variante | ≥ 60 |
|---|---|
| vorher: nichts ab 30 | 48 % |
| Stufen bei 40/50/60, dann alle 10 | 35 % |
| Einzel 30, Doppelblock 40, Fünfer doppelt 45, Ecke 55 … | 25 % |
| **gewählt:** Einzel 30, Doppelblock 35, Fünfer doppelt 45, Ecke 55, danach nichts | 15 % |
| wie gewählt, aber ab 65 weitere Steine weg | 13 % |
| dicht: 30/35/40, dann alle 5 ab 45 | 1 % |

Was daraus folgt:

- Die Kurve trifft fast nur starke Spieler. Wer vor Höhe 30 scheitert, merkt außer den früheren Fünfern nichts.
- Der Doppelblock ist der stärkste späte Hebel: bei 40 statt 35 verdoppelt sich der Anteil über Höhe 60.
- „Ab 60 nichts mehr“ kostet wenig: 15 % statt 13 %. Der Beutel ist ab 55 so sperrig, dass auch ohne weitere Stufen niemand endlos spielt.
- Grenzen: Die Bots sind keine Menschen, 3,5 s je Zug ist eine Annahme, und bei 100 bis 150 Runden sind einige Prozentpunkte Zufall. Geeicht ist die Kurve an einem einzigen Spieler.

## 2. Bausteine und Schwierigkeit

17 Formen. 13 kommen nach Anzahl gezogener Steine dazu, 4 Fünfer nach Turmhöhe (`PieceLibrary.forProgress`):

| Ab Baustein Nr. | Neue Formen |
|---|---|
| 1 | Einzelwürfel, Doppelblock, Dreier, Ecke, 2×2 |
| 11 | T, stehender Doppelblock (zwei Würfel hoch) |
| 23 | Vierer, L, gespiegeltes L |
| 37 | S, Z, Stufe (liegender Doppelblock mit aufgesetztem Würfel); Einzelwürfel doppelt im Beutel |

- **Vorschau des nächsten Bausteins** (ein Stein voraus).
- Die Schwierigkeit steigt über die Formenmischung, nicht über Zeitdruck. Es gibt kein Zeitlimit.
- Faire Zufallsfolge („Beutel“-System, seedbar): Jede Form des aktuellen Vorrats kommt einmal vor, bevor sich eine wiederholt.
- **Vorwarnung:** Bleiben weniger als 4 gültige Ablagen (über alle Positionen und Orientierungen), zeigt das Spiel „Nur noch N Plätze“.

## 2a. Wie das Spiel die Regeln zeigt

Ein Spieltest am 19.11.2026 ergab: Nach 77 Steinen war nicht erkennbar, warum die Runde endete. Die Höhenregel war unsichtbar. Seitdem gilt:

- **Höhengrenze:** Sobald der Turm ungleichmäßig wird (Unterschied ab 3 Ebenen), zeigt ein Rahmen um den Turm die höchste erlaubte Bauhöhe. Er wird rot, wenn die aktuelle Position daran scheitert.
- **Tiefste Felder:** Gleichzeitig pulsieren die niedrigsten Felder. Der Hinweis lautet „Zu hoch – erst die markierten Felder füllen“.
- **Etappe:** Beim Erreichen erscheint für einige Sekunden eine Ansage, was sich ändert, zum Beispiel „Etappe 10 · Ab jetzt höchstens 3 Ebenen Unterschied“. Der Rahmen zeigt danach die engere Grenze.
- **Spielende:** Der Stein, der nirgends passte, bleibt kurz rot über dem Turm sichtbar. Das Ergebnis zeigt ihn mit Begründung (zu wenig Auflage, Höhenunterschied oder beides).

## 3. Punkte (transparent, in `GameSession.place`)

| Ereignis | Punkte |
|---|---|
| Baustein abgelegt | 10 je Würfel |
| **Sauber abgelegt** (liegt vollständig auf) | +50 % |
| **Combo** | Jede saubere Ablage in Folge erhöht den Multiplikator um 0,1 (×1,0 → höchstens ×2,0). Er gilt für die beiden Zeilen darüber. Eine Ablage mit Überhang setzt ihn zurück. |
| **Ebene vollständig** (alle 25 Felder einer Höhe belegt) | +100 je Ebene |
| **Höhenmeilenstein** (Höhe 5, 15, 25, …) | +200 |
| **Etappe** (Höhe 10, 20, 30, …) | +500 |

Jeder Posten wird beim Ablegen über dem Baustein eingeblendet. Der Punktestand ist exakt die Summe dieser Posten (per Test abgesichert).

Überhänge sind damit eine bewusste Abwägung: Sie retten schwierige Lagen, kosten aber die Combo. „Geschickte Rotation“ wird nicht separat belohnt, sie zeigt sich in sauberen Ablagen.

Im ersten Entwurf wuchs der Multiplikator um 0,25 bis ×3,0. Im Testlauf war das Maximum nach wenigen Zügen erreicht und blieb dauerhaft stehen, deshalb die flachere Kurve.

## 3a. Statistik (dauerhaft gespeichert)

Bestwert, größte Höhe, gespielte Runden, Durchschnittspunkte, beste Combo, Gesamtzahl abgelegter Bausteine. Gespeichert lokal auf dem Gerät, ohne Konto und ohne Netz.

## 3b. Belohnungssystem (Phase 5, `lib/game/meta/rewards.dart`)

Grundsatz: Münzen kaufen nur Aussehen, nie einen Spielvorteil. Es gibt keine Wartezeiten, keine Leben und keinen Login-Streak. Ein verpasster Tag kostet nichts.

**Münzen verdienen**

| Quelle | Münzen |
|---|---|
| Runde | 1 je 100 Punkte, mindestens 1 |
| Etappe | 10 je erreichter Etappe (Höhe 10, 20, …) |
| Tagesaufgabe | 40–60 |
| Wochenaufgabe | 150–250 |
| Erfolg | 20–300, einmalig |

Eine Runde mit 5.000 Punkten und Höhe 20 bringt 70 Münzen, drei Tagesaufgaben zusammen rund 150.

**Aufgaben:** Jeden Tag drei aus zwölf, jede Woche (ab Montag) drei aus acht. Die Auswahl hängt nur vom Datum ab und enthält nie zwei Aufgaben derselben Art. Belohnungen werden am Rundenende automatisch gutgeschrieben, es gibt nichts abzuholen.

**Erfolge:** zwölf, an Lebenszeit-Zählern (Höhe, Combo, Runden, Drehungen, saubere Ablagen, volle Ebenen, Punkte).

**Freischaltungen**

| Kategorie | Kostenlos | Kaufbar (Münzen), vom günstigsten zum teuersten |
|---|---|---|
| Block-Material | Matt | Kiesel 700, Facette 700, Planke 800, Beton 800, Stoff 1000, Eis 1400, Vulkan 1500, Neonglas 1600, Noppe 1800 |
| Blockfarben | Klassik | Arctic 400, Forest 400, Sunset 500, Lagoon 500, Lavender 500, Candy 600, Volcano 600 |
| Hintergründe | Sand | Dawn 250, Mist 350, Dusk 450, Wald 800, Herbst 900, Winter 900, Unterwasser 1100, Weltraum 1300, Neonstadt 1500 |
| Plattformen | Schiefer | Ton 350, Moos 450, Eiche 800, Marmor 1000, Gletscher 1300, Futuristisch 1500, Insel 1700 |
| Effekte | Staub | Konfetti 300, Splitter 500 |

Preislogik: Umfärbungen (Farbpaletten, Ton, Moos, Verlaufs-Hintergründe) kosten 250–600, Stücke mit eigener Form oder Szenerie 700–1300, die aufwendigsten 1400–1800. Der Shop zeigt jede Kategorie in dieser Reihenfolge.

Alles zusammen kostet 29.650 Münzen. Material und Farben lassen sich frei kombinieren. Jede Blockpalette behält die Reihenfolge der Farbtöne, damit Formen wiedererkennbar bleiben; ein Test prüft den Mindestabstand der Farben.

Bis Phase 4 wechselte der Hintergrund jede Runde. Jetzt ist er eine Freischaltung, Standard ist Sand.

**Ergebnisbildschirm:** verdiente Münzen, erfüllte Aufgaben und Erfolge, Fortschritt zur günstigsten fehlenden Freischaltung.

Nicht umgesetzt: besondere Blockmaterialien und Animationen als Freischaltung, saisonale Events, der optionale Streak.

## 4. Offene Fragen für den Spieltest

- Wie lange dauert eine gute Runde jetzt wirklich, und wo endet sie (vor 20, zwischen 20 und 30, danach)?
- Wirken die Fünfer ab Höhe 20 als faire Steigerung oder als Bruch?

- Ist die Regel „gleichmäßig bauen“ mit Rahmen und markierten Feldern jetzt verständlich?
- Fühlt sich das Spielende fair an, oder kommt es trotz Vorwarnung überraschend?
- Ist die Combo-Kurve motivierend, oder wirkt ×2,0 als Obergrenze zu niedrig?
- Spielfeld 5×5 oder 4×4, Vorschau auf 1 oder 2 Steine.
