# N.E.X.U.S. OneApp

### Das Cockpit der Souveränität – eine dezentrale Alpha für die Menschheitsfamilie

![Version](https://img.shields.io/badge/version-v0.2.0--alpha-gold)
![Lizenz](https://img.shields.io/badge/lizenz-AGPL%20v3-blue)
![Plattform](https://img.shields.io/badge/plattform-Android%20%7C%20Windows-lightgrey)

> **Alpha-Hinweis:** Die App befindet sich in aktiver Entwicklung. Sie ist für
> Tests mit informierten Pionieren gedacht und noch nicht für schutzbedürftige
> oder sicherheitskritische Kommunikation freigegeben. Bitte den
> [Haftungsausschluss](DISCLAIMER.md) lesen.

## Was ist die OneApp?

Die N.E.X.U.S. OneApp verbindet selbstbestimmte Identität, Kommunikation,
Gemeinschaften und demokratische Entscheidungswerkzeuge in einer Flutter-App.
Sie arbeitet offline-first und nutzt je nach Situation Nostr, LAN und BLE als
Transportwege. Der Quellcode steht unter AGPL v3.

Das langfristige Ziel ist eine dezentrale Infrastruktur ohne Abhängigkeit von
einer einzelnen Plattform. Die heutige Alpha erreicht dieses Ziel noch nicht
vollständig: Für Kommunikation über das Internet werden öffentliche
Nostr-Relays genutzt, und es existieren administrative Rollen.

## Aktueller Funktionsstand (v0.2.0-alpha)

| Bereich | Stand |
|---|---|
| Identität | BIP-39-Seed, deterministische Schlüssel und DID, Pseudonym |
| Chat | Direktnachrichten, Kanäle, Text, Bilder, Audio, Antworten, Suche, Reaktionen |
| Transport | Nostr, lokales Netzwerk und BLE |
| Kontakte | vier Vertrauensstufen, QR-Verifizierung und Selective Disclosure |
| Zellen | lokale/thematische Gemeinschaften, Beitritts- und Mitgliederverwaltung |
| Dorfplatz | Posts, Reposts, Kommentare, Umfragen, Reaktionen und Löschpfade |
| Governance | Anträge, Diskussion, drei Abstimmungsmodi, Tally, Decision Records und Stichwahlpfade |
| Liquid Democracy | antragsbezogene, nicht-transitive Delegation mit Widerruf und Auto-Revoke |
| Backup/Updates | lokale Backup-Funktionen und Update-Prüfung |

Quadratic Voting, AETHER, interzelluläre Governance und die
Superadmin-Abwahl sind noch nicht fertig implementiert.

## Sicherheits- und Datenschutzstand

- Direktnachrichten über den aktuellen Nostr-Pfad verwenden NIP-04. NIP-44 ist
  noch nicht implementiert.
- Governance-Events wie Anträge, Stimmen, Ergebnisse und Delegationen werden
  derzeit als Klartext über öffentliche Relays verteilt. Sie sind nicht als
  private Kommunikation zu behandeln.
- Die App besitzt lokale Hash- und Signaturmechanismen. Eingehende
  Nostr-Events werden im heutigen Produktivpfad jedoch noch nicht durchgängig
  kryptografisch verifiziert und gegen Absenderberechtigungen geprüft.
- Backups sichern ausgewählte Identitäts-, Kontakt-, Kanal-, Zell- und
  Einstellungsdaten, nicht automatisch den vollständigen Nachrichtenverlauf.

Die bestätigten Risiken und die Reihenfolge der Härtung stehen im
[Projektstatus](docs/current/PROJECT_STATUS.md) und in der
[Release-Checkliste](docs/current/RELEASE_READINESS.md).

## Installation

### Android

1. Den passenden v0.2.0-Alpha-Release von
   [GitHub Releases](https://github.com/project-nexus-official/oneapp/releases)
   laden.
2. Die APK installieren; Android muss die Installation aus der gewählten
   Quelle erlauben.
3. Seed Phrase beim ersten Start offline auf Papier sichern.

### Windows

1. `Setup_NexusOneApp_v0.2.0.exe` aus dem passenden Release laden.
2. Installer ausführen und anschließend die Alpha-Hinweise beachten.

Die aktuelle Anleitung liegt als
[Markdown](docs/guides/Bedienungsanleitung.md) und nach der Generierung als
[PDF](docs/generated/pdf/NEXUS_OneApp_Bedienungsanleitung_v0.2.0-alpha.pdf)
vor.

## Entwicklung

### Stack

| Layer | Technologie |
|---|---|
| Oberfläche | Flutter / Dart |
| Daten | SQLite (`sqflite` / `sqflite_ffi`) |
| State/Navigation | Provider / GoRouter |
| Identität | BIP-39, Ed25519/SLIP-0010, `did:key` |
| Transport | Nostr, BLE, LAN |
| Kryptografie | projektspezifische AES-GCM-/X25519-Pfade sowie NIP-04 im Nostr-DM-Pfad |

### Setup

```bash
git clone https://github.com/project-nexus-official/oneapp.git
cd oneapp
flutter pub get
flutter run
flutter run -d windows
```

Wichtige Sicherheitsregeln: Nicht mit `flutter clean`, `adb uninstall` oder
`flutter install` auf bestehenden Alpha-Installationen arbeiten. Details und
Testbaseline stehen in der [Testanleitung](docs/guides/testing/TESTING.md).

### Orientierung

```text
lib/
├── core/                 Identität, Kryptografie, Transport, Storage, Router
├── features/             UI und Fachlogik nach Funktionsbereich
│   ├── chat/
│   ├── cells/
│   ├── dorfplatz/
│   ├── governance/
│   └── ...
└── services/             bereichsübergreifende Dienste
```

Der Einstieg in alle aktuellen Dokumente ist
[docs/INDEX.md](docs/INDEX.md). Architektur- und KI-Arbeitsregeln stehen in
[CLAUDE.md](CLAUDE.md).

## Nächster Entwicklungsblock

Vor neuen Großfunktionen wird die v0.2.0-Alpha gehärtet:

1. Nostr-`e`-Tags für Reaktionen/Löschungen korrigieren.
2. Stimmberechtigten-Snapshot beim Abstimmungsstart einfrieren.
3. Vollständigen Decision-Record-Retry sicherstellen.
4. Cross-Device-Tests und bekannte UI-Testfehler bereinigen.
5. Empfangsverifikation und Senderautorisierung planen und umsetzen.

Danach kann Quadratic Voting gemäß
[G2 v1.5](docs/specs/governance/G2_Spezifikation_v1.5.md) neu priorisiert
werden. AETHER bleibt bis zu einer bewussten Freigabe ein Entwurf.

## Mitmachen

Fehler und Verbesserungsvorschläge können als
[GitHub Issue](https://github.com/project-nexus-official/oneapp/issues)
eingereicht werden. Beiträge sollten klein, nachvollziehbar und mit Tests
versehen sein. Es gelten die Datenverlust- und Sync-Regeln aus `CLAUDE.md`.

## Rechtliches und Links

- [Lizenz](LICENSE): AGPL v3
- [Haftungsausschluss](DISCLAIMER.md)
- [Projektwebsite](https://nexus-terminal.org)
- [GitHub-Repository](https://github.com/project-nexus-official/oneapp)

*Protokoll, nicht Plattform. Für alle.*
