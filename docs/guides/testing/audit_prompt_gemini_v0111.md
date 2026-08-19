# Audit-Prompt für Gemini — N.E.X.U.S. OneApp v0.1.11

---

## Kontext & Auftrag

Du erhältst hiermit den vollständigen Quellcode der **N.E.X.U.S. OneApp v0.1.11-alpha** als Codebase-Dump. Bitte führe ein umfassendes technisches Audit durch bevor wir mit der Entwicklung von **G2 (Governance-Modul)** beginnen.

N.E.X.U.S. ist eine dezentrale, Offline-First Flutter-App mit folgenden Kernkomponenten:

- **Identität:** BIP-39 Seed Phrase, Ed25519/SLIP-0010, did:key W3C
- **Transport:** Nostr (NIP-konform), BLE Mesh, LAN Discovery
- **Datenbank:** SQLite (verschlüsselt, AES-256-GCM)
- **Zielplattformen:** Android, Windows
- **Stack:** Flutter/Dart, Provider, GoRouter, sqflite

---

## Audit-Bereiche

Bitte analysiere den Code systematisch in folgenden Bereichen und erstelle für jeden Bereich eine strukturierte Bewertung:

---

### 1. 🔐 Security & Kryptographie

- Korrektheit der BIP-39/SLIP-0010 Schlüsselableitung
- Sichere Speicherung von Private Keys (Secure Storage, kein Klartext in Logs)
- AES-256-GCM Implementierung in der SQLite-Verschlüsselung (`enc`-Spalte)
- Nostr-Signierung (Schnorr/secp256k1) — korrekte Implementierung?
- Timing-Attack-Risiken bei kryptographischen Operationen
- Potenzielle Key-Leaks in Logs, SharedPreferences oder UI
- Android Keystore-Nutzung — korrekt und robust?
- Bewertung: Gibt es kritische Sicherheitslücken die vor G2 behoben werden müssen?

---

### 2. 🏗️ Architektur & Code-Qualität

- Einhaltung des Offline-First Prinzips
- Async-Gap-Sicherheit (synchrones State-Locking vor erstem `await`)
- Listener-Registrierung vor Transport-Start (AETHER-RULES: PRE-START)
- Service-Layer Trennung (CellService, ContactService, GroupChannelService etc.)
- Provider-Pattern korrekt implementiert? `notifyListeners()` nach State-Änderungen?
- StreamController Lifecycle (dispose() überall vorhanden?)
- Memory-Leak-Risiken (insbesondere `_conversationCache` und BLE-Chunk-Sammlung)
- Bewertung: Technische Schulden die vor G2 adressiert werden sollten

---

### 3. 📡 Nostr-Protokoll (NIP-Konformität)

- NIP-01: Korrekte Event-Struktur und Relay-Kommunikation
- NIP-04: Verschlüsselte Direktnachrichten — korrekt implementiert?
- NIP-09: Kind-5 Deletion — Race-Condition-Absicherung ausreichend?
- NIP-33: Parameterized Replaceable Events (Kind-30000 Zellen) — Relay-Kompatibilität
- e-Tag Pflicht: Werden ausschließlich 64-Hex Nostr-Event-IDs in e-Tags verwendet?
- Subscription-Management: Werden orphaned REQ-IDs sauber geschlossen?
- Relay-Antworten: Werden OK/NOTICE Responses verarbeitet?
- Bewertung: NIP-Verstöße oder Protokoll-Risiken

---

### 4. 🗄️ Datenbank & Persistenz

- Schema-Migrations-Strategie (aktuell Version 17) — robust und rückwärtskompatibel?
- `CREATE TABLE IF NOT EXISTS` und `ALTER TABLE` korrekt verwendet?
- Keine `DROP TABLE` oder destruktiven Operationen?
- Tombstone-Mechanismus — vollständig und konsistent?
- Backup/Restore-Flow — Datenvollständigkeit gewährleistet?
- Potenzielle Datenverlust-Szenarien
- Bewertung: Datenbankrisiken vor G2

---

### 5. 📱 Android-spezifisch

- AndroidManifest.xml — werden nur notwendige Permissions angefragt?
- BLE-Permissions korrekt für Android 12+ (BLUETOOTH_SCAN, BLUETOOTH_CONNECT)?
- Background Service — flutter_background_service korrekt konfiguriert?
- Keystore-Nutzung — resilient gegen Security-Patch-Invalidierungen?
- Build-Konfiguration (build.gradle.kts) — Sicherheitsrelevantes?
- Bewertung: Android-spezifische Risiken

---

### 6. 🔄 Dezentralität & P2P-Robustheit

- Gibt es versteckte Single-Points-of-Failure?
- Relay-Abhängigkeiten — was passiert wenn nos.lol ausfällt?
- BLE Mesh — vollständig funktionsfähig oder noch unvollständig?
- LAN Discovery — Sicherheitsimplikationen im lokalen Netzwerk?
- Bootstrap-Mechanismus (bootstrap_cell_authors) — Zentralisierungsrisiko?
- Bewertung: P2P-Robustheit für produktiven Einsatz

---

### 7. 🏛️ Vorbereitung für G2 (Governance-Modul)

G2 wird folgende Komponenten einführen:
- Liquid Democracy (delegiertes Abstimmungssystem)
- Quadratic Voting
- Subsidiaritätsprinzip (Zellen-Hierarchie)
- Proposal-Lifecycle (Draft → Submitted → Approved/Rejected)

Bitte bewerte:
- Ist die bestehende Proposal-Infrastruktur (proposals, proposal_votes, proposal_edits, proposal_audit_log) ausreichend als Basis?
- Welche Architektur-Entscheidungen müssen VOR G2-Beginn getroffen werden?
- Gibt es technische Schulden im aktuellen Code die G2 blockieren oder erschweren würden?
- Empfehlung: Was muss vor G2-Start zwingend bereinigt werden?

---

## Gewünschtes Ausgabeformat

Bitte strukturiere dein Audit wie folgt:

### Executive Summary (1 Seite)
Gesamtbewertung in Ampel-Format (🔴 Kritisch / 🟡 Wichtig / 🟢 In Ordnung) pro Bereich.

### Detailanalyse pro Bereich
Für jeden der 7 Bereiche:
- **Befunde** (was wurde gefunden)
- **Risiko-Einstufung** (Kritisch / Hoch / Mittel / Niedrig)
- **Empfehlung** (konkrete Maßnahme)

### Priorisierte Maßnahmen-Liste
Eine nummerierte Liste aller empfohlenen Maßnahmen, sortiert nach Priorität:
- 🔴 Muss vor G2 behoben werden
- 🟡 Sollte vor G2 behoben werden
- 🟢 Kann parallel zu G2 behoben werden

### G2-Readiness Assessment
Abschließende Einschätzung: Ist die Codebase bereit für den Start von G2? Wenn nein — was sind die 3 wichtigsten Voraussetzungen?

---

## Wichtige Projekt-Konventionen die du kennen solltest

- **NIEMALS `flutter clean`** — löscht SharedPreferences (Datenverlust)
- **NIEMALS `DROP TABLE`** — nur `ALTER TABLE` und `CREATE TABLE IF NOT EXISTS`
- **Async-Gap-Gesetz:** State MUSS synchron vor erstem `await` im RAM gesichert werden
- **Listener vor Transport-Start** — Streams müssen vor `_manager.start()` registriert sein
- **NIP-01 e-Tag Pflicht** — nur 64-Hex Nostr-Event-IDs in e-Tags, keine UUIDs
- **UI-Sprache:** Deutsch mit echten Umlauten. Code-Kommentare: Englisch
- **AETHER-Nomenklatur:** `energyToken`, `vitaBalance`, `valueExchange` — niemals `money`, `payment`, `price`

---

*Audit-Auftrag für N.E.X.U.S. OneApp v0.1.11-alpha — April 2026*
