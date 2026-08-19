# NEXUS OneApp mit Claude bauen
## Praktischer Leitfaden: Von der Vision zum Code

---

## SCHRITT 1: Das richtige Werkzeug wählen

Du hast drei Optionen, Claude als Programmierer einzusetzen:

### Option A: Claude Code (EMPFOHLEN) ⭐
- **Was:** Ein KI-Coding-Agent, der direkt im Terminal oder in VS Code lebt
- **Kann:** Dateien lesen/schreiben, Befehle ausführen, Git verwalten, das gesamte Projekt verstehen
- **Kosten:** Claude Pro ($20/Monat) oder Max ($100/Monat) – Max empfohlen für ein Projekt dieser Größe
- **Für dich wenn:** Du bereit bist, Terminal/VS Code zu benutzen (oder es zu lernen)
- **Installieren:** https://code.claude.com/docs/en/overview

### Option B: Claude.ai mit Artifacts (was du jetzt benutzt)
- **Was:** Dieses Chat-Interface, kann Code-Dateien erstellen
- **Kann:** Code schreiben, Dateien erzeugen, Konzepte erklären
- **Limitierung:** Sieht nicht dein Projekt als Ganzes, kann keinen Code ausführen/testen
- **Für dich wenn:** Du nur Konzepte und einzelne Dateien brauchst

### Option C: Claude Code im Browser (claude.ai/code)
- **Was:** Claude Code, aber ohne lokale Installation – läuft im Browser
- **Kann:** Repos von GitHub klonen, Code schreiben und ausführen, alles in der Cloud
- **Für dich wenn:** Du nichts installieren willst, aber trotzdem agentisch arbeiten willst

**Meine Empfehlung: Starte mit Option A (Claude Code im Terminal oder VS Code).**

---

## SCHRITT 2: Dein Setup einrichten (einmalig, ~30 Minuten)

### Was du auf deinem Rechner brauchst:

```
1. Node.js (Version 18+)
   → https://nodejs.org (LTS-Version herunterladen und installieren)

2. Git
   → https://git-scm.com/downloads

3. VS Code (optional, aber empfohlen)
   → https://code.visualstudio.com

4. Claude Code installieren:
   → Folge https://code.claude.com/docs/en/overview
   → Nach Installation: Terminal öffnen, "claude" tippen
   → Beim ersten Start: Mit deinem Claude-Konto anmelden
```

### Projekt-Ordner erstellen:

```bash
# Im Terminal:
mkdir nexus-oneapp
cd nexus-oneapp
git init

# Claude Code starten:
claude
```

Beim ersten Start fragt Claude nach Berechtigungen. Erlaube Dateizugriff für diesen Ordner.

---

## SCHRITT 3: Das Herzstück – Die CLAUDE.md Datei

Das ist der wichtigste Trick. CLAUDE.md ist eine Datei im Projektordner, die Claude bei jedem Start liest. Sie ist das „Briefing" für deinen Programmierer. Hier beschreibst du, was das Projekt ist, welche Regeln gelten und wie der Code aussehen soll.

**Erstelle diese Datei als Erstes.** Du kannst Claude bitten, sie zu erstellen, oder sie selbst anlegen:

```markdown
# CLAUDE.md – NEXUS OneApp

## Projekt-Übersicht
Die NEXUS OneApp ist eine dezentrale, zensurresistente App für alternative
Gemeinschaften. Sie implementiert das AETHER-Protokoll mit drei Wertformen:
- VITA Ꝟ (fließend, für Alltag, mit Demurrage 0,5%/Monat)
- TERRA ₮ (fest, für Infrastruktur, kein Demurrage)
- AURA ₳ (immateriell, Reputation, nicht transferierbar)

## Architektur-Entscheidungen
- **Frontend:** Flutter (Dart) – eine Codebase für iOS + Android + Desktop
- **Blockchain:** Substrate (Rust) – eigene souveräne Chain
- **Chat-Protokoll:** Inspiriert von BitChat – BLE Mesh + Nostr als Internet-Fallback
- **Daten:** Solid PODs für persönliche Datensouveränität
- **Offline-First:** SQLite + CRDTs (Automerge) für lokale Datenhaltung
- **Verschlüsselung:** Post-Quanten (CRYSTALS-Dilithium), E2E (Noise Protocol)

## Projekt-Phasen
Phase 1a: BLE Mesh-Chat (Killer-App #1)
Phase 1b: AETHER Wallet + Lokaler Marktplatz
Phase 2a: Care-System
Phase 2b: Governance (Liquid Democracy)
Phase 3+: Sphären-Plugins

## Aktueller Fokus
>>> PHASE 1a: Mesh-Chat <<<

## Code-Standards
- Dart/Flutter: Effective Dart Style Guide
- Rust/Substrate: Clippy-clean, alle Warnungen beheben
- Tests: Jede neue Funktion braucht Unit-Tests
- Sprache: Code und Kommentare auf Englisch, UI-Texte auf Deutsch
- Commit-Messages: Conventional Commits (feat:, fix:, docs:, etc.)

## Befehle
- `flutter run` – App starten
- `flutter test` – Tests laufen lassen
- `cd substrate-node && cargo build --release` – Blockchain-Node bauen
- `cd substrate-node && cargo test` – Blockchain-Tests

## Wichtige Design-Prinzipien (aus dem Bauplan)
1. "Protokoll, nicht Plattform" – wir bauen einen Standard, keine geschlossene App
2. "Killer-App zuerst" – Chat muss funktionieren bevor Ökonomie kommt
3. "Offline-First" – Kernfunktionen müssen ohne Internet laufen
4. "So einfach wie WhatsApp" – Komplexität gehört in den Hintergrund
```

---

## SCHRITT 4: So arbeitest du mit Claude Code – Die Methode

### Das Grundprinzip: Denken → Planen → Bauen → Prüfen

Claude Code hat einen **Plan Mode** (Shift+Tab zweimal drücken). In diesem Modus kann Claude nur denken und planen, aber keinen Code schreiben. Das ist entscheidend für ein Projekt dieser Größe.

### Der Workflow für jedes Feature:

```
┌──────────────────────────────────────────┐
│  1. PLAN MODE: „Wie würdest du X bauen?" │
│     → Claude analysiert, schlägt vor      │
│     → Du gibst Feedback, korrigierst      │
│     → Ihr einigt euch auf den Ansatz      │
├──────────────────────────────────────────┤
│  2. CODE MODE: „Okay, bau es."           │
│     → Claude schreibt Code, erstellt      │
│       Dateien, installiert Packages       │
│     → Du siehst Inline-Diffs in VS Code  │
├──────────────────────────────────────────┤
│  3. TEST: „Teste es."                    │
│     → Claude führt Tests aus              │
│     → Fehler werden sofort gefixt         │
├──────────────────────────────────────────┤
│  4. REVIEW: „Zeig mir was du gebaut hast"│
│     → Du prüfst das Ergebnis             │
│     → „Ändere X" oder „Gut, commit."     │
├──────────────────────────────────────────┤
│  5. COMMIT: „Committe mit Message: ..."  │
│     → Claude macht den Git-Commit         │
│     → Saubere Historie                    │
└──────────────────────────────────────────┘
```

### Die goldene Regel: EINE Aufgabe pro Gespräch

Sage Claude NICHT: „Baue die gesamte OneApp."

Sage stattdessen:
- „Erstelle ein neues Flutter-Projekt mit der Grundstruktur für die OneApp."
- „Baue einen BLE-Scanner, der Geräte in der Nähe findet und anzeigt."
- „Implementiere Store-and-Forward: Nachrichten zwischenspeichern wenn Empfänger offline."

Nach jeder abgeschlossenen Aufgabe: `/clear` und neu starten. So bleibt der Kontext frisch.

---

## SCHRITT 5: Der konkrete Bauplan – Aufgabe für Aufgabe

Hier ist die exakte Reihenfolge der Aufgaben, die du Claude geben kannst. Jede Aufgabe ist ein eigenes Gespräch mit Claude Code.

### BLOCK A: Projekt-Skeleton (Tag 1)

**Aufgabe A1:** Projekt initialisieren
```
Erstelle ein Flutter-Projekt namens "nexus_oneapp" mit folgender Struktur:
- lib/core/ (Kernlogik: Crypto, Identity, Storage)
- lib/features/chat/ (Mesh-Chat Feature)
- lib/features/wallet/ (AETHER Wallet – später)
- lib/features/marketplace/ (Marktplatz – später)
- lib/shared/ (Gemeinsame Widgets, Themes)
- test/ (gespiegelte Teststruktur)

Richte ein sauberes Theme ein (Material 3, dunkel und hell).
Die App soll beim Start einen Splash-Screen zeigen mit dem NEXUS-Logo-Platzhalter.
Füge diese Dependencies hinzu: flutter_blue_plus, sqflite, cryptography, provider.
```

**Aufgabe A2:** Basis-Navigation
```
Baue die Hauptnavigation der App:
- Bottom Navigation mit 3 Tabs: Chat, Wallet (leer/coming soon), Profil
- Chat-Tab zeigt vorerst "Suche nach Geräten..."
- Wallet-Tab zeigt "AETHER Wallet – Coming Soon" mit VITA/TERRA/AURA Symbolen
- Profil-Tab zeigt den generierten Pseudonym-Namen

Benutze GoRouter für die Navigation.
```

### BLOCK B: Identität (Tag 2-3)

**Aufgabe B1:** Seed Phrase generieren
```
Implementiere ein Identity-Modul in lib/core/identity/:
- BIP-39 Seed Phrase generieren (12 Wörter, deutsch oder englisch)
- Aus der Seed Phrase ein Ed25519-Schlüsselpaar ableiten
- Seed Phrase verschlüsselt im Secure Storage speichern
- Einen lesbaren Pseudonym-Namen generieren (z.B. "FroherBiber42")

Erstelle einen Onboarding-Flow:
1. "Willkommen bei NEXUS" Screen
2. "Deine Seed Phrase" – 12 Wörter anzeigen, Warnung zum Aufschreiben
3. "Bestätige deine Phrase" – 3 zufällige Wörter abfragen
4. "Dein Name" – Pseudonym anzeigen, optional änderbar
5. "Fertig!" – Weiterleitung zum Chat

Schreibe Tests für die Seed-Phrase-Generierung und Schlüsselableitung.
```

**Aufgabe B2:** Seed Phrase wiederherstellen
```
Füge einen "Konto wiederherstellen"-Button auf dem Willkommens-Screen hinzu.
Der Nutzer gibt seine 12 Wörter ein → Schlüsselpaar wird wiederhergestellt.
Validiere die Wörter gegen die BIP-39-Wortliste.
```

### BLOCK C: BLE Mesh-Chat – Kern (Tag 4-10)

**Aufgabe C1:** BLE Scanner und Advertiser
```
Studiere BitChats Architektur (https://github.com/permissionlesstech/bitchat).
Implementiere in lib/features/chat/ble/:

1. BLE Advertising: Das Gerät macht sich als NEXUS-Node erkennbar.
   Service UUID: [generiere eine eindeutige UUID für NEXUS]
   Advertising-Daten: Pseudonym (gekürzt auf 8 Bytes) + Protokoll-Version

2. BLE Scanning: Suche nach anderen NEXUS-Nodes in der Nähe.
   Zeige gefundene Peers in einer Liste an (Pseudonym + Signalstärke).

3. Verbindungsaufbau: Wenn ein Peer gefunden wird, GATT-Verbindung herstellen.
   Definiere eine GATT-Characteristic für Nachrichtenübertragung.

Nutze flutter_blue_plus. Teste auf einem echten Android-Gerät (BLE geht nicht im Emulator).
```

**Aufgabe C2:** Nachrichten senden und empfangen
```
Implementiere das Nachrichtenprotokoll:

1. Nachrichtenformat (JSON → LZ4-komprimiert → verschlüsselt):
   {
     "id": "uuid",
     "from": "public_key_hash",
     "to": "public_key_hash" oder "broadcast",
     "type": "text",
     "body": "Hallo Welt!",
     "timestamp": 1234567890,
     "ttl": 12  // Stunden
   }

2. Fragmentierung: Nachrichten > 500 Bytes in Chunks aufteilen
   (BLE MTU ist begrenzt). Empfänger setzt Chunks wieder zusammen.

3. UI: Einfacher Chat-Screen:
   - Oben: Peer-Name + Verbindungsstatus
   - Mitte: Nachrichtenverlauf (Bubbles)
   - Unten: Texteingabe + Senden-Button

4. Nachrichten werden lokal in SQLite gespeichert.
```

**Aufgabe C3:** Multi-Hop Relay (Store-and-Forward)
```
Implementiere Multi-Hop-Routing nach BitChat-Vorbild:

1. Jedes Gerät ist gleichzeitig Client UND Relay.
2. Wenn eine Nachricht empfangen wird, die nicht für mich ist:
   → Speichere sie temporär (max 12h TTL)
   → Leite sie an alle verbundenen Peers weiter (außer dem Sender)
   → Flood-Schutz: Nachricht nur 1x weiterleiten (ID-basiert)

3. Store-and-Forward: Wenn Empfänger offline:
   → Nachricht wird von benachbarten Nodes gecacht
   → Sobald Empfänger wieder in BLE-Reichweite: automatisch zustellen

Schreibe Tests mit Mock-BLE-Devices.
```

**Aufgabe C4:** Ende-zu-Ende-Verschlüsselung
```
Implementiere E2E-Verschlüsselung für Direktnachrichten:

1. Noise Protocol Framework (XX Handshake Pattern):
   - Beide Seiten haben Ed25519-Schlüsselpaare (aus Seed Phrase)
   - Beim ersten Kontakt: Schlüsseltausch über Noise XX
   - Danach: Symmetrische Verschlüsselung (ChaChaPoly)

2. Für Broadcast/Gruppen: Nachrichten sind unverschlüsselt (wie BitChat #mesh)
   oder optional mit Passwort (wie BitChat Rooms)

3. Triple-Tap Emergency Wipe: 3x schnell auf den Screen tippen
   → Alle lokalen Daten werden sofort gelöscht
   → Identität kann nur mit Seed Phrase wiederhergestellt werden

Nutze eine bestehende Noise-Protocol-Library für Dart (oder implementiere
die Kernfunktionen basierend auf der Noise-Spezifikation).
```

**Aufgabe C5:** Gruppen-Chat (Zellen-Kanäle)
```
Implementiere IRC-Style Gruppenkanäle:

1. Lokaler #mesh Kanal: Alle BLE-verbundenen Nodes sehen alle Broadcast-Nachrichten
2. Benannte Kanäle: z.B. #lichtenberg, #garten, #hilfe
   - Erstellen mit /create #kanalname [optionales-passwort]
   - Beitreten mit /join #kanalname
3. Kanal-Liste anzeigen: /list
4. "Schwarzes Brett": Spezieller Kanal-Typ wo Nachrichten nicht chronologisch
   sondern als Pinnwand angezeigt werden (Angebote, Gesuche, Ankündigungen)

UI: Sidebar (Swipe von links) mit Kanal-Liste.
Jeder Kanal hat sein eigenes Chat-Fenster.
```

**Aufgabe C6:** Nostr-Internet-Fallback
```
Implementiere Nostr-Integration als Internet-Fallback:

1. Wenn BLE-Peers verfügbar → BLE bevorzugen
2. Wenn Internet verfügbar aber keine BLE-Peers → Nostr nutzen
3. Automatisches Umschalten (kein manueller Toggle)

Nostr-Integration:
- Nutze eine Dart-Nostr-Library (nostr_dart oder ähnlich)
- Verbinde mit öffentlichen Relays (wss://relay.damus.io etc.)
- Geohash-basierte Kanäle: Nachrichten werden nach GPS-Position
  in Geo-Kanäle einsortiert (wie BitChat's Location-Based Channels)
- Die NEXUS-Zelle = ein Geohash-Kanal auf Nostr

Der Nutzer soll den Übergang nicht bemerken. Die UI bleibt gleich.
```

### BLOCK D: Review und Polish (Tag 11-14)

**Aufgabe D1:** Gesamttest
```
Führe einen vollständigen Testlauf durch:
1. Alle Unit-Tests ausführen und Fehler beheben
2. Einen Integration-Test schreiben: Zwei virtuelle Nutzer tauschen
   Nachrichten über einen simulierten BLE-Kanal
3. Performance-Check: Wie schnell werden Nachrichten zugestellt?
4. Batterie-Optimierung: BLE-Scanning-Intervalle anpassen
```

**Aufgabe D2:** UI-Polish
```
Verbessere die UI:
1. Dunkles Theme (NEXUS-Branding: Tiefblau + Gold-Akzente)
2. Animierte Peer-Entdeckung (Radar-Animation wenn nach Peers gesucht wird)
3. Verbindungsstatus-Indikator (grün/gelb/rot)
4. Leer-Zustände: "Noch keine Peers in der Nähe. Die OneApp sucht..."
5. Onboarding-Tutorial: 3 Screens die erklären wie Mesh-Chat funktioniert
```

---

## SCHRITT 6: Tipps für effektives Arbeiten mit Claude Code

### DO ✅

1. **Kontext geben:** „Wir bauen eine dezentrale Chat-App, die über Bluetooth funktioniert. Inspiriert von BitChat. Aktueller Stand: Identität funktioniert, BLE-Scanner läuft. Nächster Schritt: Nachrichtenversand."

2. **Plan Mode zuerst:** Bei jedem größeren Feature erst in Plan Mode gehen. „Wie würdest du BLE Store-and-Forward implementieren? Welche Edge Cases gibt es?"

3. **Dateien referenzieren:** In Claude Code kannst du `@dateiname` tippen um eine Datei als Kontext einzubinden. Z.B.: „Schau dir @lib/core/identity/seed_phrase.dart an und füge Social Recovery hinzu."

4. **Kleine Schritte:** Lieber 10 kleine Aufgaben als eine riesige. Nach jedem Schritt committen.

5. **Tests fordern:** „Schreibe Tests für diese Funktion" – immer nach der Implementierung.

6. **Fehler zeigen:** Wenn etwas nicht kompiliert: Fehlermeldung kopieren und sagen „Dieser Fehler tritt auf, bitte beheben."

7. **/clear zwischen Aufgaben:** Jede neue Aufgabe startet mit frischem Kontext. Die CLAUDE.md wird automatisch wieder gelesen.

### DON'T ❌

1. **Nicht „Baue die gesamte App"** – zu groß, zu vage, schlechte Ergebnisse

2. **Nicht blind akzeptieren** – Claude-Code zeigt dir Diffs. Lies sie! Frage „Erkläre mir diese Änderung" wenn du etwas nicht verstehst

3. **Nicht ohne Tests weitermachen** – Fehler in Schritt 3 zu finden ist 10x leichter als in Schritt 30

4. **Nicht frustriert aufgeben** – Wenn Claude einen schlechten Ansatz wählt: „Stopp. Dieser Ansatz funktioniert nicht weil X. Versuche stattdessen Y."

---

## SCHRITT 7: Custom Commands für NEXUS erstellen

Claude Code erlaubt eigene Slash-Commands. Erstelle diese im Projekt:

```bash
mkdir -p .claude/commands
```

### /nexus-review (.claude/commands/nexus-review.md)
```markdown
Führe einen NEXUS-spezifischen Code-Review durch:
1. Prüfe ob alle BLE-Operationen Offline-First sind
2. Prüfe ob Verschlüsselung korrekt implementiert ist (keine Klartexte)
3. Prüfe ob UI-Texte auf Deutsch sind
4. Prüfe ob keine zentralen Server-Abhängigkeiten existieren
5. Prüfe ob Seed Phrase niemals unverschlüsselt gespeichert wird
6. Prüfe ob Tests existieren für jede neue Funktion
```

### /nexus-status (.claude/commands/nexus-status.md)
```markdown
Zeige den aktuellen Implementierungsstand:
- Welche Features aus BLOCK A-D sind implementiert?
- Welche Tests bestehen / scheitern?
- Welche TODO-Kommentare sind im Code?
- Wie viele Dateien / Zeilen Code gibt es?
Formatiere als Übersicht mit ✅/❌ pro Feature.
```

### /nexus-plan (.claude/commands/nexus-plan.md)
```markdown
Lies die CLAUDE.md und den aktuellen Code.
Schlage die nächsten 3 sinnvollen Aufgaben vor, basierend auf:
1. Was bereits implementiert ist
2. Was noch fehlt laut Phasenplan
3. Was die logische nächste Abhängigkeit ist
Formatiere als nummerierte Liste mit geschätztem Aufwand.
```

---

## SCHRITT 8: Realistische Zeitplanung

### Wenn du Vollzeit daran arbeitest (mit Claude Code):

| Woche | Ziel | Aufgaben |
|-------|------|----------|
| 1 | Projekt steht, Identität funktioniert | A1, A2, B1, B2 |
| 2 | BLE-Grundlagen funktionieren | C1, C2 |
| 3 | Multi-Hop und Verschlüsselung | C3, C4 |
| 4 | Gruppenkanäle und Nostr-Fallback | C5, C6 |
| 5 | Testing und UI-Polish | D1, D2 |
| 6 | Erster Alpha-Test mit echten Geräten | Bugfixes, Optimierung |

**= 6 Wochen bis zum funktionierenden Mesh-Chat (Killer-App #1)**

### Wenn du nebenbei arbeitest (10-15h/Woche):
→ ~12 Wochen (3 Monate)

### Benötigtes Vorwissen:
- **Minimum:** Terminal bedienen, Git-Grundlagen, Englisch lesen
- **Hilfreich:** Flutter/Dart-Grundlagen (Claude erklärt dir alles, aber es hilft)
- **Nicht nötig:** BLE-Erfahrung, Kryptografie-Expertise (Claude übernimmt das)

---

## SCHRITT 9: Wenn du noch nie programmiert hast

Falls du absoluter Einsteiger bist, empfehle ich diesen Vor-Schritt (1-2 Wochen):

### Option A: Flutter-Basics mit Claude lernen
Starte Claude Code und sage:
```
Ich bin Programmier-Anfänger und möchte Flutter lernen.
Erstelle mir ein Mini-Projekt: Eine einfache Chat-UI (ohne echtes Backend).
Erkläre mir jeden Schritt, den du machst.
Starte mit dem Einfachsten: Ein Screen mit einer Liste und einem Textfeld.
```

Claude wird dir Schritt für Schritt alles erklären. Nach 5-10 solcher Sessions verstehst du genug, um das NEXUS-Projekt zu starten.

### Option B: Claude Code im Browser (kein Setup)
Gehe zu **claude.ai/code** – dort kannst du direkt loslegen, ohne irgendetwas zu installieren. Perfekt zum Lernen und Experimentieren.

---

## ZUSAMMENFASSUNG: Dein Startbefehl

Wenn du nur eine Sache aus diesem Dokument mitnimmst, dann diese:

**Morgen früh:**
1. Claude Code installieren (10 Min)
2. `mkdir nexus-oneapp && cd nexus-oneapp && git init`
3. CLAUDE.md erstellen (Copy-Paste von oben)
4. `claude` starten
5. Erste Aufgabe geben: **A1** (Flutter-Projekt erstellen)
6. Erste Datei committed – du hast angefangen.

Der Rest folgt Schritt für Schritt. Claude ist dein Programmierer. Du bist der Architekt. Der Bauplan existiert bereits – er heißt NEXUS V12.0 und hat 400 Seiten. Jetzt bauen wir.
