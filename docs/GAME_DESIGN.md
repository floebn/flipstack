# FLIPSTACK – Game Design

Stand: Phase 1b · Kernregeln im Prototyp umgesetzt und per Bot-Simulation eingestellt

Der Brief legt Rotation, Rasterplatzierung und faire Physik fest. Offen lässt er, **warum ein Turm irgendwann nicht mehr weiterwächst**. Das ist die wichtigste Designfrage. Hier ist mein Vorschlag, mit Stellschrauben für die Tests.

## 1. Grundregeln (Stand Prototyp, in `lib/game/core/rules.dart`)

1. **Fallen wie in Säulen:** Ein abgelegter Baustein fällt senkrecht, bis eine seiner Zellen auf der Plattform oder einem Würfel aufliegt.
2. **Auflage:** Mindestens die Hälfte der Säulen eines Bausteins muss aufliegen (`minSupport` = 0,5). Überhänge sind also begrenzt erlaubt und überbrücken Lücken.
3. **Gleichmäßig bauen:** Nach dem Ablegen darf die höchste Säule höchstens 4 Ebenen über der niedrigsten liegen (`maxSpread` = 4). Diese Regel ist neu gegenüber dem ersten Entwurf. Ohne sie ließe sich für jede Form ein eigener Stapel bauen, und die Runde würde nie enden.
4. **Kein Überstand über den Rand.**
5. **Bausteine drehen sich nie selbst.** Ihre Ausrichtung zum Turm ändert sich nur durch die Plattformrotation.
6. **Spielende**, sobald der aktuelle Baustein in keiner Position und keiner der vier Orientierungen regelkonform passt.
7. **Maximalhöhe** 30 Ebenen beendet die Runde als „Gipfel erreicht“.

### Ergebnis der Bot-Simulation (`dart run tool/balance_sim.dart`, 300 Runden je Zeile)

| Auflage / Höhenunterschied | Zufallsspieler (Median Steine) | Einfacher Planer (Median, beste 10 %) |
|---|---|---|
| **50 % / 4 (gewählt)** | 20 | 52, ab 120 |
| 50 % / 3 | 16 | 37, ab 79 |
| 50 % / 2 | 12 | 15, ab 39 |
| 100 % / 4 | 12 | 25, ab 42 |
| 100 % / 3 | 12 | 20, ab 32 |

Bei rund 3–4 Sekunden je Zug entsprechen 52 Steine etwa 3 Minuten. Das trifft die Zielgröße von 2–4 Minuten. Die Bots sind einfach; wie sich die Regeln für Menschen anfühlen, muss ein Spieltest zeigen.

## 2. Bausteinfolge und Schwierigkeit

- Im Prototyp von Beginn an: Einzelwürfel, Doppelblock, Dreier, Ecke, 2×2, T. Die gestaffelte Einführung und weitere Formen (1×4, Platten) folgen in Phase 2.
- **Vorschau des nächsten Bausteins** (ein Stein voraus).
- Schwierigkeit steigt über die **Formenmischung** (mehr sperrige Formen mit der Höhe), **nicht über Zeitdruck**. Ein optionales Zeitlimit gibt es zunächst nicht.
- Faire Zufallsfolge („Beutel“-System, seedbar): Jede Form kommt genau einmal vor, bevor sich eine wiederholt.

## 3. Punkte (transparent)

| Ereignis | Punkte |
|---|---|
| Baustein abgelegt | 10 × Anzahl Würfel |
| **Sauber abgelegt** (100 % gestützt, kein neuer Hohlraum) | +50 %, zählt für die Combo *(Phase 2)* |
| **Ebene vollständig** (alle N×N Felder einer Höhe belegt) | +100 je Ebene |
| Höhenmeilenstein (alle 5 Ebenen) | +200 *(Phase 2)* |
| Combo *(Phase 2)* | Multiplikator ×1,0 → +0,25 pro saubere Ablage in Folge, max. ×3,0; endet bei einer Ablage mit neuem Hohlraum |

„Geschickte Rotation“ wird nicht separat belohnt. Sie zeigt sich in sauberen Ablagen. Das vermeidet willkürliche Bonuspunkte.

## 4. Offene Fragen für den Spieltest

- Ist die Regel „gleichmäßig bauen“ ohne Erklärung verständlich? Derzeit erscheint nur der Hinweis „Turm wird zu ungleichmäßig“.
- Fühlt sich das Spielende fair an, oder kommt es überraschend? Eine Vorwarnung („nur noch wenige Plätze“) fehlt noch.
- Spielfeld 5×5 oder 4×4, Vorschau auf 1 oder 2 Steine.
