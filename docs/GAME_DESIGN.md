# FLIPSTACK – Game Design

Stand: Phase 2 · Kernspiel umgesetzt, Regeln und Punkte per Bot-Simulation eingestellt

Der Brief legt Rotation, Rasterplatzierung und faire Physik fest. Offen lässt er, **warum ein Turm irgendwann nicht mehr weiterwächst**. Das ist die wichtigste Designfrage. Hier ist mein Vorschlag, mit Stellschrauben für die Tests.

## 1. Grundregeln (Stand Prototyp, in `lib/game/core/rules.dart`)

1. **Fallen wie in Säulen:** Ein abgelegter Baustein fällt senkrecht, bis eine seiner Zellen auf der Plattform oder einem Würfel aufliegt.
2. **Auflage:** Mindestens die Hälfte der Säulen eines Bausteins muss aufliegen (`minSupport` = 0,5). Überhänge sind also begrenzt erlaubt und überbrücken Lücken.
3. **Gleichmäßig bauen:** Nach dem Ablegen darf die höchste Säule höchstens 4 Ebenen über der niedrigsten liegen (`maxSpread` = 4). Diese Regel ist neu gegenüber dem ersten Entwurf. Ohne sie ließe sich für jede Form ein eigener Stapel bauen, und die Runde würde nie enden.
4. **Kein Überstand über den Rand.**
5. **Bausteine drehen sich nie selbst.** Ihre Ausrichtung zum Turm ändert sich nur durch die Plattformrotation.
6. **Spielende**, sobald der aktuelle Baustein in keiner Position und keiner der vier Orientierungen regelkonform passt.
7. **Maximalhöhe** 30 Ebenen beendet die Runde als „Gipfel erreicht“.

### Ergebnis der Bot-Simulation (`dart run tool/balance_sim.dart`, 300 Runden je Zeile, alle Formen mit Stufen)

| Auflage / Höhenunterschied | Zufallsspieler (Median Steine) | Einfacher Planer (Median, beste 10 %) |
|---|---|---|
| **50 % / 4 (gewählt)** | 24 | 57, ab 108 |
| 50 % / 5 | 28 | 113, ab 212 |
| 50 % / 3 | 18 | 49, ab 111 |

Bei rund 3–4 Sekunden je Zug entsprechen 57 Steine etwa 3 Minuten. Das trifft die Zielgröße von 2–4 Minuten. Die Bots sind einfach; wie sich die Regeln für Menschen anfühlen, muss ein Spieltest zeigen.

## 2. Bausteine und Schwierigkeit

13 Formen, eingeführt in vier Stufen (`PieceLibrary.forProgress`):

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
- **Spielende:** Der Stein, der nirgends passte, bleibt kurz rot über dem Turm sichtbar. Das Ergebnis zeigt ihn mit Begründung (zu wenig Auflage, Höhenunterschied oder beides).

## 3. Punkte (transparent, in `GameSession.place`)

| Ereignis | Punkte |
|---|---|
| Baustein abgelegt | 10 je Würfel |
| **Sauber abgelegt** (liegt vollständig auf) | +50 % |
| **Combo** | Jede saubere Ablage in Folge erhöht den Multiplikator um 0,1 (×1,0 → höchstens ×2,0). Er gilt für die beiden Zeilen darüber. Eine Ablage mit Überhang setzt ihn zurück. |
| **Ebene vollständig** (alle 25 Felder einer Höhe belegt) | +100 je Ebene |
| **Höhenmeilenstein** (alle 5 Ebenen) | +200 |

Jeder Posten wird beim Ablegen über dem Baustein eingeblendet. Der Punktestand ist exakt die Summe dieser Posten (per Test abgesichert).

Überhänge sind damit eine bewusste Abwägung: Sie retten schwierige Lagen, kosten aber die Combo. „Geschickte Rotation“ wird nicht separat belohnt, sie zeigt sich in sauberen Ablagen.

Im ersten Entwurf wuchs der Multiplikator um 0,25 bis ×3,0. Im Testlauf war das Maximum nach wenigen Zügen erreicht und blieb dauerhaft stehen, deshalb die flachere Kurve.

## 3a. Statistik (dauerhaft gespeichert)

Bestwert, größte Höhe, gespielte Runden, Durchschnittspunkte, beste Combo, Gesamtzahl abgelegter Bausteine. Gespeichert lokal auf dem Gerät, ohne Konto und ohne Netz.

## 4. Offene Fragen für den Spieltest

- Ist die Regel „gleichmäßig bauen“ mit Rahmen und markierten Feldern jetzt verständlich?
- Fühlt sich das Spielende fair an, oder kommt es trotz Vorwarnung überraschend?
- Ist die Combo-Kurve motivierend, oder wirkt ×2,0 als Obergrenze zu niedrig?
- Spielfeld 5×5 oder 4×4, Vorschau auf 1 oder 2 Steine.
