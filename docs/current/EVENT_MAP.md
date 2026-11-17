# Event-Karte: Nostr-Kind → Handler → Service

Stand: 18. August 2026, nachgeführt 13. November 2026
Erfüllt: [Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md), Empfehlung **E-5**

Lauf B hielt fest, dass die Zuordnung „welche Kind-Nummer gehört zu welchem
Handler" nur implizit in `_onRelayEvent` liegt und für Einsteiger nicht
auffindbar ist. Diese Karte schließt die Lücke.

Quelle: [nostr_event.dart:10](../../lib/core/transport/nostr/nostr_event.dart)
(Konstanten) und [nostr_transport.dart:2069](../../lib/core/transport/nostr/nostr_transport.dart)
(Dispatch-`switch`).

## Standard-Nostr-Kinds

| Kind | Konstante | Handler | Zuständiger Service |
|---:|---|---|---|
| 0 | `metadata` | `_handleMetadataEvent` | Profil / Kontakte |
| 1 | `textNote` | `_handleBroadcast` (#mesh, Identitätsnachweis S-1) bzw. Dorfplatz-Handler | Broadcast, Dorfplatz |
| 4 | `encryptedDm` | `_handleDm` / `_handleOwnDm` (NIP-04, Identitätsnachweis S-1) | `ChatProvider` |
| 5 | `deletion` | inline | Chat, Dorfplatz |
| 6 | `repost` | inline | Dorfplatz |
| 7 | `reaction` | inline (auch `:746`) | Chat, Dorfplatz |
| 40 | `channelCreate` | `_handleChannelCreateEvent` | `GroupChannelService` |
| 41 | `channelMetadata` | – (nur Publish) | `GroupChannelService` |
| 42 | `channelMessage` | `_handleChannelMessageEvent` (Identitätsnachweis S-1) | `ChatProvider` |

## NEXUS-eigene Kinds

| Kind | Konstante | Handler | Zuständiger Service |
|---:|---|---|---|
| 30000 | `cellAnnounce` | `_handleCellAnnounceEvent` | `CellService` |
| 30078 | `presence` | `_handlePresenceEvent` (Identitätsnachweis S-1; ohne Nachweis kein Schlüsselwechsel) | Node-Counter, Discovery |
| 30078 (`d=nexus-contacts`) | Kontaktliste der eigenen Geräte (TD-60, seit 10.11.2026) | `_handleContactSyncEvent` → `onContactSync` | `ContactSyncService` (AES-GCM mit Schlüssel aus der Seed Phrase; nur vom eigenen Schlüssel signiert) |
| 31001 | `roleAssignment` | – (nur Konstante, kein Versand und kein Empfang) | – |
| 31002 | `channelRoleAssignment` | – (nur Konstante, kein Versand und kein Empfang) | – |
| 31003 | `cellJoinRequest` | `_handleCellJoinRequestEvent` | `CellService` |
| 31004 | `cellMembershipConfirmed` | `_handleCellMembershipConfirmedEvent` | `CellService` |
| 31005 | `cellMemberUpdate` | `_handleCellMemberUpdateEvent` | `CellService` |
| 31006 | `cellFoundingPermit` | `_handleIncomingPermitEvent` | `CellFoundingPermitService` |
| 31007 | `cellRoster` (TD-33) | `_handleCellRosterEvent` | `CellService.applyRoster` (nur vom nachgewiesenen aktuellen Gründer; nennt die Liste einen anderen Gründer, ist das eine Gründer-Übergabe, seit 11.11.2026). Bewerber merken sich die Liste getrennt (`rememberApplicantRoster`) |
| 31010 | `proposalEvent` | `_handleProposalEvent` | `ProposalService` |
| 31011 | `voteEvent` | `_handleVoteEvent` | `ProposalService` |
| 31012 | `delegationEvent` | `_handleDelegationEvent` | `ProposalService` |
| 31013 | `decisionRecord` | `_handleDecisionRecordEvent` | `ProposalService` |

## Der Empfangspfad

```
Relay (WebSocket)
   │
   ▼
NostrRelayManager._handleMessage          nostr_relay_manager.dart:426
   │  case 'EVENT'
   │  NostrEvent.fromJson(…)
   │  Deduplizierung über _seenEventIds
   │  NostrEvent.verify() (NostrEventVerifier)  ← TD-39, seit 08.11.2026
   ▼
_eventController.add(event)
   │
   ▼
NostrTransport._onRelayEvent              nostr_transport.dart:2069
   │  switch (event.kind)
   ▼
_handle…Event                             Fachhandler laut Tabelle oben
   │  DID-Nachweis + Rollenprüfung (ChatProvider)  ← TD-40; 31013: eigene Auszählung hat Vorrang (TD-41)
   ▼
Service (CellService, ProposalService, ChatProvider …)
   │
   ▼
PodDatabase
```

## Vertrauensprüfungen im Bild (Stand 13.11.2026)

Die beiden Lücken aus Lauf A und B sind geschlossen:

- **Authentizität (TD-39):** Jedes Event wird vor dem Dispatch mit
  `NostrEvent.verify()` geprüft (`nostr_event_verifier.dart`).
- **Autorisierung (TD-40, TD-33):** Governance- und Zell-Events prüfen den
  Absender über den Identitätsnachweis (`_idProof`) und die fachliche
  Berechtigung (`governance_authorization.dart`), etwa Auflösung nur durch
  den aktuellen Gründer oder den Superadmin.
- **Absender im Chat (Audit S-1):** DMs, Präsenz, Kanal- und #mesh-Beiträge
  binden die DID über den Identitätsnachweis an den Nostr-Schlüssel
  (`sender_check.dart`); ohne Nachweis eine Version lang mit Hinweis.
- **LAN und BLE (S-3/C-4):** außerhalb dieser Karte; der `TransportManager`
  prüft dort die Ed25519-Signatur der Nachricht gegen die DID.

Offen: Feed-Beiträge, Reaktionen und Löschungen prüfen den Absender nur über
den Nostr-Schlüssel; Governance-Inhalte liegen im Klartext (TD-42).

## Wo die Zuordnung fehlt

Drei Kinds haben keinen `case` im Dispatch:

- **41 (`channelMetadata`)** – wird nur publiziert, nie empfangen verarbeitet.
  Betroffen von F-001 (UUID im `e`-Tag).
- **31001 / 31002 (Rollen)** – nur als Konstante definiert; Rollen werden
  derzeit nicht über Nostr verteilt (`RoleService` arbeitet lokal).

## Weiterführend

- [Architektur-Ist-Zustand](ARCHITECTURE_REALITY.md)
- [Audit Lauf A](../audits/2026-07/AUDIT_LAUF_A.md) – F-001 bis F-005
- [Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md) – V-001 bis V-008, E-5
- [Tech Debt](TECH_DEBT.md)
- [Audit November 2026](../audits/2026-11/AUDIT_BERICHT.md) – S-1, S-3, C-4
