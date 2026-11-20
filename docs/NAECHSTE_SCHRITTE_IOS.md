# FLIPSTACK – Nächste Schritte für iOS

Stand: 20.11.2026 · Code-Stand `e4c58ff` · Android folgt später.

Diese Anleitung ersetzt für die offenen Punkte die ältere `PHASE_6_IOS_ANLEITUNG.md`. Dort stehen weiterhin die Einzelheiten zu den erledigten Abschnitten A bis F.

Hinweis: Apple und Google benennen Menüs gelegentlich um. Wenn ein Eintrag bei dir anders heißt, such nach dem sinngleichen Begriff oder schick mir einen Screenshot.

## Wo wir stehen

| Was | Stand |
|---|---|
| AdMob: App, zwei Anzeigenblöcke, DSGVO-Mitteilung, IDFA-Erklärung | erledigt |
| Apple: Bundle ID, App in App Store Connect, Vereinbarung für bezahlte Apps | erledigt |
| In-App-Kauf „Werbefrei“ und Sandbox-Tester | erledigt, Kauf auf dem iPhone hat geklappt |
| Website: FlipStack-Seite, Datenschutz, Support, Impressum | live auf bosselgo.de |
| Im Spiel: Werbung mit Einwilligung, Kauf, neue Einstellungen, neues Ergebnis | fertig und gepusht |
| Angaben für den App Store (Teil 6d) | offen |
| App-Symbol, Screenshots, Texte, Einreichung (Phase 7) | offen |

## Überblick über die nächsten Schritte

| Schritt | Wer | Dauer |
|---|---|---|
| 1. Auf dem iPhone testen | du | 20–30 Minuten |
| 2. Drei Entscheidungen treffen | du | 5 Minuten |
| 3. Projekt für den Store vorbereiten | ich | – |
| 4. Angaben in App Store Connect eintragen | du | 30–45 Minuten |
| 5. Erster Build zu TestFlight | du, ich helfe | 20 Minuten plus Wartezeit |
| 6. Phase 7 beginnen | ich, mit deinen Freigaben | – |

Schritt 1 und 2 kannst du sofort machen. Für Schritt 3 brauche ich die Antworten aus Schritt 2.

---

## Schritt 1: Auf dem iPhone testen

Spiel die aktuelle Version aufs Gerät:

```bash
flutter run --release
```

Du siehst überall Googles Testanzeigen mit dem Schild „Test mode“. Das ist Absicht: Auf echte Anzeigen in der eigenen App darfst du nie tippen.

### 1a. Vollbildwerbung zwischen Runden

Auf deinem iPhone ist „Werbefrei“ gekauft, deshalb siehst du gerade keine. So testest du sie trotzdem:

1. Lösch FlipStack vom iPhone.
2. Installier neu mit `flutter run --release`.
3. Tipp **nicht** auf „Käufe wiederherstellen“.
4. Spiel drei Runden von jeweils mindestens 40 Sekunden zu Ende.
5. Tipp nach der dritten Runde auf „Nochmal“.

Erwartet: Eine Vollbild-Testanzeige erscheint. Danach kommt die nächste frühestens nach zwei weiteren Runden und vier Minuten.

### 1b. Zählerstand über einen Neustart

1. Spiel nach einer Neuinstallation zwei Runden.
2. Schließ die App vollständig (im App-Umschalter nach oben wischen).
3. Öffne sie wieder, warte eine Minute und spiel eine Runde von mindestens 40 Sekunden.

Erwartet: Nach dieser Runde kommt die Anzeige, weil es insgesamt die dritte ist.

### 1c. Freiwillige Werbung

- „Weiterspielen“: Nach der Anzeige geht die Runde mit getauschtem Stein weiter. Das Angebot erscheint in derselben Runde kein zweites Mal.
- „+X Münzen“: Nach der Anzeige steht „gutgeschrieben“, und der Kontostand ist höher.
- Anzeige vorzeitig schließen: Es darf keine Belohnung geben.

### 1d. Kauf wiederherstellen

1. Lösch die App und installier sie neu.
2. Öffne Einstellungen → „Werbefrei“ → „Käufe wiederherstellen“.

Erwartet: „Kauf wiederhergestellt“, und in den Einstellungen steht „Aktiv“.

### 1e. Worauf du sonst achten solltest

- Ton nach einer Anzeige: Spielt das Spiel danach wieder Töne?
- Neuer Ergebnisbildschirm und neue Einstellungen: Passt alles auf dein Display, ist etwas abgeschnitten?
- Leistung bei hohen Türmen (ab Höhe 20): Ruckelt es?

Schreib mir, was nicht wie erwartet läuft. Bei Problemen mit Werbung oder Kauf hilft mir die Konsolenausgabe mit den Zeilen, die mit „FLIPSTACK“ beginnen.

---

## Schritt 2: Drei Entscheidungen

1. **Preis für „Werbefrei“:** Welcher Preis ist bei Apple eingestellt, und bleibt er? Üblich sind 2,99 € bis 4,99 €.
2. **Zielgruppe:** Richtet sich das Spiel gezielt an Kinder unter 13? Ich empfehle **nein**. Für Kinder-Apps gelten strengere Regeln: keine personalisierte Werbung, kein Tracking, nur zugelassene Werbenetzwerke.
3. **Länder zum Start:** Deutschland, Österreich und Schweiz, oder weltweit? Die App und die Website sind bisher nur auf Deutsch. Ich empfehle, mit den drei Ländern zu beginnen.

---

## Schritt 3: Was ich im Projekt vorbereite

Sobald ich deine Antworten habe:

- **Datenschutz-Manifest** (`PrivacyInfo.xcprivacy`): Apple verlangt diese Datei im Projekt. Sie fehlt noch.
- **Abgleich des Datenschutz-Etiketts** mit Googles aktueller Liste für das Werbe-SDK, damit die Tabelle in Schritt 4 stimmt.
- **Release-Build mit echten Anzeigenblöcken** prüfen (`FS_ADS=live`).
- **Versionsnummer** für den ersten Upload setzen (bisher 1.0.0, Build 1).

---

## Schritt 4: Angaben in App Store Connect

Öffne appstoreconnect.apple.com → Apps → FlipStack. Die Menüs stehen links.

### 4a. App Privacy (Datenschutz-Etikett)

Links unter **Trust & Safety** → **App Privacy**.

1. **Privacy Policy URL:**

```text
https://bosselgo.de/flipstack/datenschutz/
```

2. Klick auf **Get Started** und beantworte „Do you or your third-party partners collect data from this app?“ mit **Yes**.
3. Wähle die Datenarten aus der Tabelle. Die endgültige Fassung bekommst du von mir nach Schritt 3; dies ist der voraussichtliche Stand:

| Datenart (Apple) | Zweck | Mit Identität verknüpft | Für Tracking |
|---|---|---|---|
| Identifiers → Device ID | Third-Party Advertising | nein | ja |
| Usage Data → Product Interaction | Third-Party Advertising, Analytics | nein | ja |
| Usage Data → Advertising Data | Third-Party Advertising | nein | ja |
| Location → Coarse Location | Third-Party Advertising | nein | ja |
| Diagnostics → Crash Data, Performance Data | App Functionality | nein | nein |

4. **Purchases:** Den Kauf wickelt Apple ab, die App speichert nur „gekauft ja/nein“ auf dem Gerät. Das zählt nicht als erfasste Daten.
5. Klick auf **Publish**.

Das Spiel selbst erfasst nichts: Spielstand, Münzen und Käufe bleiben auf dem Gerät. Die Angaben betreffen das Werbe-SDK.

### 4b. Altersfreigabe

Links unter **General** → **App Information** → **Age Rating** → **Edit**.

- Gewalt, Glücksspiel, Erwachsenen-Inhalte, Drogen und Ähnliches: überall **None**.
- Fragen zu Werbung und In-App-Käufen: wahrheitsgemäß **Yes**.
- Unbeschränkter Internetzugang, Chats, nutzergenerierte Inhalte: **No**.
- „Made for Kids“ bzw. Kategorie „Kids“: **nicht** wählen (siehe Entscheidung 2).

Erwartetes Ergebnis: die niedrigste Altersstufe.

### 4c. App Information

Links unter **General** → **App Information**.

- **Subtitle** (höchstens 30 Zeichen), Vorschlag: `Drehen, stapeln, hoch hinaus`
- **Category:** Primary `Games`, Unterkategorien `Puzzle` und `Casual`.
- **Content Rights:** „Does not contain third-party content“. Grafik und Ton sind selbst erzeugt.

### 4d. Preis und Verfügbarkeit

Links unter **Monetization** → **Pricing and Availability**.

- **Price:** Free.
- **Availability:** die Länder aus Entscheidung 3.

Wenn du Festlandchina abwählst, entfallen die beiden China-Hinweise oben auf der Versionsseite.

### 4e. In-App-Kauf fertig machen

Links unter **Monetization** → **In-App Purchases** → „Werbefrei“.

- Der Status sollte **Ready to Submit** sein. Steht dort „Missing Metadata“, fehlt meist die deutsche Lokalisierung oder der Review-Screenshot.
- Review-Screenshot: `docs/img/phase6_werbefrei_kaufblatt.png` aus dem Projekt.
- Der erste In-App-Kauf wird zusammen mit einer App-Version eingereicht. Auf der Versionsseite gibt es dafür den Abschnitt „In-App Purchases and Subscriptions“. Das kommt erst in Phase 7.

### 4f. Angaben nach dem Digital Services Act

Falls noch nicht geschehen: Unter **Business** fragt Apple, ob du „Trader“ (gewerblicher Anbieter) bist. Mit Werbung und Käufen bist du das in der Regel. Apple zeigt dann Anschrift, Telefonnummer und E-Mail auf der Store-Seite in der EU an.

---

## Schritt 5: Erster Build zu TestFlight

Voraussetzung: Schritt 3 ist erledigt.

1. Bau das Archiv im Projektordner:

```bash
flutter build ipa --release
```

2. Öffne `build/ios/archive/Runner.xcarchive` per Doppelklick in Xcode.
3. Wähle **Distribute App** → **App Store Connect** → **Upload** und folge den Vorgaben.
4. Nach 10 bis 30 Minuten erscheint der Build in App Store Connect unter **TestFlight**.
5. Leg unter **Internal Testing** eine Gruppe an und füg dich hinzu.
6. Installier auf dem iPhone die App **TestFlight** aus dem App Store und lade FlipStack darüber.

Dieser Build nutzt weiterhin Testanzeigen. Den Build mit echten Anzeigen gibt es erst für die Einreichung.

---

## Schritt 6: Phase 7, was noch fehlt

| Punkt | Wer | Anmerkung |
|---|---|---|
| App-Symbol | ich, du gibst frei | Die App hat noch das Standard-Symbol von Flutter. Ohne eigenes nimmt Apple sie nicht an. Es erscheint auch in der Einwilligungsabfrage |
| Screenshots für den Store | ich | aus dem Simulator, in den von Apple verlangten Größen |
| Beschreibung, Stichwörter, Werbetext | ich schlage vor, du gibst frei | |
| Leistung und Speicher auf dem Gerät | du testest, ich behebe | besonders hohe Türme und Plattformwechsel |
| Kauf-Animation im Shop, Aufgaben-Meldung im Spiel | ich | aus der Durchsicht von Phase 5 |
| Spieltest zum Endlosspiel | du | Rundenlänge, Endhöhe, ob die Fünfer ab Höhe 20 fair wirken |
| Build mit echten Anzeigen, Einreichung zur Prüfung | gemeinsam | Knopf „Add for Review“ |
| App in AdMob mit dem Store verknüpfen | du | geht erst nach Veröffentlichung |

### app-ads.txt

Schon erledigt: Die Datei auf bosselgo.de enthält deine AdMob-Kennung und gilt damit auch für FlipStack. Trag in App Store Connect auf der Versionsseite als **Marketing URL** ein:

```text
https://bosselgo.de/flipstack/
```

---

## Android

Steht komplett aus: App und Anzeigenblöcke in AdMob, Zahlungsprofil und In-App-Produkt in der Play Console, der erste Android-Build und die Tests auf einem Gerät. Im Projekt steht dort vorläufig Googles Beispiel-App-ID. Dafür schreibe ich eine eigene Anleitung, sobald iOS eingereicht ist oder du früher starten willst.

## Was ich von dir brauche

1. Die drei Entscheidungen aus Schritt 2.
2. Das Ergebnis deines Tests aus Schritt 1, vor allem alles, was nicht wie erwartet lief.
