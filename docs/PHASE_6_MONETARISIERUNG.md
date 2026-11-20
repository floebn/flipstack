# FLIPSTACK – Phase 6: Monetarisierung

Stand: Teile 6a, 6b und 6c umgesetzt · Grundlage: Masterbrief Abschnitt 8

## Aufteilung

| Teil | Inhalt | Braucht von dir | Stand |
|---|---|---|---|
| 6a | Werberegeln, zweite Chance, Münzen verdoppeln, Werbe-Schnittstelle mit Testplatzhalter. Kein Werbe-SDK, kein Netz | nichts | umgesetzt |
| 6b | Google-Mobile-Ads-SDK mit Googles öffentlichen Test-Anzeigen, Einwilligung (DSGVO-Abfrage, auf iOS zusätzlich die Tracking-Abfrage) | Einwilligungsabfrage in AdMob veröffentlichen | Code umgesetzt |
| 6c | Einmaliger Kauf „Werbefrei“, Käufe wiederherstellen | Produkt in App Store Connect anlegen, Test mit Sandbox-Konto | Code umgesetzt |
| 6d | Datenschutzerklärung in der App, Angaben für die Stores, Altersfreigabe, echte Anzeigen-Kennungen | Texte, Entscheidungen, Kennungen | offen |

## Was 6a festlegt

**Belohnte Werbung** ist immer freiwillig. Die Belohnung steht auf dem Knopf, bevor die Werbung startet. Ohne zu Ende gesehene Werbung gibt es keine Belohnung, mit ihr immer.

- **Zweite Chance:** einmal je Runde, nur wenn ein Stein nirgends passte. Der Stein wird gegen den nächsten getauscht, der passt; der Turm bleibt. Die Abrechnung der Runde (Statistik, Münzen, Aufgaben) wird zurückgenommen und am wirklichen Ende neu gemacht.
- **Münzen verdoppeln:** die Münzen für Punkte und Etappen der Runde noch einmal. Belohnungen für Aufgaben und Erfolge werden nicht verdoppelt.

**Vollbildwerbung** nur zwischen zwei Runden, beim Tippen auf „Nochmal“ oder „Hauptmenü“ (`lib/game/meta/ad_policy.dart`):

| Regel | Startwert |
|---|---|
| erste frühestens nach | 3 beendeten Runden |
| danach höchstens | jede 2. Runde |
| Mindestabstand | 240 Sekunden |
| nach dem Öffnen der App | frühestens nach 60 Sekunden |
| nicht nach einer Runde unter | 40 Sekunden (frühes Scheitern) |
| nie | im Tutorial, nach belohnter Werbung in derselben Runde, mit „Werbefrei“ |

Der Zählerstand (Runden insgesamt, Runden seit der letzten Anzeige, Zeitpunkt der letzten Anzeige) wird gespeichert und übersteht einen Neustart der App. „Jede 4. Runde“ aus dem Brief wurde auf jede 2. geändert: Runden dauern meist mehrere Minuten, mit jeder vierten käme Werbung seltener als alle 20 Minuten. Der Mindestabstand von 4 Minuten verhindert Werbung in kurzer Folge.

Es gibt keine Banner und keine Werbung während einer Runde.

**Ohne Werbung** (kein SDK, keine Einwilligung, kein Netz) gilt `NoAds`: Die Angebote erscheinen nicht, das Spiel läuft unverändert. Zum Prüfen der Abläufe: `--dart-define=FS_ADS=fake`.

## Was 6b festlegt

- **Ablauf beim Start:** Hauptmenü erscheint → Einwilligungsstatus wird abgefragt → bei Bedarf zeigt Google die Mitteilung → nur wenn Werbung angefragt werden darf, startet das Werbe-SDK und lädt je eine belohnte und eine Vollbildanzeige vor. Ohne Einwilligung, ohne Netz oder ohne veröffentlichte Mitteilung bleibt es bei keiner Werbung. Das ist bewusst streng: Googles Bibliothek meldete im Test „Werbung erlaubt“, obwohl der Abruf des Status fehlgeschlagen war; die App wertet einen fehlgeschlagenen Abruf deshalb immer als „nicht erlaubt“.
- **Testanzeigen als Vorgabe:** Jeder Build nutzt Googles öffentliche Testanzeigen. Die echten Anzeigenblöcke (`lib/services/ads/ad_ids.dart`) werden nur mit `--dart-define=FS_ADS=live` verwendet. Weitere Schalter: `fake` (Platzhalter ohne SDK), `off` (keine Werbung). Nur im Debug-Build überspringt `--dart-define=FS_SKIP_CONSENT=true` die Abfrage, um die Abläufe mit Testanzeigen zu prüfen.
- **Belohnung:** Es gibt sie nur, wenn das SDK sie meldet. Wer die Anzeige vorzeitig schließt, bekommt nichts.
- **Einstellungen:** Eintrag „Datenschutz-Einstellungen“ erscheint, sobald Google meldet, dass die Entscheidung änderbar sein muss. Dazu Links zu Datenschutzerklärung, Support und Impressum.
- **iOS:** App-ID, Text der Tracking-Abfrage, 50 SKAdNetwork-Kennungen (Stand 20.11.2026) und die Erklärung zur Verschlüsselung stehen in `ios/Runner/Info.plist`.
- **Android:** vorläufig Googles Beispiel-App-ID im Manifest, weil die Android-App in AdMob noch fehlt. Vor der Veröffentlichung ersetzen.
- **Tracking-Abfrage von Apple:** Sie wird über die IDFA-Erklärung in AdMob ausgelöst (Anleitung Abschnitt D). Ohne diese Erklärung erscheint Apples Dialog nicht, und die App nutzt keine Werbe-ID.

## Was 6c festlegt

- **Wirkung:** „Werbefrei“ entfernt die Vollbildwerbung zwischen den Runden. Freiwillige, belohnte Werbung („Weiterspielen“, Münzen verdoppeln) bleibt als Angebot. Kein Spielvorteil.
- **Produkt:** nicht verbrauchbarer Einmalkauf. Kennung iOS `com.floebn.flipstack.remove_ads`, Android `remove_ads` (`StorePurchases.productId`).
- **Preis:** kommt aus dem Store und steht nicht im Code.
- **Freischaltung:** wird lokal gemerkt und gilt sofort, auch ohne Netz. Nach einer Neuinstallation holt „Käufe wiederherstellen“ sie zurück. Es gibt keinen eigenen Server und keine Prüfung des Kaufbelegs.
- **Wo man kauft:** Einstellungen → „Werbefrei“, und im Ergebnis der Runde der Link „Werbung entfernen“ (nur wenn Werbung läuft und noch nicht gekauft ist).
- **Wenn der Store nicht antwortet oder das Produkt fehlt:** Der Knopf zeigt „Derzeit nicht verfügbar“. Zum Prüfen der Oberfläche ohne Store: `--dart-define=FS_IAP=fake`.

## Was du für 6b bis 6d vorbereiten musst

1. **AdMob-Konto** (admob.google.com): App für iOS und Android anlegen, je einen Anzeigenblock „Mit Prämie“ und „Interstitial“. Ergebnis: 2 App-IDs und 4 Anzeigenblock-IDs.
2. **Einwilligungsabfrage in AdMob** („Datenschutz und Mitteilungen“): Mitteilung für die DSGVO und für iOS die Erklärung zur Tracking-Abfrage erstellen.
3. **App Store Connect:** App anlegen, Vereinbarung für kostenpflichtige Apps mit Bank- und Steuerdaten, In-App-Kauf „Werbefrei“ (nicht verbrauchbar), ein Sandbox-Testkonto.
4. **Google Play Console:** Entwicklerkonto, App anlegen, In-App-Produkt „Werbefrei“, Lizenztester. Dazu ein Android-Gerät oder Emulator zum Testen.
5. **Datenschutzerklärung und Impressum** unter einer öffentlichen Adresse. Einen Entwurf schreibe ich; die rechtliche Prüfung kann ich nicht ersetzen.
6. **Entscheidungen:** Preis für „Werbefrei“, Zielgruppe (richtet sich das Spiel auch an Kinder unter 13? Das ändert, welche Werbung erlaubt ist), Alterseinstufung.
7. **Außerhalb der App:** Einnahmen aus Werbung und Käufen sind gewerblich. Anmeldung und Steuern bitte mit Finanzamt oder Steuerberatung klären.
