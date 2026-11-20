# FLIPSTACK – Phase 6 für iOS: Schritt für Schritt

Stand: 20.11.2026 · Android folgt später in einer eigenen Anleitung.

Diese Anleitung sagt dir, was **du** bei AdMob, im Apple-Entwicklerportal und in App Store Connect einrichtest, in welcher Reihenfolge, und was du mir danach schickst. Was ich im Projekt baue, steht jeweils dabei.

Hinweis: Apple und Google benennen Menüs gelegentlich um. Wenn ein Eintrag bei dir anders heißt, such nach dem sinngleichen Begriff. Die Menünamen für App Store Connect stehen hier auf Englisch, so wie deine Oberfläche sie zeigt.

## Erledigt

- [x] AdMob: App „FlipStack“ (iOS) angelegt
- [x] AdMob: Anzeigenblöcke „Mit Prämie“ und „Interstitial“ angelegt
- [x] Apple: Bundle ID `com.floebn.flipstack` registriert
- [x] App Store Connect: App „FlipStack“ angelegt
- [x] Abschnitt A: IDs aus AdMob geschickt (im Projekt eingetragen)
- [x] Abschnitt C: Datenschutzerklärung online: https://bosselgo.de/flipstack/datenschutz/
- [x] Abschnitt B: Vereinbarung für bezahlte Apps abgeschlossen
- [x] Abschnitt D: DSGVO-Mitteilung und IDFA-Erklärung in AdMob veröffentlicht (im Simulator geprüft). Die Mitteilung hat keinen Knopf „Nicht einwilligen“ auf der ersten Ebene; Ablehnen geht über „Optionen verwalten“.

## Überblick

| Abschnitt | Wofür | Dauer bei dir | Wartezeit |
|---|---|---|---|
| A. IDs aus AdMob schicken | Werbung einbauen (Teil 6b) | 5 Minuten | keine |
| B. Vereinbarung für bezahlte Apps | Voraussetzung für jeden In-App-Kauf | 20–30 Minuten | Prüfung durch Apple, oft 1–3 Tage |
| C. Datenschutzerklärung online stellen | Pflicht für AdMob-Abfrage und App Store | abhängig von deiner Website | keine |
| D. Einwilligungsabfrage in AdMob | DSGVO und Tracking-Abfrage (Teil 6b) | 15 Minuten | keine |
| E. In-App-Kauf „Werbefrei“ | Teil 6c | 15 Minuten | keine |
| F. Sandbox-Testkonto | Kauf kostenlos testen | 5 Minuten | keine |
| G. Erster Build zu TestFlight | Werbung und Kauf am echten Gerät testen | 20 Minuten | Verarbeitung 10–30 Minuten |
| H. Angaben für den App Store | Teil 6d | 30–45 Minuten | keine |

**Fang mit A und B an.** A brauche ich sofort, B hat die längste Wartezeit.

---

## A. IDs aus AdMob schicken

Die IDs sind keine Geheimnisse; sie stehen später ohnehin in der App.

1. Öffne admob.google.com und wähle links **Apps** → **FlipStack (iOS)**.
2. Öffne **App-Einstellungen**. Dort steht die **App-ID**. Sie enthält eine Tilde: `ca-app-pub-…~…`.
3. Öffne **Anzeigenblöcke**. Bei jedem Block steht die **Anzeigenblock-ID**. Sie enthält einen Schrägstrich: `ca-app-pub-…/…`.
4. Schick mir drei Zeilen:

```text
App-ID iOS:
Mit Prämie:
Interstitial:
```

**Was ich damit mache:** Ich baue das Google-Werbe-SDK ein. Im Entwicklungs-Build laufen ausschließlich Googles öffentliche Testanzeigen. Deine echten IDs trage ich so ein, dass nur der Release-Build sie verwendet. Tippe nie auf echte Anzeigen in deiner eigenen App: Google wertet das als Betrug und kann das Konto sperren.

---

## B. Vereinbarung für bezahlte Apps (Paid Apps Agreement)

Ohne diese Vereinbarung funktioniert kein In-App-Kauf, auch nicht im Test.

1. Öffne appstoreconnect.apple.com und wähle auf der Startseite **Business**.
2. Unter **Agreements** steht die **Paid Apps Agreement**. Klick auf **View and Agree to Terms** und stimme zu. Das kann nur der Kontoinhaber.
3. **Bankkonto:** Trag unter **Bank Accounts** dein Konto ein (IBAN, Kontoinhaber, Bank).
4. **Steuerformulare:** Füll unter **Tax Forms** die verlangten Formulare aus. Für Deutschland ist das in der Regel das US-Formular W-8BEN (Bestätigung, dass du kein US-Steuerpflichtiger bist) und gegebenenfalls Angaben zur Umsatzsteuer. Wenn du unsicher bist, klär die Angaben mit einer Steuerberatung.
5. **Angaben nach dem Digital Services Act:** Apple fragt, ob du „Trader“ (gewerblicher Anbieter) bist. Mit Werbung und Käufen bist du das in der Regel. Dann musst du Anschrift, Telefonnummer und E-Mail angeben, und Apple zeigt sie auf der Seite der App im App Store in der EU an. Überleg dir vorher, welche Kontaktdaten öffentlich stehen sollen.
6. Warte, bis der Status der Vereinbarung **Active** zeigt.

**Du bist fertig, wenn** unter Business → Agreements bei „Paid Apps“ der Status „Active“ steht.

---

## C. Datenschutzerklärung online stellen

Du brauchst eine öffentlich erreichbare Adresse, zum Beispiel `https://deine-domain.de/flipstack/datenschutz`. AdMob verlangt sie für die Einwilligungsabfrage, Apple für die App.

1. Sag mir, unter welcher Adresse die Seite liegen soll und wer als Verantwortlicher genannt wird (Name, Anschrift, E-Mail).
2. Ich schreibe den Entwurf als Text. Er beschreibt: lokale Speicherung des Spielstands, Werbung über Google AdMob mit Einwilligung, die Tracking-Abfrage von Apple, den Kauf über Apple, deine Rechte nach DSGVO.
3. Du stellst den Text online. In Deutschland gehört auf dieselbe Website ein **Impressum**.
4. Lass den Text rechtlich prüfen. Mein Entwurf ersetzt keine Rechtsberatung.

**Du bist fertig, wenn** die Adresse im Browser ohne Anmeldung erreichbar ist.

---

## D. Einwilligungsabfrage in AdMob

Die App darf in der EU erst Werbung laden, nachdem der Spieler gefragt wurde. Die Abfrage erstellst du in AdMob, die App zeigt sie dann automatisch an.

1. Öffne in AdMob links **Datenschutz und Mitteilungen**.
2. **Europäische Vorschriften (DSGVO):** Klick auf **Erstellen** bzw. **Mitteilung erstellen**.
   - Wähle die App **FlipStack (iOS)** aus.
   - Trag die Adresse deiner Datenschutzerklärung aus Abschnitt C ein.
   - Sprache: Deutsch (weitere Sprachen kannst du ergänzen).
   - Wähle die Variante mit den Schaltflächen **Einwilligen**, **Nicht einwilligen** und **Optionen verwalten**. Eine Abfrage ohne gleichwertige Ablehnen-Möglichkeit ist in Deutschland angreifbar.
   - Veröffentliche die Mitteilung.
3. **IDFA-Erklärung für iOS:** Im selben Bereich gibt es eine Mitteilung, die vor Apples Tracking-Abfrage erscheint.
   - Erstelle sie für **FlipStack (iOS)** und veröffentliche sie.
   - Sie erklärt kurz, warum gleich Apples Systemdialog „Darf FlipStack dein Verhalten über Apps hinweg erfassen?“ erscheint.
4. **Werbepartner:** AdMob zeigt eine Liste der Anbieter, für die die Einwilligung gilt. Lass die Vorgabe stehen, wenn du keine besonderen Wünsche hast.

**Was ich dazu baue:** Die App fragt beim Start den Einwilligungsstatus ab, zeigt bei Bedarf deine Mitteilung und danach auf iOS Apples Tracking-Dialog. Erst danach wird das Werbe-SDK gestartet. In den Einstellungen des Spiels kommt ein Eintrag, mit dem man die Entscheidung jederzeit ändern kann. Lehnt jemand ab, läuft das Spiel normal weiter; je nach Antwort gibt es dann nicht personalisierte oder gar keine Werbung.

**Du bist fertig, wenn** beide Mitteilungen in AdMob den Status „Veröffentlicht“ haben.

---

## E. In-App-Kauf „Werbefrei“ anlegen

Voraussetzung: Abschnitt B ist „Active“.

1. Öffne in App Store Connect die App **FlipStack** und wähle links unter **Monetization** → **In-App Purchases**.
2. Klick auf **Create** bzw. das Plus.
3. **Type:** `Non-Consumable` (einmaliger Kauf, bleibt für immer).
4. **Reference Name:** `Werbefrei` (nur für dich sichtbar).
5. **Product ID:**

```text
com.floebn.flipstack.remove_ads
```

   Die Product ID lässt sich nach dem Anlegen nie wieder ändern oder neu vergeben. Tipp sie genau so ein.
6. **Availability:** alle Länder, in denen die App erscheinen soll.
7. **Price Schedule:** Wähle einen Preis. Üblich für „Werbefrei“ bei solchen Spielen sind 2,99 € bis 4,99 €. Der Preis lässt sich später ändern.
8. **App Store Localization:** Füge **German** hinzu.
   - Display Name: `Werbefrei`
   - Description: `Entfernt die Werbung zwischen den Runden dauerhaft.`
9. **Review Information:** Apple verlangt einen Screenshot der Stelle im Spiel, an der man kauft. Er liegt im Projekt: `docs/img/phase6_werbefrei_kaufblatt.png`. Lade ihn dort hoch. Der Preis im Bild (2,99 €) ist ein Platzhalter; die App zeigt später den Preis, den du hier festlegst.
10. Speichern.

**Wichtig für später:** Der erste In-App-Kauf einer App wird zusammen mit einer App-Version zur Prüfung eingereicht. Auf der Versionsseite gibt es dafür den Abschnitt „In-App Purchases and Subscriptions“.

**Entscheidung, die ich von dir brauche:** Bleibt belohnte Werbung („Weiterspielen“, „Münzen verdoppeln“) nach dem Kauf erhalten? Ich empfehle ja: „Werbefrei“ entfernt nur die unfreiwillige Vollbildwerbung, die freiwilligen Angebote bleiben. So ist es bei den meisten Spielen, und so habe ich die Beschreibung oben formuliert.

---

## F. Sandbox-Testkonto

Damit kaufst du „Werbefrei“ beliebig oft, ohne zu bezahlen.

1. Öffne in App Store Connect **Users and Access** → Reiter **Sandbox** → **Test Accounts**.
2. Klick auf das Plus und leg einen Tester an.
   - E-Mail: eine Adresse, die **noch keine Apple-ID** ist. Ein Alias deiner eigenen Adresse genügt, zum Beispiel `name+flipstack@…`.
   - Land: Deutschland.
   - Merk dir das Passwort.
3. Auf dem iPhone: **Einstellungen** → **Entwickler** → **Sandbox-Apple-Account** und dort mit dem Testkonto anmelden. Den Eintrag „Entwickler“ gibt es, sobald der Entwicklermodus aktiv ist; das ist er bei dir, weil du die App schon aufs Gerät gespielt hast.

Melde das Testkonto nie in den normalen iCloud- oder App-Store-Einstellungen an, nur an dieser Stelle.

---

## G. Erster Build zu TestFlight

Echte Werbeabläufe, die Einwilligungsabfrage und der Kauf lassen sich nur auf einem echten Gerät sinnvoll testen. TestFlight ist dafür der Weg.

1. Ich bereite das Projekt vor: Versionsnummer, Erklärung zur Verschlüsselung, Texte für die Tracking-Abfrage, App-Symbol-Prüfung.
2. Du baust das Archiv. Im Projektordner:

```bash
flutter build ipa --release
```

3. Du lädst es hoch: Öffne die erzeugte Datei `build/ios/archive/Runner.xcarchive` per Doppelklick in Xcode und wähle **Distribute App** → **App Store Connect** → **Upload**.
4. In App Store Connect erscheint der Build nach 10 bis 30 Minuten unter **TestFlight**.
5. **Internal Testing:** Leg eine Gruppe an und füg dich selbst hinzu. Interne Tester brauchen keine Prüfung durch Apple.
6. Installier auf dem iPhone die App **TestFlight** aus dem App Store und lade FlipStack darüber.

**Was du dort testest:** Erscheint die Einwilligungsabfrage, dann Apples Tracking-Dialog? Laufen Testanzeigen? Funktionieren „Weiterspielen“ und „Münzen verdoppeln“? Geht der Kauf mit dem Sandbox-Konto durch, und bleibt die Vollbildwerbung danach aus? Funktioniert „Käufe wiederherstellen“ nach dem Löschen und Neuinstallieren?

---

## H. Angaben für den App Store

Diese Punkte gehören zu Teil 6d. Die genauen Antworten bereite ich vor, sobald das Werbe-SDK eingebaut ist, weil sie davon abhängen, was es tatsächlich überträgt. Hier steht, was auf dich zukommt.

### H1. App Privacy (Datenschutz-Etikett)

Links unter **Trust & Safety** → **App Privacy**.

1. **Privacy Policy URL:** die Adresse aus Abschnitt C.
2. **Data Collection:** Mit AdMob lautet die Antwort **Ja, die App erfasst Daten**. Voraussichtlich anzugeben:

| Datenart | Zweck | Mit Identität verknüpft | Für Tracking genutzt |
|---|---|---|---|
| Device ID (Geräte- bzw. Werbe-ID) | Werbung von Drittanbietern | nein | ja |
| Product Interaction und Advertising Data (Nutzungsdaten) | Werbung von Drittanbietern, Analyse | nein | ja |
| Coarse Location (ungefährer Standort, aus der IP-Adresse) | Werbung von Drittanbietern | nein | ja |
| Crash Data und Performance Data (Diagnose) | App-Funktionalität | nein | nein |

   Das Spiel selbst erfasst nichts davon: Spielstand, Münzen und Käufe bleiben auf dem Gerät. Die Angaben betreffen das Werbe-SDK. Ich gleiche die Tabelle vor dem Einreichen mit Googles aktueller Liste für das SDK ab.

### H2. Altersfreigabe

Links unter **General** → **App Information** → **Age Rating**.

- Gewalt, Glücksspiel, Erwachsenen-Inhalte und Ähnliches: überall **None**.
- Fragen zu Werbung und Käufen: wahrheitsgemäß **Ja** (die App zeigt Werbung und bietet einen In-App-Kauf).
- Voraussichtliches Ergebnis: die niedrigste Stufe.

**Entscheidung, die ich von dir brauche:** Richtet sich das Spiel gezielt an Kinder unter 13? Ich empfehle **nein** und rate von der Kategorie „Kids“ ab. Für Kinder-Apps gelten bei Apple und in der Werbung deutlich strengere Regeln: keine personalisierte Werbung, kein Tracking, nur zugelassene Werbenetzwerke. FLIPSTACK ist ein Spiel für alle, kein Kinderspiel.

### H3. Preis und Verfügbarkeit

Links unter **Monetization** → **Pricing and Availability**.

- Preis: **Free** (0 €).
- Länder: alle, oder zunächst nur die, für die du die rechtlichen Fragen geklärt hast. Für den Start ist Deutschland, Österreich, Schweiz ein vorsichtiger Anfang; später lässt sich erweitern.

Die Hinweise zu China, die deine Seite oben anzeigt, betreffen nur den Vertrieb in Festlandchina. Wenn du China bei den Ländern abwählst, musst du dazu nichts einreichen.

### H4. App Information

Links unter **General** → **App Information**.

- **Category:** Primary `Games`, Unterkategorie `Puzzle`. Als zweite passt `Casual`.
- **Content Rights:** Die App enthält keine fremden Inhalte. Grafik und Ton sind selbst erzeugt.

### H5. Verschlüsselung (Export Compliance)

Beim ersten Hochladen fragt Apple, ob die App Verschlüsselung verwendet. FLIPSTACK nutzt nur die übliche Verschlüsselung von Internetverbindungen durch das Betriebssystem, das ist ausgenommen. Ich trage die Antwort ins Projekt ein, dann stellt Apple die Frage nicht mehr.

### H6. Datei app-ads.txt

Damit AdMob deine Anzeigenblöcke voll ausliefert, muss auf deiner Website eine Datei `app-ads.txt` liegen, und die Website muss im App Store als Website des Entwicklers eingetragen sein.

1. AdMob zeigt dir unter **Apps** → **app-ads.txt** eine Zeile zum Kopieren.
2. Leg sie als Textdatei unter `https://deine-domain.de/app-ads.txt` ab.
3. Trag dieselbe Domain in App Store Connect auf der Versionsseite als **Marketing URL** ein.

Das greift erst, wenn die App im Store ist. Du kannst es bis kurz vor der Veröffentlichung aufschieben.

### H7. App in AdMob mit dem Store verknüpfen

Sobald die App im App Store erschienen ist: in AdMob unter **App-Einstellungen** → **App-Shop-Details** die Store-Seite hinzufügen. Vorher geht das nicht.

---

## Was nicht zu Phase 6 gehört

App-Symbol, Screenshots, Beschreibungstexte und die eigentliche Einreichung zur Prüfung sind Phase 7. Der Knopf „Add for Review“ oben rechts bleibt bis dahin unberührt.

## Was ich von dir brauche, in dieser Reihenfolge

1. Die drei IDs aus Abschnitt A.
2. Adresse der Datenschutzerklärung und Angaben zum Verantwortlichen (Abschnitt C).
3. Bescheid, sobald die Vereinbarung „Active“ ist (Abschnitt B).
4. Den Preis für „Werbefrei“ und ob belohnte Werbung nach dem Kauf bleibt (Abschnitt E).
5. Die Antwort zur Zielgruppe (Abschnitt H2).
