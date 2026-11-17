# Release Readiness – v0.2.0-alpha

Stand: 15. Juli 2026, nachgeführt 13. November 2026  
Status: **nicht bereit für einen produktiven Release**

Ein Release an einen kleinen, informierten und vertrauten Alpha-Testkreis ist
nach Behebung und Live-Prüfung der Blocker denkbar. Die folgende Liste ist die
verbindliche Reihenfolge; Zukunftsfunktionen gehören nicht in diesen Block.

## P0 – vor dem nächsten Alpha-Paket

- [x] F-001: echte Nostr-Event-ID für Chat-/Kanal-Reaktionen, Löschungen und
  Kanal-Metadaten verwenden; niemals UUID als `e`-Tag senden. (PR #4)
- [ ] F-002: `eligibleVoters` beim Übergang zu `VOTING` einfrieren,
  persistieren und geräteübergreifend prüfen. Code und Tests seit
  09.11.2026 (TD-37), Gerätetest offen.
- [ ] F-003: Decision-Record-Retry aus demselben vollständigen Payload-Builder
  wie den Erstversand erzeugen. Code und Regressionstest seit 09.11.2026
  (TD-38), Livetest offen.
- [x] Für alle drei Funde Unit-/Regressionstests ergänzen.
- [ ] Android↔Windows-Livetest: Reaktion, Löschen, Abstimmungsstart,
  Finalisierung und Retry nach Relay-Ausfall.
- [x] Den realen 30-Pixel-Desktop-Overflow beheben. (09.11.2026: feste
  Kartenhöhe im Desktop-Raster, Regressionstest für 800–1920 px; Sichtprüfung
  unter Windows offen)
- [x] Die 11 bekannten Navigation-/Dashboard-Tests aktualisieren oder den
  jeweils zugrunde liegenden Fehler dokumentiert beheben. (09.11.2026:
  Tests an die heutige Navigation angepasst, zwei Handy-Überläufe behoben;
  offen nur LAN-/TransportManager-Tests)
- [x] Versionsmetadaten und veröffentlichte Download-URLs synchronisiert:
  `version.json`, App und Installer stehen auf v0.2.0 / Build 12 und verweisen
  auf die vorhandenen Release-Assets unter `v0.2.0_alpha`.

## P1 – vor Öffnung für nicht vertraute Nutzer

- [x] Eingehende Nostr-Events vor jeder Zustandsänderung kryptografisch
  verifizieren. (TD-39, 08.11.2026)
- [x] Senderberechtigungen prüfen: insbesondere Zellauflösung nur durch den
  berechtigten Gründer-Pubkey sowie Votes/Anträge nur durch bestätigte
  Mitglieder. (TD-40, im Zwei-Geräte-Test bestätigt; Zellauflösung durch
  Superadmin seit 12.11.2026 am Gerät bestätigt)
- [ ] Absender von Direktnachrichten, Präsenz, Kanal- und #mesh-Beiträgen
  sowie LAN/BLE prüfen (Audit S-1, S-3/C-4). Code seit 13.11.2026,
  Gerätetest offen; Übergangszeit für Nachrichten ohne Nachweis beenden.
- [ ] Medien in privaten Kanälen verschlüsseln (S-4, Code seit 13.11.2026)
  und neuen Kanalschlüssel beim Entfernen eines Mitglieds.
- [ ] Android-Release mit eigenem Release-Schlüssel statt Debug-Schlüssel
  (R-1); Debug-Keystore seit 13.11.2026 gesichert.
- [x] `version.json` signieren (Rest TD-61, 13.11.2026).
- [x] CI mit `flutter analyze` und `flutter test` (13.11.2026; erster Lauf
  beim nächsten Push).
- [ ] `eligibleVotersCount` in Decision Record, Datenbank, Wire-Format und Hash
  explizit aufnehmen. Code und Tests seit 09.11.2026 (TD-34), Gerätetest
  offen.
- [ ] `content_hash` und Hash-Kette beim Empfang neu berechnen und prüfen.
- [ ] Produktentscheidung treffen: Governance-Daten bewusst öffentlich lassen
  oder vertraulich transportieren; danach Datenschutztexte angleichen.
- [ ] Backup/Restore mit Zellmitgliedschaften auf einem frischen Zweitgerät
  testen. (Kontoumzug ohne Backup am 12.11.2026 bestätigt; mit
  Backup-Datei und Zellmitgliedschaften offen, TD-43)

## P2 – nach der Härtung

- [x] Architekturkarte `Nostr-Kind → Handler → Service` erstellen.
  ([EVENT_MAP.md](EVENT_MAP.md))
- [ ] Reparatur- und Debug-Funktionen aus der regulären Nutzeroberfläche
  trennen.
- [ ] `proposal_service.dart` und `nostr_transport.dart` schrittweise
  modularisieren, nicht als Big-Bang-Refactoring.
- [ ] NIP-17/NIP-44 als ein Nachrichtenformat festlegen (S-5, Block 4).
- [ ] Quadratic Voting gemäß G2 v1.5 planen.

## Kein Bestandteil dieses Release-Blocks

- AETHER-Wallet/Marktplatz
- eigene Blockchain oder Substrate
- Reticulum-Sprachbrücke
- iOS/macOS-Portierung
- interzelluläre Governance

## Release-Nachweis

Ein Punkt gilt erst als erledigt, wenn Code, automatischer Test und – bei
Sync-Verhalten – Zwei-Geräte-Livetest übereinstimmen. Ergebnisse und bekannte
Abweichungen werden in der aktuellen Testanleitung oder in einem datierten
Testbericht dokumentiert.
