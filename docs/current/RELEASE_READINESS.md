# Release Readiness – v0.2.0-alpha

Stand: 15. Juli 2026  
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

- [ ] Eingehende Nostr-Events vor jeder Zustandsänderung kryptografisch
  verifizieren.
- [ ] Senderberechtigungen prüfen: insbesondere Zellauflösung nur durch den
  berechtigten Gründer-Pubkey sowie Votes/Anträge nur durch bestätigte
  Mitglieder.
- [ ] `eligibleVotersCount` in Decision Record, Datenbank, Wire-Format und Hash
  explizit aufnehmen. Code und Tests seit 09.11.2026 (TD-34), Gerätetest
  offen.
- [ ] `content_hash` und Hash-Kette beim Empfang neu berechnen und prüfen.
- [ ] Produktentscheidung treffen: Governance-Daten bewusst öffentlich lassen
  oder vertraulich transportieren; danach Datenschutztexte angleichen.
- [ ] Backup/Restore mit Zellmitgliedschaften auf einem frischen Zweitgerät
  testen.

## P2 – nach der Härtung

- [ ] Architekturkarte `Nostr-Kind → Handler → Service` erstellen.
- [ ] Reparatur- und Debug-Funktionen aus der regulären Nutzeroberfläche
  trennen.
- [ ] `proposal_service.dart` und `nostr_transport.dart` schrittweise
  modularisieren, nicht als Big-Bang-Refactoring.
- [ ] NIP-44-Migration bewerten.
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
