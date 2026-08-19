# Event-Karte: Nostr-Kind → Handler → Service

Stand: 18. August 2026
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
| 1 | `textNote` | inline in `_onRelayEvent` | Broadcast, Dorfplatz |
| 4 | `encryptedDm` | inline (NIP-04) | `ChatProvider` |
| 5 | `deletion` | inline | Chat, Dorfplatz |
| 6 | `repost` | inline | Dorfplatz |
| 7 | `reaction` | inline (auch `:746`) | Chat, Dorfplatz |
| 40 | `channelCreate` | `_handleChannelCreateEvent` | `GroupChannelService` |
| 41 | `channelMetadata` | – (nur Publish) | `GroupChannelService` |
| 42 | `channelMessage` | `_handleChannelMessageEvent` | `ChatProvider` |

## NEXUS-eigene Kinds

| Kind | Konstante | Handler | Zuständiger Service |
|---:|---|---|---|
| 30000 | `cellAnnounce` | `_handleCellAnnounceEvent` | `CellService` |
| 30078 | `presence` | `_handlePresenceEvent` | Node-Counter, Discovery |
| 31001 | `roleAssignment` | – (über Subscription) | `RoleService` |
| 31002 | `channelRoleAssignment` | – (über Subscription) | `RoleService` |
| 31003 | `cellJoinRequest` | `_handleCellJoinRequestEvent` | `CellService` |
| 31004 | `cellMembershipConfirmed` | `_handleCellMembershipConfirmedEvent` | `CellService` |
| 31005 | `cellMemberUpdate` | `_handleCellMemberUpdateEvent` | `CellService` |
| 31006 | `cellFoundingPermit` | `_handleIncomingPermitEvent` | `CellFoundingPermitService` |
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
   │  ⚠ KEINE Signaturprüfung  ← TD-39 / V-002
   ▼
_eventController.add(event)
   │
   ▼
NostrTransport._onRelayEvent              nostr_transport.dart:2069
   │  switch (event.kind)
   ▼
_handle…Event                             Fachhandler laut Tabelle oben
   │  ⚠ vertraut event.pubkey ungeprüft  ← TD-40 / V-003, V-005
   ▼
Service (CellService, ProposalService, ChatProvider …)
   │
   ▼
PodDatabase
```

## Die beiden Vertrauenslücken im Bild

Die Karte macht sichtbar, was Lauf A und Lauf B beschrieben haben:

**Lücke 1 – Authentizität (TD-39 / V-002).** Zwischen `fromJson` und
`_eventController.add` fehlt der Aufruf von `NostrEvent.verify()`. Die Funktion
existiert ([nostr_event.dart:214](../../lib/core/transport/nostr/nostr_event.dart)),
ist getestet, hat aber null Aufrufer im Produktivcode.

**Lücke 2 – Autorisierung (TD-40 / V-003, V-005).** Selbst mit gültiger Signatur
prüft kein Handler, ob der Absender *berechtigt* ist. Lauf B nennt den
schwerwiegendsten Fall: `_handleCellAnnounceEvent` akzeptiert ein
Auflösungs-Event (Kind 30000, `deleted=true`) ohne Gründerprüfung.

Beide Lücken liegen an **einer einzigen Engstelle** – dem Dispatch. Das ist
die gute Nachricht: Lücke 1 ist ein Aufruf an genau einer Stelle. Lücke 2
braucht pro Kind eine Regel, aber an derselben Stelle ansetzbar.

## Wo die Zuordnung fehlt

Vier Kinds haben keinen `case` im Dispatch:

- **41 (`channelMetadata`)** – wird nur publiziert, nie empfangen verarbeitet.
  Betroffen von F-001 (UUID im `e`-Tag).
- **31001 / 31002 (Rollen)** – laufen über eigene Subscriptions in
  `RoleService`, nicht über den zentralen Dispatch.

Diese Sonderwege sind der Grund, warum die Zuordnung bisher nicht aus einer
einzigen Stelle ablesbar war.

## Weiterführend

- [Architektur-Ist-Zustand](ARCHITECTURE_REALITY.md)
- [Audit Lauf A](../audits/2026-07/AUDIT_LAUF_A.md) – F-001 bis F-005
- [Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md) – V-001 bis V-008, E-5
- [Tech Debt](TECH_DEBT.md) – TD-39, TD-40
