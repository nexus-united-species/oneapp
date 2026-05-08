// ignore_for_file: avoid_print
// Phase G2.1.6 — Multi-device delegation auto-revoke on incoming direct vote.
//
// Verifies that handleIncomingVote on receiver devices performs an immediate
// local REVOKE of any ACTIVE delegation belonging to the same voterDid after
// successful vote persistence — without waiting for the separate
// Kind-31012-Revoke event (Sender-only pattern §31.3).
//
// No mock framework — capture callbacks and real in-memory DB throughout.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/identity.dart';
import 'package:nexus_oneapp/core/identity/identity_service.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result_status.dart';
import 'package:nexus_oneapp/features/governance/audit_log_entry.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';
import 'package:nexus_oneapp/features/governance/cell_member.dart';
import 'package:nexus_oneapp/features/governance/cell_service.dart';
import 'package:nexus_oneapp/features/governance/delegation.dart';
import 'package:nexus_oneapp/features/governance/proposal.dart';
import 'package:nexus_oneapp/features/governance/proposal_service.dart';
import 'package:nexus_oneapp/features/governance/vote.dart';
import 'package:nexus_oneapp/features/governance/voting_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

// Receiver device identity (this device — "A1").
const _myDid = 'did:key:z6MkReceiverIncoming';
const _myPubkey =
    'aa00000000000000000000000000000000000000000000000000000000000001';

// Voter / delegator (user A on device A2 — sends the vote).
const _voterDid = 'did:key:z6MkVoterIncoming';
const _voterPubkey =
    'bb00000000000000000000000000000000000000000000000000000000000002';

// Delegate (user B — the one who had received the delegation).
const _delegateDid = 'did:key:z6MkDelegateIncoming';

// Unrelated member.
const _otherDid = 'did:key:z6MkOtherIncoming';

const _cellId = 'cell_incoming_g216_test';
const _propId = 'prop_incoming_g216_test';

// ── DB helper ──────────────────────────────────────────────────────────────────

Future<Database> _openTestDb() async {
  final db = await openDatabase(
    inMemoryDatabasePath,
    version: 1,
    onCreate: (db, _) async {
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
      await db.execute('''
        CREATE TABLE cells (
          id TEXT PRIMARY KEY, enc TEXT NOT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE cell_members (
          cell_id TEXT NOT NULL, did TEXT NOT NULL,
          enc TEXT NOT NULL, PRIMARY KEY (cell_id, did)
        )
      ''');
      await db.execute(
          'CREATE TABLE cell_join_requests (id TEXT PRIMARY KEY, cell_id TEXT NOT NULL, is_sent INTEGER NOT NULL DEFAULT 0, enc TEXT NOT NULL)');
      await db.execute('''
        CREATE TABLE proposals (
          id TEXT PRIMARY KEY, cell_id TEXT NOT NULL,
          creator_did TEXT NOT NULL, creator_pseudonym TEXT NOT NULL DEFAULT '',
          title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
          proposal_type TEXT NOT NULL DEFAULT 'SACHFRAGE', category TEXT,
          status TEXT NOT NULL DEFAULT 'DRAFT',
          created_at INTEGER NOT NULL, discussion_started_at INTEGER,
          voting_started_at INTEGER, voting_ends_at INTEGER,
          decided_at INTEGER, archived_at INTEGER, withdrawn_at INTEGER,
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
          voice_credits INTEGER NOT NULL DEFAULT 1,
          reasoning TEXT, selected_option_id TEXT,
          created_at INTEGER NOT NULL,
          is_delegated INTEGER NOT NULL DEFAULT 0,
          delegated_from TEXT,
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
          record_id TEXT PRIMARY KEY,
          proposal_id TEXT NOT NULL UNIQUE,
          cell_id TEXT NOT NULL, final_title TEXT NOT NULL,
          final_description TEXT NOT NULL, result TEXT NOT NULL,
          yes_votes INTEGER NOT NULL, no_votes INTEGER NOT NULL,
          abstain_votes INTEGER NOT NULL, participation REAL NOT NULL,
          decided_at INTEGER NOT NULL, all_votes TEXT NOT NULL,
          content_hash TEXT NOT NULL, previous_decision_hash TEXT,
          nostr_event_id TEXT NOT NULL DEFAULT ''
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
          id TEXT NOT NULL, type TEXT NOT NULL,
          reason TEXT, created_at INTEGER NOT NULL,
          PRIMARY KEY (id, type)
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
          publish_result_id TEXT PRIMARY KEY,
          local_event_id TEXT NOT NULL, nostr_event_id TEXT,
          event_kind INTEGER NOT NULL, proposal_id TEXT,
          cell_id TEXT, vote_id TEXT,
          status TEXT NOT NULL DEFAULT 'PENDING',
          attempted_at INTEGER NOT NULL, ack_received_at INTEGER,
          error_code TEXT, error_message TEXT,
          retry_count INTEGER NOT NULL DEFAULT 0,
          next_retry_at INTEGER,
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
          label TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'ACTIVE',
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS delegations (
          delegation_id TEXT PRIMARY KEY,
          delegator_did TEXT NOT NULL, delegate_did TEXT NOT NULL,
          proposal_id TEXT NOT NULL, cell_id TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'ACTIVE',
          nostr_event_id TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_delegations_proposal_g216 ON delegations(proposal_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_delegations_delegator_g216 ON delegations(delegator_did)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_delegations_status_g216 ON delegations(status)');
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS ux_active_delegation_per_proposal_g216
          ON delegations(delegator_did, proposal_id)
          WHERE status = 'ACTIVE'
      ''');
    },
  );
  final key = Uint8List(32)..fillRange(0, 32, 0x43);
  PodDatabase.instance.injectDatabase(db, key);
  return db;
}

// ── Per-test state setup ───────────────────────────────────────────────────────

Future<void> _setupStandardState({
  ProposalStatus status = ProposalStatus.VOTING,
  VotingMode votingMode = VotingMode.YES_NO_ABSTAIN,
}) async {
  IdentityService.instance.setForTest(
    NexusIdentity(publicKeyHex: _myPubkey, pseudonym: 'Empfänger', did: _myDid),
  );

  final cell = Cell(
    id: _cellId,
    name: 'Testzelle G2.1.6',
    description: '',
    createdBy: _myDid,
    createdAt: DateTime.utc(2026, 1, 1),
    cellType: CellType.local,
    locationName: 'Testort',
    nostrTag: 'nexus-cell-$_cellId',
    maxMembers: 150,
    memberCount: 4,
  );
  CellService.instance.addCellForTest(cell);

  final now = DateTime.utc(2026, 1, 1);
  for (final (did, role) in [
    (_myDid, MemberRole.founder),
    (_voterDid, MemberRole.member),
    (_delegateDid, MemberRole.member),
    (_otherDid, MemberRole.member),
  ]) {
    final m = CellMember(
      cellId: _cellId,
      did: did,
      joinedAt: now,
      role: role,
      confirmedBy: _myDid,
    );
    CellService.instance.addMemberForTest(_cellId, m);
    await PodDatabase.instance.upsertCellMember(_cellId, did, m.toJson());
  }

  final prop = Proposal(
    id: _propId,
    cellId: _cellId,
    creatorDid: _myDid,
    creatorPseudonym: 'Empfänger',
    title: 'G2.1.6 Testantrag',
    description: '',
    createdAt: DateTime.utc(2026, 1, 1),
    status: status,
    votingMode: votingMode,
    votingEndsAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
  ProposalService.instance.injectProposalForTest(prop);
}

// ── DB read helpers ────────────────────────────────────────────────────────────

Future<List<AuditLogEntry>> _readAudit(String proposalId) async {
  final rows = await PodDatabase.instance.listAuditLog(proposalId);
  return rows.map(AuditLogEntry.fromMap).toList();
}

Future<List<AuditLogEntry>> _readAutoRevokeAudit(String proposalId) async {
  final all = await _readAudit(proposalId);
  return all
      .where((a) =>
          a.eventType == AuditEventType.DELEGATION_REVOKED_BY_DIRECT_VOTE)
      .toList();
}

Future<Map<String, dynamic>?> _readDelegation(String delegationId) =>
    PodDatabase.instance.getDelegation(delegationId);

// ── Delegation insert helper ───────────────────────────────────────────────────

Future<Delegation> _insertActiveDelegation({
  String? delegationId,
  String delegatorDid = _voterDid,
  String delegateDid = _delegateDid,
  String proposalId = _propId,
  DelegationStatus status = DelegationStatus.ACTIVE,
}) async {
  final now = DateTime.now().toUtc();
  final d = Delegation(
    delegationId: delegationId ?? 'del_g216_${now.microsecondsSinceEpoch}',
    delegatorDid: delegatorDid,
    delegateDid: delegateDid,
    proposalId: proposalId,
    cellId: _cellId,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
  await PodDatabase.instance.upsertDelegation(d.toMap());
  return d;
}

// ── NostrEvent factories ───────────────────────────────────────────────────────

int _evtCounter = 0;

/// Builds a Kind-31011 incoming vote NostrEvent.
/// [pubkey] defaults to [_voterPubkey] (not our own key → not an echo).
NostrEvent _makeVoteEvent({
  String? voteId,
  String voterDid = _voterDid,
  String proposalId = _propId,
  String cellId = _cellId,
  String choice = 'YES',
  String? selectedOptionId,
  String? pubkey,
  String? eventId,
}) {
  _evtCounter++;
  final id = eventId ??
      'cafebabe${_evtCounter.toString().padLeft(56, '0')}';
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final content = jsonEncode(<String, dynamic>{
    'voteId': voteId ?? 'vote_g216_$_evtCounter',
    'voterDid': voterDid,
    'voterPseudonym': 'Wähler',
    'createdAt': nowMs ~/ 1000,
    if (selectedOptionId != null) 'selectedOptionId': selectedOptionId,
  });
  return NostrEvent(
    id: id,
    pubkey: pubkey ?? _voterPubkey,
    createdAt: nowMs ~/ 1000,
    kind: NostrKind.voteEvent,
    tags: [
      ['proposal_id', proposalId],
      ['t', 'nexus-cell-$cellId'],
      ['choice', choice],
    ],
    content: content,
    sig: 'sig${'0' * 124}',
  );
}

/// Builds a Kind-31012 incoming delegation NostrEvent with the given status.
/// Used in wire-order tests (G2.1.6 C.4).
NostrEvent _makeDelegationEvent({
  required String delegationId,
  String delegatorDid = _voterDid,
  String delegateDid = _delegateDid,
  String proposalId = _propId,
  String cellId = _cellId,
  String status = 'REVOKED',
  String? pubkey,
}) {
  _evtCounter++;
  final id = 'deadbeef${_evtCounter.toString().padLeft(56, '0')}';
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final content = jsonEncode(<String, dynamic>{
    'delegationId': delegationId,
    'delegatorDid': delegatorDid,
    'delegateDid': delegateDid,
    'proposalId': proposalId,
    'cellId': cellId,
    'status': status,
    'createdAt': nowMs,
    'updatedAt': nowMs,
  });
  return NostrEvent(
    id: id,
    pubkey: pubkey ?? _voterPubkey,
    createdAt: nowMs ~/ 1000,
    kind: NostrKind.delegationEvent,
    tags: [
      ['d', delegationId],
      ['t', 'nexus-delegation'],
      ['t', 'nexus-cell-$cellId'],
      ['proposal_id', proposalId],
    ],
    content: content,
    sig: 'sig${'0' * 124}',
  );
}

// ── PublishResult factory ──────────────────────────────────────────────────────

PublishResult _acceptedResult() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return PublishResult(
    publishResultId: 'pr_g216_$now',
    localEventId: 'le_g216_$now',
    eventKind: NostrKind.delegationEvent,
    status: PublishResultStatus.accepted,
    finalStatus: PublishResultStatus.accepted,
    attemptedAt: now,
    retryCount: 0,
    requiredAckCount: 2,
    acceptedRelayCount: 2,
    failedRelayCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await _openTestDb();
    await _setupStandardState();
    ProposalService.instance.getMyNostrPubkeyHex = () => _myPubkey;
    // Default: no-op vote publish (required so castVote doesn't crash).
    ProposalService.instance.onPublishVoteToNostr = (_) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      return PublishResult(
        publishResultId: 'vote_pr_$now',
        localEventId: 'vote_le_$now',
        eventKind: NostrKind.voteEvent,
        status: PublishResultStatus.accepted,
        finalStatus: PublishResultStatus.accepted,
        attemptedAt: now,
        retryCount: 0,
        requiredAckCount: 2,
        acceptedRelayCount: 2,
        failedRelayCount: 0,
        createdAt: now,
        updatedAt: now,
      );
    };
    // Default: no-op delegation publish.
    ProposalService.instance.onPublishDelegationToNostr =
        (_) async => _acceptedResult();
  });

  tearDown(() async {
    ProposalService.instance.resetForTest();
    CellService.instance.clearForTest();
    IdentityService.instance.clearForTest();
    await db.close();
  });

  // ── C.1 Happy-path tests ───────────────────────────────────────────────────

  group('G2.1.6 — Happy path', () {
    test(
        'handleIncomingVote auto-revokes existing ACTIVE delegation of the same voter',
        () async {
      final del = await _insertActiveDelegation();
      final event = _makeVoteEvent();

      await ProposalService.instance.handleIncomingVote(event);

      final row = await _readDelegation(del.delegationId);
      expect(row, isNotNull);
      expect(row!['status'], equals('REVOKED'),
          reason: 'Delegation must be REVOKED after incoming direct vote');
    });

    test(
        'handleIncomingVote writes DELEGATION_REVOKED_BY_DIRECT_VOTE audit on receiver',
        () async {
      final del = await _insertActiveDelegation();
      final event = _makeVoteEvent();

      await ProposalService.instance.handleIncomingVote(event);

      final autoRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevoke, hasLength(1));
      expect(autoRevoke.first.actorDid, equals(_voterDid));
      expect(autoRevoke.first.payload['delegationId'],
          equals(del.delegationId));
    });

    test(
        'handleIncomingVote auto-revoke does NOT publish Kind-31012 '
        '(sender-only pattern §31.3)', () async {
      await _insertActiveDelegation();
      final event = _makeVoteEvent();

      final delegationPublishCalls = <Delegation>[];
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        delegationPublishCalls.add(d);
        return _acceptedResult();
      };

      await ProposalService.instance.handleIncomingVote(event);

      expect(delegationPublishCalls, isEmpty,
          reason: 'Receiver must NOT publish Kind-31012 (sender-only §31.3)');
    });
  });

  // ── C.2 Idempotency tests ──────────────────────────────────────────────────

  group('G2.1.6 — Idempotency', () {
    test(
        'handleIncomingVote auto-revoke is idempotent — '
        'second arrival of same vote does not write second audit entry',
        () async {
      await _insertActiveDelegation();
      // Use a fixed event ID so the second call is a genuine duplicate.
      const fixedEventId =
          'cafebabe0000000000000000000000000000000000000000000000001234abcd';
      final event = _makeVoteEvent(eventId: fixedEventId);

      await ProposalService.instance.handleIncomingVote(event);
      // Second call with identical event — _seenVoteEventIds guard catches it.
      await ProposalService.instance.handleIncomingVote(event);

      final autoRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevoke, hasLength(1),
          reason: 'Duplicate vote arrival must not produce a second auto-revoke audit');
    });

    test(
        'handleIncomingVote auto-revoke does NOT trigger '
        'when delegation is already REVOKED', () async {
      await _insertActiveDelegation(status: DelegationStatus.REVOKED);
      final event = _makeVoteEvent();

      await ProposalService.instance.handleIncomingVote(event);

      final autoRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevoke, isEmpty,
          reason: 'Already-REVOKED delegation must not trigger auto-revoke');
    });

    test(
        'handleIncomingVote auto-revoke does NOT trigger '
        'when delegation is SUPERSEDED', () async {
      await _insertActiveDelegation(status: DelegationStatus.SUPERSEDED);
      final event = _makeVoteEvent();

      await ProposalService.instance.handleIncomingVote(event);

      final autoRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevoke, isEmpty,
          reason: 'SUPERSEDED delegation must not trigger auto-revoke');
    });

    test(
        'handleIncomingVote echo of own vote does NOT write second audit '
        '(delegation already revoked by castVote)', () async {
      // Simulate: castVote on this device already revoked the delegation.
      // The delegation is stored as REVOKED in the DB.
      await _insertActiveDelegation(
        delegatorDid: _myDid,
        status: DelegationStatus.REVOKED,
      );
      // Echo: pubkey == _myPubkey → handleIncomingVote returns immediately.
      final echoEvent = _makeVoteEvent(
        voterDid: _myDid,
        pubkey: _myPubkey,
      );

      await ProposalService.instance.handleIncomingVote(echoEvent);

      final autoRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevoke, isEmpty,
          reason: 'Echo of own vote must not produce an auto-revoke audit');
    });
  });

  // ── C.3 Negative tests ────────────────────────────────────────────────────

  group('G2.1.6 — Negative (no auto-revoke)', () {
    test(
        'handleIncomingVote auto-revoke does NOT trigger '
        'when no ACTIVE delegation exists for the voter', () async {
      // No delegation inserted at all.
      final event = _makeVoteEvent();

      await ProposalService.instance.handleIncomingVote(event);

      final autoRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevoke, isEmpty);
    });

    test(
        'handleIncomingVote auto-revoke does NOT trigger '
        'when delegation belongs to a different voter', () async {
      // Delegation is for _otherDid, not _voterDid.
      await _insertActiveDelegation(delegatorDid: _otherDid);
      final event = _makeVoteEvent(voterDid: _voterDid);

      await ProposalService.instance.handleIncomingVote(event);

      final autoRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevoke, isEmpty,
          reason: 'Auto-revoke must not fire for a delegation of a different voter');
    });

    test(
        'handleIncomingVote auto-revoke does NOT trigger '
        'on rejected/invalid incoming votes (Phase 4.7b reject path)', () async {
      // YES_NO_ABSTAIN mode + selectedOptionId set → rejectReason is non-null
      // → handleIncomingVote returns before the success path (and before G2.1.6).
      final del = await _insertActiveDelegation();
      final rejectedEvent = _makeVoteEvent(selectedOptionId: 'opt_invalid');

      await ProposalService.instance.handleIncomingVote(rejectedEvent);

      // Vote must NOT be persisted.
      final votes = await PodDatabase.instance.testDb.query(
        'proposal_votes',
        where: 'proposal_id = ?',
        whereArgs: [_propId],
      );
      expect(votes, isEmpty,
          reason: 'Rejected vote must not be persisted to DB');

      // Delegation must remain ACTIVE.
      final row = await _readDelegation(del.delegationId);
      expect(row!['status'], equals('ACTIVE'),
          reason: 'Auto-revoke must not run on rejected vote path');

      // No auto-revoke audit.
      final autoRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevoke, isEmpty);
    });
  });

  // ── C.4 Wire-order tests ──────────────────────────────────────────────────

  group('G2.1.6 — Wire order', () {
    test(
        'Vote arrives before Kind-31012 revoke event: '
        'G2.1.6 revokes locally; later-arriving revoke event '
        'triggers no second DELEGATION_REVOKED_BY_DIRECT_VOTE audit',
        () async {
      final del = await _insertActiveDelegation();

      // Step 1: vote arrives first → G2.1.6 auto-revokes.
      final voteEvent = _makeVoteEvent();
      await ProposalService.instance.handleIncomingVote(voteEvent);

      final autoRevokeAfterVote = await _readAutoRevokeAudit(_propId);
      expect(autoRevokeAfterVote, hasLength(1),
          reason: 'G2.1.6 must have revoked after vote arrived');

      // Step 2: Kind-31012-Revoke event arrives later.
      final delegationRevokeEvent = _makeDelegationEvent(
        delegationId: del.delegationId,
        status: 'REVOKED',
      );
      await ProposalService.instance
          .handleIncomingDelegationEvent(delegationRevokeEvent);

      // G2.1.6 auto-revoke count must still be exactly 1.
      final autoRevokeAfterRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevokeAfterRevoke, hasLength(1),
          reason: 'Subsequent Kind-31012 must not write a second '
              'DELEGATION_REVOKED_BY_DIRECT_VOTE audit');
    });

    test(
        'Kind-31012 revoke event arrives before vote: '
        'delegation already REVOKED; vote arrival finds no ACTIVE delegation, '
        'no DELEGATION_REVOKED_BY_DIRECT_VOTE audit',
        () async {
      final del = await _insertActiveDelegation();

      // Step 1: Kind-31012-Revoke arrives first → handleIncomingDelegationEvent.
      final delegationRevokeEvent = _makeDelegationEvent(
        delegationId: del.delegationId,
        status: 'REVOKED',
      );
      await ProposalService.instance
          .handleIncomingDelegationEvent(delegationRevokeEvent);

      // Delegation is now REVOKED via G2.1.2 path.
      final rowAfterRevoke = await _readDelegation(del.delegationId);
      expect(rowAfterRevoke!['status'], equals('REVOKED'));

      // Step 2: Vote arrives later → G2.1.6 finds no ACTIVE delegation.
      final voteEvent = _makeVoteEvent();
      await ProposalService.instance.handleIncomingVote(voteEvent);

      // No DELEGATION_REVOKED_BY_DIRECT_VOTE audit (G2.1.2 already handled it).
      final autoRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevoke, isEmpty,
          reason: 'When Kind-31012 arrived first, G2.1.6 must find no ACTIVE '
              'delegation and skip auto-revoke silently');
    });
  });

  // ── C.5 Audit-format test ─────────────────────────────────────────────────

  group('G2.1.6 — Audit format', () {
    test(
        'Audit DELEGATION_REVOKED_BY_DIRECT_VOTE on receiver has '
        'actorDid=voterDid, actorPseudonym is empty, '
        'payload includes delegationId and previousDelegateDid',
        () async {
      final del = await _insertActiveDelegation();
      final event = _makeVoteEvent();

      await ProposalService.instance.handleIncomingVote(event);

      final autoRevoke = await _readAutoRevokeAudit(_propId);
      expect(autoRevoke, hasLength(1));

      final entry = autoRevoke.first;
      expect(entry.actorDid, equals(_voterDid),
          reason: 'actorDid must equal voterDid (Joachim-Entscheidung)');
      expect(entry.actorPseudonym, equals(''),
          reason: 'actorPseudonym must be empty (technical consistency audit)');
      expect(entry.payload['delegationId'], equals(del.delegationId));
      expect(entry.payload['previousDelegateDid'], equals(_delegateDid));
      expect(entry.payload['reason'], equals('DIRECT_VOTE_CAST'));
    });
  });
}
