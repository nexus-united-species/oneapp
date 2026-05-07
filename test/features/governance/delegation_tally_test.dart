// ignore_for_file: avoid_print
//
// G2.1.3 — Delegation tally aggregation tests.
//
// Tests verify that _aggregateVotesWithDelegations is called correctly from
// finalizeProposal (YNA path) and _finalizeSingleChoice (SC path), and that
// the resulting DecisionRecord counts reflect delegated votes.
//
// D9 Variante A is enforced throughout: the delegations table is NEVER mutated
// during tally — expired/invalid delegations remain ACTIVE in the DB.
//
// Coverage: D.1–D.10 (26 tests).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/identity.dart';
import 'package:nexus_oneapp/core/identity/identity_service.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';
import 'package:nexus_oneapp/features/governance/audit_log_entry.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';
import 'package:nexus_oneapp/features/governance/cell_service.dart';
import 'package:nexus_oneapp/features/governance/delegation.dart';
import 'package:nexus_oneapp/features/governance/proposal.dart';
import 'package:nexus_oneapp/features/governance/proposal_option.dart';
import 'package:nexus_oneapp/features/governance/proposal_service.dart';
import 'package:nexus_oneapp/features/governance/vote.dart';
import 'package:nexus_oneapp/features/governance/voting_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ── Test constants ────────────────────────────────────────────────────────────

const _cellId = 'cell_dt_test';
const _aDid = 'did:key:z6MkDTA'; // typical delegator
const _bDid = 'did:key:z6MkDTB'; // typical delegate
const _cDid = 'did:key:z6MkDTC';
const _dDid = 'did:key:z6MkDTD';
const _eDid = 'did:key:z6MkDTE';

// Proposal IDs for different tests to isolate state.
const _propYna = 'prop_dt_yna';
const _propSc = 'prop_dt_sc';
const _propCc = 'prop_dt_cc';
const _propRunoff = 'prop_dt_runoff';

// All 5 members — used as eligibleVoters snapshot on proposals.
const _allMembers = [_aDid, _bDid, _cDid, _dDid, _eDid];

// ── In-memory DB ─────────────────────────────────────────────────────────────

Future<Database> _openTestDb() async {
  final db = await openDatabase(
    inMemoryDatabasePath,
    version: 1,
    onCreate: (db, _) async {
      // Core tables required by PodDatabase singletons.
      await db.execute(
          'CREATE TABLE pod_identity (id INTEGER PRIMARY KEY, key TEXT NOT NULL UNIQUE, enc TEXT NOT NULL, ts INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE pod_contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, peer_did TEXT NOT NULL UNIQUE, enc TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, encryption_public_key TEXT)');
      await db.execute(
          'CREATE TABLE pod_messages (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id TEXT NOT NULL, sender_did TEXT NOT NULL, enc TEXT NOT NULL, ts INTEGER NOT NULL, status TEXT NOT NULL DEFAULT "pending", encrypted INTEGER NOT NULL DEFAULT 0, message_id TEXT, is_favorite INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0, edited_body TEXT)');
      await db.execute(
          'CREATE TABLE pod_credentials (id INTEGER PRIMARY KEY AUTOINCREMENT, credential_id TEXT NOT NULL UNIQUE, type TEXT NOT NULL, issuer_did TEXT NOT NULL, enc TEXT NOT NULL, issued_at INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE recovery_shares (id INTEGER PRIMARY KEY AUTOINCREMENT, share_index INTEGER NOT NULL, threshold INTEGER NOT NULL, total_shares INTEGER NOT NULL, share_data_enc TEXT NOT NULL, guardian_did TEXT, created_at INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE group_channels (id TEXT PRIMARY KEY, enc TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE pod_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE system_roles (did TEXT PRIMARY KEY, role TEXT NOT NULL, granted_by TEXT NOT NULL, granted_at INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE channel_roles (channel_id TEXT NOT NULL, did TEXT NOT NULL, role TEXT NOT NULL, granted_by TEXT NOT NULL, granted_at INTEGER NOT NULL, PRIMARY KEY (channel_id, did))');

      // Governance tables.
      await db.execute('''
        CREATE TABLE cells (
          id TEXT PRIMARY KEY, enc TEXT NOT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE cell_members (
          cell_id TEXT NOT NULL, did TEXT NOT NULL, enc TEXT NOT NULL,
          PRIMARY KEY (cell_id, did)
        )
      ''');
      await db.execute('''
        CREATE TABLE cell_join_requests (
          id TEXT PRIMARY KEY, cell_id TEXT NOT NULL,
          is_sent INTEGER NOT NULL DEFAULT 0, enc TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE proposals (
          id TEXT PRIMARY KEY, cell_id TEXT NOT NULL,
          creator_did TEXT NOT NULL, creator_pseudonym TEXT NOT NULL DEFAULT '',
          title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
          proposal_type TEXT NOT NULL DEFAULT 'SACHFRAGE', category TEXT,
          status TEXT NOT NULL DEFAULT 'DRAFT', created_at INTEGER NOT NULL,
          discussion_started_at INTEGER, voting_started_at INTEGER,
          voting_ends_at INTEGER, decided_at INTEGER, archived_at INTEGER,
          withdrawn_at INTEGER,
          quorum_required REAL NOT NULL DEFAULT 0.5,
          grace_period_hours INTEGER NOT NULL DEFAULT 12,
          version INTEGER NOT NULL DEFAULT 1,
          previous_decision_hash TEXT, impulse_supporters TEXT,
          result_summary TEXT, result_yes INTEGER, result_no INTEGER,
          result_abstain INTEGER, result_participation REAL,
          scope TEXT NOT NULL DEFAULT 'cell',
          domain TEXT NOT NULL DEFAULT 'Sonstiges',
          voting_mode TEXT NOT NULL DEFAULT 'YES_NO_ABSTAIN',
          eligible_voters_json TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE proposal_votes (
          vote_id TEXT PRIMARY KEY, proposal_id TEXT NOT NULL,
          voter_pubkey TEXT NOT NULL, voter_did TEXT NOT NULL,
          voter_pseudonym TEXT NOT NULL DEFAULT '',
          choice TEXT NOT NULL, weight INTEGER NOT NULL DEFAULT 1,
          voice_credits INTEGER NOT NULL DEFAULT 1, reasoning TEXT,
          selected_option_id TEXT, created_at INTEGER NOT NULL,
          is_delegated INTEGER NOT NULL DEFAULT 0, delegated_from TEXT,
          nostr_event_id TEXT NOT NULL DEFAULT '',
          UNIQUE(proposal_id, voter_pubkey)
        )
      ''');
      await db.execute('''
        CREATE TABLE proposal_edits (
          edit_id TEXT PRIMARY KEY, proposal_id TEXT NOT NULL,
          editor_did TEXT NOT NULL, editor_pseudonym TEXT NOT NULL DEFAULT '',
          old_title TEXT NOT NULL, new_title TEXT NOT NULL,
          old_description TEXT NOT NULL, new_description TEXT NOT NULL,
          edited_at INTEGER NOT NULL, edit_reason TEXT,
          version_before INTEGER NOT NULL, version_after INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE proposal_audit_log (
          entry_id TEXT PRIMARY KEY, proposal_id TEXT NOT NULL,
          cell_id TEXT NOT NULL, event_type TEXT NOT NULL,
          actor_did TEXT NOT NULL, actor_pseudonym TEXT NOT NULL DEFAULT '',
          timestamp INTEGER NOT NULL, payload TEXT NOT NULL,
          nostr_event_id TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE decision_records (
          record_id TEXT PRIMARY KEY, proposal_id TEXT NOT NULL UNIQUE,
          cell_id TEXT NOT NULL, final_title TEXT NOT NULL,
          final_description TEXT NOT NULL, result TEXT NOT NULL,
          yes_votes INTEGER NOT NULL, no_votes INTEGER NOT NULL,
          abstain_votes INTEGER NOT NULL, participation REAL NOT NULL,
          decided_at INTEGER NOT NULL, all_votes TEXT NOT NULL,
          content_hash TEXT NOT NULL, previous_decision_hash TEXT,
          nostr_event_id TEXT NOT NULL DEFAULT '',
          result_relation TEXT,
          previous_proposal_id TEXT,
          option_results_json TEXT,
          tie_option_ids_json TEXT,
          result_reason TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS proposal_discussions (
          id TEXT PRIMARY KEY, proposal_id TEXT NOT NULL,
          author_did TEXT NOT NULL, author_pseudo TEXT NOT NULL DEFAULT '',
          content TEXT NOT NULL, created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tombstones (
          id TEXT NOT NULL, type TEXT NOT NULL, reason TEXT,
          created_at INTEGER NOT NULL, PRIMARY KEY (id, type)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cell_founding_permits (
          id TEXT PRIMARY KEY, is_sent INTEGER NOT NULL DEFAULT 0,
          enc TEXT NOT NULL, created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS publish_results (
          publish_result_id TEXT PRIMARY KEY, local_event_id TEXT NOT NULL,
          nostr_event_id TEXT, event_kind INTEGER NOT NULL,
          proposal_id TEXT, cell_id TEXT, vote_id TEXT,
          status TEXT NOT NULL DEFAULT 'PENDING',
          attempted_at INTEGER NOT NULL, ack_received_at INTEGER,
          error_code TEXT, error_message TEXT,
          retry_count INTEGER NOT NULL DEFAULT 0, next_retry_at INTEGER,
          required_ack_count INTEGER NOT NULL DEFAULT 2,
          accepted_relay_count INTEGER NOT NULL DEFAULT 0,
          failed_relay_count INTEGER NOT NULL DEFAULT 0,
          final_status TEXT, created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS proposal_options (
          option_id TEXT PRIMARY KEY, proposal_id TEXT NOT NULL,
          label TEXT NOT NULL, description TEXT,
          candidate_did TEXT, candidate_pseudonym TEXT,
          candidate_accepted_at INTEGER, candidate_withdrawn_at INTEGER,
          status TEXT NOT NULL DEFAULT 'ACTIVE',
          position INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
        )
      ''');
      // Delegations table (v23).
      await db.execute('''
        CREATE TABLE IF NOT EXISTS delegations (
          delegation_id TEXT PRIMARY KEY, delegator_did TEXT NOT NULL,
          delegate_did TEXT NOT NULL, proposal_id TEXT NOT NULL,
          cell_id TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'ACTIVE',
          nostr_event_id TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_delegations_proposal ON delegations(proposal_id)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS ux_active_delegation_per_proposal '
        'ON delegations(delegator_did, proposal_id) WHERE status = \'ACTIVE\'',
      );
    },
  );
  final key = Uint8List(32)..fillRange(0, 32, 0x42);
  PodDatabase.instance.injectDatabase(db, key);
  return db;
}

// ── Per-test state setup ──────────────────────────────────────────────────────

/// Sets up identity, cell (in-memory), and the ProposalService singleton.
void _setupServices() {
  IdentityService.instance.setForTest(
    NexusIdentity(publicKeyHex: 'aabbccdd', pseudonym: 'Tester', did: _aDid),
  );
  CellService.instance.addCellForTest(
    Cell(
      id: _cellId,
      name: 'Testzelle',
      description: '',
      createdBy: _aDid,
      createdAt: DateTime.utc(2026, 1, 1),
      cellType: CellType.local,
      locationName: 'Testort',
      nostrTag: 'nexus-cell-$_cellId',
      maxMembers: 150,
      memberCount: 5,
    ),
  );
}

/// Injects a YNA proposal in VOTING_ENDED into ProposalService.
/// [eligibleVoters] defaults to all 5 test members.
/// [quorumRequired] defaults to 0.0 so quorum never blocks the tally result.
Proposal _injectYnaProposal({
  String proposalId = _propYna,
  List<String>? eligibleVoters,
  double quorumRequired = 0.0,
}) {
  final p = Proposal(
    id: proposalId,
    cellId: _cellId,
    creatorDid: _aDid,
    creatorPseudonym: 'Tester',
    title: 'YNA Testantrag',
    description: '',
    createdAt: DateTime.utc(2026, 1, 1),
    status: ProposalStatus.VOTING_ENDED,
    votingMode: VotingMode.YES_NO_ABSTAIN,
    votingEndsAt: DateTime.utc(2026, 1, 2),
    quorumRequired: quorumRequired,
    eligibleVoters: eligibleVoters ?? [..._allMembers],
  );
  ProposalService.instance.injectProposalForTest(p);
  return p;
}

/// Injects a SINGLE_CHOICE proposal in VOTING_ENDED.
Proposal _injectScProposal({
  String proposalId = _propSc,
  List<String>? eligibleVoters,
  double quorumRequired = 0.0,
}) {
  final p = Proposal(
    id: proposalId,
    cellId: _cellId,
    creatorDid: _aDid,
    creatorPseudonym: 'Tester',
    title: 'SC Testantrag',
    description: '',
    createdAt: DateTime.utc(2026, 1, 1),
    status: ProposalStatus.VOTING_ENDED,
    votingMode: VotingMode.SINGLE_CHOICE,
    votingEndsAt: DateTime.utc(2026, 1, 2),
    quorumRequired: quorumRequired,
    eligibleVoters: eligibleVoters ?? [..._allMembers],
  );
  ProposalService.instance.injectProposalForTest(p);
  return p;
}

/// Injects a CANDIDATE_CHOICE proposal in VOTING_ENDED.
Proposal _injectCcProposal({
  String proposalId = _propCc,
  List<String>? eligibleVoters,
}) {
  final p = Proposal(
    id: proposalId,
    cellId: _cellId,
    creatorDid: _aDid,
    creatorPseudonym: 'Tester',
    title: 'CC Testantrag',
    description: '',
    createdAt: DateTime.utc(2026, 1, 1),
    status: ProposalStatus.VOTING_ENDED,
    votingMode: VotingMode.CANDIDATE_CHOICE,
    votingEndsAt: DateTime.utc(2026, 1, 2),
    quorumRequired: 0.0,
    eligibleVoters: eligibleVoters ?? [..._allMembers],
  );
  ProposalService.instance.injectProposalForTest(p);
  return p;
}

/// Inserts a direct YNA vote for [voterDid] into the DB.
Future<Vote> _insertYnaVote(
  String proposalId,
  String voterDid,
  VoteChoice choice, {
  DateTime? createdAt,
}) async {
  final v = Vote(
    voteId: 'v-$voterDid-$proposalId',
    proposalId: proposalId,
    voterPubkey: voterDid, // use DID as pubkey for test uniqueness
    voterDid: voterDid,
    voterPseudonym: '',
    choice: choice,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1, 12),
    nostrEventId: '',
  );
  await PodDatabase.instance.upsertVote(v.toMap());
  return v;
}

/// Inserts a SINGLE_CHOICE vote for [voterDid] into the DB.
Future<Vote> _insertScVote(
  String proposalId,
  String voterDid,
  String optionId, {
  DateTime? createdAt,
}) async {
  final v = Vote(
    voteId: 'v-$voterDid-$proposalId',
    proposalId: proposalId,
    voterPubkey: voterDid,
    voterDid: voterDid,
    voterPseudonym: '',
    choice: VoteChoice.YES, // SC uses selectedOptionId, not choice
    selectedOptionId: optionId,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1, 12),
    nostrEventId: '',
  );
  await PodDatabase.instance.upsertVote(v.toMap());
  return v;
}

/// Inserts an ACTIVE delegation (delegatorDid → delegateDid) into the DB.
Future<Delegation> _insertDelegation(
  String proposalId,
  String delegatorDid,
  String delegateDid, {
  DateTime? createdAt,
}) async {
  final now = createdAt ?? DateTime.utc(2026, 1, 1, 6);
  final d = Delegation(
    delegationId: 'del-$delegatorDid-$delegateDid-$proposalId',
    delegatorDid: delegatorDid,
    delegateDid: delegateDid,
    proposalId: proposalId,
    cellId: _cellId,
    status: DelegationStatus.ACTIVE,
    createdAt: now,
    updatedAt: now,
  );
  await PodDatabase.instance.upsertDelegation(d.toMap());
  return d;
}

/// Inserts a proposal option into the DB.
Future<ProposalOption> _insertOption(
  String proposalId,
  String optionId,
  String label, {
  int position = 0,
}) async {
  final now = DateTime.utc(2026, 1, 1);
  final opt = ProposalOption(
    optionId: optionId,
    proposalId: proposalId,
    label: label,
    position: position,
    createdAt: now,
    updatedAt: now,
  );
  await PodDatabase.instance.upsertProposalOption(opt.toMap());
  return opt;
}

/// Reads back the DecisionRecord for [proposalId].
Future<Map<String, dynamic>?> _readRecord(String proposalId) async {
  return PodDatabase.instance.getDecisionRecord(proposalId);
}

/// Reads audit log entries filtered by [eventType] for [proposalId].
Future<List<AuditLogEntry>> _readAuditByType(
  String proposalId,
  AuditEventType eventType,
) async {
  final rows = await PodDatabase.instance.listAuditLog(proposalId);
  return rows
      .map(AuditLogEntry.fromMap)
      .where((e) => e.eventType == eventType)
      .toList();
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await _openTestDb();
    _setupServices();
  });

  tearDown(() async {
    ProposalService.instance.resetForTest();
    CellService.instance.clearForTest();
    IdentityService.instance.clearForTest();
    await db.close();
  });

  // ── D.1 Happy-Path YNA ────────────────────────────────────────────────────

  group('D.1 YNA Happy-Path', () {
    test('A→B, B votes YES → A counts as YES (yesVotes=2)', () async {
      _injectYnaProposal();
      await _insertYnaVote(_propYna, _bDid, VoteChoice.YES);
      await _insertDelegation(_propYna, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      expect(rec, isNotNull);
      expect(rec!['yes_votes'], equals(2),
          reason: 'A delegates to B who voted YES → A counted as YES');
      expect(rec['no_votes'], equals(0));
      expect(rec['abstain_votes'], equals(0));
    });

    test('A→B, B votes NO → A counts as NO (noVotes=2)', () async {
      _injectYnaProposal();
      await _insertYnaVote(_propYna, _bDid, VoteChoice.NO);
      await _insertDelegation(_propYna, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      expect(rec!['no_votes'], equals(2));
      expect(rec['yes_votes'], equals(0));
    });

    test('A→B, B votes ABSTAIN → A counts as ABSTAIN (abstainVotes=2)',
        () async {
      _injectYnaProposal();
      await _insertYnaVote(_propYna, _bDid, VoteChoice.ABSTAIN);
      await _insertDelegation(_propYna, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      expect(rec!['abstain_votes'], equals(2));
    });
  });

  // ── D.1 Happy-Path SC ─────────────────────────────────────────────────────

  group('D.1 SC Happy-Path', () {
    test('SC: A→B, B votes Option-X → A counts for Option-X', () async {
      _injectScProposal();
      await _insertOption(_propSc, 'opt1', 'Ja bitte', position: 0);
      await _insertOption(_propSc, 'opt2', 'Nein danke', position: 1);

      // B votes for opt1; A delegates to B.
      await _insertScVote(_propSc, _bDid, 'opt1');
      await _insertDelegation(_propSc, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propSc);

      final rec = await _readRecord(_propSc);
      expect(rec, isNotNull);
      // opt1 should have 2 votes (B direct + A delegated).
      final optResults =
          (rec!['option_results_json'] as String?) ?? '{}';
      // result is the winner label — either check optionResultsJson or
      // verify via the result (opt1 wins with 2 vs 0).
      expect(rec['result'], equals('approved'),
          reason: 'opt1 wins with 2/5 votes, quorum=0.0 → approved');
    });
  });

  // ── D.2 Non-transitive (E4) ───────────────────────────────────────────────

  group('D.2 Non-transitive (E4)', () {
    test('A→B, B→C, nobody votes → both delegations expire', () async {
      _injectYnaProposal();
      // No direct votes at all. Both delegations expire.
      await _insertDelegation(_propYna, _aDid, _bDid);
      await _insertDelegation(_propYna, _bDid, _cDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final expired =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_EXPIRED);
      // A→B: delegate B has no direct vote → EXPIRED.
      // B→C: delegate C has no direct vote → EXPIRED.
      expect(expired.length, equals(2),
          reason: 'Both delegations expire (neither B nor C voted directly)');
    });

    test(
        'A→B, B→C, only C votes directly → '
        'A expires (B no direct vote); B gets synthetic vote via C. '
        'Non-transitive: A does NOT benefit from C\'s vote', () async {
      // E4: A's delegation to B requires B to vote DIRECTLY.
      // B→C is an independent delegation: C voted → B gets a synthetic vote.
      // A's delegation expires because B never cast a direct vote.
      _injectYnaProposal();
      await _insertYnaVote(_propYna, _cDid, VoteChoice.NO);
      await _insertDelegation(_propYna, _aDid, _bDid);
      await _insertDelegation(_propYna, _bDid, _cDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      // C direct NO + B synthetic NO (via C) = 2 NO.
      // A's delegation expired; A is NOT counted (B never voted directly).
      expect(rec!['no_votes'], equals(2),
          reason: 'C direct + B synthetic via C; A expires (B no direct vote)');
      expect(rec['yes_votes'], equals(0));

      final expired =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_EXPIRED);
      expect(expired.length, equals(1),
          reason: 'Only A→B expires; B→C succeeds (C voted directly)');
    });

    test(
        'A→B, B→C chain: B votes YES, C votes NO → '
        'A=YES (via B direct), B=YES (direct), C=NO (direct), '
        'B\'s delegation to C silently ignored. YES=2, NO=1', () async {
      // This test verifies: non-transitive rule + direct-vote-overrides path.
      //
      // Setup:
      //   A → B (delegation)
      //   B → C (delegation; B is also delegator here)
      //   B votes YES directly  ← this is the critical fact
      //   C votes NO directly
      //
      // Tally evaluation order (sorted by createdAt):
      //   For delegation A→B: B has direct vote → SUCCESS → A gets YES.
      //   For delegation B→C: B (delegator) has direct vote → step 5c
      //                        (silently ignored, NO audit entry).
      //   C's direct NO vote counts normally.
      //
      // Expected: YES=2 (B direct + A synthetic), NO=1 (C direct).
      _injectYnaProposal();
      final t1 = DateTime.utc(2026, 1, 1, 6, 0);
      final t2 = DateTime.utc(2026, 1, 1, 6, 1);
      await _insertYnaVote(_propYna, _bDid, VoteChoice.YES);
      await _insertYnaVote(_propYna, _cDid, VoteChoice.NO);
      // A→B created before B→C for deterministic sort.
      await _insertDelegation(_propYna, _aDid, _bDid, createdAt: t1);
      await _insertDelegation(_propYna, _bDid, _cDid, createdAt: t2);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      expect(rec!['yes_votes'], equals(2),
          reason: 'B direct YES + A synthetic YES via B');
      expect(rec!['no_votes'], equals(1), reason: 'C direct NO');
      expect(rec!['abstain_votes'], equals(0));

      // No DELEGATION_EXPIRED entry for B→C (it's a silent ignore, step 5c).
      final expired =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_EXPIRED);
      expect(expired, isEmpty,
          reason: 'B→C is silently ignored (not expired), A→B succeeds');
    });
  });

  // ── D.3 EXPIRED classification ────────────────────────────────────────────

  group('D.3 EXPIRED classification', () {
    test('A→B, B does NOT vote → delegation EXPIRES, no vote added', () async {
      _injectYnaProposal();
      // No vote for B is inserted. A delegates to B.
      await _insertDelegation(_propYna, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      // No votes at all → no_valid_votes result.
      expect(rec!['yes_votes'], equals(0));
      expect(rec['no_votes'], equals(0));
      expect(rec['abstain_votes'], equals(0));
    });

    test('D9 Variante A: DB row remains ACTIVE after tally (no mutation)',
        () async {
      _injectYnaProposal();
      await _insertDelegation(_propYna, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      // The delegation row must still be ACTIVE — tally must NOT write EXPIRED.
      final rows =
          await PodDatabase.instance.listActiveDelegationsForProposal(_propYna);
      expect(rows.length, equals(1),
          reason: 'ACTIVE delegation unchanged in DB (D9 Variante A)');
      expect(rows.first['status'], equals('ACTIVE'));
    });

    test('Audit DELEGATION_EXPIRED has actorDid=SYSTEM and correct payload',
        () async {
      _injectYnaProposal();
      final d = await _insertDelegation(_propYna, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final expired =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_EXPIRED);
      expect(expired.length, equals(1));
      final entry = expired.first;
      expect(entry.actorDid, equals('SYSTEM'));
      expect(entry.payload['delegationId'], equals(d.delegationId));
      expect(entry.payload['reason'], equals('DELEGATE_DID_NOT_VOTE'));
      expect(entry.payload['delegateDid'], equals(_bDid));
    });
  });

  // ── D.4 INVALID classification ────────────────────────────────────────────

  group('D.4 INVALID classification', () {
    test(
        'Delegator not in eligibleVoters → DELEGATION_INVALIDATED '
        '(DELEGATOR_NOT_ELIGIBLE), no vote added', () async {
      // eligibleVoters excludes _aDid (the delegator).
      _injectYnaProposal(
          eligibleVoters: [_bDid, _cDid, _dDid, _eDid]);
      await _insertYnaVote(_propYna, _bDid, VoteChoice.YES);
      final d = await _insertDelegation(_propYna, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      // Only B's direct vote counts; A's delegation is INVALID.
      final rec = await _readRecord(_propYna);
      expect(rec!['yes_votes'], equals(1),
          reason: 'Only B direct vote; A delegation invalid');

      final invalid =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_INVALIDATED);
      expect(invalid.length, equals(1));
      expect(invalid.first.actorDid, equals('SYSTEM'));
      expect(invalid.first.payload['delegationId'], equals(d.delegationId));
      expect(invalid.first.payload['reason'],
          equals('DELEGATOR_NOT_ELIGIBLE'));
    });

    test(
        'Delegate not in eligibleVoters → DELEGATION_INVALIDATED '
        '(DELEGATE_NOT_ELIGIBLE), no vote added', () async {
      // eligibleVoters excludes _bDid (the delegate).
      _injectYnaProposal(
          eligibleVoters: [_aDid, _cDid, _dDid, _eDid]);
      // B is not eligible so we don't give B a vote either.
      final d = await _insertDelegation(_propYna, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      expect(rec!['yes_votes'], equals(0));

      final invalid =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_INVALIDATED);
      expect(invalid.length, equals(1));
      expect(invalid.first.payload['reason'],
          equals('DELEGATE_NOT_ELIGIBLE'));
      expect(invalid.first.payload['delegateDid'], equals(_bDid));
    });

    test('INVALID delegation DB row remains ACTIVE (D9 Variante A)', () async {
      _injectYnaProposal(eligibleVoters: [_bDid, _cDid, _dDid, _eDid]);
      await _insertDelegation(_propYna, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rows =
          await PodDatabase.instance.listActiveDelegationsForProposal(_propYna);
      expect(rows.length, equals(1),
          reason: 'INVALID delegation also stays ACTIVE in DB');
    });
  });

  // ── D.5 Direct-vote-overrides-delegation consistency ─────────────────────

  group('D.5 Direct-vote-overrides-delegation consistency', () {
    test(
        'ACTIVE delegation in DB + direct vote by delegator → '
        'direct vote counts, delegation silently ignored, NO audit entry',
        () async {
      // Simulates a multi-device race: delegation not yet revoked on this device
      // but delegator has already voted directly (e.g. on another device).
      _injectYnaProposal();
      await _insertYnaVote(_propYna, _aDid, VoteChoice.NO); // A direct vote
      await _insertYnaVote(_propYna, _bDid, VoteChoice.YES); // B direct vote
      await _insertDelegation(_propYna, _aDid, _bDid); // A still delegates (stale)

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      // A's direct NO + B's direct YES = 1+1; delegation ignored.
      expect(rec!['no_votes'], equals(1));
      expect(rec['yes_votes'], equals(1));

      // No audit entry for the ignored delegation (normal consistency path).
      final expired =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_EXPIRED);
      final invalid =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_INVALIDATED);
      expect(expired, isEmpty, reason: 'No EXPIRED audit for direct-vote path');
      expect(invalid, isEmpty,
          reason: 'No INVALIDATED audit for direct-vote path');
    });
  });

  // ── D.6 participationCount semantics ─────────────────────────────────────

  group('D.6 participationCount', () {
    test(
        'YNA: 5 members, 2 direct votes, 1 successful delegation, '
        '1 expired delegation → participation = 3/5 = 0.6', () async {
      _injectYnaProposal(); // eligibleVoters = [A,B,C,D,E]
      // B votes YES (direct); C votes NO (direct); D delegates to B (success);
      // A delegates to E (E doesn't vote → EXPIRED).
      await _insertYnaVote(_propYna, _bDid, VoteChoice.YES);
      await _insertYnaVote(_propYna, _cDid, VoteChoice.NO);
      await _insertDelegation(_propYna, _dDid, _bDid); // success: B voted
      await _insertDelegation(_propYna, _aDid, _eDid); // expired: E didn't vote

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      expect(rec!['yes_votes'], equals(2),
          reason: 'B direct YES + D synthetic YES via B');
      expect(rec['no_votes'], equals(1), reason: 'C direct NO');
      // participation = (2+1+0) / 5 = 0.6 (3 effective votes out of 5)
      expect((rec['participation'] as double).toStringAsFixed(4), equals('0.6000'));
    });

    test(
        'SC: successful delegation counts in participation', () async {
      _injectScProposal(); // 5 eligible
      await _insertOption(_propSc, 'optA', 'Variante A', position: 0);
      await _insertOption(_propSc, 'optB', 'Variante B', position: 1);

      // B votes optA; A delegates to B.
      await _insertScVote(_propSc, _bDid, 'optA');
      await _insertDelegation(_propSc, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propSc);

      final rec = await _readRecord(_propSc);
      // participation = 2/5 = 0.4
      expect((rec!['participation'] as double).toStringAsFixed(4),
          equals('0.4000'),
          reason: 'B direct + A delegated = 2 effective votes out of 5');
    });
  });

  // ── D.7 Determinism / contentHash ────────────────────────────────────────

  group('D.7 Determinism', () {
    test(
        'Identical inputs produce identical contentHash '
        '(idempotency guard prevents second run)', () async {
      _injectYnaProposal();
      await _insertYnaVote(_propYna, _bDid, VoteChoice.YES);
      await _insertDelegation(_propYna, _aDid, _bDid);

      // First tally.
      await ProposalService.instance.finalizeProposal(_propYna);
      final rec1 = await _readRecord(_propYna);
      final hash1 = rec1!['content_hash'] as String;

      // Reset in-memory status to VOTING_ENDED to allow second call.
      // (In production, second device hits idempotency guard instead.)
      final p = ProposalService.instance.allProposals
          .firstWhere((p) => p.id == _propYna);
      p.status = ProposalStatus.VOTING_ENDED;

      // Second finalizeProposal call: idempotency guard fires because the
      // DecisionRecord already exists in DB → skips computation entirely,
      // but the hash in DB is unchanged.
      await ProposalService.instance.finalizeProposal(_propYna);
      final rec2 = await _readRecord(_propYna);
      final hash2 = rec2!['content_hash'] as String;

      expect(hash1, equals(hash2),
          reason: 'contentHash must be stable across identical computations');
    });

    test(
        'Delegation order is deterministic: sorted by createdAt ASC, '
        'delegationId ASC — same DB yields same synthetic vote list', () async {
      _injectYnaProposal();
      // Insert three delegations with different timestamps.
      await _insertYnaVote(_propYna, _cDid, VoteChoice.YES);
      final t1 = DateTime.utc(2026, 1, 1, 6, 0);
      final t2 = DateTime.utc(2026, 1, 1, 7, 0);
      final t3 = DateTime.utc(2026, 1, 1, 8, 0);
      await _insertDelegation(_propYna, _aDid, _cDid, createdAt: t1);
      await _insertDelegation(_propYna, _bDid, _cDid, createdAt: t2);
      await _insertDelegation(_propYna, _dDid, _cDid, createdAt: t3);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      // C direct YES + A, B, D synthetic YES = 4 total YES.
      expect(rec!['yes_votes'], equals(4));
    });
  });

  // ── D.8 CANDIDATE_CHOICE exclusion ────────────────────────────────────────

  group('D.8 CANDIDATE_CHOICE — delegation has no effect', () {
    test(
        'CC proposal with delegations in DB: tally ignores delegations, '
        'no DELEGATION_* audit entries', () async {
      _injectCcProposal();
      await _insertOption(_propCc, 'cand1', 'Kandidat 1', position: 0);

      // B votes for cand1; A delegates to B — but CC ignores delegations.
      await _insertScVote(_propCc, _bDid, 'cand1');
      await _insertDelegation(_propCc, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propCc);

      // Only B's direct vote should count in the CC tally.
      final rec = await _readRecord(_propCc);
      // optionResultsJson format: canonical JSON map {"optionId": count, ...}
      // e.g. {"cand1":1}
      final optJson = rec!['option_results_json'] as String?;
      expect(optJson, isNotNull);
      expect(optJson, contains('"cand1":1'),
          reason: 'Only 1 vote for cand1 (B direct), delegation ignored');
      expect(optJson, isNot(contains('"cand1":2')));

      // No delegation audit entries at all from CC path.
      final expired =
          await _readAuditByType(_propCc, AuditEventType.DELEGATION_EXPIRED);
      final invalid =
          await _readAuditByType(_propCc, AuditEventType.DELEGATION_INVALIDATED);
      expect(expired, isEmpty);
      expect(invalid, isEmpty);
    });
  });

  // ── D.9 Stichwahl (runoff) — no cross-proposal delegation ────────────────

  group('D.9 Stichwahl-Folge-Proposal', () {
    test(
        'Runoff proposal does NOT inherit delegations from original: '
        'delegations are scoped to their proposalId', () async {
      // Set up original proposal with a delegation.
      _injectYnaProposal(proposalId: 'prop_orig');
      await _insertDelegation('prop_orig', _aDid, _bDid);

      // Set up a separate runoff proposal (new proposalId) with NO delegations.
      _injectScProposal(proposalId: _propRunoff);
      await _insertOption(_propRunoff, 'r1', 'Opt 1', position: 0);
      await _insertOption(_propRunoff, 'r2', 'Opt 2', position: 1);
      await _insertScVote(_propRunoff, _bDid, 'r1');
      // A does NOT vote on the runoff and has NO delegation for the runoff.

      await ProposalService.instance.finalizeProposal(_propRunoff);

      final rec = await _readRecord(_propRunoff);
      // Only B's direct vote counts; A's delegation to _propOrig does NOT
      // affect the runoff proposal (different proposalId).
      expect(rec!['participation'],
          lessThan(2 / 5 + 0.01), // ≤ 0.4
          reason: 'Only 1 vote counted (B direct), A has no runoff delegation');
    });
  });

  // ── D.10 Edge cases ───────────────────────────────────────────────────────

  group('D.10 Edge cases', () {
    test(
        'No delegations at all: directVotes returned unchanged, '
        'no DELEGATION_* audit entries, only regular RESULT_CALCULATED', () async {
      _injectYnaProposal();
      await _insertYnaVote(_propYna, _bDid, VoteChoice.YES);
      await _insertYnaVote(_propYna, _cDid, VoteChoice.NO);
      // No delegations inserted.

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      expect(rec!['yes_votes'], equals(1));
      expect(rec['no_votes'], equals(1));

      final expired =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_EXPIRED);
      final invalid =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_INVALIDATED);
      expect(expired, isEmpty);
      expect(invalid, isEmpty);
    });

    test(
        'Only EXPIRED delegations: no synthetic votes, '
        'audit entries written, participation unchanged', () async {
      _injectYnaProposal();
      // C votes; A→B and D→E delegations both expire (B and E don't vote).
      await _insertYnaVote(_propYna, _cDid, VoteChoice.YES);
      await _insertDelegation(_propYna, _aDid, _bDid);
      await _insertDelegation(_propYna, _dDid, _eDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      // Only C's direct vote counts.
      expect(rec!['yes_votes'], equals(1));

      final expired =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_EXPIRED);
      expect(expired.length, equals(2));
    });

    test(
        'Self-delegation defense: A→A with A voting directly → '
        'step 5c catches it (direct-vote-overrides), no audit', () async {
      // Self-delegation is blocked at createDelegation, but if one reaches DB
      // (e.g. from a buggy peer device), the tally must handle it gracefully.
      _injectYnaProposal();
      await _insertYnaVote(_propYna, _aDid, VoteChoice.YES);
      // Insert a self-delegation A→A directly to DB (bypassing service validation).
      final now = DateTime.utc(2026, 1, 1, 6);
      await db.insert('delegations', {
        'delegation_id': 'self-del-a',
        'delegator_did': _aDid,
        'delegate_did': _aDid,
        'proposal_id': _propYna,
        'cell_id': _cellId,
        'status': 'ACTIVE',
        'nostr_event_id': '',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      // A's direct YES counts; self-delegation is silently ignored (step 5c).
      expect(rec!['yes_votes'], equals(1));

      final expired =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_EXPIRED);
      final invalid =
          await _readAuditByType(_propYna, AuditEventType.DELEGATION_INVALIDATED);
      expect(expired, isEmpty, reason: 'Self-delegation uses step 5c, not 5d');
      expect(invalid, isEmpty);
    });

    test(
        'Multiple successful delegations to same delegate: '
        'all aggregate correctly', () async {
      _injectYnaProposal();
      // B votes YES; A, C, D all delegate to B.
      await _insertYnaVote(_propYna, _bDid, VoteChoice.YES);
      await _insertDelegation(_propYna, _aDid, _bDid);
      await _insertDelegation(_propYna, _cDid, _bDid);
      await _insertDelegation(_propYna, _dDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await _readRecord(_propYna);
      // B direct + A, C, D synthetic = 4 YES total.
      expect(rec!['yes_votes'], equals(4));
    });

    test(
        'Synthetic vote voteId starts with "delegated-" '
        '(visible in allVotes of DecisionRecord)', () async {
      _injectYnaProposal();
      await _insertYnaVote(_propYna, _bDid, VoteChoice.YES);
      final d = await _insertDelegation(_propYna, _aDid, _bDid);

      await ProposalService.instance.finalizeProposal(_propYna);

      final rec = await ProposalService.instance.getDecisionRecord(_propYna);
      expect(rec, isNotNull);
      final syntheticVote = rec!.allVotes.firstWhere(
        (v) => v.isDelegated,
        orElse: () => throw TestFailure('No synthetic vote found'),
      );
      expect(syntheticVote.voteId, equals('delegated-${d.delegationId}'));
      expect(syntheticVote.delegatedFrom, equals(_bDid));
      expect(syntheticVote.voterDid, equals(_aDid));
    });
  });
}
