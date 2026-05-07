import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Creates a fresh in-memory DB with only the delegations table and its
  /// indexes (including the Partial Unique Index), then injects it into
  /// PodDatabase.instance.
  ///
  /// Schema is duplicated from pod_database.dart migration v23. If the real
  /// schema changes, this helper must be updated accordingly.
  Future<Database> openTestDb() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE delegations (
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
          'CREATE INDEX idx_delegations_proposal ON delegations(proposal_id)',
        );
        await db.execute(
          'CREATE INDEX idx_delegations_delegator ON delegations(delegator_did)',
        );
        await db.execute(
          'CREATE INDEX idx_delegations_delegate ON delegations(delegate_did)',
        );
        await db.execute(
          'CREATE INDEX idx_delegations_status ON delegations(status)',
        );
        // Plan-A Partial Unique Index (D6).
        // This test suite verifies whether sqflite enforces the WHERE clause.
        await db.execute('''
          CREATE UNIQUE INDEX ux_active_delegation_per_proposal
            ON delegations(delegator_did, proposal_id)
            WHERE status = 'ACTIVE'
        ''');
      },
    );
    final key = Uint8List(32)..fillRange(0, 32, 0x42);
    PodDatabase.instance.injectDatabase(db, key);
    return db;
  }

  /// Builds a minimal delegation map for use in DAO tests.
  Map<String, dynamic> makeRow({
    required String delegationId,
    required String delegatorDid,
    required String delegateDid,
    required String proposalId,
    String cellId = 'cell_test',
    String status = 'ACTIVE',
    String nostrEventId = '',
    int? createdAt,
    int? updatedAt,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'delegation_id': delegationId,
      'delegator_did': delegatorDid,
      'delegate_did': delegateDid,
      'proposal_id': proposalId,
      'cell_id': cellId,
      'status': status,
      'nostr_event_id': nostrEventId,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
    };
  }

  // ── Group 1: upsertDelegation ─────────────────────────────────────────────

  group('upsertDelegation', () {
    late Database db;
    setUp(() async { db = await openTestDb(); });
    tearDown(() async { await db.close(); });

    test('inserts a new row', () async {
      final row = makeRow(
        delegationId: 'del_001',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_A',
      );
      await PodDatabase.instance.upsertDelegation(row);

      final rows = await db.query(
        'delegations',
        where: 'delegation_id = ?',
        whereArgs: ['del_001'],
      );
      expect(rows.length, equals(1));
      expect(rows.first['delegator_did'], equals('did:key:z6MkAlice'));
      expect(rows.first['delegate_did'], equals('did:key:z6MkBob'));
      expect(rows.first['status'], equals('ACTIVE'));
      expect(rows.first['nostr_event_id'], equals(''));
    });

    test('replaces existing row on same delegation_id (idempotent)', () async {
      final original = makeRow(
        delegationId: 'del_replace',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_A',
        status: 'ACTIVE',
      );
      await PodDatabase.instance.upsertDelegation(original);

      final updated = makeRow(
        delegationId: 'del_replace',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_A',
        status: 'REVOKED',
        nostrEventId: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      );
      await PodDatabase.instance.upsertDelegation(updated);

      final rows = await db.query(
        'delegations',
        where: 'delegation_id = ?',
        whereArgs: ['del_replace'],
      );
      expect(rows.length, equals(1), reason: 'Should replace, not append');
      expect(rows.first['status'], equals('REVOKED'));
      expect(rows.first['nostr_event_id'], isNotEmpty);
    });

    test('inserts row with nostrEventId="" (default for local creation)',
        () async {
      final row = makeRow(
        delegationId: 'del_local',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_A',
        nostrEventId: '',
      );
      await PodDatabase.instance.upsertDelegation(row);

      final rows = await db.query('delegations',
          where: 'delegation_id = ?', whereArgs: ['del_local']);
      expect(rows.first['nostr_event_id'], equals(''));
    });
  });

  // ── Group 2: getDelegation ────────────────────────────────────────────────

  group('getDelegation', () {
    late Database db;
    setUp(() async { db = await openTestDb(); });
    tearDown(() async { await db.close(); });

    test('returns null for unknown delegationId', () async {
      final result =
          await PodDatabase.instance.getDelegation('does_not_exist');
      expect(result, isNull);
    });

    test('returns the row after insert', () async {
      final row = makeRow(
        delegationId: 'del_get_001',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_B',
      );
      await PodDatabase.instance.upsertDelegation(row);

      final result = await PodDatabase.instance.getDelegation('del_get_001');
      expect(result, isNotNull);
      expect(result!['delegation_id'], equals('del_get_001'));
      expect(result['proposal_id'], equals('prop_B'));
      expect(result['status'], equals('ACTIVE'));
    });
  });

  // ── Group 3: listDelegationsForProposal ───────────────────────────────────

  group('listDelegationsForProposal', () {
    late Database db;
    setUp(() async { db = await openTestDb(); });
    tearDown(() async { await db.close(); });

    test('returns all rows (any status) ordered by created_at ASC', () async {
      final base = DateTime.now().millisecondsSinceEpoch;
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_b',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_list',
        status: 'REVOKED',
        createdAt: base + 100,
      ));
      // Insert SUPERSEDED first (older timestamp)
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_a',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkCarol',
        proposalId: 'prop_list',
        status: 'SUPERSEDED',
        createdAt: base,
      ));

      final result = await PodDatabase.instance
          .listDelegationsForProposal('prop_list');

      expect(result.length, equals(2));
      expect(result[0]['delegation_id'], equals('del_a')); // older first
      expect(result[1]['delegation_id'], equals('del_b'));
    });

    test('returns empty list for unknown proposalId', () async {
      final result = await PodDatabase.instance
          .listDelegationsForProposal('does_not_exist');
      expect(result, isEmpty);
    });

    test('does not return delegations for other proposals', () async {
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_p1',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_one',
      ));
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_p2',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_two',
      ));

      final result = await PodDatabase.instance
          .listDelegationsForProposal('prop_one');
      expect(result.length, equals(1));
      expect(result.first['delegation_id'], equals('del_p1'));
    });
  });

  // ── Group 4: listActiveDelegationsForProposal ─────────────────────────────

  group('listActiveDelegationsForProposal', () {
    late Database db;
    setUp(() async { db = await openTestDb(); });
    tearDown(() async { await db.close(); });

    test('returns only ACTIVE rows, hides REVOKED and SUPERSEDED', () async {
      final base = DateTime.now().millisecondsSinceEpoch;
      // Insert a SUPERSEDED (older)
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_sup',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_active',
        status: 'SUPERSEDED',
        createdAt: base,
      ));
      // Insert a REVOKED
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_rev',
        delegatorDid: 'did:key:z6MkDave',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_active',
        status: 'REVOKED',
        createdAt: base + 100,
      ));
      // Insert an ACTIVE from Carol
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_act',
        delegatorDid: 'did:key:z6MkCarol',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_active',
        status: 'ACTIVE',
        createdAt: base + 200,
      ));

      final result = await PodDatabase.instance
          .listActiveDelegationsForProposal('prop_active');

      expect(result.length, equals(1));
      expect(result.first['delegation_id'], equals('del_act'));
      expect(result.first['status'], equals('ACTIVE'));
    });

    test('returns empty list when no ACTIVE delegations exist', () async {
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_only_rev',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_no_active',
        status: 'REVOKED',
      ));

      final result = await PodDatabase.instance
          .listActiveDelegationsForProposal('prop_no_active');
      expect(result, isEmpty);
    });
  });

  // ── Group 5: listDelegationsByDelegator ───────────────────────────────────

  group('listDelegationsByDelegator', () {
    late Database db;
    setUp(() async { db = await openTestDb(); });
    tearDown(() async { await db.close(); });

    test('returns all delegations across proposals for a delegator', () async {
      final base = DateTime.now().millisecondsSinceEpoch;
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_d1',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_X',
        updatedAt: base,
      ));
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_d2',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkCarol',
        proposalId: 'prop_Y',
        updatedAt: base + 100,
      ));
      // Different delegator — should not appear
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_d3',
        delegatorDid: 'did:key:z6MkDave',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_X',
        updatedAt: base + 50,
      ));

      final result = await PodDatabase.instance
          .listDelegationsByDelegator('did:key:z6MkAlice');

      expect(result.length, equals(2));
      // Ordered by updated_at DESC → prop_Y first (newer)
      expect(result[0]['delegation_id'], equals('del_d2'));
      expect(result[1]['delegation_id'], equals('del_d1'));
    });

    test('returns empty list for unknown delegatorDid', () async {
      final result = await PodDatabase.instance
          .listDelegationsByDelegator('did:key:z6MkUnknown');
      expect(result, isEmpty);
    });
  });

  // ── Group 6: Partial Unique Index Smoke Test (D6 Plan-A) ─────────────────
  //
  // CRITICAL: This group verifies whether sqflite enforces the
  // WHERE status = 'ACTIVE' clause on the unique index at runtime.
  //
  // GRÜN: Plan-A enforced. G2.1.1b service-layer guard is redundant but
  //       still recommended as defense-in-depth.
  // ROT:  Plan-A NOT enforced. G2.1.1b MUST add a service-layer guard.

  group('Partial Unique Index ux_active_delegation_per_proposal (D6)', () {
    late Database db;
    setUp(() async { db = await openTestDb(); });
    tearDown(() async { await db.close(); });

    test('first ACTIVE delegation for (delegator, proposal) inserts '
        'successfully', () async {
      final row = makeRow(
        delegationId: 'del_pui_01',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_pui',
        status: 'ACTIVE',
      );
      await expectLater(
        PodDatabase.instance.upsertDelegation(row),
        completes,
      );
    });

    test('second ACTIVE delegation for same (delegator, proposal) MUST '
        'throw DatabaseException — Plan-A verification', () async {
      // Insert first ACTIVE via normal DAO path.
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_pui_A',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_pui_conflict',
        status: 'ACTIVE',
      ));

      // Second ACTIVE for same (delegator_did, proposal_id) — different
      // delegation_id so PRIMARY KEY does not trigger.
      //
      // We use ConflictAlgorithm.fail (not REPLACE) to directly probe whether
      // the SQLite engine enforces the partial unique index. REPLACE would
      // silently delete the first row and succeed, which masks the violation.
      //
      // GRÜN: partial index enforced → DatabaseException thrown.
      // ROT:  partial index NOT enforced → insert succeeds, no exception.
      //       In that case G2.1.1b MUST add a service-layer uniqueness guard.
      await expectLater(
        db.insert(
          'delegations',
          makeRow(
            delegationId: 'del_pui_B',
            delegatorDid: 'did:key:z6MkAlice',
            delegateDid: 'did:key:z6MkCarol',
            proposalId: 'prop_pui_conflict',
            status: 'ACTIVE',
          ),
          conflictAlgorithm: ConflictAlgorithm.fail,
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('REVOKED delegation for (delegator, proposal) does NOT block a '
        'new ACTIVE delegation', () async {
      // Insert REVOKED — should not consume the partial index slot
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_pui_rev',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_pui_revoked',
        status: 'REVOKED',
      ));

      // Now insert ACTIVE for same (delegator, proposal) — must succeed
      await expectLater(
        PodDatabase.instance.upsertDelegation(makeRow(
          delegationId: 'del_pui_act',
          delegatorDid: 'did:key:z6MkAlice',
          delegateDid: 'did:key:z6MkCarol',
          proposalId: 'prop_pui_revoked',
          status: 'ACTIVE',
        )),
        completes,
      );

      final rows = await db.query('delegations',
          where: 'proposal_id = ?', whereArgs: ['prop_pui_revoked']);
      expect(rows.length, equals(2));
    });

    test('SUPERSEDED delegation for (delegator, proposal) does NOT block a '
        'new ACTIVE delegation', () async {
      await PodDatabase.instance.upsertDelegation(makeRow(
        delegationId: 'del_pui_sup',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_pui_superseded',
        status: 'SUPERSEDED',
      ));

      await expectLater(
        PodDatabase.instance.upsertDelegation(makeRow(
          delegationId: 'del_pui_new',
          delegatorDid: 'did:key:z6MkAlice',
          delegateDid: 'did:key:z6MkCarol',
          proposalId: 'prop_pui_superseded',
          status: 'ACTIVE',
        )),
        completes,
      );

      final rows = await db.query('delegations',
          where: 'proposal_id = ?', whereArgs: ['prop_pui_superseded']);
      expect(rows.length, equals(2));
    });
  });
}
