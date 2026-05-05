import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Creates a fresh in-memory DB with only the proposal_options table
  /// and injects it into PodDatabase.instance.
  ///
  /// Schema is duplicated from pod_database.dart migration v20. If the
  /// real schema changes, this helper must be updated too.
  Future<Database> openTestDb() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE proposal_options (
            option_id              TEXT PRIMARY KEY,
            proposal_id            TEXT NOT NULL,
            label                  TEXT NOT NULL,
            description            TEXT,
            candidate_did          TEXT,
            candidate_pseudonym    TEXT,
            candidate_accepted_at  INTEGER,
            candidate_withdrawn_at INTEGER,
            status                 TEXT NOT NULL DEFAULT 'ACTIVE',
            position               INTEGER NOT NULL DEFAULT 0,
            created_at             INTEGER NOT NULL,
            updated_at             INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_proposal_options_proposal ON proposal_options(proposal_id)');
        await db.execute(
            'CREATE INDEX idx_proposal_options_status ON proposal_options(status)');
        await db.execute(
            'CREATE INDEX idx_proposal_options_position ON proposal_options(position)');
      },
    );
    final key = Uint8List(32)..fillRange(0, 32, 0x42);
    PodDatabase.instance.injectDatabase(db, key);
    return db;
  }

  int _ts(int offsetMs) => DateTime.now().millisecondsSinceEpoch + offsetMs;

  Map<String, dynamic> makeOption({
    required String optionId,
    required String proposalId,
    required String label,
    int position = 0,
    String status = 'ACTIVE',
    int? createdAt,
    int? updatedAt,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'option_id': optionId,
      'proposal_id': proposalId,
      'label': label,
      'description': null,
      'candidate_did': null,
      'candidate_pseudonym': null,
      'candidate_accepted_at': null,
      'candidate_withdrawn_at': null,
      'status': status,
      'position': position,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
    };
  }

  // ── Group 1: upsertProposalOption ─────────────────────────────────────────

  group('upsertProposalOption', () {
    late Database db;
    setUp(() async {
      db = await openTestDb();
    });
    tearDown(() async {
      await db.close();
    });

    test('inserts new row', () async {
      final data = makeOption(
        optionId: 'opt_001',
        proposalId: 'prop_A',
        label: 'Ja',
        position: 0,
      );
      await PodDatabase.instance.upsertProposalOption(data);

      final rows = await db.query(
        'proposal_options',
        where: 'option_id = ?',
        whereArgs: ['opt_001'],
      );
      expect(rows.length, equals(1));
      expect(rows.first['label'], equals('Ja'));
      expect(rows.first['proposal_id'], equals('prop_A'));
      expect(rows.first['status'], equals('ACTIVE'));
      expect(rows.first['position'], equals(0));
    });

    test('with same option_id replaces existing row', () async {
      final original = makeOption(
        optionId: 'opt_replace',
        proposalId: 'prop_A',
        label: 'Original',
        position: 0,
      );
      await PodDatabase.instance.upsertProposalOption(original);

      final updated = makeOption(
        optionId: 'opt_replace',
        proposalId: 'prop_A',
        label: 'Replaced',
        position: 1,
        status: 'WITHDRAWN',
      );
      await PodDatabase.instance.upsertProposalOption(updated);

      final rows = await db.query(
        'proposal_options',
        where: 'option_id = ?',
        whereArgs: ['opt_replace'],
      );
      expect(rows.length, equals(1), reason: 'Should replace, not append');
      expect(rows.first['label'], equals('Replaced'));
      expect(rows.first['status'], equals('WITHDRAWN'));
      expect(rows.first['position'], equals(1));
    });
  });

  // ── Group 2: listProposalOptions ──────────────────────────────────────────

  group('listProposalOptions', () {
    late Database db;
    setUp(() async {
      db = await openTestDb();
    });
    tearDown(() async {
      await db.close();
    });

    test('returns sorted by position ASC', () async {
      final base = DateTime.now().millisecondsSinceEpoch;
      // Insert in reverse position order
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_c',
        proposalId: 'prop_sort',
        label: 'C',
        position: 2,
        createdAt: base,
      ));
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_a',
        proposalId: 'prop_sort',
        label: 'A',
        position: 0,
        createdAt: base + 1,
      ));
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_b',
        proposalId: 'prop_sort',
        label: 'B',
        position: 1,
        createdAt: base + 2,
      ));

      final result =
          await PodDatabase.instance.listProposalOptions('prop_sort');

      expect(result.length, equals(3));
      expect(result[0]['label'], equals('A'));
      expect(result[1]['label'], equals('B'));
      expect(result[2]['label'], equals('C'));
    });

    test('sorts by created_at ASC within same position', () async {
      final base = DateTime.now().millisecondsSinceEpoch;
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_later',
        proposalId: 'prop_tiebreak',
        label: 'Later',
        position: 0,
        createdAt: base + 100,
      ));
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_earlier',
        proposalId: 'prop_tiebreak',
        label: 'Earlier',
        position: 0,
        createdAt: base,
      ));

      final result =
          await PodDatabase.instance.listProposalOptions('prop_tiebreak');

      expect(result.length, equals(2));
      expect(result[0]['label'], equals('Earlier'));
      expect(result[1]['label'], equals('Later'));
    });

    test('returns empty list for unknown proposalId', () async {
      final result =
          await PodDatabase.instance.listProposalOptions('does_not_exist');
      expect(result, isEmpty);
    });

    test('filters by proposalId only — does not return other proposals', () async {
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_x1',
        proposalId: 'prop_X',
        label: 'X-Option',
        position: 0,
      ));
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_y1',
        proposalId: 'prop_Y',
        label: 'Y-Option',
        position: 0,
      ));

      final result = await PodDatabase.instance.listProposalOptions('prop_X');

      expect(result.length, equals(1));
      expect(result.first['option_id'], equals('opt_x1'));
    });
  });

  // ── Group 3: deleteOptionsForProposal ─────────────────────────────────────

  group('deleteOptionsForProposal', () {
    late Database db;
    setUp(() async {
      db = await openTestDb();
    });
    tearDown(() async {
      await db.close();
    });

    test('removes only matching options', () async {
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_del1',
        proposalId: 'prop_del',
        label: 'Del 1',
        position: 0,
      ));
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_del2',
        proposalId: 'prop_del',
        label: 'Del 2',
        position: 1,
      ));

      await PodDatabase.instance.deleteOptionsForProposal('prop_del');

      final result =
          await PodDatabase.instance.listProposalOptions('prop_del');
      expect(result, isEmpty);
    });

    test('does not affect options of other proposals', () async {
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_keep1',
        proposalId: 'prop_keep',
        label: 'Keep this',
        position: 0,
      ));
      await PodDatabase.instance.upsertProposalOption(makeOption(
        optionId: 'opt_gone1',
        proposalId: 'prop_gone',
        label: 'Delete this',
        position: 0,
      ));

      await PodDatabase.instance.deleteOptionsForProposal('prop_gone');

      final kept =
          await PodDatabase.instance.listProposalOptions('prop_keep');
      final gone =
          await PodDatabase.instance.listProposalOptions('prop_gone');

      expect(kept.length, equals(1));
      expect(kept.first['option_id'], equals('opt_keep1'));
      expect(gone, isEmpty);
    });
  });
}
