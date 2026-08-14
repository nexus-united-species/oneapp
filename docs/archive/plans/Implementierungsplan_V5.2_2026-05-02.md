# N.E.X.U.S. OneApp: Technischer Implementierungsplan V5
## Vom 400-Seiten-Bauplan zur funktionierenden Software
### Aktualisiert: 2. Mai 2026 — Reflektiert den Stand nach v0.1.12-alpha / Cell Founding Permit Sprint

---

## 1. AKTUELLER STATUS: Was bereits gebaut wurde

Die OneApp-Entwicklung startete am 23. März 2026 mit KI-gestütztem Development (Claude Code). Aktueller Arbeitsstand: **v0.1.12-alpha** mit erfolgreich getesteter Zellgründungsfreigabe.

### ✅ Phase 0 — Fundament (abgeschlossen)
- Flutter-Projekt mit N.E.X.U.S.-Branding (Tiefblau #0A1628 + Gold #D4AF37)
- Material 3 Theme (Dark)
- GoRouter Navigation
- CLAUDE.md Projekt-Briefing für KI-gestütztes Development

### ✅ Self-Sovereign Identity (abgeschlossen)
- **Schicht 1 — Kryptografische Basis:** BIP-39 Seed Phrase (12 Wörter), Ed25519-Schlüsselpaar (SLIP-0010), DID (did:key, W3C Standard)
- **Schicht 2 — Menschliches Profil:** Pseudonym-Generator (deutsch), Profilbild (Kamera/Galerie, mit Selective Disclosure), Bio, Klarname, Standort, Sprachen, Fähigkeiten
- **Schicht 3 — Lokaler Daten-Tresor (Proto-POD):** SQLite mit AES-256-GCM Verschlüsselung, aktuell DB-Version 16 mit 15+ Tabellen
- **Schicht 4 — Recovery:** Konto-Wiederherstellung via 12-Wort-Eingabe, automatisches verschlüsseltes Backup (Seed-basiert, externer Speicher)
- **Onboarding-Flow:** Willkommen → Seed Phrase → Bestätigung → Pseudonym → Grundsätze der Menschheitsfamilie → Einladungscode (optional) → Backup-Einrichtung → Dashboard
- **Profil mit Selective Disclosure:** 5 Stufen pro Feld (Alle / Kontakte / Vertrauenspersonen / Bürgen / Privat)
- **Profilbild-Sichtbarkeit:** Eigene Disclosure-Stufe, Identicon als Fallback
- **Kontaktsystem:** 4 Vertrauensstufen (Entdeckt → Kontakt → Vertrauensperson → Bürge)
- **QR-Code** mit DID zum Hinzufügen anderer Nutzer
- **Identicon** (5x5 Grid, deterministisch aus Public Key)

### ✅ Rollen-System (abgeschlossen)
- **SUPERADMIN** → SYSTEM_ADMIN → CHANNEL_ADMIN → CHANNEL_MODERATOR → Zellen-Rollen
- Superadmin-DID in assets/config/system.json (gitignored)
- permission_helper.dart für zentrale Berechtigungsprüfungen
- Admin-Verwaltung in Einstellungen (nur für Superadmin)
- Superadmin-Übertragung (irreversibel in Genesis-Phase)
- Später (G2): Superadmin abwählbar per Grundstimm-Recht

### ✅ Transport-Architektur (abgeschlossen)
- **Abstraktes MessageTransport-Interface** — Hardware-agnostisch, Plugin-fähig
- **TransportManager** mit automatischer Fallback-Kaskade
- **NexusMessage-Format:** UUID, DID-basiert, signiert, komprimiert, fragmentierbar
- **3 implementierte Transports:** BLE, LAN, Nostr (Details siehe Kapitel 2)

### ✅ Mesh-Chat (vollständig)
- **E2E-Verschlüsselung** (X25519 ECDH, NIP-44 kompatibel)
- **Konversationsliste** mit Sortierung, Ungelesen-Badge, Zeitstempel
- **Peer-Discovery** mit animiertem Radar (15 Min Expiry)
- **Chat-UI** mit Bubbles, Inline-Bildvorschau, Vollbild-Zoom
- **Emoji-Picker** + Emoji-Reaktionen (👍❤️😂😮😢👎)
- **Bild-Versand** (Kamera/Galerie, komprimiert)
- **Sprachnachrichten** (Hold-to-Record, Wellenform, 1x/1.5x/2x)
- **Antworten/Zitieren** (Swipe-to-Reply, Quote-Bubbles)
- **Nachrichtensuche** (Global + pro Konversation)
- **Hyperlinks** als anklickbare URLs
- **Vollständiges Kontextmenü** (Weiterleiten, Bearbeiten, Löschen, Favorisieren, Info)
- **Kontakte stummschalten** (1h/8h/24h/7d/dauerhaft)
- **Push-Benachrichtigungen** (Google-free, pro-Kontakt Stummschaltung, Nicht-Stören)
- **Nachrichten-Sync** (Since-Timestamp für verpasste Nachrichten)
- **Nostr Profil-Sync** (Kind-0, Pseudonym statt DID)

### ✅ Kontaktanfrage-System (abgeschlossen)
- Fremde müssen Kontaktanfrage mit Vorstellungstext senden (Nostr Kind-4)
- Annehmen / Ablehnen / Ignorieren
- Stilles Ablehnen (Anfragender erfährt nichts)
- Rate-Limiting: max 10 Anfragen/Tag, 30-Tage-Sperre nach Ablehnung
- Spam-Schutz: Blockierte werden automatisch gefiltert
- Ausnahmen: QR-Code und Einladungscode umgehen Anfrage

### ✅ Kanäle & Gruppen (vollständig)
- NIP-28 Gruppenkanäle mit Chats|Kanäle Tabs
- **Kanal vs. Gruppe** (📢 announcement / 👥 discussion)
- **Private Kanäle** (3 Typen: public / private_visible / private_hidden)
- NIP-44 verschlüsselt, Channel-Key per DM, AES-256-GCM
- **Kanal-Admin-Screen** (Name/Beschreibung/Typ ändern, Mitglieder entfernen, Kanal löschen)
- Emoji-Reaktionen, Nachrichten melden (an Admin per verschlüsselter DM)
- Kanal teilen per QR-Code und nexus:// Deep-Link
- **#hotnews** Ankündigungskanal (nur Admins posten, alle reagieren)
- **NIP-01-konforme Kanal-Löschung** (Kind-5 mit korrekten 64-Hex e-Tags + channel_id Custom-Tag + channel_name Custom-Tag)
- **Tombstone-System:** Gelöschte Kanäle bleiben dauerhaft unsichtbar, auch nach Relay-Sync
- **Auto-Recovery:** Gründer-Kanäle werden nach Datenverlust automatisch wiederhergestellt

### ✅ Dorfplatz — Dezentraler Social Feed (abgeschlossen)
- Dezentraler Facebook-Ersatz: Chronologisch, kein Algorithmus, keine Werbung
- **Posts:** Text (unbegrenzt) + Bilder (max 4) + Sprachnachrichten + Link-Preview + eingebettete Umfragen (2-6 Optionen)
- **3 Tabs:** Kontakte | Meine Zelle | Entdecken
- **Sichtbarkeit:** Kontakte / Zelle / Öffentlich (nachträglich erweiterbar, nicht einschränkbar)
- **Kommentare:** Verschachtelt bis 3 Ebenen, goldene Einrücklinie
- **Emoji-Reaktionen** auf Posts und Kommentare
- **Teilen:** In eigenen Feed (Repost mit Kommentar) / Per DM / In Kanal oder Gruppe
- **Post-Menü:** Bearbeiten (24h), Löschen (Kind-5), Melden, Stummschalten, Favorisieren
- **Nostr-basiert:** Kind-1 Posts, Kind-7 Reaktionen, Kind-6 Reposts

### ✅ Governance G1 — Zellen + Proposals (abgeschlossen, erweitert in v0.1.12)
- **Zellen-Hub** als eigener Bereich unter Entdecken → "Meine Zelle"
- **Zwei Zelltypen:** LOCAL (mit GPS/Geohash) / THEMATIC (mit Kategorie)
- **Konfigurierbare Einstellungen:** joinPolicy (APPROVAL_REQUIRED/INVITE_ONLY), minTrustLevel, proposalWaitDays, maxMembers
- **Zellen-Discovery:** GPS-basiert (Nähe), Kategorie-Chips, Kontakt-Empfehlungen, Nostr Kind-30000
- **Beitrittsanfragen** mit Vertrauens-Kontext
- **Rollen:** FOUNDER / MODERATOR / MEMBER / PENDING
- **Zellgründung über Gründungsfreigabe:** Normale Nutzer können eine Zellgründung beantragen; Admin/System-Admin genehmigt eine zeitlich begrenzte Gründungsfreigabe; der Nutzer gründet die Zelle anschließend selbst auf seinem Gerät.
- **Lokale Zellen mit echten Geodaten:** Bei LOCAL-Zellen werden GPS/Geohash erst beim tatsächlichen Gründen auf dem Gerät des zukünftigen Founders gesetzt. Der Admin ist Genehmiger, nicht Gründer.
- **Cell Founding Permit System:** Neues Permit-Modell mit verschlüsselter Speicherung (`enc`), Nostr Kind-31006, Admin-Genehmigung, Ablehnung, Widerruf und `used`-Status nach erfolgreicher Zellgründung.
- **Manueller End-to-End-Test erfolgreich:** Windows-Testuser beantragt Zellgründung → Android-Admin genehmigt → Windows-Testuser gründet lokale Zelle selbst → Permit wird verbraucht.
- **Zelle löschen** nur durch Superadmin/System-Admin
- **Gründer-Rolle übertragbar**
- **Founder-Schutz:** Kann Zelle nicht verlassen ohne Nachfolger
- **Auto-Recovery für Gründer:** Nach Datenverlust/Gerätewechsel werden eigene Zellen automatisch über Nostr-Signatur wiederhergestellt (kryptografisch sicher via Kind-30000 createdBy-Feld)
- **Proposals:** DRAFT→DISCUSSION→VOTING→DECIDED→ARCHIVED
- **Diskussions-Thread** im Zell-Kanal automatisch erstellt
- **Abstimmung:** Platzhalter für G2 (Ja/Nein/Enthaltung disabled)

### ✅ Sync-Stabilisierung v0.1.8/v0.1.9 (abgeschlossen)
- **Race Condition behoben:** 4 Broadcast-Streams (Channel/Cell Announced/Deleted) werden jetzt VOR der Relay-Subscription registriert — verhindert Event-Drop auf schnellen Netzwerken (Windows ~117ms Fenster)
- **Tombstone-Filter beim Empfang:** Kind-40 Events werden beim Relay-Sync gegen Tombstones geprüft — Zombies können nicht mehr zurückkehren
- **channel_name Custom-Tag in Delete-Events:** Empfänger können Namen-Tombstone setzen auch ohne die Channel-UUID zu kennen
- **Zombie-Republish:** Einmaliger automatischer Republish alter Tombstones beim ersten Start (heilt Altlasten aus früheren Versionen)
- **Systematischer Stream-Audit:** 37 Broadcast-Streams geprüft, 2 aktive Bugs und 2 latente Zeitbomben entschärft

### ✅ Navigation (aktuell)
- **Bottom Bar:** Home | Chat | Dorfplatz | Entdecken | Profil
- **Dashboard:** Radar, Nachrichten, Kanäle, Kontakte, Meine Zelle, Agora, Dorfplatz, Freunde einladen
- **Entdecken-Hub:** Kontakte, Kanäle, Meine Zelle, Einstellungen
- **Sphären:** Agora, Asklepios, Paideia, Demeter, Hestia
- Responsive Layout: Desktop (>800px: Sidebar), Mobile

### ✅ Infrastruktur
- **Grundsätze der Menschheitsfamilie:** 3-Screen-Flow
- **Freunde einladen:** NEXUS-XXXX-XXXX Codes, 30 Tage gültig
- **Automatischer Update-Checker:** Prüft alle 6h auf GitHub Pages (terminal-Repo), 24h-Dialog-Throttle, Dashboard-Banner
- **Automatisches verschlüsseltes Backup:** Seed-basiert (AES-256-GCM, HKDF), externer Speicher, alle 24h ⚠️ Restore-Flow noch nicht vollständig (siehe offene Punkte)
- **Windows Installer:** Inno Setup, Setup.exe
- **Repository:** Privat auf GitHub (project-nexus-official), Distribution über terminal-Repo und Telegram
- **35+ automatisierte Tests**, alle grün

---

## 2. TRANSPORT-ARCHITEKTUR: Das Plugin-System

### 2.1 Grundprinzip

Die zentrale Architektur-Entscheidung: **Der Chat-Code weiß nicht, über welchen Kanal eine Nachricht geht.**

```
┌─────────────────────────────────────────────────────┐
│         Chat / Dorfplatz / Governance / etc.         │
└──────────────────────────┬──────────────────────────┘
                           │
┌──────────────────────────┴──────────────────────────┐
│                  TransportManager                    │
│  - Fallback-Kaskade (automatisch)                   │
│  - Peer-Merging (gleiche DID = ein Peer)            │
│  - Deduplizierung (jede Nachricht nur 1x)           │
│  - Ed25519-Signierung aller Nachrichten             │
└──┬──────────┬──────────┬────────────────────────────┘
   │          │          │
┌──┴──┐  ┌───┴──┐  ┌───┴───┐
│ BLE │  │ LAN  │  │ Nostr │
│  ✅  │  │  ✅   │  │  ✅    │
└─────┘  └──────┘  └───────┘
```

### 2.2 Fallback-Kaskade

| Priorität | Transport | Reichweite | Internet? | Status |
|-----------|-----------|-----------|-----------|--------|
| 1 | **BLE Mesh** | 30-100m | Nein | ✅ |
| 2 | **LAN (WiFi)** | Lokales Netz | Nein | ✅ |
| 3 | **Nostr** | Weltweit | Ja | ✅ |
| 4 | WiFi Direct | ~100m | Nein | 🔜 Phase 2 |
| 5 | LoRa | 1-10km | Nein | 🔜 Phase 3 |

### 2.3 Nostr-Integration (umfassend)

| Event-Kind | Verwendung | Status |
|------------|-----------|--------|
| Kind-0 | Profil-Sync (Pseudonym, Profilbild) | ✅ |
| Kind-1 | Dorfplatz-Posts, Kommentare (NIP-10) | ✅ |
| Kind-4 | Verschlüsselte DMs, Kontaktanfragen | ✅ |
| Kind-5 | Delete Events (NIP-09, NIP-01-konform mit 64-Hex e-Tags) | ✅ |
| Kind-6 | Reposts (Dorfplatz teilen) | ✅ |
| Kind-7 | Emoji-Reaktionen (NIP-25) | ✅ |
| Kind-28/40 | Gruppenkanäle (NIP-28) mit nostr_event_id Speicherung | ✅ |
| Kind-30000 | Zellen-Announcements (NIP-33 replaceable) | ✅ |
| Kind-31001 | Rollen-Zuweisungen | ✅ |
| Kind-31002 | Kanal-Rollen-Zuweisungen | ✅ |
| Kind-31003 | Zellen-Beitrittsanfragen | ✅ |
| Kind-31004 | Mitgliedschafts-Bestätigung | ✅ |
| Kind-31005 | Mitglieder-Leave/Remove/Joined Broadcast | ✅ |
| Kind-31006 | Zellgründungsfreigaben / Cell Founding Permits | ✅ |
| Kind-31010 | Proposals | ✅ |
| Kind-31011 | Abstimmungen | ✅ |
| Kind-31013 | Entscheidungs-Records | ✅ |

Hinweis: Kind-31006 nutzt aktuell noch temporär den bestehenden verschlüsselten DM-Pfad. Vor produktiver G2-Governance soll dieser Pfad auf NIP-44 v2 / X25519-AES-GCM gehärtet werden.

---

## 3. OFFENE PUNKTE & BEKANNTE BUGS (Stand 2. Mai 2026)

### 🔴 Kritisch (vor nächstem Release)

| Bug/Feature | Beschreibung | Status |
|-------------|-------------|--------|
| Restore-Flow | Beim Seed-Phrase-Restore wird der Backup-Recovery-Dialog nicht angezeigt. Backup existiert, wird aber nicht zuverlässig angeboten. | Nicht gestartet |
| Backup-Speicherort | Backup liegt noch nicht robust genug außerhalb app-spezifischer Daten. Ziel: Documents/Downloads bzw. nutzerwählbarer Speicherort, damit Neuinstallation nicht zum Backup-Verlust führt. | Nicht gestartet |

### ✅ Seit v0.1.11/v0.1.12 erledigt

| Bug/Feature | Beschreibung | Status |
|-------------|-------------|--------|
| Zellen-Mitgliedschafts-Broadcast | Kind-31005 mit action: `joined` sorgt dafür, dass Mitgliederlisten und spätere G2-Quoren zwischen Geräten synchron bleiben. | ✅ Implementiert |
| Cell Founding Permit System | Nutzer können Zellgründungen beantragen; Admin genehmigt; Nutzer gründet selbst mit echten lokalen Geodaten. | ✅ Implementiert und manuell getestet |

### 🟡 Technische Restpunkte nach Cell Founding Permit Sprint

| Thema | Beschreibung | Status |
|-------|-------------|--------|
| NIP-04-Fallback temporär | Permit-Events können aktuell noch über den bestehenden NIP-04-Pfad laufen. Für produktive Governance soll auf NIP-44 v2 / X25519-AES-GCM umgestellt werden. | 🟡 Vor G2-Produktion härten |
| Relay-ACK / PublishResult fehlt | `Future<bool>` bedeutet aktuell nur Übergabe an den RelayManager, nicht bestätigte Annahme durch Relays. Für Governance braucht es echtes ACK-/Quorum-Tracking. | 🔴 Vor produktivem G2 erforderlich |
| Admin-Test via RoleService | Ein Admin-Berechtigungstest für `canCreateCell(adminDid, ...)` ist wegen RoleService-/DB-Initialisierung noch als Integration-/Device-Test nachzuholen. | 🟡 Test-TODO |
| Retry-Queue für Permit-Events | Wenn Permit-Request oder Permit-Decision lokal gespeichert, aber nicht gesendet wird, gibt es noch keine automatische Retry-Queue. | 🟡 Vor größerer Nutzung sinnvoll |

### 🟡 Vor G2 erforderlich

| Bug/Feature | Beschreibung | Status |
|-------------|-------------|--------|
| G2-Spezifikation | Liquid Democracy, Delegation, Quadratic Voting, Quoren, Superadmin-Abwahl, Datenschutz- und Audit-Modell müssen vor Code finalisiert werden. | In Planung |
| Audit-Log append-only | Governance-Audit-Logs dürfen bei Withdraw/Delete nicht hart gelöscht werden. Ziel: unveränderlicher Verlauf mit Tombstone/Status statt Geschichtsverlust. | Nicht gestartet |
| Hybrid-Governance-Schema | Sensible Governance-Inhalte sollen verschlüsselt in `enc` liegen; nur technische Indexspalten bleiben im Klartext. | Nicht gestartet |

### 🟢 Niedrige Priorität

| Bug/Feature | Beschreibung | Status |
|-------------|-------------|--------|
| Cell-Tombstone-Republish | TODO im Code: `_republishCellTombstones()` analog zu `_republishZombieChannels()`. Niedrige Prio, weil Kind-30000 NIP-33-replaceable ist. | TODO im Code |
| Zombie-Anfragen | Wenn Zelle gelöscht wird, bleiben offene Join Requests als "pending" auf anderen Geräten. | Deferred |

---

## 4. GOVERNANCE-ROADMAP (Subsidiarität)

| Stufe | Inhalt | Status |
|-------|--------|--------|
| **G1** | Zellen (Lokal/Thematisch) + Proposals mit Scope | ✅ Implementiert |
| **G1.1** | Zellgründungsfreigaben / Cell Founding Permit System | ✅ Implementiert und manuell getestet |
| **G2** | Liquid Democracy + Delegation + Quadratic Voting + Superadmin-Abwahl | ⬜ Nächster Schritt |
| G3 | Föderations-Governance | 🔜 Zurückgestellt |
| G4 | Grundstimm-Recht bei Verfassungsfragen | 🔜 Zurückgestellt |
| G5 | Decay, Statistiken, Cross-Cell-Audit | 🔜 Zurückgestellt |

### G2 im Detail (nächster Schritt nach Stabilisierung):
- **Direkt abstimmen:** Ja / Nein / Enthaltung
- **Stimme delegieren:** Per-Antrag, jederzeit widerrufbar, NUR zell-intern (verhindert Machtakkumulation), keine transitive Delegation, keine Akzeptanz nötig
- **Quadratic Voting:** 100 Punkte pro Quartal, Default 1 Stimme
- **Superadmin-Abwahl:** Per Grundstimm-Recht (1:1, keine Delegation, 2/3 Quorum)
- **Nostr-Sync:** Wird gleichzeitig mit G2 gebaut
- **Implementierung:** 4 sequenzielle Claude Code Prompts (Cell-Infrastruktur → Voting → Delegation → Superadmin-Entfernung)

### Wichtige Architektur-Entscheidungen (gesetzt):
- Mehrfach-Mitgliedschaft erlaubt, Abstimmungen nur zellintern
- Delegation streng zellintern — kein Machtakkumulation durch Zellen-übergreifende Delegation
- Nostr über Matrix gewählt (kein eigener Server)

---

## 5. FEATURE-ROADMAP (nach G2)

| Prio | Feature | Beschreibung |
|------|---------|-------------|
| 1 | Dashboard erweitern | Governance-Karten mit echten Daten |
| 2 | Sprach-/Videotelefonie | WebRTC über Nostr-Signaling + P2P-Stream |
| 3 | Multi-Device-Sync | Ausgehende Nachrichten als verschlüsseltes Nostr-Event an eigene DID ("Selbst-Kopie") |
| 4 | Peer-Backup über Bürgen | Social Recovery für Kontakte/Nachrichten bei Gerätewechsel |
| 5 | Echtzeit-Übersetzung | Lokales KI-Modell (NLLB/ONNX), kein Server, Gamechanger für mehrsprachige Zellen |
| 6 | i18n Vorbereitung | Strings extrahieren in l10n Dateien (Voraussetzung für Übersetzung) |

### Zurückgestellt:
- Multi-Hop BLE Relay
- Emergency Wipe (Triple-Tap)
- LoRa-Transport (Meshtastic-Kompatibilität)
- WiFi Direct Transport

---

## 6. PLATTFORM-UNABHÄNGIGKEIT

| Plattform | Status | Transport-Support |
|-----------|--------|-------------------|
| **Android** | ✅ Läuft | BLE + LAN + Nostr |
| **Windows Desktop** | ✅ Läuft (Installer) | LAN + Nostr |
| iOS | 🔜 Braucht Mac + Apple Dev Account | BLE + LAN + Nostr |
| Linux Desktop | 🔜 Vorbereitet | LAN + Nostr |

### Distribution:

| Kanal | Status |
|-------|--------|
| **GitHub Releases (terminal-Repo)** | ✅ APK + Setup.exe |
| **Automatischer Update-Checker** | ✅ In-App (GitHub Pages, 24h Throttle) |
| **Telegram (Pioniere)** | ✅ Manuelle Verteilung |
| **nexus-terminal.org** | 🔜 Download-Seite einrichten |
| F-Droid | 🔜 Nach stabilem Release |

---

## 7. TECH-STACK

### Identität & Daten
| Komponente | Technologie | Status |
|-----------|------------|--------|
| Dezentrale ID | did:key (W3C) | ✅ |
| Datensouveränität | Proto-POD (SQLite, AES-256-GCM) | ✅ |
| Schlüsselverwaltung | BIP-39, Ed25519 (SLIP-0010) | ✅ |
| E2E-Verschlüsselung | X25519 ECDH, NIP-44 | ✅ |
| Backup | Seed-basiert, AES-256-GCM, HKDF | ✅ (Restore-Flow offen) |
| Tombstone-System | SQLite tombstones-Tabelle (DB v14+) | ✅ |
| Zellgründungsfreigaben | Cell Founding Permits, verschlüsselt im Proto-POD (`enc`), Nostr Kind-31006 | ✅ |

### Frontend / App
| Komponente | Technologie | Status |
|-----------|------------|--------|
| Cross-Platform | Flutter/Dart | ✅ |
| Offline-First DB | SQLite + Proto-POD (DB v16) | ✅ |
| State Management | Provider | ✅ |
| Navigation | GoRouter | ✅ |
| UI-Design | Material 3 + N.E.X.U.S. Design | ✅ |

---

## 8. KRITISCHE ENTWICKLUNGSREGELN

⛔ **NIEMALS** `adb uninstall` oder `flutter install` — immer `flutter run` (verliert Android Keystore + Identität)
⛔ **NIEMALS** `flutter clean` — löscht SharedPreferences auf Windows
⛔ **NIEMALS** bestehende DB-Tabellen löschen bei Migrationen — nur ALTER TABLE
⛔ **NIEMALS** `Remove-Item -Recurse -Force` auf den gesamten build-Ordner ohne vorherige Warnung
⛔ **Immer** auf Gerät testen BEVOR gepusht wird
⛔ Git Push: immer `git push origin master:main`
⛔ **Nostr e-Tags** MÜSSEN 64-Hex Event-IDs sein — eigene UUIDs in Custom-Tags (channel_id, proposal_id etc.)
⛔ **Broadcast-Streams** Listener MÜSSEN vor `_startNostrIfConnected()` registriert werden — d.h. vor dem Moment wo Relay-Subscriptions (REQ) geöffnet werden und Events eintreffen können

### Windows Build-Besonderheiten:
- Kaspersky-Ausnahme für C:\nexus-oneapp erforderlich
- LongPathsEnabled=1 in Registry erforderlich
- `New-Item -ItemType Directory -Path "C:\nexus-oneapp\build\native_assets\windows" -Force` nach build-Ordner-Löschung
- Inno Setup direkt aufrufen: `& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\windows_setup.iss`

---

## 9. TEAM & COMMUNITY

- **Solo-Gründer** + KI-gestütztes Development (Claude Code)
- **Genesis Circle:** ElSID (IT/Code), Josef (Community), Jackson (Multimedia), Angela (Tiergerechtigkeit), Gabi (Hamburg)
- **Community:** Telegram (Pioniere), Discord (Architekten/Genesis Circle)
- **SHiFT-Summit 2.0:** April 2026 ausgestrahlt — starkes Wachstum der Menschheitsfamilie
- **Finanzierung:** Aus eigener Tasche (Joachim), OpenCollective vorbereitet
- **Lizenz:** AGPL v3 (Code — Repo aktuell privat, Öffnung bei kritischer Masse geplant), Copyright (Bauplan)
- **Repository:** Privat auf GitHub, Distribution über terminal-Repo (GitHub Pages) und Telegram

---

## 10. ZUSAMMENFASSUNG

**Stand nach v0.1.12-alpha:** Eine vollständige dezentrale Plattform mit gehärtetem Sync-System. Messenger, Social Feed, Governance-Grundstruktur, Rollen-System, Backup-System, robustes Tombstone-System für gelöschte Inhalte und verantwortete Zellgründung über Gründungsfreigaben.

**Zusatzstand nach v0.1.12-alpha:** Das Cell Founding Permit System ist implementiert und manuell getestet. Damit wurde das konzeptionelle Problem gelöst, dass lokale Zellen nicht vom Admin gegründet werden sollten, weil GPS/Geohash vom tatsächlichen Gründergerät stammen müssen. Der Admin erteilt nun nur noch eine Gründungsfreigabe; der Nutzer gründet die Zelle anschließend selbst und wird automatisch Founder.

**Vor G2 zu erledigen:**
1. Restore-Flow reparieren
2. Relay-ACK / PublishResult für Governance-Events
3. Audit-Log append-only machen
4. Hybrid-Governance-Schema für sensible Daten
5. G2-Spezifikation finalisieren

**Nächste Meilensteine:**
1. **Stabilisierung** (Restore-Flow + PublishResult + Audit-/Schema-Härtung)
2. **G2 Liquid Democracy** — das Herzstück der Agora
3. **Sprach-/Videotelefonie** — WebRTC über Nostr
4. **Multi-Device-Sync** — damit Daten auf allen Geräten verfügbar sind

Das Prinzip bleibt: **"Killer-App zuerst."** Funktionierende Software vor Bewegungsaufbau. Jede Zeile Code ist ein Beweis, dass N.E.X.U.S. mehr als Theorie ist.
