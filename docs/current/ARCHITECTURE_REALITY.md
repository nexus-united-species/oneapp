# N.E.X.U.S. OneApp – Architektur-Ist-Zustand

Stand: 18. August 2026
Basis: direkte Codeanalyse auf Branch `lead/multi-agent`, Commit `94b8135`

Dieses Dokument beschreibt die Architektur, **wie sie im Code tatsächlich
existiert** – nicht wie sie geplant oder dokumentiert war. Es ist die
Antwort auf die Frage „Code Truth" aus dem Architektur-Briefing 2026.

Zielarchitektur, Migrationspläne und offene Entscheidungen stehen bewusst
**nicht** hier, sondern in [../decisions/](../decisions/).

## Methode

Alle Aussagen unten sind durch Codeabfragen belegt, nicht aus Dokumenten
abgeleitet. Verwendet wurden Importanalyse, Symbolzählung und gezieltes Lesen
der Schlüsseldateien. Zahlen sind zum Stichtag reproduzierbar.

Ausdrücklich nicht geprüft: Laufzeitverhalten, Cross-Device-Verhalten,
Relay-Verhalten. Das bleibt Sache der Gerätetests.

## Verhältnis zu Audit Lauf A und B

Dieses Dokument **ersetzt die Audits vom Juli 2026 nicht** – es hat einen
anderen Gegenstand.

| | Lauf A | Lauf B | Dieses Dokument |
|---|---|---|---|
| Frage | Ist der Code korrekt? | Halten die Versprechen? | Wie ist die Architektur geschnitten? |
| Ergebnis | F-001 bis F-005 | V-001 bis V-008, E-1 bis E-7 | Befund 1 bis 8 |
| Ebene | Fehler und Fehlverhalten | Zusicherung gegen Wirklichkeit | Kopplung und Schichtung |

Beide Audits sind inhaltlich bestätigt worden, soweit dieses Dokument sie
berührt. Wo ein Befund unten bereits dort steht, ist das vermerkt. Neu sind vor
allem Befund 1 (Identitätsschlüssel), Befund 4 (Zustellsemantik), Befund 6
(Multi-Device) und Befund 7 (Storage-Kopplung) – Letzterer liegt ausdrücklich
in einer von Lauf A benannten Blindstelle („`*_screen.dart`-Dateien wurden nur
punktuell gelesen").

Die von Lauf B in **E-5** angeforderte Kind-zu-Handler-Karte wurde nachgeliefert:
[EVENT_MAP.md](EVENT_MAP.md).

## Umfang

| Bereich | Dateien | Zeilen |
|---|---:|---:|
| `lib/core/` | 39 | 11.775 |
| `lib/features/` | 87 | 50.760 |
| `lib/services/` | 11 | 3.149 |
| `lib/shared/` | 9 | 1.587 |
| **`lib/` gesamt** | **147** | **67.852** |
| `test/` | 67 | 28.028 |

Das Verhältnis von Testcode zu Produktivcode liegt bei etwa 41 Prozent. Das
ist für ein KI-gestütztes Einzelprojekt ungewöhnlich gut und eine der
wichtigsten Schutzschichten für jede künftige Migration.

## Schichtung, wie sie real existiert

```
lib/features/     Chat · Contacts · Dashboard · Discover · Dorfplatz
                  Governance · Invite · Onboarding · Profile · Settings · Wallet
        │
lib/services/     Background · Backup · ContactRequest · Invite
                  Notification · Principles · Role · Update
        │
lib/core/         config · contacts · crypto · identity · roles · storage · utils
                  transport/ ── ble · lan · nostr
```

Ein Core existiert bereits als `lib/core/`. Er enthält rund 80 Prozent der
Bereiche, die das Briefing als „NEXUS Core" hypothetisiert: Identity, Crypto,
Storage, Contacts, Roles, Transport. Die offene Frage ist daher nicht, ob ein
Core gebaut werden muss, sondern wie sauber die Grenze zwischen `core/` und
`features/` gehalten wird.

`lib/services/` ist eine dritte Schicht ohne klare Zuordnung: teils
Infrastruktur (Backup, Background), teils Fachlogik (Invite, Role, Principles).
Diese Schicht ist der unschärfste Teil der aktuellen Struktur.

## Befund 1 – Zwei Identitätsschlüssel auf zwei Kurven

**Das ist der wichtigste Befund dieses Audits.**

Aus einem BIP-39-Seed werden zwei kryptografisch unabhängige Schlüsselbäume
abgeleitet:

| | NEXUS-Identität | Nostr-Identität |
|---|---|---|
| Kurve | Ed25519 | secp256k1 |
| Ableitung | SLIP-0010 ([identity_service.dart:165](../../lib/core/identity/identity_service.dart)) | BIP-32-artig ([nostr_keys.dart:38](../../lib/core/transport/nostr/nostr_keys.dart)) |
| Signatur | Ed25519 | BIP-340 Schnorr |
| Repräsentation | `did:key:z6Mk…` | `nostrPubkey` (hex) / `npub` |
| Vorkommen im Code | ~845 | ~103 |

Beide stammen aus demselben Seed, sind aber **nicht ineinander umrechenbar**.
Sie sind zwei verschiedene Schlüssel, nicht zwei Schreibweisen desselben
Schlüssels.

Sichtbar wird das im Kontaktmodell ([contact.dart:76-87](../../lib/core/contacts/contact.dart)),
das beide getrennt speichert:

```dart
final String did;                    // Ed25519-basiert
String? encryptionPublicKey;         // X25519, aus Ed25519 abgeleitet
String? nostrPubkey;                 // secp256k1, unabhängig
```

Konsequenzen:

- Ein Kontakt ist erst vollständig nutzbar, wenn **beide** Identifier bekannt
  sind. Die Verknüpfung muss explizit übertragen werden (QR, Kind-0-Profil).
- Jede Frage „ist das dieselbe Person?" muss entscheiden, welcher Identifier
  maßgeblich ist. Diese Entscheidung ist bisher nirgends normativ festgehalten.
- Signaturprüfung ist kurvenabhängig. Welcher Prüfpfad gilt, hängt davon ab,
  welcher Identifier den Datensatz trägt.
- Würde Nostr ersetzt, verlöre `nostrPubkey` seine Bedeutung. Daten, die auf
  `nostrPubkey` verschlüsselt sind, wären verwaist.

Das ist keine Fehlkonstruktion – für einen Nostr-Client ist ein
secp256k1-Schlüssel notwendig. Aber es ist eine unentschiedene Grundfrage im
Datenmodell, und sie wird mit jeder weiteren Funktion teurer. Siehe
[ADR-0001](../decisions/ADR-0001-identitaets-identifier.md).

### Die Governance-Auszählung als konkreter Beleg

Am schärfsten sichtbar wird die unentschiedene Frage in der Abstimmungslogik.
Dort laufen **beide Identifier nebeneinander, mit unterschiedlicher Wirkung**:

| Was | Identifier | Beleg |
|---|---|---|
| `Vote` speichert | **beide**: `voterPubkey` *und* `voterDid` | [vote.dart:10-11](../../lib/features/governance/vote.dart) |
| Stimmberechtigten-Menge | **DID** | `_loadEligibleVoterSet` → `members.map((m) => m.did)`, [proposal_service.dart:3575](../../lib/features/governance/proposal_service.dart) |
| Delegations-Berechtigung | **DID** | `eligibleVoters.contains(d.delegatorDid)`, [proposal_service.dart:3632](../../lib/features/governance/proposal_service.dart) |
| Eindeutigkeit einer Stimme | **nostrPubkey** | `UNIQUE(proposal_id, voter_pubkey)`, [pod_database.dart:348](../../lib/core/storage/pod_database.dart) |
| Berechtigung einer Direktstimme | **gar nicht geprüft** | Lauf B, V-005 |

Das `Vote`-Modell trägt beide Felder, weil nie entschieden wurde, welches gilt.
Die Folge ist ein System, das **Berechtigung über DIDs prüft, Eindeutigkeit aber
über Nostr-Pubkeys durchsetzt** – zwei Mengen, die nicht ineinander überführbar
sind.

**Das erklärt V-005 aus Lauf B.** Dort steht als Befund: „es gibt keine Prüfung,
ob der Wähler zum eingefrorenen Stimmberechtigten-Kreis gehört (nur Delegationen
werden gegen `eligibleVoters` geprüft)". Der Grund ist strukturell: Die
Direktstimme trägt primär einen Pubkey, die Berechtigungsmenge enthält DIDs.
Ein Vergleich ist ohne Zuordnungsschritt nicht möglich – also unterblieb er.

Praktische Konsequenz für die Reihenfolge: **V-005 lässt sich nicht sauber
beheben, ohne vorher ADR-0001 zu entscheiden.** Wer den Wählerfilter ergänzt,
muss festlegen, welcher Identifier verglichen wird. Diese Entscheidung fällt
sonst implizit und beiläufig im Fix-Prompt.

## Befund 2 – Die Nostr-Kopplung ist schwächer als erwartet

Die Erwartung des Briefings war eine tiefe Protokollkopplung. Die Messung
zeigt ein anderes Bild:

| Messung | Wert |
|---|---:|
| Dateien mit dem Wort „Nostr" | 57 |
| Dateien, die `nostr_transport` **importieren** | 6 |
| Stellen mit hartkodierten Event-Kinds außerhalb `core/transport/` | 9 |

Die sechs importierenden Dateien sind
[chat_provider.dart](../../lib/features/chat/chat_provider.dart),
[feed_service.dart](../../lib/features/dorfplatz/feed_service.dart),
[proposal_service.dart](../../lib/features/governance/proposal_service.dart),
[background_service.dart](../../lib/services/background_service.dart),
[manual_key_input_dialog.dart](../../lib/features/contacts/manual_key_input_dialog.dart)
und [nostr_settings_screen.dart](../../lib/features/settings/nostr_settings_screen.dart).

Von den neun Kind-Stellen sind fünf reine `print()`-Diagnosen. Echte
Protokolllogik außerhalb der Transportschicht steht praktisch nur in
[background_service.dart:147](../../lib/services/background_service.dart)
(`kind: 30078`) und `:201` (`kind == 4`).

Die restlichen 51 Dateien nennen Nostr, weil sie das **Feld** `nostrPubkey`
tragen – also wegen Befund 1, nicht wegen Protokollkopplung.

**Einordnung:** Die Transportabstraktion hält weitgehend. Das eigentliche
Kopplungsproblem ist das Identitätsmodell, nicht das Protokoll. Eine
Entkopplung von Nostr wäre deutlich billiger als befürchtet – wenn vorher
Befund 1 entschieden ist.

## Befund 3 – `MessageTransport` ist eine tragfähige Abstraktion

[message_transport.dart](../../lib/core/transport/message_transport.dart) ist
43 Zeilen, dokumentiert, und formuliert die Schichtregel bereits selbst:

> „The chat layer MUST ONLY talk to `TransportManager`, never to a concrete
> transport directly."

Die Signatur arbeitet mit `recipientDid`, nicht mit einem Pubkey – die
Abstraktion ist also bereits identitätsneutral gedacht. `TransportType` kennt
neben `ble`, `lan`, `nostr` schon `wifiDirect` und `lora` als Platzhalter.

Diese Datei ist ein gelungenes Beispiel dafür, dass das im Briefing gesuchte
Adapterprinzip in diesem Projekt bereits funktioniert. Sie sollte als Vorlage
für weitere Abstraktionen dienen und nicht ersetzt werden.

## Befund 4 – Zustellsemantik existiert, aber Nostr-gefesselt

[publish_result_status.dart](../../lib/core/transport/nostr/publish_result_status.dart)
definiert einen vollständigen Lebenszyklus:

```
PENDING → PARTIAL → ACCEPTED
        ↘ RETRYING → FAILED
        ↘ REJECTED
```

Dazu existieren `publish_result.dart` (189 Zeilen), ein DAO (119 Zeilen),
Retry-Backoff und Tests. Das ist inhaltlich sehr nah an der
transportneutralen Zustellsemantik, die das Briefing in Abschnitt 23 fordert.

Zwei Einschränkungen:

- Der Code liegt unter `core/transport/**nostr**/` und ist damit an einen
  Transport gebunden. BLE und LAN haben keine vergleichbare Semantik.
- Der Begriff „Outbox" kommt im Code **null** mal vor. Die Warteschlangen-
  Semantik ist implizit über `PENDING`/`RETRYING` abgebildet, nicht als
  eigenständiges Konzept.

Das Hochziehen dieser Zustandsmaschine auf Transportebene ist die kleinste
Architekturverbesserung mit dem größten Hebel. Siehe
[ADR-0003](../decisions/ADR-0003-zustellsemantik.md).

## Befund 5 – Vertrauensmodell ist bereits relational

Im Code existiert genau ein Vertrauensbegriff
([contact.dart:7](../../lib/core/contacts/contact.dart)):

```dart
enum TrustLevel { discovered, contact, trusted, guardian }
```

Das entspricht exakt dem relationalen Modell, das das Briefing fordert:
Entdeckt → Kontakt → Vertrauensperson → Bürge. Es ist **kein** globaler Score,
nicht übertragbar, nicht aggregiert.

Suche nach Social-Scoring-Mustern im gesamten `lib/`:

| Begriff | Vorkommen |
|---|---:|
| `TrustLevel` / `trustLevel` | 101 |
| `Reputation` | 1 |
| `AURA` | 1 |
| `credential` / `Credential` | 6 |
| globaler Trust-Score | 0 |

Die einzige AURA-Stelle ist ein UI-Label in
[wallet_screen.dart:33](../../lib/features/wallet/wallet_screen.dart) – einem
Platzhalterbildschirm von 84 Zeilen ohne Logik.

**Einordnung:** Die im Briefing befürchtete Social-Scoring-Gefahr existiert im
Code nicht. Sie ist ein Dokumenten- und Konzeptthema. Anzumerken ist
allerdings, dass der Platzhalter AURA bereits als einzelne Zahl darstellt
(„Reputation · Nicht transferierbar · 0"). Diese Darstellungsform vorwegnimmt
genau das Modell, das das Briefing ablehnt. Sie zu korrigieren kostet heute
Minuten.

## Befund 6 – Multi-Device ist nicht vorhanden

| Symbol | Vorkommen |
|---|---:|
| `deviceKey` / `DeviceKey` | 0 |
| `Device` (Klasse/Typ) | 2 |
| `device` (überwiegend BLE/LAN-Peers) | 137 |

Es gibt kein Gerätekonzept auf Identitätsebene. Identität ist implizit gleich
Gerät: der Seed liegt im Secure Storage, daraus entstehen die Schlüssel, und
ein zweites Gerät mit demselben Seed ist aus Sicht des Netzwerks dieselbe
Entität – ununterscheidbar und nicht einzeln widerrufbar.

Nicht zu verwechseln: `delegation` (205 Vorkommen) ist die
Governance-Stimmdelegation aus G2.1.6, kein Gerätekonzept.

Das ist eine Datenmodell-Lücke, keine Funktionslücke. Sie wird mit jeder
weiteren Funktion teurer zu schließen. Siehe
[ADR-0002](../decisions/ADR-0002-geraet-und-person.md).

## Befund 7 – Storage-Kopplung

20 Dateien importieren [pod_database.dart](../../lib/core/storage/pod_database.dart)
direkt, davon 13 aus `features/` und `services/`:

```
features/chat/          channel_conversation_screen · chat_provider
                        conversation_screen · conversation_service
                        group_channel_service · message_search_screen
features/governance/    cell_founding_permit_service · cell_service
                        proposal_detail_screen · proposal_service
features/dorfplatz/     feed_service
features/profile/       profile_screen
features/settings/      settings_screen
services/               contact_request_service · role_service
```

Bemerkenswert: Auch zwei **Screens** greifen direkt auf die Datenbank zu
(`proposal_detail_screen`, `profile_screen`, `settings_screen`,
`channel_conversation_screen`, `conversation_screen`, `message_search_screen`).
Damit reicht die Persistenzschicht bis in die Widget-Ebene.

Eine Repository-Grenze existiert nicht. Es gibt einzelne DAOs
(`publish_result_dao`, `proposal_option_dao`, `delegation_dao`), aber sie sind
nicht durchgängig. Siehe [ADR-0004](../decisions/ADR-0004-storage-grenze.md).

## Befund 8 – Größenverteilung ist das konkreteste Wartbarkeitsrisiko

| Datei | Zeilen |
|---|---:|
| [proposal_service.dart](../../lib/features/governance/proposal_service.dart) | 4.097 |
| [conversation_screen.dart](../../lib/features/chat/conversation_screen.dart) | 3.690 |
| [nostr_transport.dart](../../lib/core/transport/nostr/nostr_transport.dart) | 2.976 |
| [proposal_detail_screen.dart](../../lib/features/governance/proposal_detail_screen.dart) | 2.766 |
| [chat_provider.dart](../../lib/features/chat/chat_provider.dart) | 2.765 |
| [pod_database.dart](../../lib/core/storage/pod_database.dart) | 2.632 |
| [channel_conversation_screen.dart](../../lib/features/chat/channel_conversation_screen.dart) | 2.396 |

Diese sieben Dateien tragen 21.322 Zeilen – knapp ein Drittel der gesamten
Codebasis. `proposal_service.dart` allein ist größer als `lib/shared/` und
`lib/services/` zusammen.

**Nicht neu.** [Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md), Achse 4,
benennt bereits „zwei Gott-Dateien": `proposal_service.dart` (4.097) und
`nostr_transport.dart` (2.976). Lauf B empfiehlt ausdrücklich, sie **nicht**
zu refaktorieren, und schlägt stattdessen die Architekturkarte aus E-5 vor.

Neu ist hier nur die Ausweitung: Es sind nicht zwei, sondern sieben Dateien,
und der Anteil beträgt 31 Prozent. Die Empfehlung von Lauf B bleibt gültig und
ist in [ADR-0005](../decisions/ADR-0005-dateigroesse.md) übernommen – dort wird
`proposal_service.dart` ausdrücklich zurückgestellt.

## Code gegen Dokumentation

Das Briefing erwartete eine längere Liste von Widersprüchen zwischen Code und
Dokumentation. Die Prüfung von [PROJECT_STATUS.md](PROJECT_STATUS.md) und
[TECH_DEBT.md](TECH_DEBT.md) gegen den Code ergibt das Gegenteil:

| Aussage der Doku | Codeprüfung |
|---|---|
| Codeversion `0.2.0+12` | bestätigt (`pubspec.yaml`) |
| Datenbankschema 23 | bestätigt ([pod_database.dart:58](../../lib/core/storage/pod_database.dart)) |
| 947 Analyze-Hinweise | bestätigt, unverändert (Lauf vom 18.08.2026) |
| „Eingehende Nostr-Events werden nicht mit `NostrEvent.verify()` verifiziert" | bestätigt – siehe unten |
| AURA nicht fertig | bestätigt (84-Zeilen-Platzhalter) |
| AETHER Entwurf/Platzhalter | bestätigt |
| Identität: BIP-39, deterministische Schlüssel/DID | bestätigt |

**Es wurden keine Widersprüche zwischen `docs/current/` und dem Code
gefunden.** Der Juli-Audit war sorgfältig, und die Statusdokumente sind
belastbar.

Das verändert die Ausgangslage des Briefings erheblich: Das Problem ist nicht,
dass die Dokumentation falsch ist. Das Problem ist, dass sie **nur Status
beschreibt und keine Architektur**. Es existierte bis heute kein Dokument,
das die Schichtung, die Kopplungen oder die Identitätsstruktur beschreibt.
Genau diese Lücke schließt das vorliegende Dokument.

## Bestätigung des kritischen Sicherheitsbefunds

Dieser Befund stammt aus [Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md)
(V-002) und steht als TD-39 in der Schuldenliste. Er wird hier **nicht neu
entdeckt**, sondern zum Stichtag erneut im Code nachvollzogen und in den
Architekturzusammenhang gestellt:

[nostr_relay_manager.dart:431-449](../../lib/core/transport/nostr/nostr_relay_manager.dart)
verarbeitet eingehende Events so:

```dart
case 'EVENT':
  final event = NostrEvent.fromJson(eventJson);
  …                                  // Deduplizierung
  _eventController.add(event);       // direkt in die App
```

`NostrEvent.verify()` ([nostr_event.dart:214](../../lib/core/transport/nostr/nostr_event.dart))
ist implementiert, korrekt und durch fünf Tests abgedeckt – wird im
Produktivpfad aber **an keiner Stelle aufgerufen**. Die einzigen Aufrufe
stehen in `test/`.

Praktisch mildernd wirkt, dass Relays laut NIP-01 selbst signaturprüfen. Genau
diese Annahme widerspricht jedoch dem Projektgrundsatz aus `CLAUDE.md`, dass
Relays nur dumme Pipes sind und keine Vertrauensinstanz.

**Einordnung für die Architekturarbeit:** Eine modulare Architektur auf
ungeprüften Eingangsdaten ist wenig wert. Dieser Punkt sollte vor oder
parallel zu jeder Architekturmigration geschlossen werden, nicht danach.

Lauf B ordnet die Behebung als E-3 ein („vor produktivem Release", nicht vor
der Testphase) und nennt ein gewichtiges Gegenargument: Eine strikte Prüfung
kann bereits im Netz liegende, vor dem Fix erzeugte Events verwerfen und damit
live Daten verschwinden lassen. Diese Einschätzung wird hier nicht revidiert.
Die [EVENT_MAP.md](EVENT_MAP.md) zeigt, dass beide Vertrauenslücken an einer
einzigen Engstelle sitzen – das erleichtert einen kontrollierten Rollout.

## Zusammenfassung

Was besser ist als erwartet:

- Ein Core existiert bereits und ist überwiegend richtig geschnitten.
- Die Transportabstraktion trägt.
- Das Vertrauensmodell ist bereits relational und frei von Social Scoring.
- Die Zustellsemantik ist zu weiten Teilen vorhanden.
- Die Dokumentation stimmt mit dem Code überein.
- Die Testabdeckung ist substanziell.

Was schlechter ist als erwartet:

- Zwei unabhängige Identitätsschlüssel ohne normative Entscheidung, welcher gilt.
- Keine Signaturprüfung im Empfangspfad (bekannt als TD-39, hier bestätigt).
- Persistenz reicht bis in die Widget-Ebene.
- Sieben Dateien tragen ein Drittel des Codes.

Was gar nicht existiert:

- Gerätekonzept auf Identitätsebene.
- Transportneutrale Zustellsemantik.
- Architekturdokumentation (bis heute).
- Entscheidungsdokumentation (bis heute).

## Weiterführend

- Offene Grundsatzentscheidungen: [../decisions/](../decisions/)
- Was nicht angefasst werden sollte: [DO_NOT_TOUCH.md](DO_NOT_TOUCH.md)
- Bestätigte Schulden mit Priorität: [TECH_DEBT.md](TECH_DEBT.md)
- Funktionaler Stand: [PROJECT_STATUS.md](PROJECT_STATUS.md)
