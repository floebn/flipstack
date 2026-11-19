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

## 1a. Etappen: so steigt die Schwierigkeit

| Etappe (Turmhöhe) | Änderung |
|---|---|
| 10 | Höhenunterschied höchstens 3 statt 4 |
| 20 | Zwei Formen aus fünf Würfeln kommen dazu (P-Form, langer Haken); der zweite Einzelwürfel entfällt |
| 30 | Zwei weitere Fünfer kommen dazu (U-Form, Kreuz) |
| 40, 50, … | nur Bonus |

Neue Formen erscheinen erst mit dem nächsten Beutel, also bis zu 14 Steine nach der Etappe.

### Ergebnis der Bot-Simulation (`dart run tool/balance_sim.dart`, 100 Runden je Zeile, Median der abgelegten Steine)

| Bot | Alte Regeln (immer 4, keine Fünfer) | **Gewählt** | Zusätzlich Unterschied 2 ab Höhe 30 |
|---|---|---|---|
| Zufall | 23 | 23 | 23 |
| Gierig (tief und gestützt ablegen) | 56 | 56 | 56 |
| Flächenbot (hält die Oberfläche flach, ein Zug voraus) | über 1500 (Abbruch) | 219, Höhe 30 | 215 |
| Planer (plant den Vorschau-Stein ein) | über 1500 (Abbruch) | 434, Höhe 64 | 245, Höhe 33 |

Was daraus folgt:

- Mit den alten Regeln war das Spiel für sauberes Spiel praktisch endlos. Die Grenze bei 30 hat das verdeckt.
- **Höhenunterschied 2 ist eine Wand:** Auch der Planer scheitert wenige Züge danach. Die Stufe wurde deshalb verworfen.
- Die Fünfer sind der stärkere Hebel als der Höhenunterschied. Ohne sie schafft der Flächenbot bei Unterschied 3 im Median 304 Steine.
- Bei rund 3,5 Sekunden je Zug wären 219 Steine knapp 13 Minuten. Das ist länger als das Ziel von 5–8 Minuten für geübte Spieler. Die Bots machen aber keine Flüchtigkeitsfehler. Wo Menschen landen, muss der Spieltest zeigen; die Schwellen sind Konstanten (`RuleConfig.tightening`, `PieceLibrary.bigPiecesFromHeight`).

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

| Kategorie | Kostenlos | Kaufbar (Münzen) |
|---|---|---|
| Block-Material | Matt | Kiesel 600, Planke 800, Facette 1000, Eis 1400, Noppe 1800 |
| Blockfarben | Klassik | Arctic 500, Forest 800, Candy 1000 |
| Hintergründe | Sand | Dawn 250, Mist 400, Dusk 600 |
| Plattformen | Schiefer | Ton 400, Moos 700 |
| Effekte | Staub | Konfetti 300, Splitter 400 |

Alles zusammen kostet 10.950 Münzen. Material und Farben lassen sich frei kombinieren. Jede Blockpalette behält die Reihenfolge der Farbtöne, damit Formen wiedererkennbar bleiben; ein Test prüft den Mindestabstand der Farben.

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
