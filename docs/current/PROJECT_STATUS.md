# Projektstatus – N.E.X.U.S. OneApp

Stand: 13. November 2026 (vorher 15. Juli 2026)  
Codeversion: `0.2.0+12` laut `pubspec.yaml` (kein neues Release geplant)  
Datenbankschema: Version 28

## Kurzfassung

Die App ist eine funktionsreiche Alpha für Android und Windows. Nach dem
Release-Härtungsblock (7.–10.11.2026) und Stufe B (eigenes Relay,
Kontoumzug, Abgleich zwischen eigenen Geräten, netzweite Gründer-Übergabe)
läuft Block 1 des [Arbeitsplans nach dem Audit](../planning/NOW_NEXT_LATER.md):
Vertrauen. Die P0-Befunde des Audits vom November 2026 sind bis auf R-1
(Release-Schlüssel, bewusst verschoben) umgesetzt; ihre Gerätetests stehen
teilweise noch aus ([GERAETETESTS_OFFEN.md](GERAETETESTS_OFFEN.md)).

Quadratic Voting ist spezifiziert, aber nicht implementiert. AETHER ist ein
Entwurf beziehungsweise Platzhalter und kein aktives Produktmodul.

## Implementierter Stand

| Bereich | Aktueller Stand |
|---|---|
| Identität | BIP-39-Seed, deterministische Schlüssel/DID, Identitätsnachweis (DID ↔ Nostr-Schlüssel, ADR-0001); Kontoumzug per Seed mit oder ohne Backup-Datei |
| Kommunikation | Direktchat, Kanäle, Text/Bilder/Audio, Reaktionen und Löschpfade; Transport über Nostr (eigenes Relay plus damus, nos.lol), LAN und BLE als Direktverbindung (kein Weiterleiten) |
| Mehrere Geräte | eigene DMs und verschlüsselte Kontaktliste werden zwischen den eigenen Geräten abgeglichen |
| Gemeinschaften | Zellen, Beitritt, Mitgliederliste vom Gründer, Gründer-Übergabe netzweit, Auflösung durch Gründer oder Superadmin, Pinnwand und Agora |
| Dorfplatz | Posts, Kommentare, Reposts, Reaktionen und Löschungen |
| Governance | Anträge, Diskussion, YNA/Single Choice/Candidate Choice, eingefrorene Stimmberechtigten-Liste, Tally mit einer Stimme pro Person, Decision Records mit Retry, Stichwahlpfade |
| Liquid Democracy | Pro Antrag delegieren, widerrufen und durch eigene Stimme aufheben; nicht transitiv; Candidate Choice ausgenommen |
| Plattformen | Android und Windows im aktiven Projektumfang |

## Empfangsprüfung (Stand 13.11.2026)

- Jedes Nostr-Event wird beim Empfang mit `NostrEvent.verify()` geprüft
  (TD-39).
- Governance- und Zell-Events: Absender über den Identitätsnachweis und die
  fachliche Berechtigung geprüft (TD-40, TD-33).
- Direktnachrichten, Präsenz, Kanal- und #mesh-Beiträge: Identitätsnachweis
  geprüft; ohne Nachweis eine Version lang angenommen und als „Absender
  nicht bestätigt“ gekennzeichnet (S-1).
- LAN und BLE: Signatur der Nachricht gegen die DID geprüft (S-3/C-4).

## Nicht als fertig behandeln

- Quadratic Voting und Voice Credits
- Superadmin-Abwahl über Grundstimm-Recht
- vollständige Expertenprofile, AURA und Statementpflicht
- interzelluläre Governance
- AETHER-Wallet und Marktplatz
- iOS/macOS-Auslieferung
- NIP-17/NIP-44 statt NIP-04 (S-5)
- vertrauliche Governance-Events (TD-42)
- Weiterleiten über BLE/LAN (Mesh-Zweig)
- signierte Update-Information (`version.json`)

## Testbaseline (13.11.2026)

- `flutter test`: alle 1858 Tests grün. Ausnahme: LAN-Discovery-Tests
  schlagen fehl, wenn eine Windows-App im selben Netz läuft (TD-25).
- `flutter analyze`: keine Fehler; Hinweise und Warnungen als Baseline.
- CI (`.github/workflows/ci.yml`, Windows-Runner): `flutter analyze` (bricht nur
  bei Fehlern ab) und `flutter test` bei jedem Push auf `main`/`lead/**` und
  bei Pull Requests; aktiv ab dem nächsten Push (13.11.2026 angelegt).

## Offene Punkte

Aktuelle Liste: [TECH_DEBT.md](TECH_DEBT.md). Reihenfolge:
[NOW_NEXT_LATER.md](../planning/NOW_NEXT_LATER.md). Release-Checkliste:
[RELEASE_READINESS.md](RELEASE_READINESS.md).
