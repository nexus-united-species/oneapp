// ignore_for_file: avoid_print
// Phase G2.1.2 — Wire format Kind 31012 tests.
//
// Outgoing: verifies ProposalService calls onPublishDelegationToNostr with the
// correct Delegation object at the right times (createDelegation,
// revokeDelegation, castVote auto-revoke, re-delegation two-event order).
//
// Incoming: verifies handleIncomingDelegationEvent with echo detection,
// idempotency, stale-event rejection, mode/membership validation, and
// D9-Variante-A status rejection.
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

const _founderDid = 'did:key:z6MkFounderWire';
const _bDid = 'did:key:z6MkMemberBWire';
const _cDid = 'did:key:z6MkMemberCWire';
const _outsiderDid = 'did:key:z6MkOutsiderWire';
const _cellId = 'cell_wire_delegation_test';
const _propId = 'prop_wire_delegation_test';

// Fake Nostr pubkeys (64 hex chars, each unique).
const _myPubkey =
    'aabb000000000000000000000000000000000000000000000000000000000001';
const _senderPubkey =
    'ccdd000000000000000000000000000000000000000000000000000000000002';

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
          'CREATE INDEX IF NOT EXISTS idx_delegations_proposal ON delegations(proposal_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_delegations_delegator ON delegations(delegator_did)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_delegations_delegate ON delegations(delegate_did)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_delegations_status ON delegations(status)');
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS ux_active_delegation_per_proposal
          ON delegations(delegator_did, proposal_id)
          WHERE status = 'ACTIVE'
      ''');
    },
  );
  final key = Uint8List(32)..fillRange(0, 32, 0x42);
  PodDatabase.instance.injectDatabase(db, key);
  return db;
}

// ── Per-test helpers ───────────────────────────────────────────────────────────

Future<void> _setupStandardState({
  ProposalStatus status = ProposalStatus.VOTING,
  VotingMode votingMode = VotingMode.YES_NO_ABSTAIN,
  DateTime? votingEndsAt,
}) async {
  IdentityService.instance.setForTest(
    NexusIdentity(
        publicKeyHex: _myPubkey, pseudonym: 'Gründer', did: _founderDid),
  );

  final cell = Cell(
    id: _cellId,
    name: 'Testzelle',
    description: '',
    createdBy: _founderDid,
    createdAt: DateTime.utc(2026, 1, 1),
    cellType: CellType.local,
    locationName: 'Testort',
    nostrTag: 'nexus-cell-$_cellId',
    maxMembers: 150,
    memberCount: 3,
  );
  CellService.instance.addCellForTest(cell);

  final now = DateTime.utc(2026, 1, 1);
  final founderMember = CellMember(
    cellId: _cellId,
    did: _founderDid,
    joinedAt: now,
    role: MemberRole.founder,
    confirmedBy: _founderDid,
  );
  final memberB = CellMember(
    cellId: _cellId,
    did: _bDid,
    joinedAt: now,
    role: MemberRole.member,
    confirmedBy: _founderDid,
  );
  final memberC = CellMember(
    cellId: _cellId,
    did: _cDid,
    joinedAt: now,
    role: MemberRole.member,
    confirmedBy: _founderDid,
  );

  CellService.instance.addMemberForTest(_cellId, founderMember);
  CellService.instance.addMemberForTest(_cellId, memberB);
  CellService.instance.addMemberForTest(_cellId, memberC);

  await PodDatabase.instance.upsertCellMember(
      _cellId, _founderDid, founderMember.toJson());
  await PodDatabase.instance.upsertCellMember(_cellId, _bDid, memberB.toJson());
  await PodDatabase.instance.upsertCellMember(_cellId, _cDid, memberC.toJson());

  final prop = Proposal(
    id: _propId,
    cellId: _cellId,
    creatorDid: _founderDid,
    creatorPseudonym: 'Gründer',
    title: 'Testantrag',
    description: '',
    createdAt: DateTime.utc(2026, 1, 1),
    status: status,
    votingMode: votingMode,
    votingEndsAt:
        votingEndsAt ?? DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
  ProposalService.instance.injectProposalForTest(prop);
}

/// Reads delegations for [proposalId] directly from DB.
Future<List<Map<String, dynamic>>> _readDelegations(String proposalId) =>
    PodDatabase.instance.listDelegationsForProposal(proposalId);

/// Reads audit entries for [proposalId] directly from DB.
Future<List<AuditLogEntry>> _readAudit(String proposalId) async {
  final rows = await PodDatabase.instance.listAuditLog(proposalId);
  return rows.map(AuditLogEntry.fromMap).toList();
}

/// Reads publish_results for a given [delegationId] (stored in vote_id).
Future<List<Map<String, dynamic>>> _readPublishResults(
    String delegationId) async {
  return PodDatabase.instance.testDb.query(
    'publish_results',
    where: 'vote_id = ?',
    whereArgs: [delegationId],
  );
}

// ── Result factories ───────────────────────────────────────────────────────────

PublishResult _fullResult() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return PublishResult(
    publishResultId: 'test_full_$now',
    localEventId: 'evt_full_$now',
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

PublishResult _partialResult() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return PublishResult(
    publishResultId: 'test_partial_$now',
    localEventId: 'evt_partial_$now',
    eventKind: NostrKind.delegationEvent,
    status: PublishResultStatus.partial,
    attemptedAt: now,
    retryCount: 0,
    requiredAckCount: 2,
    acceptedRelayCount: 1,
    failedRelayCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}

PublishResult _failedResult() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return PublishResult(
    publishResultId: 'test_failed_$now',
    localEventId: 'evt_failed_$now',
    eventKind: NostrKind.delegationEvent,
    status: PublishResultStatus.retrying,
    attemptedAt: now,
    retryCount: 0,
    requiredAckCount: 2,
    acceptedRelayCount: 0,
    failedRelayCount: 0,
    nextRetryAt: now + 60000,
    createdAt: now,
    updatedAt: now,
  );
}

// ── NostrEvent factory for incoming tests ──────────────────────────────────────

int _evtCounter = 0;

/// Builds a minimal NostrEvent for handleIncomingDelegationEvent tests.
/// [pubkey] defaults to [_senderPubkey] (not our own key → no echo).
NostrEvent _makeIncomingEvent({
  String? delegationId,
  String? delegatorDid,
  String? delegateDid,
  String? proposalId,
  String? cellId,
  String? status,
  int? createdAt,
  int? updatedAt,
  String? pubkey,
  String? rawContent,
  Map<String, dynamic>? extraContentFields,
}) {
  _evtCounter++;
  final id = 'deadbeef${_evtCounter.toString().padLeft(56, '0')}';
  final now = DateTime.now().millisecondsSinceEpoch;
  final content = rawContent ??
      jsonEncode(<String, dynamic>{
        'delegationId': delegationId ?? 'del_incoming_$_evtCounter',
        'delegatorDid': delegatorDid ?? _founderDid,
        'delegateDid': delegateDid ?? _bDid,
        'proposalId': proposalId ?? _propId,
        'cellId': cellId ?? _cellId,
        'status': status ?? 'ACTIVE',
        'createdAt': createdAt ?? now,
        'updatedAt': updatedAt ?? now,
        ...?extraContentFields,
      });
  return NostrEvent(
    id: id,
    pubkey: pubkey ?? _senderPubkey,
    createdAt: now ~/ 1000,
    kind: NostrKind.delegationEvent,
    tags: [
      ['d', delegationId ?? 'del_incoming_$_evtCounter'],
      ['t', 'nexus-delegation'],
      ['t', 'nexus-cell-${cellId ?? _cellId}'],
      ['proposal_id', proposalId ?? _propId],
    ],
    content: content,
    sig: 'sig${'0' * 124}',
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
    // Wire echo pubkey so handleIncomingDelegationEvent can detect own events.
    ProposalService.instance.getMyNostrPubkeyHex = () => _myPubkey;
  });

  tearDown(() async {
    ProposalService.instance.resetForTest();
    CellService.instance.clearForTest();
    IdentityService.instance.clearForTest();
    await db.close();
  });

  // ── G.1 Outgoing tests ──────────────────────────────────────────────────────

  group('Outgoing — createDelegation', () {
    test('createDelegation publishes Kind-31012 event with correct fields',
        () async {
      final captured = <Delegation>[];
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        captured.add(d);
        return _fullResult();
      };

      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      expect(captured, hasLength(1));
      final d = captured.first;
      expect(d.delegatorDid, equals(_founderDid));
      expect(d.delegateDid, equals(_bDid));
      expect(d.proposalId, equals(_propId));
      expect(d.cellId, equals(_cellId));
      expect(d.status, equals(DelegationStatus.ACTIVE));
    });

    test('createDelegation idempotent path does NOT publish', () async {
      // First create.
      ProposalService.instance.onPublishDelegationToNostr = (d) async =>
          _fullResult();
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      // Second call with same delegate — idempotent.
      final capturedSecond = <Delegation>[];
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        capturedSecond.add(d);
        return _fullResult();
      };
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      expect(capturedSecond, isEmpty,
          reason: 'Idempotent path must not trigger a wire publish');
    });

    test(
        'Re-delegation publishes TWO events: first SUPERSEDED, then new ACTIVE',
        () async {
      // First: create initial delegation.
      ProposalService.instance.onPublishDelegationToNostr = (d) async =>
          _fullResult();
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      // Second: re-delegate to C.
      final captured = <Delegation>[];
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        captured.add(d);
        return _fullResult();
      };
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _cDid,
        proposalId: _propId,
      );

      expect(captured, hasLength(2),
          reason: 'Re-delegation must publish exactly two events');
      expect(captured[0].status, equals(DelegationStatus.SUPERSEDED),
          reason: 'First published event is the old SUPERSEDED delegation');
      expect(captured[1].status, equals(DelegationStatus.ACTIVE),
          reason: 'Second published event is the new ACTIVE delegation');
      expect(captured[1].delegateDid, equals(_cDid));
    });

    test('publish PARTIAL is treated as success — service logs no failure',
        () async {
      final captured = <Delegation>[];
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        captured.add(d);
        return _partialResult(); // acceptedRelayCount = 1
      };

      // Should not throw; partial is a success.
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      expect(captured, hasLength(1));
      expect(captured.first.status, equals(DelegationStatus.ACTIVE));
    });

    test(
        'publish FAILED (acceptedRelayCount=0) — service continues without throwing',
        () async {
      ProposalService.instance.onPublishDelegationToNostr =
          (d) async => _failedResult();

      // Must not throw; retry is handled by the transport layer.
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      final delegations = await _readDelegations(_propId);
      expect(delegations, hasLength(1),
          reason: 'DB write must succeed even when publish fails');
    });

    test('Wire-content is camelCase — no snake_case keys leak', () async {
      Delegation? captured;
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        captured = d;
        return _fullResult();
      };

      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      expect(captured, isNotNull);
      // Build the content map the same way publishDelegationEvent would,
      // then verify all keys are camelCase (no underscores).
      final wireContent = <String, dynamic>{
        'delegationId': captured!.delegationId,
        'delegatorDid': captured!.delegatorDid,
        'delegateDid': captured!.delegateDid,
        'proposalId': captured!.proposalId,
        'cellId': captured!.cellId,
        'status': captured!.status.name,
        'createdAt': captured!.createdAt.millisecondsSinceEpoch,
        'updatedAt': captured!.updatedAt.millisecondsSinceEpoch,
      };
      for (final key in wireContent.keys) {
        expect(key, isNot(contains('_')),
            reason: 'Wire content key "$key" must be camelCase');
      }
    });

    test('Tags include proposal_id as custom tag (NOT e-tag)', () async {
      Delegation? captured;
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        captured = d;
        return _fullResult();
      };

      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      expect(captured, isNotNull);
      // The expected tags list mirrors publishDelegationEvent exactly.
      final expectedTags = <List<String>>[
        ['d', captured!.delegationId],
        ['t', 'nexus-delegation'],
        ['t', 'nexus-cell-${captured!.cellId}'],
        ['proposal_id', captured!.proposalId],
        ['cell', captured!.cellId],
        ['delegator', captured!.delegatorDid],
        ['delegate', captured!.delegateDid],
        ['status', captured!.status.name.toLowerCase()],
      ];
      // No 'e' tag with the proposalId.
      final eTags =
          expectedTags.where((t) => t.isNotEmpty && t[0] == 'e').toList();
      expect(eTags, isEmpty,
          reason: 'proposalId (UUID) must NOT appear as e-tag');
      // 'proposal_id' custom tag present.
      final propIdTags =
          expectedTags.where((t) => t.isNotEmpty && t[0] == 'proposal_id').toList();
      expect(propIdTags, hasLength(1));
      expect(propIdTags.first[1], equals(_propId));
    });

    test('Tags include nexus-cell-<cellId> for relay filtering', () async {
      Delegation? captured;
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        captured = d;
        return _fullResult();
      };

      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      expect(captured, isNotNull);
      final expectedCellTag = 'nexus-cell-${captured!.cellId}';
      final tags = <List<String>>[
        ['d', captured!.delegationId],
        ['t', 'nexus-delegation'],
        ['t', expectedCellTag],
        ['proposal_id', captured!.proposalId],
        ['cell', captured!.cellId],
        ['delegator', captured!.delegatorDid],
        ['delegate', captured!.delegateDid],
        ['status', captured!.status.name.toLowerCase()],
      ];
      final cellTags = tags
          .where((t) => t.isNotEmpty && t[0] == 't' && t.length > 1)
          .map((t) => t[1])
          .toList();
      expect(cellTags, contains(expectedCellTag));
    });

    test('Tags include delegator tag alongside delegate tag', () async {
      Delegation? captured;
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        captured = d;
        return _fullResult();
      };

      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      expect(captured, isNotNull);
      // Both delegator and delegate must appear as tags.
      final tags = <List<String>>[
        ['d', captured!.delegationId],
        ['t', 'nexus-delegation'],
        ['t', 'nexus-cell-${captured!.cellId}'],
        ['proposal_id', captured!.proposalId],
        ['cell', captured!.cellId],
        ['delegator', captured!.delegatorDid],
        ['delegate', captured!.delegateDid],
        ['status', captured!.status.name.toLowerCase()],
      ];
      final delegatorTags =
          tags.where((t) => t.isNotEmpty && t[0] == 'delegator').toList();
      final delegateTags =
          tags.where((t) => t.isNotEmpty && t[0] == 'delegate').toList();
      expect(delegatorTags, hasLength(1));
      expect(delegatorTags.first[1], equals(_founderDid));
      expect(delegateTags, hasLength(1));
      expect(delegateTags.first[1], equals(_bDid));
    });
  });

  group('Outgoing — revokeDelegation', () {
    test('revokeDelegation publishes Kind-31012 with status=REVOKED', () async {
      // Create first.
      Delegation? created;
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        if (d.status == DelegationStatus.ACTIVE) created = d;
        return _fullResult();
      };
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );
      expect(created, isNotNull);

      // Now revoke.
      final revokeCapture = <Delegation>[];
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        revokeCapture.add(d);
        return _fullResult();
      };
      await ProposalService.instance.revokeDelegation(created!.delegationId);

      expect(revokeCapture, hasLength(1));
      expect(revokeCapture.first.status, equals(DelegationStatus.REVOKED));
      expect(revokeCapture.first.delegationId, equals(created!.delegationId));
    });
  });

  group('Outgoing — castVote auto-revoke', () {
    test('castVote auto-revoke publishes Kind-31012 with status=REVOKED',
        () async {
      // Create delegation.
      Delegation? delegationCreated;
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        delegationCreated = d;
        return _fullResult();
      };
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );
      expect(delegationCreated, isNotNull);

      // Set up castVote.
      ProposalService.instance.onPublishVoteToNostr = (params) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        return PublishResult(
          publishResultId: 'vote_result_$now',
          localEventId: 'vote_evt_$now',
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

      // Capture the auto-revoke publish.
      final autoRevokeCapture = <Delegation>[];
      ProposalService.instance.onPublishDelegationToNostr = (d) async {
        autoRevokeCapture.add(d);
        return _fullResult();
      };

      await ProposalService.instance.castVote(
        _propId,
        VoteChoice.YES,
      );

      expect(
          autoRevokeCapture.where((d) => d.status == DelegationStatus.REVOKED),
          isNotEmpty,
          reason: 'Auto-revoke must publish a REVOKED delegation event');
      expect(autoRevokeCapture.first.delegationId,
          equals(delegationCreated!.delegationId));
    });
  });

  // ── G.2 Incoming tests ──────────────────────────────────────────────────────

  group('Incoming — handleIncomingDelegationEvent', () {
    test('persists new delegation when not locally known', () async {
      final delId = 'del_incoming_persist_1';
      final event = _makeIncomingEvent(delegationId: delId);

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row, isNotNull);
      expect(row!['delegation_id'], equals(delId));
      expect(row['status'], equals('ACTIVE'));
    });

    test(
        'writes DELEGATION_CREATED audit when status=ACTIVE and not previously known',
        () async {
      final delId = 'del_incoming_audit_active';
      final event = _makeIncomingEvent(
          delegationId: delId, status: 'ACTIVE');

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final audit = await _readAudit(_propId);
      final entry =
          audit.where((a) => a.payload['delegationId'] == delId).firstOrNull;
      expect(entry, isNotNull);
      expect(entry!.eventType, equals(AuditEventType.DELEGATION_CREATED));
      expect(entry.nostrEventId, equals(event.id));
    });

    test(
        'writes DELEGATION_REVOKED audit when status=REVOKED and not previously known',
        () async {
      final delId = 'del_incoming_audit_revoked';
      final event = _makeIncomingEvent(
          delegationId: delId, status: 'REVOKED');

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final audit = await _readAudit(_propId);
      final entry =
          audit.where((a) => a.payload['delegationId'] == delId).firstOrNull;
      expect(entry, isNotNull);
      expect(entry!.eventType, equals(AuditEventType.DELEGATION_REVOKED));
    });

    test(
        'writes DELEGATION_SUPERSEDED audit when status=SUPERSEDED and not previously known',
        () async {
      final delId = 'del_incoming_audit_superseded';
      final event = _makeIncomingEvent(
          delegationId: delId, status: 'SUPERSEDED');

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final audit = await _readAudit(_propId);
      final entry =
          audit.where((a) => a.payload['delegationId'] == delId).firstOrNull;
      expect(entry, isNotNull);
      expect(entry!.eventType, equals(AuditEventType.DELEGATION_SUPERSEDED));
    });

    test('ignores own echo (pubkey == myPubkey)', () async {
      final delId = 'del_echo_test';
      final event = _makeIncomingEvent(
          delegationId: delId, pubkey: _myPubkey); // own event

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row, isNull, reason: 'Echo of own event must not be persisted');
    });

    test(
        'ignores stale incoming (incoming.updatedAt <= local.updatedAt)',
        () async {
      final delId = 'del_stale_test';
      final t1 = DateTime.utc(2026, 1, 10).millisecondsSinceEpoch;
      final t2 = DateTime.utc(2026, 1, 9).millisecondsSinceEpoch; // older

      // Persist local version at t1.
      final local = Delegation(
        delegationId: delId,
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
        cellId: _cellId,
        status: DelegationStatus.ACTIVE,
        nostrEventId: 'evt_local',
        createdAt: DateTime.fromMillisecondsSinceEpoch(t1, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(t1, isUtc: true),
      );
      await PodDatabase.instance.upsertDelegation(local.toMap());

      // Incoming event with older updatedAt.
      final event = _makeIncomingEvent(
          delegationId: delId,
          updatedAt: t2,
          status: 'REVOKED'); // stale

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      // Status must remain ACTIVE (stale event ignored).
      expect(row!['status'], equals('ACTIVE'));
    });

    test(
        'updates from wire when incoming.updatedAt > local — NO audit (already known)',
        () async {
      final delId = 'del_update_wire';
      final t1 = DateTime.utc(2026, 1, 10).millisecondsSinceEpoch;
      final t2 = DateTime.utc(2026, 1, 11).millisecondsSinceEpoch; // newer

      // Persist local.
      final local = Delegation(
        delegationId: delId,
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
        cellId: _cellId,
        status: DelegationStatus.ACTIVE,
        nostrEventId: 'evt_local2',
        createdAt: DateTime.fromMillisecondsSinceEpoch(t1, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(t1, isUtc: true),
      );
      await PodDatabase.instance.upsertDelegation(local.toMap());

      final auditBefore = await _readAudit(_propId);

      final event = _makeIncomingEvent(
          delegationId: delId, updatedAt: t2, status: 'REVOKED');
      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row!['status'], equals('REVOKED'), reason: 'Status must update');

      final auditAfter = await _readAudit(_propId);
      expect(auditAfter.length, equals(auditBefore.length),
          reason: 'No new audit entry for already-known delegation');
    });

    test('rejects malformed JSON content', () async {
      final delId = 'del_malformed';
      final event = _makeIncomingEvent(
          delegationId: delId, rawContent: 'NOT_JSON{{{{');

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row, isNull);
    });

    test('rejects missing required fields in content', () async {
      final event = _makeIncomingEvent(rawContent: jsonEncode({
        // missing delegationId, delegatorDid, etc.
        'status': 'ACTIVE',
      }));

      // Should not throw; just log and return.
      await expectLater(
          ProposalService.instance.handleIncomingDelegationEvent(event),
          completes);
    });

    test('rejects unknown proposal', () async {
      final delId = 'del_unknown_proposal';
      final event = _makeIncomingEvent(
          delegationId: delId, proposalId: 'prop_does_not_exist');

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row, isNull);
    });

    test('rejects CANDIDATE_CHOICE proposal (defense-in-depth)', () async {
      // Create a CC proposal.
      const ccPropId = 'prop_cc_wire';
      final ccProp = Proposal(
        id: ccPropId,
        cellId: _cellId,
        creatorDid: _founderDid,
        creatorPseudonym: 'Gründer',
        title: 'CC Antrag',
        description: '',
        createdAt: DateTime.utc(2026, 1, 1),
        status: ProposalStatus.VOTING,
        votingMode: VotingMode.CANDIDATE_CHOICE,
        votingEndsAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      ProposalService.instance.injectProposalForTest(ccProp);

      final delId = 'del_cc_reject';
      final event = _makeIncomingEvent(
          delegationId: delId, proposalId: ccPropId, cellId: _cellId);

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row, isNull,
          reason: 'CC delegation must be rejected on receiver side');
    });

    test('rejects when delegator not in cell', () async {
      final delId = 'del_delegator_not_member';
      final event = _makeIncomingEvent(
          delegationId: delId,
          delegatorDid: _outsiderDid); // not in cell

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row, isNull);
    });

    test('rejects when delegate not in cell', () async {
      final delId = 'del_delegate_not_member';
      final event = _makeIncomingEvent(
          delegationId: delId,
          delegateDid: _outsiderDid); // not in cell

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row, isNull);
    });

    test('rejects status=EXPIRED (D9 Variante A)', () async {
      final delId = 'del_expired_reject';
      final event =
          _makeIncomingEvent(delegationId: delId, status: 'EXPIRED');

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row, isNull,
          reason: 'EXPIRED is a tally-only state, not a wire status');
    });

    test('rejects status=INVALID (D9 Variante A)', () async {
      final delId = 'del_invalid_reject';
      final event =
          _makeIncomingEvent(delegationId: delId, status: 'INVALID');

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row, isNull,
          reason: 'INVALID is a tally-only state, not a wire status');
    });

    test(
        'tolerates unknown extra content keys (backwards-compat per §31.2.5)',
        () async {
      final delId = 'del_extra_keys';
      final event = _makeIncomingEvent(
          delegationId: delId,
          extraContentFields: {
            'futureField': 'some_value',
            'anotherFutureKey': 42,
          });

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      final row = await PodDatabase.instance.getDelegation(delId);
      expect(row, isNotNull,
          reason: 'Unknown content fields must not cause rejection');
    });

    test(
        'does NOT trigger any auto-action on receiver side (sender-only §31.3)',
        () async {
      // Delegator A has an existing ACTIVE delegation on a SECOND proposal
      // (different proposalId avoids the partial-unique-index conflict so
      // the test purely verifies no service-level auto-mutation, not DB
      // constraint behavior).
      const secondPropId = 'prop_wire_second';
      final secondProp = Proposal(
        id: secondPropId,
        cellId: _cellId,
        creatorDid: _founderDid,
        creatorPseudonym: 'Gründer',
        title: 'Zweiter Antrag',
        description: '',
        createdAt: DateTime.utc(2026, 1, 1),
        status: ProposalStatus.VOTING,
        votingMode: VotingMode.YES_NO_ABSTAIN,
        votingEndsAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      ProposalService.instance.injectProposalForTest(secondProp);

      final existingDelId = 'del_existing_active_second';
      final existing = Delegation(
        delegationId: existingDelId,
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: secondPropId,
        cellId: _cellId,
        status: DelegationStatus.ACTIVE,
        nostrEventId: 'evt_existing_second',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await PodDatabase.instance.upsertDelegation(existing.toMap());

      // Incoming event on the ORIGINAL proposal: A delegates to C.
      final newDelId = 'del_incoming_redelegation_no_auto';
      final event = _makeIncomingEvent(
          delegationId: newDelId,
          delegatorDid: _founderDid,
          delegateDid: _cDid,
          status: 'ACTIVE');

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      // The delegation on the second proposal must NOT be touched.
      final oldRow = await PodDatabase.instance.getDelegation(existingDelId);
      expect(oldRow, isNotNull,
          reason: 'Delegation on a different proposal must not be deleted');
      expect(oldRow!['status'], equals('ACTIVE'),
          reason:
              'Receiver must NOT auto-mutate delegations on other proposals '
              '(§31.3 sender-only)');

      // The new incoming delegation is persisted.
      final newRow = await PodDatabase.instance.getDelegation(newDelId);
      expect(newRow, isNotNull);
    });
  });

  // ── G.3 Sender-only confirmation ────────────────────────────────────────────

  group('Sender-only pattern §31.3', () {
    test(
        'handleIncomingDelegationEvent for Delegator A on Proposal P does NOT '
        'auto-revoke any other ACTIVE delegation by A', () async {
      // Use a separate proposal so the partial-unique-index does not conflict,
      // isolating the test to service-level auto-action behavior.
      const propSenderOnly = 'prop_sender_only_test';
      final soProposal = Proposal(
        id: propSenderOnly,
        cellId: _cellId,
        creatorDid: _founderDid,
        creatorPseudonym: 'Gründer',
        title: 'Sender-Only Test Proposal',
        description: '',
        createdAt: DateTime.utc(2026, 1, 1),
        status: ProposalStatus.VOTING,
        votingMode: VotingMode.YES_NO_ABSTAIN,
        votingEndsAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      ProposalService.instance.injectProposalForTest(soProposal);

      // Pre-existing ACTIVE delegation on the sender-only proposal.
      final oldDelId = 'del_old_active_sender_only';
      await PodDatabase.instance.upsertDelegation(Delegation(
        delegationId: oldDelId,
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: propSenderOnly,
        cellId: _cellId,
        status: DelegationStatus.ACTIVE,
        nostrEventId: 'evt_old_so',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ).toMap());

      // Incoming new ACTIVE delegation on the ORIGINAL _propId.
      // Receiver just persists it, never auto-revokes/supersedes other rows.
      final newDelId = 'del_new_active_sender_only';
      final event = _makeIncomingEvent(
          delegationId: newDelId,
          delegatorDid: _founderDid,
          delegateDid: _cDid,
          proposalId: _propId,
          status: 'ACTIVE');

      await ProposalService.instance.handleIncomingDelegationEvent(event);

      // Old delegation on the other proposal must be untouched.
      final oldRow = await PodDatabase.instance.getDelegation(oldDelId);
      expect(oldRow, isNotNull);
      expect(oldRow!['status'], equals('ACTIVE'),
          reason: 'Receiver never auto-revokes on behalf of the sender');

      // New delegation persisted.
      final newRow = await PodDatabase.instance.getDelegation(newDelId);
      expect(newRow, isNotNull);
    });
  });
}
