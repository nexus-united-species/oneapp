# Phase 3.0 — Ist-Zustand-Bericht (N.E.X.U.S. OneApp)

Datum: 2026-05-04  
DB-Version: 19  
Zweck: Basis für Phase-3.1-Planung (Voting-Modi-Schema-Erweiterungen, G2-Spec v1.3)

---

## TEIL A — Datenbank-Schema

### A.1 DB-Version

**19** (`version: 19` in `openDatabase(...)`, `lib/core/storage/pod_database.dart` Zeile 58)

---

### A.2 Migrations-Geschichte

| Version | Was wurde gemacht |
|---|---|
| < 2 | `pod_contacts.encryption_public_key` + `pod_messages.encrypted` hinzugefügt |
| < 3 | `pod_messages.message_id` hinzugefügt (Deduplication) |
| < 4 | `group_channels`-Tabelle erstellt |
| < 5 | `pod_messages.is_favorite`, `is_deleted`, `edited_body` hinzugefügt |
| < 6 | `system_roles` + `channel_roles`-Tabellen erstellt |
| < 7 | `message_reactions`-Tabelle erstellt |
| < 8 | `contact_requests`-Tabelle erstellt |
| < 9 | `feed_posts`, `feed_comments`, `feed_mutes`-Tabellen erstellt |
| < 10 | `cells`, `cell_members`, `cell_join_requests`, `proposals` (enc-blob, G1) erstellt |
| < 11 | `group_channels.cell_id` hinzugefügt |
| < 12 | `proposals` → `proposals_legacy` umbenannt; neue `proposals`-Tabelle (G2 flat-column), `proposal_votes`, `proposal_edits`, `proposal_audit_log`, `decision_records` erstellt |
| < 13 | `proposal_discussions`-Tabelle erstellt |
| < 14 | `tombstones`-Tabelle erstellt |
| < 15 | `message_reactions.nostr_event_id` hinzugefügt |
| < 16 | `group_channels.nostr_event_id` hinzugefügt |
| < 17 | Zombie-Channels per hardcoded Nostr-Event-ID-Liste aus `group_channels` gelöscht |
| < 18 | `cell_founding_permits`-Tabelle erstellt |
| < 19 | `publish_results`-Tabelle + 4 Indexes erstellt |

---

### A.3 `proposals`-Tabellen-Schema (aktuell, G2 flat-column)

| Spalte | Typ | Default |
|---|---|---|
| `id` | TEXT PRIMARY KEY | — |
| `cell_id` | TEXT NOT NULL | — |
| `creator_did` | TEXT NOT NULL | — |
| `creator_pseudonym` | TEXT NOT NULL | `''` |
| `title` | TEXT NOT NULL | — |
| `description` | TEXT NOT NULL | `''` |
| `proposal_type` | TEXT NOT NULL | `'SACHFRAGE'` |
| `category` | TEXT | NULL |
| `status` | TEXT NOT NULL | `'DRAFT'` |
| `created_at` | INTEGER NOT NULL | — |
| `discussion_started_at` | INTEGER | NULL |
| `voting_started_at` | INTEGER | NULL |
| `voting_ends_at` | INTEGER | NULL |
| `decided_at` | INTEGER | NULL |
| `archived_at` | INTEGER | NULL |
| `withdrawn_at` | INTEGER | NULL |
| `quorum_required` | REAL NOT NULL | `0.5` |
| `grace_period_hours` | INTEGER NOT NULL | `12` |
| `version` | INTEGER NOT NULL | `1` |
| `previous_decision_hash` | TEXT | NULL |
| `impulse_supporters` | TEXT | NULL |
| `result_summary` | TEXT | NULL |
| `result_yes` | INTEGER | NULL |
| `result_no` | INTEGER | NULL |
| `result_abstain` | INTEGER | NULL |
| `result_participation` | REAL | NULL |
| `scope` | TEXT NOT NULL | `'cell'` |
| `domain` | TEXT NOT NULL | `'Sonstiges'` |

**Kein `voting_mode`-Feld vorhanden.**

---

### A.4 `proposal_votes`-Tabellen-Schema

| Spalte | Typ | Default |
|---|---|---|
| `vote_id` | TEXT PRIMARY KEY | — |
| `proposal_id` | TEXT NOT NULL | — |
| `voter_pubkey` | TEXT NOT NULL | — |
| `voter_did` | TEXT NOT NULL | — |
| `voter_pseudonym` | TEXT NOT NULL | `''` |
| `choice` | TEXT NOT NULL | — |
| `weight` | INTEGER NOT NULL | `1` |
| `voice_credits` | INTEGER NOT NULL | `1` |
| `reasoning` | TEXT | NULL |
| `created_at` | INTEGER NOT NULL | — |
| `is_delegated` | INTEGER NOT NULL | `0` |
| `delegated_from` | TEXT | NULL |
| `nostr_event_id` | TEXT NOT NULL | `''` |
| UNIQUE | `(proposal_id, voter_pubkey)` | — |

**Kein `selected_option_id`-Feld vorhanden.**

---

### A.5 `decision_records`-Tabellen-Schema

| Spalte | Typ | Default |
|---|---|---|
| `record_id` | TEXT PRIMARY KEY | — |
| `proposal_id` | TEXT NOT NULL UNIQUE | — |
| `cell_id` | TEXT NOT NULL | — |
| `final_title` | TEXT NOT NULL | — |
| `final_description` | TEXT NOT NULL | — |
| `result` | TEXT NOT NULL | — |
| `yes_votes` | INTEGER NOT NULL | — |
| `no_votes` | INTEGER NOT NULL | — |
| `abstain_votes` | INTEGER NOT NULL | — |
| `participation` | REAL NOT NULL | — |
| `decided_at` | INTEGER NOT NULL | — |
| `all_votes` | TEXT NOT NULL | — |
| `content_hash` | TEXT NOT NULL | — |
| `previous_decision_hash` | TEXT | NULL |
| `nostr_event_id` | TEXT NOT NULL | `''` |

**Keine Felder `result_relation`, `previous_proposal_id`, `option_results_json`, `tie_option_ids_json`.**

---

### A.6 `proposal_options`-Tabelle

**NEIN** — existiert nicht.

---

### A.7 `proposals_legacy`-Tabelle

**JA** — existiert. Erstellt in v12-Migration durch `ALTER TABLE proposals RENAME TO proposals_legacy`. Zweck: Aufbewahrung des alten enc-Blob-Formats (G1) zur Sicherung; die Datenmigration (Entschlüsselung) erfolgt zur Laufzeit in `ProposalService.load()`. Spalten: `id`, `cell_id`, `enc`, `created_at`, `status` (G1-Schema).

---

## TEIL B — Datenmodelle

### B.1 Proposal-Modell (`lib/features/governance/proposal.dart`)

**Konstruktor-Parameter:**

| Parameter | Typ | required/optional |
|---|---|---|
| `id` | `String` | required |
| `cellId` | `String` | required |
| `creatorDid` | `String` | required |
| `creatorPseudonym` | `String` | required |
| `title` | `String` | required |
| `description` | `String` | required |
| `proposalType` | `ProposalType` | optional (default: `SACHFRAGE`) |
| `category` | `String?` | optional |
| `status` | `ProposalStatus` | optional (default: `DRAFT`) |
| `createdAt` | `DateTime` | required |
| `discussionStartedAt` | `DateTime?` | optional |
| `votingStartedAt` | `DateTime?` | optional |
| `votingEndsAt` | `DateTime?` | optional |
| `decidedAt` | `DateTime?` | optional |
| `archivedAt` | `DateTime?` | optional |
| `withdrawnAt` | `DateTime?` | optional |
| `quorumRequired` | `double` | optional (default: `0.5`) |
| `gracePeriodHours` | `int` | optional (default: `12`) |
| `version` | `int` | optional (default: `1`) |
| `previousDecisionHash` | `String?` | optional |
| `impulseSupporters` | `List<String>?` | optional (default: `[]`) |
| `resultSummary` | `String?` | optional |
| `resultYes` | `int?` | optional |
| `resultNo` | `int?` | optional |
| `resultAbstain` | `int?` | optional |
| `resultParticipation` | `double?` | optional |
| `scope` | `ProposalScope` | optional (default: `cell`) |
| `domain` | `String?` | optional |

**Getter-Properties:**
- `isActive` → `bool`
- `isDraft` → `bool`
- `createdBy` → `String` (Alias für `creatorDid`)

**`ProposalStatus`-Enum-Werte:** `DRAFT`, `DISCUSSION`, `VOTING`, `VOTING_ENDED`, `DECIDED`, `ARCHIVED`, `WITHDRAWN`

**`ProposalType`-Enum-Werte:** `SACHFRAGE`, `VERFASSUNGSFRAGE`

**`ProposalScope`-Enum:** JA — `cell`, `federation`, `global` (Kommentar: "kept for UI compatibility from G1, only CELL-scope functional in G2")

- `votingMode`-Feld: **NEIN** (Erwartung bestätigt)
- `proposalOptions`-Liste: **NEIN** (Erwartung bestätigt)

---

### B.2 Vote-Modell (`lib/features/governance/vote.dart`)

**Konstruktor-Parameter:**

| Parameter | Typ | required/optional |
|---|---|---|
| `voteId` | `String` | required |
| `proposalId` | `String` | required |
| `voterPubkey` | `String` | required |
| `voterDid` | `String` | required |
| `voterPseudonym` | `String` | required |
| `choice` | `VoteChoice` | required |
| `weight` | `int` | optional (default: `1`) |
| `voiceCredits` | `int` | optional (default: `1`) |
| `reasoning` | `String?` | optional |
| `createdAt` | `DateTime` | required |
| `isDelegated` | `bool` | optional (default: `false`) |
| `delegatedFrom` | `String?` | optional |
| `nostrEventId` | `String` | required |

**Getter-Properties:** keine (nur direkte Felder)

**`VoteChoice`-Enum-Werte:** `YES`, `NO`, `ABSTAIN`

- `selectedOptionId`-Feld: **NEIN** (Erwartung bestätigt)
- `OPTION` als `VoteChoice`: **NEIN** (Erwartung bestätigt)

---

### B.3 DecisionRecord-Modell (`lib/features/governance/decision_record.dart`)

**Konstruktor-Parameter:**

| Parameter | Typ | required/optional |
|---|---|---|
| `recordId` | `String` | required |
| `proposalId` | `String` | required |
| `cellId` | `String` | required |
| `finalTitle` | `String` | required |
| `finalDescription` | `String` | required |
| `result` | `String` | required |
| `yesVotes` | `int` | required |
| `noVotes` | `int` | required |
| `abstainVotes` | `int` | required |
| `participation` | `double` | required |
| `decidedAt` | `DateTime` | required |
| `allVotes` | `List<Vote>` | required |
| `contentHash` | `String` | required |
| `previousDecisionHash` | `String?` | optional |
| `nostrEventId` | `String` | required |

**Getter-Properties:** keine

- `resultRelation`-Feld: **NEIN** (Erwartung bestätigt)
- `previousProposalId`-Feld: **NEIN** (Erwartung bestätigt)
- `optionResultsJson`-Feld: **NEIN** (Erwartung bestätigt)
- `resultReason`-Feld: **NEIN**
- `tieOptionIdsJson`-Feld: **NEIN** (Erwartung bestätigt)

---

### B.4 ProposalOption-Modell

**NICHT vorhanden** — weder `proposal_option.dart` noch eine `ProposalOption`-Klasse in `lib/` oder `test/`.

---

## TEIL C — DAO-Methoden

### C.1 Proposals-DAO

| Methode | Signatur |
|---|---|
| `upsertProposal` | `Future<void> upsertProposal(String id, String cellId, Map<String, dynamic> data)` |
| `listProposals` | `Future<List<Map<String, dynamic>>> listProposals({String? cellId})` |
| `deleteProposal` | `Future<void> deleteProposal(String id)` |
| `listLegacyProposals` | `Future<List<Map<String, dynamic>>> listLegacyProposals()` |
| `deleteAllProposalDataForCell` | `Future<void> deleteAllProposalDataForCell(String cellId)` |

> Hinweis: Kein `getProposal(id)` by-ID-Methode vorhanden — nur `listProposals({cellId})`.

---

### C.2 Votes-DAO

| Methode | Signatur |
|---|---|
| `upsertVote` | `Future<void> upsertVote(Map<String, dynamic> voteMap)` |
| `listVotes` | `Future<List<Map<String, dynamic>>> listVotes(String proposalId)` |
| `deleteVotesForProposal` | `Future<void> deleteVotesForProposal(String proposalId)` |

---

### C.3 DecisionRecord-DAO

| Methode | Signatur |
|---|---|
| `insertDecisionRecord` | `Future<void> insertDecisionRecord(Map<String, dynamic> recordMap)` |
| `getDecisionRecord` | `Future<Map<String, dynamic>?> getDecisionRecord(String proposalId)` |
| `listDecisionRecords` | `Future<List<Map<String, dynamic>>> listDecisionRecords({String? cellId})` |
| `deleteDecisionRecord` | `Future<void> deleteDecisionRecord(String proposalId)` |

---

### C.4 `proposal_options`-DAO

**NICHT vorhanden** (Erwartung bestätigt).

---

## TEIL D — Voting-Modi-relevante Code-Stellen

### D.1 `votingMode` / `voting_mode`

**Keine Treffer** in `lib/` und `test/`. Vollständig abwesend — keine Vorarbeit vorhanden.

### D.2 `VOTING_MODE`, `YES_NO_ABSTAIN`, `SINGLE_CHOICE`, `CANDIDATE_CHOICE`

**Keine Treffer** in `lib/` und `test/`.

### D.3 `selectedOptionId` / `selected_option_id`

**Keine Treffer** in `lib/` und `test/`.

### D.4 `ProposalOption`

**Keine Treffer** in `lib/` und `test/`.

---

## TEIL E — Lücken-Analyse

| Bereich | Spec v1.3 sagt | Code aktuell | Was fehlt für Phase 3.1 |
|---|---|---|---|
| `proposals.voting_mode` | `TEXT NOT NULL DEFAULT 'YES_NO_ABSTAIN'` | **fehlt** | ALTER TABLE + Modellfeld + toMap/fromMap |
| `proposal_votes.selected_option_id` | `TEXT` nullable | **fehlt** | ALTER TABLE + Modellfeld + toMap/fromMap |
| `decision_records.result_relation` | `TEXT` nullable | **fehlt** | ALTER TABLE + Modellfeld + toMap/fromMap |
| `decision_records.previous_proposal_id` | `TEXT` nullable | **fehlt** | ALTER TABLE + Modellfeld + toMap/fromMap |
| `decision_records.option_results_json` | `TEXT` nullable | **fehlt** | ALTER TABLE + Modellfeld + toMap/fromMap |
| `proposal_options`-Tabelle | NEU (id, proposal_id, label, description, position) | **fehlt** | CREATE TABLE + DAO-Methoden |
| `Proposal.votingMode` | Pflichtfeld (enum `VotingMode`) | **fehlt** | Dart-Feld + Enum + toMap/fromMap |
| `Vote.selectedOptionId` | nullable String | **fehlt** | Dart-Feld + toMap/fromMap |
| `DecisionRecord` (3 neue Felder) | `resultRelation`, `previousProposalId`, `optionResultsJson` | **alle 3 fehlen** | Dart-Felder + toMap/fromMap |
| `ProposalOption`-Modell | NEU | **fehlt** | Neue Dart-Datei + fromMap/toMap |
| `ProposalOption`-DAO | NEU | **fehlt** | CRUD-Methoden in pod_database.dart |

---

## TEIL F — Empfehlung für Phase 3.1+

> **EMPFEHLUNG** — keine Code-Beispiele, nur strukturierte Aufzählung. Joachim entscheidet über den tatsächlichen Scope.

### 3.1 — DB-Migration v20 (Schema-Erweiterungen)

- `ALTER TABLE proposals ADD COLUMN voting_mode` (TEXT NOT NULL DEFAULT 'YES_NO_ABSTAIN')
- `ALTER TABLE proposal_votes ADD COLUMN selected_option_id` (TEXT nullable)
- `ALTER TABLE decision_records ADD COLUMN result_relation` (TEXT nullable)
- `ALTER TABLE decision_records ADD COLUMN previous_proposal_id` (TEXT nullable)
- `ALTER TABLE decision_records ADD COLUMN option_results_json` (TEXT nullable)
- `CREATE TABLE IF NOT EXISTS proposal_options` (NEU)
- Vollständig idempotent mit `_hasColumn`-Guard und `CREATE TABLE IF NOT EXISTS`
- Keine Daten-Migration nötig (alle neuen Spalten nullable oder mit Default)

**Geschätzter Aufwand: ~1,5h**

---

### 3.2 — `VotingMode`-Enum + `ProposalOption`-Modell (NEU)

- Dart-Enum `VotingMode` mit Werten `YES_NO_ABSTAIN`, `SINGLE_CHOICE`, `CANDIDATE_CHOICE`
- Neue Datei `lib/features/governance/proposal_option.dart` mit `ProposalOption`-Klasse, `toMap`/`fromMap`
- Keine Abhängigkeit von 3.3/3.4 — kann parallel vorbereitet werden

**Geschätzter Aufwand: ~1h**

---

### 3.3 — `Proposal`-Modell erweitern

- `votingMode`-Feld (`VotingMode`, optional mit Default `YES_NO_ABSTAIN`)
- `toMap`/`fromMap` erweitern
- `Proposal.create()`-Factory anpassen
- **Abhängigkeit:** `VotingMode`-Enum aus 3.2 muss fertig sein

**Geschätzter Aufwand: ~1h**

---

### 3.4 — `Vote`-Modell erweitern

- `selectedOptionId`-Feld (nullable String)
- `toMap`/`fromMap` erweitern
- Unabhängig von 3.3 — kann parallel erfolgen

**Geschätzter Aufwand: ~0,5h**

---

### 3.5 — `DecisionRecord`-Modell erweitern

- Felder: `resultRelation`, `previousProposalId`, `optionResultsJson`
- `toMap`/`fromMap` erweitern
- **Abhängigkeit:** 3.1 (DB-Schema) muss fertig sein

**Geschätzter Aufwand: ~0,5h**

---

### 3.6 — `proposal_options`-DAO in `pod_database.dart`

- Methoden: `insertProposalOption`, `listProposalOptions(proposalId)`, `deleteOptionsForProposal(proposalId)`
- `deleteAllProposalDataForCell` muss `deleteOptionsForProposal` einschließen
- **Abhängigkeit:** 3.1 (Tabelle) muss existieren

**Geschätzter Aufwand: ~0,5h**

---

### 3.7 — Tests

- Unit-Tests für neue Modellfelder (toMap/fromMap round-trip)
- DAO-Integrationstests für `proposal_options`
- Sicherstellung: Bestands-Tests (`proposal_service_test.dart`) bleiben grün

**Geschätzter Aufwand: ~2h**

---

### Empfohlene Reihenfolge

```
3.1 (DB-Migration)
  └─> 3.2 (Enum + ProposalOption-Modell)   ← parallel zu 3.1 möglich
        └─> 3.3 (Proposal-Modell)
        └─> 3.4 (Vote-Modell)              ← parallel zu 3.3
        └─> 3.5 (DecisionRecord-Modell)    ← parallel zu 3.3
        └─> 3.6 (proposal_options-DAO)
              └─> 3.7 (Tests)
```

**Gesamtaufwand geschätzt: ~7h**
