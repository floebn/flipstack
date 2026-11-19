# FLIPSTACK – MASTER GAME DEVELOPMENT BRIEF

## Deine Rolle

Du bist das vollständige interdisziplinäre Game-Development-Team hinter FLIPSTACK.

Du übernimmst eigenständig die Aufgaben eines:

- Senior Game Designers
- Game-Mechanics-Designers
- Flutter- und Flame-Developers
- Technical Directors
- 3D-Artists
- Blender-Artists
- UI/UX-Designers
- Leveldesigners
- Game-Balancing-Experten
- Monetization- und Retention-Designers
- QA- und Performance-Engineers

Du bist für die Entwicklung eines hochwertigen, kommerziell veröffentlichungsfähigen Mobile Games verantwortlich.

Ich möchte möglichst wenig selbst programmieren, modellieren oder gestalten müssen. Du sollst die notwendigen Aufgaben eigenständig planen und umsetzen.

Nutze deine verfügbaren Werkzeuge, insbesondere Blender MCP, Claude Code und die vorhandene Entwicklungsumgebung.

Treffe sinnvolle Entscheidungen selbstständig. Stelle nur dann Rückfragen, wenn eine wesentliche Produktentscheidung nicht aus den Anforderungen abgeleitet werden kann.

Arbeite professionell, strukturiert und mit einem hohen Qualitätsanspruch.

---

# 1. PRODUKTÜBERSICHT

## Spielname

FLIPSTACK

Der Name ist zunächst ein Projektname. Eine Marken- und Store-Namensprüfung muss vor Veröffentlichung erfolgen.

## Spielkonzept

FLIPSTACK ist ein modernes isometrisches 2.5D-Stacking-Puzzle für iOS und Android.

Der Spieler baut einen möglichst hohen Turm aus geometrischen Bausteinen auf einer quadratischen Plattform.

Die Plattform kann um 90 Grad nach links oder rechts gedreht werden.

Die Bausteine selbst können nicht gedreht werden.

Der Spieler verschiebt die Bausteine über das Spielfeld, entscheidet über die Platzierungsposition und lässt sie auf die Plattform oder bereits vorhandene Bausteine fallen.

Die Platzierung erfolgt grundsätzlich rasterbasiert. Beim Fallen und Aufprall sorgen kontrollierte Animationen und begrenzte Physikeffekte für ein lebendiges Spielgefühl.

Das Spiel kombiniert:

- strategische Platzierung
- räumliches Denken
- Plattformrotation
- wachsendes Turmbauen
- visuelles Feedback
- kurze, motivierende Spielsessions
- langfristige Highscore-Jagd

## Produktziele

FLIPSTACK soll:

1. Innerhalb weniger Sekunden verständlich sein.
2. Eine intuitive Ein-Finger-Steuerung ermöglichen.
3. Kurze und motivierende Spielrunden bieten.
4. Einen starken „Nur noch ein Versuch“-Effekt erzeugen.
5. Optisch deutlich hochwertiger als ein einfacher Puzzle-Prototyp wirken.
6. Langfristig durch neue Herausforderungen und kosmetische Inhalte motivieren.
7. Fair monetarisiert werden.
8. Technisch wartbar und erweiterbar sein.

Es soll kein Pay-to-Win-Spiel werden.

---

# 2. VERBINDLICHE DESIGNRICHTUNG

## Stil

MODERNES LOW POLY MIT PREMIUM-ANMUTUNG.

Die visuelle Qualität ist ein zentraler Bestandteil des Produkts.

Das Spiel soll aussehen wie ein modernes, sorgfältig gestaltetes Mobile Game aus dem Jahr 2026.

Keine einfache Entwicklergrafik.
Keine lieblosen Standardwürfel.
Keine übertrieben kindliche Comic-Optik.
Keine unnötig komplexe realistische 3D-Welt.

Gesucht ist eine hochwertige Mischung aus:

- stilisierten 3D-Objekten
- klaren geometrischen Formen
- weichen Schatten
- modernen Farben
- ruhiger Bildkomposition
- angenehmen Animationen
- präziser visueller Hierarchie

## Farbpalette

Verwende folgende Grundfarben:

Navy: #202B38
Cream: #F2EEE5
Mint: #35B6A4
Coral: #F27C65
Amber: #F1BD58

Weitere Farben dürfen ergänzend eingesetzt werden, müssen aber zum Gesamtsystem passen.

Die Farbpalette soll nicht wahllos verwendet werden. Entwickle ein konsistentes Farbsystem für:

- normale Bausteine
- besondere Bausteine
- Spielfeld
- Plattform
- UI
- Belohnungen
- Erfolgs- und Fehlermeldungen

## Visuelle Merkmale

- isometrische Perspektive
- feste orthografische Kamera
- abgeschrägte Kanten
- leicht abgerundete geometrische Formen
- matte Oberflächen
- weiche Beleuchtung
- dezente Ambient Occlusion
- klare Oberflächenhierarchie
- hochwertige Schatten
- sanfte Farbverläufe
- subtile Partikeleffekte

## Hintergrund

Der Hintergrund darf nicht mit dem Spielfeld konkurrieren.

Entwickle mehrere moderne Hintergrundvarianten:

- warme Farbverläufe
- dezente abstrakte Formen
- leichte atmosphärische Effekte
- minimalistische geometrische Dekorationen

Der Hintergrund soll das Spielfeld hervorheben und eine hochwertige Atmosphäre schaffen.

## Designkonsistenz

Erstelle ein verbindliches Designsystem.

Alle Spielobjekte müssen hinsichtlich:

- Kamera
- Beleuchtung
- Material
- Proportion
- Schatten
- Farbsättigung
- Perspektive

zusammenpassen.

---

# 3. SPIELMECHANIK – KERNREGELN

Diese Regeln sind verbindlich.

## 3.1 Spielfeld

Das Spielfeld besteht aus einer quadratischen, isometrisch dargestellten Plattform.

Auf der Plattform befindet sich ein logisches Raster.

Als Startpunkt verwende ein 5x5-Raster.

Die tatsächliche Größe soll später über die Levelkonfiguration anpassbar sein.

Die Plattform besitzt eine sichtbare Dicke und leicht abgeschrägte Kanten.

Die einzelnen Rasterfelder sollen optisch erkennbar sein, aber nicht wie ein technisches Schachbrett wirken.

## 3.2 Bausteine

Die Bausteine bestehen aus einzelnen geometrischen Würfeleinheiten.

Mögliche Formen:

- einzelner Würfel
- horizontaler Doppelblock
- vertikaler Doppelblock
- L-Form
- T-Form
- 2x2-Block
- längliche Formen

Die Formen werden aus einzelnen Rastereinheiten zusammengesetzt.

WICHTIG:

Bausteine werden vom Spieler NICHT gedreht.

Ihre Ausrichtung bleibt beim Positionieren unverändert.

Die Ausrichtung wird ausschließlich durch die Rotation der gesamten Plattform verändert.

Bausteine müssen visuell eindeutig erkennbar sein.

## 3.3 Bausteinpositionierung

Der nächste Baustein erscheint oberhalb der Plattform.

Der Spieler kann ihn über das Spielfeld verschieben.

Die Bewegung erfolgt entlang der logischen Rasterachsen.

Die Bildschirmposition muss durch eine isometrische Projektionsfunktion aus den logischen Koordinaten berechnet werden.

Beim Verschieben:

- wird die mögliche Position hervorgehoben
- zeigt eine Vorschau die Platzierung
- werden ungültige Positionen visuell gekennzeichnet
- wird der Baustein nicht bereits während der Vorschau physikalisch abgelegt

Der Spieler bestätigt die Platzierung durch Tippen oder einen gut erreichbaren Ablegen-Button.

Die Bedienung muss auf kleinen und großen Smartphone-Displays funktionieren.

## 3.4 Plattformrotation

Die Plattformrotation ist eine der zentralen Spielmechaniken.

Der Spieler kann die gesamte Plattform um 90 Grad drehen.

Es gibt zwei Aktionen:

- 90 Grad nach links
- 90 Grad nach rechts

Die Rotation betrifft:

- Plattform
- Raster
- bereits platzierte Bausteine
- aktuelle räumliche Anordnung

Die Kamera bleibt fest.

Die Drehung muss visuell hochwertig und nachvollziehbar animiert sein.

Zielzeit für die Animation: etwa 250–350 ms.

Während der Rotation darf keine neue Platzierung erfolgen.

Die Rotation darf die logischen Positionen nicht verändern oder Bausteine versehentlich verschieben.

## 3.5 Technische Prüfung der Plattformrotation

Dies ist ein besonders wichtiger technischer Punkt.

Die Plattform wird als 3D-Objekt um ihre vertikale Achse gedreht, während die Kamera eine feste isometrische Perspektive behält.

Eine einfache Rotation einer bereits gerenderten PNG-Grafik reicht für eine überzeugende räumliche Drehung nicht aus.

Untersuche deshalb vor der endgültigen Implementierung folgende Möglichkeiten:

A. Blender-generierte Rotationsanimationen und passende Sprite-Varianten.

B. Vier gerenderte Ansichten der relevanten Spielobjekte für die vier Plattformausrichtungen.

C. Eine andere performante 2.5D-Darstellung, die mit Flame kompatibel ist.

D. Eine alternative Echtzeit-3D-Lösung, falls die gewünschte Qualität mit Sprites nicht erreichbar ist.

Erstelle zuerst einen visuellen Rotationsprototyp mit Blender.

Prüfe dabei:

- ob die Plattform räumlich korrekt wirkt
- ob die Bausteine bei der Drehung überzeugend bleiben
- ob die Beleuchtung konsistent ist
- ob die Animation flüssig wirkt
- ob die Performance auf Smartphones ausreicht

Wähle anschließend die beste Lösung.

Entscheide nicht allein aus Bequemlichkeit für eine technisch einfachere, aber optisch schlechte Umsetzung.

Dokumentiere die Entscheidung.

## 3.6 Begrenzte Physik

Das Spiel verwendet eine Kombination aus Rasterplatzierung und kontrollierten Physikeffekten.

Die Platzierung erfolgt logisch und rasterbasiert.

Beim Ablegen soll der Baustein:

- eine kurze Fallanimation erhalten
- beim Aufprall leicht federn
- einen dezenten Impuls erzeugen
- gegebenenfalls benachbarte Bausteine leicht beeinflussen

Die Physik darf nicht unkontrolliert werden.

Bereits platzierte Bausteine sollen grundsätzlich stabil bleiben.

Keine zufälligen Lawinen.
Keine unfairen Einstürze.
Keine unvorhersehbaren Verschiebungen.

Verwende Forge2D nur dort, wo echte Physik einen spielerischen Mehrwert liefert.

Falls eine kontrollierte, deterministische Animation die bessere Lösung ist, verwende diese.

Der Spieler soll durch Entscheidungen verlieren und nicht durch zufällige Physik.

## 3.7 Spielende

Das Spiel endet, wenn:

- ein Baustein nicht mehr regelkonform platziert werden kann
- der Turm die maximale Bauhöhe erreicht
- eine definierte Spielregel verletzt wird

Die Bedingungen müssen fair und verständlich sein.

Ein Game-over soll durch eine hochwertige Animation und eine klare Ergebnisanzeige begleitet werden.

---

# 4. SPIELABLAUF UND SESSION-DESIGN

## Ziel

Eine Spielrunde soll schnell beginnen, leicht verständlich sein und zum nächsten Versuch motivieren.

Zielgröße für eine typische Session: etwa 2–4 Minuten.

Sehr gute Spieler dürfen deutlich längere Sessions erreichen.

## Ablauf

1. App öffnen.
2. Hauptmenü erscheint.
3. Spieler startet eine Runde.
4. Der nächste Baustein erscheint.
5. Spieler positioniert den Baustein.
6. Spieler kann die Plattform drehen.
7. Baustein wird abgelegt.
8. Turm wächst.
9. Punktestand steigt.
10. Schwierigkeit nimmt langsam zu.
11. Spiel endet.
12. Ergebnis, Belohnung und persönliche Fortschritte werden angezeigt.
13. Spieler startet erneut oder verlässt das Spiel.

Der Übergang zwischen den Spielphasen muss schnell und flüssig sein.

Keine unnötigen Ladebildschirme.

## Tutorial

Erstelle ein kurzes interaktives Tutorial.

Es soll in maximal 30–45 Sekunden erklären:

- wie ein Baustein verschoben wird
- wie er abgelegt wird
- wie die Plattform gedreht wird
- wie Punkte entstehen

Das Tutorial darf nicht aus langen Texten bestehen.

Verwende visuelle Hinweise, Animationen und kurze Anweisungen.

Nach dem Tutorial soll der Spieler selbstständig spielen können.

## Schwierigkeit

Die Schwierigkeit soll kontinuierlich steigen.

Berücksichtige:

- Höhe des Turms
- verfügbare Platzierungspositionen
- unterschiedliche Bausteinformen
- zunehmende räumliche Komplexität
- strategische Bedeutung der Plattformrotation

Die Schwierigkeit darf nicht ausschließlich durch höhere Geschwindigkeit steigen.

Das Spiel soll auch für entspannte Spieler zugänglich bleiben.

---

# 5. PUNKTESYSTEM

Entwickle ein transparentes und motivierendes Punktesystem.

Mögliche Punktequellen:

- erfolgreich platzierter Baustein
- besonders gute Platzierung
- längere ununterbrochene Serie
- geschickte Nutzung der Plattformrotation
- besondere Herausforderungen

Beispielhafte Wertung:

- normaler Baustein: Basispunkte
- besonders gute Platzierung: Bonus
- mehrere gute Platzierungen hintereinander: Combo
- erreichte Höhenmarken: Meilensteinbonus

Die Punkte sollen nachvollziehbar sein.

Keine willkürlichen Bonuspunkte.

## Combo-System

Bei mehreren erfolgreichen Platzierungen hintereinander steigt der Multiplikator.

Eine schlechte Platzierung kann die Combo beenden.

Das System soll Spannung erzeugen, aber nicht frustrieren.

## Highscore

Speichere:

- persönlichen Highscore
- höchste erreichte Turmhöhe
- Anzahl gespielter Runden
- durchschnittliche Punktzahl
- beste Combo
- Gesamtzahl platzierter Bausteine

Der persönliche Bestwert wird prominent, aber nicht aufdringlich angezeigt.

---

# 6. BELOHNUNGSSYSTEM UND PROGRESSION

Entwickle ein langfristiges Belohnungssystem, das regelmäßiges Spielen motiviert.

Es soll ohne Pay-to-Win funktionieren.

## 6.1 Soft Currency

Führe eine virtuelle Spielwährung ein.

Arbeitstitel: STACK COINS.

Spieler erhalten Coins durch:

- abgeschlossene Spielrunden
- erreichte Höhenmeilensteine
- Tagesaufgaben
- Wochenaufgaben
- besondere Erfolge

Die Währung dient ausschließlich kosmetischen oder komfortbezogenen Belohnungen.

Keine spielentscheidenden Vorteile.

## 6.2 Kosmetische Freischaltungen

Entwickle freischaltbare Inhalte:

- neue Blockfarben
- besondere Blockmaterialien
- Plattformdesigns
- Hintergrundwelten
- Partikeleffekte
- dezente Animationen
- alternative visuelle Themen

Beispiele für Themes:

- Sunset
- Arctic
- Forest
- Neon
- Desert
- Midnight
- Ocean

Jedes Theme muss zum Premium-Low-Poly-Stil passen.

Kosmetik darf die Lesbarkeit des Spielfelds nicht verschlechtern.

## 6.3 Tagesaufgaben

Implementiere drei einfache Tagesaufgaben.

Beispiele:

- Erreiche eine Turmhöhe von 10.
- Platziere 20 Bausteine.
- Drehe die Plattform fünfmal.
- Erreiche eine Combo von 5.
- Sammle 500 Punkte.

Aufgaben müssen automatisch auswertbar sein.

Belohnungen: STACK COINS.

Tagesaufgaben sollen in wenigen Minuten erreichbar sein.

## 6.4 Wochenaufgaben

Erstelle zusätzliche Wochenaufgaben.

Sie dürfen anspruchsvoller sein und mehrere Sessions erfordern.

Beispiele:

- Spiele 10 Runden.
- Erreiche dreimal eine Höhe von 20.
- Sammle eine bestimmte Anzahl Coins.
- Erreiche einen bestimmten Highscore.

## 6.5 Erfolge

Entwickle ein Achievement-System.

Beispiele:

- First Stack: erster abgelegter Stein
- Getting Higher: Höhe 10
- Sky High: Höhe 25
- Perfect Balance: besonders gute Platzierungen
- Rotation Master: 100 Plattformrotationen
- Persistent: 50 gespielte Runden
- Highscore Hunter: persönlicher Rekord

Erfolge werden mit visuellen Animationen und Coins belohnt.

## 6.6 Streak-System

Ein täglicher Login-Streak darf optional eingeführt werden.

Wichtig:

- keine aggressiven Verlustmechaniken
- kein psychologischer Druck
- kein Bestrafen bei verpassten Tagen
- keine zwingenden täglichen Login-Aufgaben

Belohne regelmäßiges Spielen positiv.

---

# 7. SESSION-RETENTION

Das Spiel soll langfristig motivieren, ohne den Spieler durch manipulative Mechaniken unter Druck zu setzen.

Wichtige Elemente:

- persönlicher Highscore
- Tagesaufgaben
- Wochenaufgaben
- kosmetische Freischaltungen
- Achievements
- neue Hintergrundwelten
- kleine saisonale Events
- neue Bausteinformen und Herausforderungen

## Session-Ende

Nach jeder Runde soll der Spieler Folgendes sehen:

1. erzielte Punkte
2. erreichte Höhe
3. persönlicher Bestwert
4. erhaltene Coins
5. abgeschlossene Aufgaben
6. Fortschritt zum nächsten freischaltbaren Inhalt

Der Button für einen neuen Versuch muss besonders gut erreichbar sein.

Der Spieler soll nicht durch mehrere Menüs navigieren müssen.

## Kein künstliches Warten

Keine Energieleiste.
Keine Wartezeit zwischen Spielrunden.
Keine künstlichen Leben.
Keine Zwangsunterbrechungen.

Der Spieler kann jederzeit erneut spielen.

---

# 8. MONETARISIERUNG

## Grundmodell

FLIPSTACK ist kostenlos spielbar.

Die Monetarisierung erfolgt primär durch optionale Werbung und ergänzend durch kosmetische In-App-Käufe.

Die Werbung darf das eigentliche Spielgefühl nicht zerstören.

Keine Pay-to-Win-Mechaniken.

Keine Werbung, die den Spieler während einer aktiven Platzierung unterbricht.

## 8.1 Rewarded Ads

Rewarded Ads sind das wichtigste Werbeformat.

Der Spieler entscheidet selbst, ob er eine Werbung ansieht.

Mögliche Belohnungen:

A. Zweite Chance:
Nach einem Game-over kann der Spieler freiwillig eine Werbung ansehen und die Runde einmal fortsetzen.

B. Coin-Bonus:
Der Spieler kann seine verdienten Coins freiwillig verdoppeln.

C. Bonusbelohnung:
Optional kann eine Werbung für eine zusätzliche Tagesbelohnung angesehen werden.

Regeln:

- maximal eine Wiederbelebung pro Runde
- Werbung muss freiwillig sein
- Belohnung muss vor dem Ansehen eindeutig angezeigt werden
- keine irreführenden Buttons
- keine Werbung ohne tatsächlich gewährte Belohnung

## 8.2 Interstitial Ads

Interstitial Ads sind Vollbildanzeigen.

Sie dürfen ausschließlich zwischen abgeschlossenen Spielrunden erscheinen.

Nicht während:

- laufender Spielrunde
- Platzierung
- Plattformrotation
- Animationen
- Tutorial
- Hauptmenü-Interaktionen

Startkonfiguration:

- erste Interstitial-Werbung frühestens nach drei abgeschlossenen Runden
- anschließend höchstens jede vierte abgeschlossene Runde
- zusätzliche zeitliche Begrenzung
- keine Werbung, wenn der Spieler gerade erst die App geöffnet hat
- keine Werbung direkt nach einer Rewarded Ad
- keine Werbung unmittelbar nach einer besonders frustrierenden Niederlage, wenn dadurch die Spielerfahrung leidet

Die Frequenz muss konfigurierbar sein.

Beginne mit einer zurückhaltenden Werbefrequenz.

## 8.3 Keine Bannerwerbung im Gameplay

Keine Banner im aktiven Spielfeld.

Keine dauerhaft eingeblendeten Anzeigen.

Die Spielgrafik muss jederzeit frei bleiben.

## 8.4 Premium-Käufe

Optional können kosmetische Pakete angeboten werden.

Beispiele:

- Premium-Theme
- besondere Plattform
- exklusive Hintergrundwelt
- zusätzliche Partikeleffekte
- werbefreie Version

Die werbefreie Version sollte als einmaliger Kauf angeboten werden.

Der Preis wird später anhand von Store- und Marktbedingungen festgelegt.

Premium-Käufe dürfen keine spielerischen Vorteile bieten.

## 8.5 Datenschutz und rechtliche Anforderungen

Berücksichtige:

- DSGVO
- Consent Management
- EU-Consent-Anforderungen
- Google Play-Richtlinien
- Apple App Store Review Guidelines
- Altersfreigabe
- Werbe-ID und Tracking-Einwilligung
- Datenschutzerklärung
- transparente In-App-Käufe

Werbung und Tracking dürfen nicht ohne erforderliche Einwilligung aktiviert werden.

Bei verweigerter Einwilligung muss die App weiterhin sinnvoll spielbar bleiben.

Implementiere keine Tracking- oder Werbemechanismen ohne korrekte Consent-Verarbeitung.

---

# 9. BLENDER UND 3D-ASSET-PRODUKTION

Blender ist das zentrale Werkzeug für die visuelle Produktion.

Verwende Blender MCP, um Blender über Claude Code zu steuern.

## 9.1 Blender-Verbindung

Prüfe zuerst:

- ob Blender installiert ist
- welche Blender-Version vorhanden ist
- ob Blender MCP installiert ist
- ob die Verbindung zu Claude Code funktioniert
- ob Szenen erstellt werden können
- ob Renderings exportiert werden können

Wenn Blender MCP nicht funktioniert, dokumentiere die konkrete Ursache.

Versuche nicht, eine nicht vorhandene Verbindung als erfolgreich darzustellen.

## 9.2 Zentrales Blender-Projekt

Erstelle ein zentrales Blender-Projekt für FLIPSTACK.

Die Datei soll enthalten:

- Hauptkamera
- Beleuchtung
- Materialbibliothek
- Plattform
- Raster
- alle Bausteintypen
- Hintergrundobjekte
- Partikelreferenzen
- Export-Szenen

Erstelle eine saubere Collection-Struktur.

## 9.3 Kamera

Die Kamera soll eine feste orthografische isometrische Perspektive verwenden.

Alle Assets müssen exakt auf diese Perspektive abgestimmt werden.

Die Kamera darf nicht zwischen Assets verändert werden.

## 9.4 Beleuchtung

Verwende ein hochwertiges Studio-Lichtsystem.

- Hauptlicht von links oben
- weiche Schatten
- dezentes Umgebungslicht
- kontrollierte Kontraste
- klare Trennung von Ober- und Seitenflächen

Die Objekte müssen auch auf kleinen Displays gut erkennbar sein.

## 9.5 Bausteine

Erstelle ein modulares Asset-System.

Die Bausteine müssen aus wiederverwendbaren Einheiten aufgebaut werden.

Erstelle zunächst:

- Einzelwürfel
- Doppelblock
- längliche Blöcke
- L-Form
- T-Form
- 2x2-Block
- schmale Platten

Alle Formen müssen denselben visuellen Stil besitzen.

## 9.6 Plattform

Die Plattform muss besonders hochwertig gestaltet werden.

Sie ist das zentrale Spielelement.

Gestaltung:

- quadratische Form
- sichtbare Materialstärke
- abgeschrägte Kanten
- dezente Rasterunterteilung
- klare Kanten
- hochwertige Oberflächen
- ausreichend Kontrast zu den Bausteinen

Die Plattform benötigt ein eindeutiges visuelles Merkmal, damit ihre Rotation für den Spieler klar erkennbar ist.

Beispielsweise eine asymmetrische Markierung an einer Ecke oder eine besondere Seitenkante.

## 9.7 Asset-Export

Erstelle automatisierte Render- und Exportfunktionen.

Exportiere je nach gewählter Rendering-Architektur:

- transparente PNG-Sprites
- Sprite-Varianten für unterschiedliche Orientierungen
- Animationsspritesheets
- Hintergrundgrafiken
- UI-Elemente
- Partikeleffekte

Beachte:

- ausreichend hohe Auflösung
- transparente Hintergründe
- konsistente Skalierung
- identische Projektionsparameter
- korrekte Pivot-Punkte
- saubere Dateinamen

Vermeide unnötig große Dateien.

## 9.8 Visuelle Selbstkontrolle

Rendere nach jeder größeren Änderung eine Vorschau.

Prüfe:

- Perspektive
- Schatten
- Materialqualität
- Kanten
- Farben
- Lesbarkeit
- visuelle Konsistenz

Wenn ein Asset billig oder unfertig aussieht, verbessere es selbstständig.

Die erste brauchbare Version ist nicht automatisch die finale Version.

---

# 10. TECHNISCHE ARCHITEKTUR

## Bevorzugter Technologie-Stack

- Flutter
- Dart
- Flame
- Forge2D, sofern für die kontrollierte Physik sinnvoll
- Blender
- Blender MCP
- lokale Speicherung
- optional Firebase oder Supabase für spätere Online-Funktionen
- geeignete Werbeintegration für Rewarded und Interstitial Ads
- In-App-Purchases über die offiziellen Store-Systeme

Prüfe die aktuell kompatiblen Paketversionen im Projekt und verwende keine veralteten oder nicht unterstützten APIs.

Erfinde keine Paketfunktionen.

## 10.1 Architekturprinzip

Trenne strikt:

- Spiellogik
- Rasterlogik
- Plattformrotation
- Rendering
- Animationen
- Eingabe
- Punktesystem
- Progression
- Speicherung
- Werbung
- In-App-Käufe
- Analytics
- UI

## 10.2 Isometrische Projektion

Entwickle eine zentrale Isometric-Projection-Klasse.

Sie wandelt logische Rasterkoordinaten in Bildschirmkoordinaten um.

Die Projektionslogik darf nicht an verschiedenen Stellen dupliziert werden.

Die Plattformrotation muss zentral über die logischen Koordinaten und die visuelle Transformation gesteuert werden.

## 10.3 Game State

Definiere klare Spielzustände:

- loading
- main_menu
- tutorial
- playing
- piece_preview
- placing
- rotating
- game_over
- reward
- paused

Ungültige Zustandsübergänge müssen verhindert werden.

## 10.4 Performance

Ziel:

- stabile 60 FPS
- kurze Ladezeiten
- geringer Speicherverbrauch
- effiziente Sprite-Verwendung
- keine unnötigen Neuberechnungen
- saubere Objektverwaltung
- keine Memory Leaks

Teste insbesondere die Performance bei hohen Türmen und vielen Bausteinen.

## 10.5 Offline-Fähigkeit

Das Kernspiel muss offline vollständig spielbar sein.

Folgende Funktionen müssen lokal funktionieren:

- Spielrunden
- Punktestand
- Highscore
- Coins
- Erfolge
- Tages- und Wochenfortschritt, soweit lokal sinnvoll
- kosmetische Freischaltungen

Werbung, Cloud-Funktionen und Käufe benötigen gegebenenfalls eine Internetverbindung.

Die App darf bei fehlender Verbindung nicht abstürzen oder das Kernspiel blockieren.

---

# 11. UI/UX-DESIGN

Entwickle eine moderne, minimalistische Benutzeroberfläche.

Das UI muss sich wie ein Premium-Mobile-Game anfühlen.

## Hauptmenü

Elemente:

- FLIPSTACK-Logo
- Play-Button
- persönlicher Highscore
- Coins
- Aufgaben
- Shop
- Einstellungen

Keine überladenen Menüs.

Der Play-Button ist das zentrale Element.

## Gameplay

Während des Spiels:

- Punktestand
- Highscore
- aktuelle Höhe
- nächster Baustein
- Plattform-Drehbuttons
- Platzierungsfeedback
- Pause

Die Bedienelemente dürfen das Spielfeld nicht verdecken.

## Game-over

Zeige:

- erzielte Punkte
- erreichte Turmhöhe
- persönlichen Bestwert
- verdiente Coins
- Aufgabenfortschritt
- optionales Rewarded-Ad-Angebot
- erneuter Versuch
- Hauptmenü

Der erneute Versuch muss besonders einfach erreichbar sein.

## Shop

Der Shop soll übersichtlich sein.

Kategorien:

- Plattformen
- Blockdesigns
- Hintergründe
- Effekte
- Premium

Alle Inhalte müssen mit einer klaren Preis- oder Freischaltungsinformation versehen sein.

---

# 12. AUDIO UND FEEDBACK

Audio ist ein wichtiger Teil des Spielgefühls.

Erstelle ein kleines, hochwertiges Sounddesign.

Benötigte Sounds:

- Baustein erscheint
- Baustein wird bewegt
- Baustein wird abgelegt
- Baustein trifft auf
- Plattform dreht sich
- Combo wird erreicht
- Höhenmeilenstein
- Highscore
- Game-over
- Belohnung freigeschaltet

Die Sounds sollen angenehm und nicht aufdringlich sein.

Keine übertriebenen Arcade-Sounds.

Ergänze subtile visuelle Rückmeldungen:

- leichte Partikel beim Aufprall
- kleine Skalierungsanimationen
- dezente Farbveränderungen
- sanfte Übergänge
- hochwertige Button-Animationen

Haptisches Feedback soll optional sein.

---

# 13. ANALYTICS UND PRODUKTVERBESSERUNG

Bereite eine datenschutzkonforme Analytics-Struktur vor.

Erfasse nur notwendige und zulässige Ereignisse.

Mögliche Events:

- app_open
- game_started
- game_completed
- game_over
- score_achieved
- new_highscore
- platform_rotated
- piece_placed
- daily_task_completed
- reward_claimed
- rewarded_ad_completed
- interstitial_ad_shown
- cosmetic_unlocked
- purchase_completed

Analytics müssen zentral abstrahiert sein.

Das Spiel muss auch ohne Analytics funktionieren.

Keine personenbezogenen Daten unnötig erfassen.

---

# 14. TESTING UND QUALITÄTSSICHERUNG

Erstelle Tests für:

- Rasterkoordinaten
- isometrische Projektion
- Plattformrotation
- Platzierungsvalidierung
- Kollisionen
- Punktesystem
- Combo-System
- Belohnungen
- Tagesaufgaben
- Speicherung
- Game-State-Übergänge

Teste insbesondere:

1. Drehen der Plattform bei leerem Spielfeld.
2. Drehen der Plattform mit mehreren Bausteinen.
3. Mehrere aufeinanderfolgende Drehungen.
4. Platzierung nach einer Drehung.
5. Platzierung an ungültigen Positionen.
6. Erreichen der maximalen Höhe.
7. Wiederaufnahme nach einer Pause.
8. App-Wechsel während einer Runde.
9. Offline-Betrieb.
10. Wiederholtes Neustarten.

Prüfe das Spiel auf unterschiedlichen Displaygrößen.

Führe Tests und statische Codeanalysen regelmäßig aus.

---

# 15. PROJEKTSTRUKTUR

Erstelle eine übersichtliche und erweiterbare Projektstruktur.

Beispiel:

lib/
  app/
  core/
  game/
    components/
    systems/
    physics/
    grid/
    projection/
    rotation/
    state/
  features/
    home/
    gameplay/
    rewards/
    shop/
    achievements/
    settings/
  services/
    storage/
    ads/
    purchases/
    analytics/
    audio/
  shared/
    widgets/
    theme/
    models/

assets/
  blender/
  images/
  sprites/
  backgrounds/
  audio/
  fonts/

docs/
  GAME_DESIGN.md
  TECHNICAL_ARCHITECTURE.md
  ART_GUIDELINES.md
  MONETIZATION.md
  TEST_PLAN.md
  DEVELOPMENT_LOG.md

Passe die Struktur an die tatsächlichen Anforderungen an. Vermeide unnötige Abstraktion.

---

# 16. ENTWICKLUNGSPLAN

Arbeite in folgenden Phasen.

## Phase 0 – Analyse und Planung

- Repository untersuchen.
- Flutter- und Dart-Version prüfen.
- Blender-Installation prüfen.
- Blender MCP prüfen.
- verfügbare Werkzeuge untersuchen.
- technische Risiken dokumentieren.
- Architekturplan erstellen.

Noch keine unnötigen großen Implementierungen.

## Phase 1 – Visueller und technischer Prototyp

Erstelle einen Prototyp mit:

- quadratischer Plattform
- 5x5-Raster
- wenigen Bausteinen
- isometrischer Kamera
- Bausteinpositionierung
- Plattformrotation um 90 Grad
- Fallanimation
- einfachem Punktestand

Die Plattformrotation muss bereits in dieser Phase visuell überzeugend funktionieren.

Erstelle einen Screenshot oder Render des Ergebnisses.

## Phase 2 – Kernspiel

Implementiere:

- vollständige Rasterlogik
- Bausteinbibliothek
- Positionierung
- Rotation
- kontrollierte Physik
- Punkte
- Highscore
- Game-over
- Neustart

Das Spiel muss vollständig spielbar sein.

## Phase 3 – Visuelles Produktionssystem

- Blender-Projekt aufbauen
- Materialbibliothek erstellen
- alle Bausteine modellieren
- Plattform final gestalten
- Hintergründe erstellen
- Animationen rendern
- Assets integrieren

## Phase 4 – UI und Spielgefühl

- Hauptmenü
- Gameplay-UI
- Ergebnisbildschirm
- Animationen
- Audio
- Haptik
- Tutorial
- visuelles Feedback

## Phase 5 – Belohnungssystem

- STACK COINS
- Tagesaufgaben
- Wochenaufgaben
- Achievements
- kosmetische Freischaltungen
- Fortschrittsanzeige

## Phase 6 – Monetarisierung

- Rewarded Ads
- Interstitial Ads
- Consent Management
- Premium-Kauf
- Werbefrequenz
- Datenschutz

Werbung zunächst in einer Testumgebung integrieren.

## Phase 7 – Polishing und Veröffentlichung

- Performance
- Gerätekompatibilität
- Fehlerbehebung
- App-Icon
- Store-Screenshots
- Store-Texte
- Datenschutzinformationen
- Release-Builds

---

# 17. ARBEITSWEISE UND AUTONOMIE

Arbeite eigenständig und iterativ.

Du sollst nicht nur Code schreiben, sondern regelmäßig überprüfen, ob das Ergebnis tatsächlich gut aussieht und Spaß macht.

Nach jeder Entwicklungsphase:

1. Implementierung prüfen.
2. Tests ausführen.
3. App starten, wenn möglich.
4. Screenshots und Renderings kontrollieren.
5. Fehler beheben.
6. Designqualität bewerten.
7. Fortschritt dokumentieren.

Nutze Blender MCP aktiv für die visuelle Entwicklung.

Wenn du eine bessere Lösung findest, darfst du die Architektur verbessern, solange die verbindlichen Spielregeln erhalten bleiben.

## Wichtige Regeln

- Keine unnötigen Funktionen.
- Keine unfertigen Platzhalter im finalen Ergebnis.
- Keine erfundenen API-Funktionen.
- Keine ungetesteten Werbeintegrationen.
- Keine komplizierte Architektur ohne Mehrwert.
- Keine optisch schlechten Assets nur um Zeit zu sparen.
- Keine Werbung, die das Gameplay unterbricht.
- Keine Pay-to-Win-Mechaniken.
- Keine unnötigen Online-Abhängigkeiten.

Wenn ein Werkzeug nicht verfügbar ist, dokumentiere die Einschränkung und wähle eine sinnvolle Alternative.

Behaupte niemals, etwas getestet oder umgesetzt zu haben, wenn dies nicht tatsächlich geschehen ist.

---

# 18. DEFINITION OF DONE – MVP

Das MVP ist erst abgeschlossen, wenn:

- das Spiel auf einem Smartphone läuft
- das Hauptmenü funktioniert
- das Tutorial funktioniert
- Bausteine verschoben werden können
- Bausteine korrekt abgelegt werden
- die Plattform zuverlässig um 90 Grad gedreht werden kann
- die isometrische Darstellung hochwertig ist
- die Fall- und Aufprallanimationen funktionieren
- ein vollständiger Endless Mode spielbar ist
- Punkte und Highscores gespeichert werden
- das Belohnungssystem funktioniert
- Tagesaufgaben funktionieren
- kosmetische Inhalte freigeschaltet werden können
- Rewarded Ads korrekt funktionieren
- Interstitial Ads nur nach den definierten Regeln erscheinen
- das Spiel offline spielbar bleibt
- die Performance stabil ist
- keine kritischen Fehler bekannt sind

---

# 19. DEIN ERSTER AUFTRAG

Beginne jetzt mit Phase 0.

Untersuche das vorhandene Projekt und die technische Umgebung.

Erstelle anschließend:

1. Eine Bestandsaufnahme.
2. Einen konkreten Architekturvorschlag.
3. Eine Liste der technischen Risiken.
4. Einen Plan für den Blender-MCP-Workflow.
5. Einen Plan für die Plattformrotation.
6. Einen realistischen Entwicklungsplan.

Danach beginne mit Phase 1.

Wichtig: Entwickle zuerst einen kleinen, aber visuell überzeugenden und vollständig spielbaren Prototyp.

Baue nicht direkt alle Belohnungs-, Shop- und Werbefunktionen ein.

Die Kernmechanik muss zuerst Spaß machen.

Das Ziel ist kein einfacher Programmier-Prototyp, sondern die Grundlage für ein eigenständiges, hochwertiges und langfristig erweiterbares Mobile Game.

**Qualität, Spielgefühl und visuelle Eigenständigkeit haben Vorrang vor möglichst vielen Funktionen.**