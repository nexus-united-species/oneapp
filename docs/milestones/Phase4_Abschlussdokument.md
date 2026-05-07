# Phase 4 — Abschlussdokument

**Projekt:** N.E.X.U.S. OneApp
**Status:** Abgeschlossen
**Live-verifiziert am:** 07. Mai 2026
**Test-Suite:** 274 Tests grün, 0 Bestand-Tests gebrochen

---

## 1. Ziel

Phase 4 sollte den Tally- und DecisionRecord-Pfad in allen drei Abstimmungsmodi vollständig funktional machen — Backend-Logik, Wire-Format, Cross-Device-Sync und eine minimale UI für den neuen Modus `SINGLE_CHOICE`.

Vor Phase 4 lief nur `YES_NO_ABSTAIN` produktiv. `SINGLE_CHOICE` und `CANDIDATE_CHOICE` waren als Modelle vorhanden (Phase 3.2/3.3), aber ohne Tally-Engine, ohne UI, ohne Wire-Sync der Optionen und ohne Behandlung des Tie-Falls.

---

## 2. Erreichter Stand

| Modus | Backend-Tally | Wire-Sync | UI | Tie-Behandlung |
|---|---|---|---|---|
| YES_NO_ABSTAIN | ✅ | ✅ | ✅ | nicht zutreffend |
| SINGLE_CHOICE | ✅ | ✅ | ✅ minimal | ✅ Auto-Stichwahl |
| CANDIDATE_CHOICE | ✅ | ✅ | ⚠ minimal | ✅ Auto-Stichwahl |

**Anmerkung CC-UI:** Im Detail-Screen fällt CANDIDATE_CHOICE in denselben Layout-Pfad wie SINGLE_CHOICE. Die UI crasht nicht, zeigt aber keine Kandidaten-Avatare und keine WITHDRAWN-Hinweise. Volle CC-UI ist Phase 5+.

---

## 3. Sub-Phasen-Übersicht

### 4.0–4.6 — Backend-Foundation

| Sub | Inhalt |
|---|---|
| 4.0 | Architekturbericht mit sieben Entscheidungen (P1–P7) zu Tally-Verhalten, Idempotenz, Stichwahl als separater Schritt, Logging-Konventionen |
| 4.1a | DB-Migration v22, neue Spalte `eligible_voters_json` |
| 4.1b | `tally_helpers.dart` (170 Zeilen) mit `ResultReason`-Konstanten, deterministischem Vote-Sort, `computeContentHash` via SHA-256 |
| 4.2a | Modus-Verzweigung in `finalizeProposal` mit Skip-Logs für SC/CC |
| 4.2b | YES_NO_ABSTAIN-Tally modernisiert mit ResultReason-Konstanten und Phase-3.5-Feldern |
| 4.3 | SINGLE_CHOICE-Tally aktiviert (`_finalizeSingleChoice`, +217 Zeilen, 14 Tests) |
| 4.4 | CANDIDATE_CHOICE-Tally aktiviert (`_finalizeCandidateChoice`, +279 Zeilen, 16 Tests). Verbindliche Reihenfolge der Result-Reasons: NO_VALID_VOTES → QUORUM_NOT_MET → ALL_ABSTAIN → ALL_CANDIDATES_WITHDRAWN → WINNER_WITHDRAWN → TIE_REQUIRES_RUNOFF → approved |
| 4.5a | `_buildAndPersistDecisionRecord`-Helper für alle drei Modi (Refactor, –25 Zeilen netto) |
| 4.5b | `_buildRecordContent` + `_publishAndQueueRetry`-Helpers, Wire-Format vereinheitlicht |
| 4.5c | `handleIncomingDecisionRecord` erweitert um fünf v1.3-Felder |
| 4.6 | Idempotenz-Guard in `finalizeProposal` (Race-Schutz: `Status==VOTING_ENDED && DecisionRecord existiert → Skip + heal`) |

### 4.7 — Vote-API, Wire-Format, UI

| Sub | Inhalt |
|---|---|
| 4.7a1/a2 | `castVote` akzeptiert `selectedOptionId`. Wire-Format trägt `selectedOptionId` im `event.content` |
| 4.7b | Modus-Validierung in `castVote` und `handleIncomingVote` (`[VOTE-REJECT]`-Log bei Verstoß). YNA mit `selectedOptionId` verboten; SC/CC mit `YES`/`NO` verboten; CC mit `WITHDRAWN`-Kandidat verboten. Historische Votes werden nicht re-validiert |
| 4.7c1 | `votingMode` ins Proposal-Wire-Format aufgenommen. Backwards-kompatibel: Legacy-Events ohne Key werden zu `YES_NO_ABSTAIN` |
| 4.7c2 | `proposalOptions` atomar im Proposal-`content` embedded. Empfänger persistieren via `upsertProposalOption` (idempotent). Wire-Key `label`, lokale Felder `createdAt`/`updatedAt` reisen nicht über Wire |
| 4.7c3 | Minimal-UI für SINGLE_CHOICE: VotingMode-Dropdown im Create-Screen (YNA + SC, kein CC), dynamische Options-Liste, Modus-bewusste Voting-Buttons, `_OptionVoteButton`-Widget, `_VoteRow` zeigt Option-Label statt „Enthaltung" bei `selectedOptionId != null` |
| 4.7c4 | Live-Test Android + Windows. SC end-to-end verifiziert: contentHash auf beiden Geräten identisch, optionResultsJson korrekt synchronisiert, kein `[VOTE-REJECT]`, kein `[TALLY-WARN]` |
| 4.7d | PARTIAL-Publish-Semantik korrigiert. `acceptedRelayCount > 0` gilt jetzt als Erfolg (FULL oder PARTIAL); nur `acceptedRelayCount == 0` (FAILED) führt zu Retry-Queue. Logging differenziert FULL/PARTIAL/FAILED in allen drei Publish-Pfaden |

### 4.8 — Stichwahl-Auto-Anlage

Wenn ein Tally `resultReason=TIE_REQUIRES_RUNOFF` produziert, legt das Tally-Owner-Gerät automatisch ein Stichwahl-Folge-Proposal an: `votingMode=SINGLE_CHOICE`, exakt die Tie-Optionen, Status `DISCUSSION`, Titel `"Stichwahl: <Original-Titel>"`, `creatorPseudonym='Stichwahl-System'`. Andere Geräte empfangen das Folge-Proposal über die normale Nostr-Pipeline (Phase 4.7c2 inkl. `proposalOptions`).

---

## 4. Architektur-Entscheidungen (stabil)

Folgende Entscheidungen wurden in Phase 4 getroffen und sollen in späteren Phasen nicht ohne expliziten Anlass revidiert werden.

- **VoteChoice.OPTION** wurde nicht eingeführt. SC/CC-Options-Stimmen werden als `choice=ABSTAIN` plus `selectedOptionId` modelliert. Enthaltung ohne Optionswahl: `choice=ABSTAIN`, `selectedOptionId=null`.
- **eligibleVoters-Snapshot**: Bei Voting-Start wird die Mitgliederliste in `eligible_voters_json` eingefroren. Fallback bei fehlendem Snapshot: aktuelle `cell_members` (`[TALLY-FALLBACK]`-Log).
- **Stichwahl** ist ein eigener Folge-Antrag, kein impliziter Tally-Re-Run.
- **Sender-only-Garantie** für Auto-Aktionen: Nur das Gerät, das den Tally durchgeführt hat, legt Folge-Proposals an. Cross-Device-Idempotenz ist strukturell durch den Phase-4.6-Guard gegeben.
- **Wire-Format-Konvention**: alle content-Keys camelCase. Keine separaten Tags für Felder, die im content reisen können.
- **PublishResult-Semantik**: PARTIAL = Erfolg. Retry nur bei `acceptedRelayCount == 0`.
- **`creatorPseudonym='Stichwahl-System'`** für Auto-Stichwahlen — bewusst kein User-Pseudonym, um Tally-Owner-Identität nicht zu offenbaren.
- **Reihenfolge der Result-Reasons** in CC-Tally ist verbindlich (siehe Phase 4.4).
- **Logging-Tags** (`[TALLY-START]`, `[TALLY-RESULT]`, `[VOTE-PUB]`, `[PUBLISH]`, `[PROPOSAL]`, `[VOTE-REJECT]`, `[RUNOFF]`) sind die kanonischen Diagnose-Marker für Phase-4-Funktionalität.

---

## 5. Live-Test-Verifikation

### 4.7c4 — SC end-to-end (07.05.2026 ~09:00 UTC)

- Android (Founder, DID 6e814fa7) erstellt SC-Proposal mit drei Optionen
- Windows (DID c04a1ae9) empfängt Proposal und Optionen, kann abstimmen
- Cross-Device-Vote-Sync funktioniert, Echo-Erkennung greift
- Tally läuft auf Android, `result=approved`, `optionResultsJson` korrekt
- DecisionRecord-`contentHash` auf beiden Geräten identisch: `11eb6fadc39a2d32ca14fd6ae6223cbb0e880544bfdb5fa735e4cdf8aae9522b`

### 4.8 — Stichwahl-Auto-Anlage (07.05.2026 ~11:42 UTC)

- Konstruierter Tie: Android votiert für Option A, Windows für Option B
- `[TALLY-RESULT] result=invalid reason=TIE_REQUIRES_RUNOFF`
- 6 ms später: `[PROPOSAL] Creating draft: "Stichwahl: ..." mode=SINGLE_CHOICE options=2`
- Stichwahl wird direkt in `DISCUSSION` publiziert, nicht in `DRAFT`
- Andere Gerät erhält den DecisionRecord, **legt KEINE eigene Stichwahl an** (Idempotenz greift: `Decision record already exists, skipping`)
- Phase-4.7d-Logging korrekt: `Decision record publish PARTIAL: 1/2 relays accepted` statt fälschlich „failed, queuing retry"

---

## 6. Codebase-Delta (Phase 4 gesamt)

Hauptberührungspunkte:

- `lib/features/governance/proposal_service.dart` — Tally-Engine, DecisionRecord-Pipeline, Stichwahl-Anlage. Größter Codebase-Treffer in Phase 4.
- `lib/features/governance/tally_helpers.dart` — neu in 4.1b
- `lib/features/governance/proposal.dart` — `votingMode`-Feld bestand bereits seit Phase 3.3, in 4.7c1 ins Wire aufgenommen
- `lib/features/governance/proposal_option.dart` — bestand seit Phase 3.2, unverändert in Phase 4
- `lib/features/governance/create_proposal_screen.dart` — VotingMode-Dropdown + Options-Block in 4.7c3
- `lib/features/governance/proposal_detail_screen.dart` — Modus-bewusste Voting-UI in 4.7c3
- `lib/core/transport/nostr/nostr_transport.dart` — Wire-Format-Erweiterungen, PARTIAL-Logging
- `lib/features/chat/chat_provider.dart` — Param-Passthrough für neue Wire-Felder
- `lib/core/storage/pod_database.dart` — DB-Migration v22 in 4.1a, danach unverändert in Phase 4

DB-Migrationen: eine (`v22`, Phase 4.1a). Keine weiteren Schema-Änderungen.

---

## 7. Offene Punkte

### 7.1 Aus Phase 4 selbst übrig

- **CC-UI ist minimal.** Detail-Screen rendert CC im SC-Layout. WITHDRAWN-Hinweise und Kandidaten-Avatare fehlen. Phase 5+.
- **Kein automatischer `startVoting` für Stichwahl-Folge-Proposals.** Bewusste Entscheidung in Phase 4.8 — Founder/Admin startet manuell. Falls automatischer Start gewünscht: separate Mini-Phase.
- **Stichwahl einer Stichwahl** triggert rekursiv Phase 4.8. Im Code nicht blockiert, im Doku-Kommentar erwähnt.
- **`previousProposalId`** als Modell-Feld bewusst nicht eingeführt. Stichwahl-Folge-Proposals tragen die Original-ID textuell in der Description. UI-Linkage zwischen Original und Stichwahl folgt in einer späteren Mini-Phase.

### 7.2 Tech-Debt-Liste (Stand nach Phase 4)

| TD | Beschreibung | Priorität |
|---|---|---|
| TD-3 | `PodDatabase.testDb` produktiv genutzt | mittel |
| TD-4 | sporadischer „deactivated widget"-Fehler | niedrig |
| TD-5 | UI-Bug Windows `_isConfirmedMemberOf` für Nicht-Founder | mittel-hoch |
| TD-6 | Relay-Infrastruktur, nur 2/4 Default-Relays stabil | hoch |
| TD-9 | `backoffMs(0)` liefert 6h Failsafe | niedrig |
| TD-15 | SQLCipher als Optional-Hardening | Phase 5+ |
| TD-16/17 | Cell-Key-Rotation, historische Lesbarkeit | Phase 5+ |
| TD-18 | AuditLog-Sync | Phase 5+ |
| TD-19 | Forward-Secrecy für Votes | Phase 5+ |
| TD-20 | Vote-Signer-Anonymität via pseudonyme Vote-Keys | hoch, Phase 4.5+ |
| TD-25 | 15 Pre-existing Test-Failures außerhalb Governance | mittel |
| TD-27 | `allVotes`-Rekonstruktion in `handleIncomingDecisionRecord` deferred indefinitely | Phase 5+ |

---

## 8. Was als nächstes

Phase 4 ist abgeschlossen. Der nächste Schritt ist Phase G2: Liquid Democracy + Quadratic Voting + Grundstimm-Recht. G2 wird als eigene Phase mit eigenem Spec-Dokument behandelt, nicht als Nachzügler von Phase 4.

Vor Beginn der G2-Implementierung:

1. **G2-Spezifikation auf v1.4 aktualisieren** mit den Erkenntnissen aus Phase 4 (insbesondere zur Wire-Format-Konvention und zum Sender-only-Pattern, das auch G2-Auto-Aktionen leiten sollte).
2. **Release-Verschiebung bewusst dokumentieren:** Kein `v0.1.9-alpha`-Release nach Phase 4. Der nächste Release-Anker ist nach Abschluss des G2-Kerns. Begründung: Joachims Strategieentscheidung — Pioniere sollen den nächsten großen Governance-Sprung als Ganzes erleben, nicht als Backend-Feature ohne sichtbaren Mehrwert.

---

## 9. Anerkennung

Phase 4 hat den Kernpfad des Antragswesens auf solide Beine gestellt. Sie war länger als ursprünglich geplant — 4.7 wurde in c1/c2/c3/c4/d aufgeteilt, 4.8 wurde dazwischengeschoben — und genau das war richtig. Jeder Sub-Schritt war fokussiert genug, um sauber getestet zu werden, und das Live-Test-Pärchen 4.7c4 + 4.8 hat in der Praxis verifiziert, was die 274 Unit-Tests theoretisch zeigen: die Pipeline funktioniert end-to-end auf realer Hardware mit echtem Nostr-Netzwerk.
