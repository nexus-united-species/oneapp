// ignore_for_file: avoid_print
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/identity.dart';
import 'package:nexus_oneapp/core/identity/identity_service.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';
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

// ── Constants ─────────────────────────────────────────────────────────────────

const _founderDid = 'did:key:z6MkFounder';
const _bDid = 'did:key:z6MkMemberB';
const _cDid = 'did:key:z6MkMemberC';
const _outsiderDid = 'did:key:z6MkOutsider';
const _cellId = 'cell_test_delegation';
const _propId = 'prop_test_delegation';

// ── DB helper ─────────────────────────────────────────────────────────────────

Future<Database> _openTestDb() async {
  final db = await openDatabase(
    inMemoryDatabasePath,
    version: 1,
    onCreate: (db, _) async {
      // Minimal tables required by PodDatabase and ProposalService.
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
          id         TEXT PRIMARY KEY,
          enc        TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE cell_members (
          cell_id TEXT NOT NULL,
          did     TEXT NOT NULL,
          enc     TEXT NOT NULL,
          PRIMARY KEY (cell_id, did)
        )
      ''');
      await db.execute('''
        CREATE TABLE cell_join_requests (
          id       TEXT PRIMARY KEY,
          cell_id  TEXT NOT NULL,
          is_sent  INTEGER NOT NULL DEFAULT 0,
          enc      TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE proposals (
          id                    TEXT PRIMARY KEY,
          cell_id               TEXT NOT NULL,
          creator_did           TEXT NOT NULL,
          creator_pseudonym     TEXT NOT NULL DEFAULT '',
          title                 TEXT NOT NULL,
          description           TEXT NOT NULL DEFAULT '',
          proposal_type         TEXT NOT NULL DEFAULT 'SACHFRAGE',
          category              TEXT,
          status                TEXT NOT NULL DEFAULT 'DRAFT',
          created_at            INTEGER NOT NULL,
          discussion_started_at INTEGER,
          voting_started_at     INTEGER,
          voting_ends_at        INTEGER,
          decided_at            INTEGER,
          archived_at           INTEGER,
          withdrawn_at          INTEGER,
          quorum_required       REAL NOT NULL DEFAULT 0.5,
          grace_period_hours    INTEGER NOT NULL DEFAULT 12,
          version               INTEGER NOT NULL DEFAULT 1,
          previous_decision_hash TEXT,
          impulse_supporters    TEXT,
          result_summary        TEXT,
          result_yes            INTEGER,
          result_no             INTEGER,
          result_abstain        INTEGER,
          result_participation  REAL,
          scope                 TEXT NOT NULL DEFAULT 'cell',
          domain                TEXT NOT NULL DEFAULT 'Sonstiges',
          voting_mode           TEXT NOT NULL DEFAULT 'YES_NO_ABSTAIN',
          eligible_voters_json  TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE proposal_votes (
          vote_id         TEXT PRIMARY KEY,
          proposal_id     TEXT NOT NULL,
          voter_pubkey    TEXT NOT NULL,
          voter_did       TEXT NOT NULL,
          voter_pseudonym TEXT NOT NULL DEFAULT '',
          choice          TEXT NOT NULL,
          weight          INTEGER NOT NULL DEFAULT 1,
          voice_credits   INTEGER NOT NULL DEFAULT 1,
          reasoning       TEXT,
          selected_option_id TEXT,
          created_at      INTEGER NOT NULL,
          is_delegated    INTEGER NOT NULL DEFAULT 0,
          delegated_from  TEXT,
          nostr_event_id  TEXT NOT NULL DEFAULT '',
          UNIQUE(proposal_id, voter_pubkey)
        )
      ''');
      await db.execute('''
        CREATE TABLE proposal_edits (
          edit_id          TEXT PRIMARY KEY,
          proposal_id      TEXT NOT NULL,
          editor_did       TEXT NOT NULL,
          editor_pseudonym TEXT NOT NULL DEFAULT '',
          old_title        TEXT NOT NULL,
          new_title        TEXT NOT NULL,
          old_description  TEXT NOT NULL,
          new_description  TEXT NOT NULL,
          edited_at        INTEGER NOT NULL,
          edit_reason      TEXT,
          version_before   INTEGER NOT NULL,
          version_after    INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE proposal_audit_log (
          entry_id        TEXT PRIMARY KEY,
          proposal_id     TEXT NOT NULL,
          cell_id         TEXT NOT NULL,
          event_type      TEXT NOT NULL,
          actor_did       TEXT NOT NULL,
          actor_pseudonym TEXT NOT NULL DEFAULT '',
          timestamp       INTEGER NOT NULL,
          payload         TEXT NOT NULL,
          nostr_event_id  TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE decision_records (
          record_id              TEXT PRIMARY KEY,
          proposal_id            TEXT NOT NULL UNIQUE,
          cell_id                TEXT NOT NULL,
          final_title            TEXT NOT NULL,
          final_description      TEXT NOT NULL,
          result                 TEXT NOT NULL,
          yes_votes              INTEGER NOT NULL,
          no_votes               INTEGER NOT NULL,
          abstain_votes          INTEGER NOT NULL,
          participation          REAL NOT NULL,
          decided_at             INTEGER NOT NULL,
          all_votes              TEXT NOT NULL,
          content_hash           TEXT NOT NULL,
          previous_decision_hash TEXT,
          nostr_event_id         TEXT NOT NULL DEFAULT ''
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS proposal_discussions (
          id           TEXT PRIMARY KEY,
          proposal_id  TEXT NOT NULL,
          author_did   TEXT NOT NULL,
          author_pseudo TEXT NOT NULL DEFAULT '',
          content      TEXT NOT NULL,
          created_at   INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tombstones (
          id         TEXT NOT NULL,
          type       TEXT NOT NULL,
          reason     TEXT,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (id, type)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cell_founding_permits (
          id         TEXT PRIMARY KEY,
          is_sent    INTEGER NOT NULL DEFAULT 0,
          enc        TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS publish_results (
          publish_result_id     TEXT PRIMARY KEY,
          local_event_id        TEXT NOT NULL,
          nostr_event_id        TEXT,
          event_kind            INTEGER NOT NULL,
          proposal_id           TEXT,
          cell_id               TEXT,
          vote_id               TEXT,
          status                TEXT NOT NULL DEFAULT 'PENDING',
          attempted_at          INTEGER NOT NULL,
          ack_received_at       INTEGER,
          error_code            TEXT,
          error_message         TEXT,
          retry_count           INTEGER NOT NULL DEFAULT 0,
          next_retry_at         INTEGER,
          required_ack_count    INTEGER NOT NULL DEFAULT 2,
          accepted_relay_count  INTEGER NOT NULL DEFAULT 0,
          failed_relay_count    INTEGER NOT NULL DEFAULT 0,
          final_status          TEXT,
          created_at            INTEGER NOT NULL,
          updated_at            INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS proposal_options (
          option_id   TEXT PRIMARY KEY,
          proposal_id TEXT NOT NULL,
          label       TEXT NOT NULL,
          status      TEXT NOT NULL DEFAULT 'ACTIVE',
          created_at  INTEGER NOT NULL
        )
      ''');
      // Delegations table (v23).
      await db.execute('''
        CREATE TABLE IF NOT EXISTS delegations (
          delegation_id  TEXT PRIMARY KEY,
          delegator_did  TEXT NOT NULL,
          delegate_did   TEXT NOT NULL,
          proposal_id    TEXT NOT NULL,
          cell_id        TEXT NOT NULL,
          status         TEXT NOT NULL DEFAULT 'ACTIVE',
          nostr_event_id TEXT NOT NULL DEFAULT '',
          created_at     INTEGER NOT NULL,
          updated_at     INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_delegations_proposal '
        'ON delegations(proposal_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_delegations_delegator '
        'ON delegations(delegator_did)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_delegations_delegate '
        'ON delegations(delegate_did)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_delegations_status '
        'ON delegations(status)',
      );
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

// ── Per-test helpers ──────────────────────────────────────────────────────────

/// Builds a standard cell with 3 members and injects everything needed.
Future<void> _setupStandardState({
  DateTime? votingEndsAt,
  ProposalStatus status = ProposalStatus.VOTING,
  VotingMode votingMode = VotingMode.YES_NO_ABSTAIN,
  String proposalId = _propId,
}) async {
  // Identity: Founder is the current user.
  IdentityService.instance.setForTest(
    NexusIdentity(publicKeyHex: 'deadbeef', pseudonym: 'Gründer', did: _founderDid),
  );

  // Cell in-memory (needed by CellService.isMember for castVote).
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
    cellId: _cellId, did: _founderDid, joinedAt: now,
    role: MemberRole.founder, confirmedBy: _founderDid,
  );
  final memberB = CellMember(
    cellId: _cellId, did: _bDid, joinedAt: now,
    role: MemberRole.member, confirmedBy: _founderDid,
  );
  final memberC = CellMember(
    cellId: _cellId, did: _cDid, joinedAt: now,
    role: MemberRole.member, confirmedBy: _founderDid,
  );

  // In-memory (for CellService.isMember).
  CellService.instance.addMemberForTest(_cellId, founderMember);
  CellService.instance.addMemberForTest(_cellId, memberB);
  CellService.instance.addMemberForTest(_cellId, memberC);

  // DB (for createDelegation's listCellMembers check).
  await PodDatabase.instance.upsertCellMember(
      _cellId, _founderDid, founderMember.toJson());
  await PodDatabase.instance.upsertCellMember(
      _cellId, _bDid, memberB.toJson());
  await PodDatabase.instance.upsertCellMember(
      _cellId, _cDid, memberC.toJson());

  // Proposal: inject into in-memory map.
  final prop = Proposal(
    id: proposalId,
    cellId: _cellId,
    creatorDid: _founderDid,
    creatorPseudonym: 'Gründer',
    title: 'Testantrag',
    description: '',
    createdAt: DateTime.utc(2026, 1, 1),
    status: status,
    votingMode: votingMode,
    votingEndsAt: votingEndsAt ?? DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
  ProposalService.instance.injectProposalForTest(prop);
}

/// Reads all audit log entries for [proposalId] directly from DB.
Future<List<AuditLogEntry>> _readAudit(String proposalId) async {
  final rows = await PodDatabase.instance.listAuditLog(proposalId);
  return rows.map(AuditLogEntry.fromMap).toList();
}

/// Reads all delegations for [proposalId] directly from DB.
Future<List<Map<String, dynamic>>> _readDelegations(String proposalId) async {
  return PodDatabase.instance.listDelegationsForProposal(proposalId);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

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
  });

  tearDown(() async {
    ProposalService.instance.resetForTest();
    CellService.instance.clearForTest();
    IdentityService.instance.clearForTest();
    await db.close();
  });

  // ── D.1 createDelegation Happy-Paths ────────────────────────────────────────

  group('createDelegation Happy-Paths', () {
    test('createDelegation persists ACTIVE delegation', () async {
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      final rows = await _readDelegations(_propId);
      expect(rows.length, equals(1));
      final d = Delegation.fromMap(rows.first);
      expect(d.delegatorDid, equals(_founderDid));
      expect(d.delegateDid, equals(_bDid));
      expect(d.status, equals(DelegationStatus.ACTIVE));
      expect(d.cellId, equals(_cellId));
      expect(d.proposalId, equals(_propId));
    });

    test('createDelegation writes DELEGATION_CREATED audit', () async {
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      final entries = await _readAudit(_propId);
      expect(entries.any((e) => e.eventType == AuditEventType.DELEGATION_CREATED),
          isTrue);
      final e = entries.firstWhere(
          (e) => e.eventType == AuditEventType.DELEGATION_CREATED);
      expect(e.actorDid, equals(_founderDid));
      expect(e.payload['delegateDid'], equals(_bDid));
      expect(e.payload['proposalId'], equals(_propId));
      expect(e.payload['cellId'], equals(_cellId));
    });

    test('createDelegation returns the new Delegation', () async {
      final d = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      expect(d.delegatorDid, equals(_founderDid));
      expect(d.delegateDid, equals(_bDid));
      expect(d.proposalId, equals(_propId));
      expect(d.status, equals(DelegationStatus.ACTIVE));
      expect(d.delegationId, isNotEmpty);
    });
  });

  // ── D.2 createDelegation Validierung ────────────────────────────────────────

  group('createDelegation Validierung', () {
    test('createDelegation throws when proposal not found', () async {
      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _founderDid,
          delegateDid: _bDid,
          proposalId: 'nonexistent_id',
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('nicht gefunden'))),
      );
    });

    test('createDelegation throws StateError for CANDIDATE_CHOICE', () async {
      await _setupStandardState(
        votingMode: VotingMode.CANDIDATE_CHOICE,
        proposalId: 'prop_cc',
      );

      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _founderDid,
          delegateDid: _bDid,
          proposalId: 'prop_cc',
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('Kandidatenwahlen'))),
      );
    });

    test('createDelegation throws StateError when status=DRAFT', () async {
      await _setupStandardState(
          status: ProposalStatus.DRAFT, proposalId: 'prop_draft');

      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _founderDid,
          delegateDid: _bDid,
          proposalId: 'prop_draft',
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('laufender Abstimmung'))),
      );
    });

    test('createDelegation throws StateError when status=DISCUSSION', () async {
      await _setupStandardState(
          status: ProposalStatus.DISCUSSION, proposalId: 'prop_disc');

      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _founderDid,
          delegateDid: _bDid,
          proposalId: 'prop_disc',
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('laufender Abstimmung'))),
      );
    });

    test('createDelegation throws StateError when status=VOTING_ENDED',
        () async {
      await _setupStandardState(
          status: ProposalStatus.VOTING_ENDED, proposalId: 'prop_ve');

      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _founderDid,
          delegateDid: _bDid,
          proposalId: 'prop_ve',
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('laufender Abstimmung'))),
      );
    });

    test('createDelegation throws StateError when status=DECIDED', () async {
      await _setupStandardState(
          status: ProposalStatus.DECIDED, proposalId: 'prop_dec');

      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _founderDid,
          delegateDid: _bDid,
          proposalId: 'prop_dec',
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('laufender Abstimmung'))),
      );
    });

    test('createDelegation throws StateError when votingEndsAt is in the past',
        () async {
      await _setupStandardState(
        votingEndsAt:
            DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        proposalId: 'prop_expired',
      );

      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _founderDid,
          delegateDid: _bDid,
          proposalId: 'prop_expired',
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('Abstimmungsfrist'))),
      );
    });

    test(
        'createDelegation succeeds when votingEndsAt is null '
        '(open-ended voting period)', () async {
      await _setupStandardState(
          votingEndsAt: null, proposalId: 'prop_open');
      // Override: inject without votingEndsAt.
      ProposalService.instance.injectProposalForTest(Proposal(
        id: 'prop_open',
        cellId: _cellId,
        creatorDid: _founderDid,
        creatorPseudonym: 'Gründer',
        title: 'Open',
        description: '',
        createdAt: DateTime.utc(2026, 1, 1),
        status: ProposalStatus.VOTING,
        votingMode: VotingMode.YES_NO_ABSTAIN,
        votingEndsAt: null,
      ));

      final d = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: 'prop_open',
      );
      expect(d.status, equals(DelegationStatus.ACTIVE));
    });

    test(
        'createDelegation succeeds when votingEndsAt is in the future',
        () async {
      final d = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );
      expect(d.status, equals(DelegationStatus.ACTIVE));
    });

    test('createDelegation throws on self-delegation', () async {
      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _founderDid,
          delegateDid: _founderDid,
          proposalId: _propId,
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('selbst delegieren'))),
      );
    });

    test('createDelegation throws when delegate not in cell', () async {
      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _founderDid,
          delegateDid: _outsiderDid,
          proposalId: _propId,
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('kein Mitglied'))),
      );
    });

    test('createDelegation throws when delegator not in cell', () async {
      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _outsiderDid,
          delegateDid: _bDid,
          proposalId: _propId,
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('stimmberechtigtes Mitglied'))),
      );
    });

    test('createDelegation throws when delegator has already voted', () async {
      // Insert a direct vote for the founder.
      await db.insert('proposal_votes', {
        'vote_id': 'vote_founder_direct',
        'proposal_id': _propId,
        'voter_pubkey': 'deadbeef_pubkey',
        'voter_did': _founderDid,
        'voter_pseudonym': 'Gründer',
        'choice': 'YES',
        'weight': 1,
        'voice_credits': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'is_delegated': 0,
        'nostr_event_id': '',
      });

      await expectLater(
        ProposalService.instance.createDelegation(
          delegatorDid: _founderDid,
          delegateDid: _bDid,
          proposalId: _propId,
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('direkt abgestimmt'))),
      );
    });
  });

  // ── D.3 Re-Delegation ────────────────────────────────────────────────────────

  group('createDelegation Re-Delegation', () {
    test('createDelegation idempotent when same delegate', () async {
      final d1 = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );
      final d2 = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      // Same delegation ID returned.
      expect(d2.delegationId, equals(d1.delegationId));

      // Only one DB row.
      final rows = await _readDelegations(_propId);
      expect(rows.length, equals(1));

      // Only one DELEGATION_CREATED audit entry, no SUPERSEDED.
      final entries = await _readAudit(_propId);
      final created =
          entries.where((e) => e.eventType == AuditEventType.DELEGATION_CREATED);
      final superseded = entries
          .where((e) => e.eventType == AuditEventType.DELEGATION_SUPERSEDED);
      expect(created.length, equals(1));
      expect(superseded.length, equals(0));
    });

    test('createDelegation re-delegates: old SUPERSEDED, new ACTIVE', () async {
      // First: Founder → B.
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );
      // Then: Founder → C.
      final d2 = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _cDid,
        proposalId: _propId,
      );

      expect(d2.delegateDid, equals(_cDid));
      expect(d2.status, equals(DelegationStatus.ACTIVE));

      final rows = await _readDelegations(_propId);
      expect(rows.length, equals(2));

      final supersededRows =
          rows.where((r) => r['status'] == 'SUPERSEDED').toList();
      final activeRows =
          rows.where((r) => r['status'] == 'ACTIVE').toList();
      expect(supersededRows.length, equals(1));
      expect(activeRows.length, equals(1));
      expect(Delegation.fromMap(supersededRows.first).delegateDid,
          equals(_bDid));
      expect(Delegation.fromMap(activeRows.first).delegateDid, equals(_cDid));
    });

    test(
        'createDelegation re-delegation preserves the old '
        'delegationId in audit oldDelegationId', () async {
      final d1 = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _cDid,
        proposalId: _propId,
      );

      final entries = await _readAudit(_propId);
      final supersededEntry = entries
          .firstWhere((e) => e.eventType == AuditEventType.DELEGATION_SUPERSEDED);
      expect(supersededEntry.payload['oldDelegationId'],
          equals(d1.delegationId));
      expect(supersededEntry.payload['oldDelegateDid'], equals(_bDid));
      expect(supersededEntry.payload['newDelegateDid'], equals(_cDid));
    });
  });

  // ── D.4 revokeDelegation Happy-Path ─────────────────────────────────────────

  group('revokeDelegation Happy-Path', () {
    late String delegationId;

    setUp(() async {
      final d = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );
      delegationId = d.delegationId;
    });

    test('revokeDelegation flips status to REVOKED', () async {
      await ProposalService.instance.revokeDelegation(delegationId);

      final row = await PodDatabase.instance.getDelegation(delegationId);
      expect(row, isNotNull);
      expect(Delegation.fromMap(row!).status, equals(DelegationStatus.REVOKED));
    });

    test('revokeDelegation updates updatedAt', () async {
      // Compare at millisecond precision: the DB stores updatedAt as
      // millisecondsSinceEpoch, truncating microseconds. Comparing
      // full-precision DateTime values is flaky when both sides fall
      // within the same millisecond (truncated value < microsecond value).
      final beforeMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      await ProposalService.instance.revokeDelegation(delegationId);
      final afterMs = DateTime.now().toUtc().millisecondsSinceEpoch;

      final row = await PodDatabase.instance.getDelegation(delegationId);
      final d = Delegation.fromMap(row!);
      expect(
        d.updatedAt.millisecondsSinceEpoch,
        allOf(greaterThanOrEqualTo(beforeMs), lessThanOrEqualTo(afterMs)),
      );
    });

    test('revokeDelegation writes DELEGATION_REVOKED audit', () async {
      await ProposalService.instance.revokeDelegation(delegationId);

      final entries = await _readAudit(_propId);
      final revokeEntry = entries
          .firstWhere((e) => e.eventType == AuditEventType.DELEGATION_REVOKED);
      expect(revokeEntry.payload['delegationId'], equals(delegationId));
      expect(revokeEntry.payload['reason'], equals('USER_REVOKED'));
      expect(revokeEntry.payload['delegateDid'], equals(_bDid));
    });

    test('revokeDelegation returns the updated Delegation', () async {
      final revoked = await ProposalService.instance.revokeDelegation(delegationId);

      expect(revoked.delegationId, equals(delegationId));
      expect(revoked.status, equals(DelegationStatus.REVOKED));
      expect(revoked.delegatorDid, equals(_founderDid));
      expect(revoked.delegateDid, equals(_bDid));
    });
  });

  // ── D.5 revokeDelegation Validierung ────────────────────────────────────────

  group('revokeDelegation Validierung', () {
    late String delegationId;

    setUp(() async {
      final d = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );
      delegationId = d.delegationId;
    });

    test('revokeDelegation throws when delegation not found', () async {
      await expectLater(
        ProposalService.instance.revokeDelegation('nonexistent_delegation_id'),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('nicht gefunden'))),
      );
    });

    test('revokeDelegation throws when status already REVOKED', () async {
      await ProposalService.instance.revokeDelegation(delegationId);

      await expectLater(
        ProposalService.instance.revokeDelegation(delegationId),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('aktive Delegationen'))),
      );
    });

    test('revokeDelegation throws when status SUPERSEDED', () async {
      // Re-delegate to create a SUPERSEDED row.
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _cDid,
        proposalId: _propId,
      );
      // delegationId now points to the SUPERSEDED row (Founder→B).
      await expectLater(
        ProposalService.instance.revokeDelegation(delegationId),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('aktive Delegationen'))),
      );
    });

    test('revokeDelegation throws when proposal status DRAFT', () async {
      await _setupStandardState(
          status: ProposalStatus.DRAFT, proposalId: 'prop_draft_rev');
      // Create delegation via direct DB insert to bypass service guard.
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('delegations', {
        'delegation_id': 'del_draft_test',
        'delegator_did': _founderDid,
        'delegate_did': _bDid,
        'proposal_id': 'prop_draft_rev',
        'cell_id': _cellId,
        'status': 'ACTIVE',
        'nostr_event_id': '',
        'created_at': now,
        'updated_at': now,
      });

      await expectLater(
        ProposalService.instance.revokeDelegation('del_draft_test'),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('laufender Abstimmung'))),
      );
    });

    test('revokeDelegation throws when proposal status DISCUSSION', () async {
      await _setupStandardState(
          status: ProposalStatus.DISCUSSION, proposalId: 'prop_disc_rev');
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('delegations', {
        'delegation_id': 'del_disc_test',
        'delegator_did': _founderDid,
        'delegate_did': _bDid,
        'proposal_id': 'prop_disc_rev',
        'cell_id': _cellId,
        'status': 'ACTIVE',
        'nostr_event_id': '',
        'created_at': now,
        'updated_at': now,
      });

      await expectLater(
        ProposalService.instance.revokeDelegation('del_disc_test'),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('laufender Abstimmung'))),
      );
    });

    test(
        'revokeDelegation throws when proposal status VOTING_ENDED '
        '(stricter rule per Joachim G2.1.1b precision)', () async {
      await _setupStandardState(
          status: ProposalStatus.VOTING_ENDED, proposalId: 'prop_ve_rev');
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('delegations', {
        'delegation_id': 'del_ve_test',
        'delegator_did': _founderDid,
        'delegate_did': _bDid,
        'proposal_id': 'prop_ve_rev',
        'cell_id': _cellId,
        'status': 'ACTIVE',
        'nostr_event_id': '',
        'created_at': now,
        'updated_at': now,
      });

      await expectLater(
        ProposalService.instance.revokeDelegation('del_ve_test'),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('laufender Abstimmung'))),
      );
    });

    test('revokeDelegation throws when proposal status DECIDED', () async {
      await _setupStandardState(
          status: ProposalStatus.DECIDED, proposalId: 'prop_dec_rev');
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('delegations', {
        'delegation_id': 'del_dec_test',
        'delegator_did': _founderDid,
        'delegate_did': _bDid,
        'proposal_id': 'prop_dec_rev',
        'cell_id': _cellId,
        'status': 'ACTIVE',
        'nostr_event_id': '',
        'created_at': now,
        'updated_at': now,
      });

      await expectLater(
        ProposalService.instance.revokeDelegation('del_dec_test'),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('laufender Abstimmung'))),
      );
    });

    test(
        'revokeDelegation throws when votingEndsAt is in the past '
        '(even if status still VOTING)', () async {
      await _setupStandardState(
        votingEndsAt:
            DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        proposalId: 'prop_past_rev',
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('delegations', {
        'delegation_id': 'del_past_test',
        'delegator_did': _founderDid,
        'delegate_did': _bDid,
        'proposal_id': 'prop_past_rev',
        'cell_id': _cellId,
        'status': 'ACTIVE',
        'nostr_event_id': '',
        'created_at': now,
        'updated_at': now,
      });

      await expectLater(
        ProposalService.instance.revokeDelegation('del_past_test'),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('Abstimmungsfrist'))),
      );
    });

    test('revokeDelegation succeeds when votingEndsAt is null', () async {
      ProposalService.instance.injectProposalForTest(Proposal(
        id: 'prop_open_rev',
        cellId: _cellId,
        creatorDid: _founderDid,
        creatorPseudonym: 'Gründer',
        title: 'Open',
        description: '',
        createdAt: DateTime.utc(2026, 1, 1),
        status: ProposalStatus.VOTING,
        votingMode: VotingMode.YES_NO_ABSTAIN,
        votingEndsAt: null,
      ));
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('delegations', {
        'delegation_id': 'del_open_test',
        'delegator_did': _founderDid,
        'delegate_did': _bDid,
        'proposal_id': 'prop_open_rev',
        'cell_id': _cellId,
        'status': 'ACTIVE',
        'nostr_event_id': '',
        'created_at': now,
        'updated_at': now,
      });

      final revoked =
          await ProposalService.instance.revokeDelegation('del_open_test');
      expect(revoked.status, equals(DelegationStatus.REVOKED));
    });

    test('revokeDelegation succeeds when votingEndsAt is in the future',
        () async {
      final revoked =
          await ProposalService.instance.revokeDelegation(delegationId);
      expect(revoked.status, equals(DelegationStatus.REVOKED));
    });
  });

  // ── D.6 castVote Auto-Revoke ─────────────────────────────────────────────────

  group('castVote Auto-Revoke', () {
    test('castVote auto-revokes existing ACTIVE delegation', () async {
      // Setup: Founder has an ACTIVE delegation to B.
      final d = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      // Founder now casts a direct vote.
      // Wire publish is disabled (no nostr callback set).
      await ProposalService.instance.castVote(_propId, VoteChoice.YES);

      // Delegation should now be REVOKED.
      final row = await PodDatabase.instance.getDelegation(d.delegationId);
      expect(Delegation.fromMap(row!).status, equals(DelegationStatus.REVOKED));
    });

    test(
        'castVote auto-revoke writes '
        'DELEGATION_REVOKED_BY_DIRECT_VOTE audit', () async {
      final d = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      await ProposalService.instance.castVote(_propId, VoteChoice.YES);

      final entries = await _readAudit(_propId);
      final autoRevoke = entries.where((e) =>
          e.eventType == AuditEventType.DELEGATION_REVOKED_BY_DIRECT_VOTE);
      expect(autoRevoke.length, equals(1));
      expect(autoRevoke.first.payload['delegationId'], equals(d.delegationId));
      expect(autoRevoke.first.payload['previousDelegateDid'], equals(_bDid));
      expect(autoRevoke.first.payload['reason'], equals('DIRECT_VOTE_CAST'));
    });

    test(
        'castVote auto-revoke is idempotent — second castVote '
        'does not write second audit entry', () async {
      await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      // First vote auto-revokes the delegation.
      await ProposalService.instance.castVote(_propId, VoteChoice.YES);
      // Second vote (change): no ACTIVE delegation exists any more.
      await ProposalService.instance.castVote(_propId, VoteChoice.NO);

      final entries = await _readAudit(_propId);
      final autoRevokeCount = entries
          .where((e) =>
              e.eventType ==
              AuditEventType.DELEGATION_REVOKED_BY_DIRECT_VOTE)
          .length;
      expect(autoRevokeCount, equals(1));
    });

    test(
        'castVote without prior delegation: no auto-revoke '
        'logic runs (no spurious audit)', () async {
      // No delegation created.
      await ProposalService.instance.castVote(_propId, VoteChoice.YES);

      final entries = await _readAudit(_propId);
      final autoRevoke = entries.where((e) =>
          e.eventType == AuditEventType.DELEGATION_REVOKED_BY_DIRECT_VOTE);
      expect(autoRevoke.length, equals(0));
    });

    test(
        'castVote auto-revoke does NOT trigger when delegation '
        'belongs to a different voter', () async {
      // B delegates to C — does NOT affect Founder's vote.
      await ProposalService.instance.createDelegation(
        delegatorDid: _bDid,
        delegateDid: _cDid,
        proposalId: _propId,
      );

      // Founder votes directly.
      await ProposalService.instance.castVote(_propId, VoteChoice.YES);

      final entries = await _readAudit(_propId);
      final autoRevoke = entries.where((e) =>
          e.eventType == AuditEventType.DELEGATION_REVOKED_BY_DIRECT_VOTE);
      // No auto-revoke for Founder, since Founder had no delegation.
      expect(autoRevoke.length, equals(0));

      // B→C delegation remains ACTIVE.
      final rows = await _readDelegations(_propId);
      final bToC = rows
          .where((r) =>
              r['delegator_did'] == _bDid && r['delegate_did'] == _cDid)
          .toList();
      expect(bToC.length, equals(1));
      expect(bToC.first['status'], equals('ACTIVE'));
    });
  });

  // ── D.7 Defense-in-Depth ─────────────────────────────────────────────────────

  group('Defense-in-Depth', () {
    test(
        'Partial Unique Index + Service-Layer-Guard: two sequential '
        'createDelegation calls produce deterministic outcome '
        '(one ACTIVE, no DB exception leaks to caller)', () async {
      // First call: Founder → B.
      final d1 = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _bDid,
        proposalId: _propId,
      );

      // Second call: Founder → C (re-delegation, not idempotent).
      // Service-layer guard kicks in before the Partial Unique Index
      // could even be hit.
      final d2 = await ProposalService.instance.createDelegation(
        delegatorDid: _founderDid,
        delegateDid: _cDid,
        proposalId: _propId,
      );

      // Caller receives the new ACTIVE delegation cleanly.
      expect(d2.status, equals(DelegationStatus.ACTIVE));
      expect(d2.delegateDid, equals(_cDid));
      expect(d2.delegationId, isNot(equals(d1.delegationId)));

      // DB: exactly one ACTIVE row for this delegator+proposal.
      final active = await PodDatabase.instance
          .listActiveDelegationsForProposal(_propId);
      final founderActive = active
          .where((m) => m['delegator_did'] == _founderDid)
          .toList();
      expect(founderActive.length, equals(1));
      expect(founderActive.first['delegate_did'], equals(_cDid));
    });
  });
}
