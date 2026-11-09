import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Columns and tables that migrations added after the first release. A fresh
/// install must have all of them, since it never runs `_onUpgrade`.
const _migratedColumns = {
  'pod_contacts': ['encryption_public_key'],
  'pod_messages': [
    'encrypted',
    'message_id',
    'is_favorite',
    'is_deleted',
    'edited_body',
    'nostr_event_id',
  ],
  'group_channels': ['cell_id', 'nostr_event_id'],
  'message_reactions': ['nostr_event_id'],
  'proposals': ['voting_mode', 'eligible_voters_json'],
  'proposal_votes': ['selected_option_id'],
  'decision_records': [
    'result_relation',
    'previous_proposal_id',
    'option_results_json',
    'tie_option_ids_json',
    'result_reason',
    'eligible_voters_count',
  ],
};

const _migratedTables = [
  'proposal_discussions',
  'tombstones',
  'cell_founding_permits',
  'publish_results',
  'proposal_options',
  'delegations',
  'nostr_outbox',
  'cell_departures',
];

Future<Set<String>> _columns(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return {for (final row in rows) row['name'] as String};
}

Future<Set<String>> _tables(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  );
  return {for (final row in rows) row['name'] as String};
}

Future<List<String>> _missingColumns(Database db) async {
  final missing = <String>[];
  for (final entry in _migratedColumns.entries) {
    final present = await _columns(db, entry.key);
    for (final column in entry.value) {
      if (!present.contains(column)) missing.add('${entry.key}.$column');
    }
  }
  return missing;
}

void main() {
  group('device freshly installed with an earlier build (v28 repair)', () {
    late Database broken;

    setUpAll(sqfliteFfiInit);

    setUp(() async {
      broken = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      // What fresh installs used to get: only the base tables.
      await PodDatabase.createBaseTablesForTest(broken);
    });

    tearDown(() => broken.close());

    test('the update to v28 adds every missing column and table', () async {
      expect(
        await _missingColumns(broken),
        isNotEmpty,
        reason: 'precondition: the old fresh-install schema is incomplete',
      );

      await PodDatabase.upgradeForTest(broken, 26);

      expect(await _missingColumns(broken), isEmpty);
      final tables = await _tables(broken);
      expect(_migratedTables.where((t) => !tables.contains(t)), isEmpty);
      expect(tables.contains('proposals_legacy'), isFalse);
    });

    test('the repair keeps existing rows', () async {
      await broken.insert('proposals', {
        'id': 'p1',
        'cell_id': 'c1',
        'creator_did': 'did:key:a',
        'title': 'Hochbeete',
        'created_at': 0,
      });

      await PodDatabase.upgradeForTest(broken, 26);

      final rows = await broken.query('proposals');
      expect(rows.single['title'], 'Hochbeete');
      expect(rows.single['voting_mode'], 'YES_NO_ABSTAIN');
    });
  });

  group('fresh install', () {
    late Database db;

    setUpAll(sqfliteFfiInit);

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await PodDatabase.createSchemaForTest(db);
    });

    tearDown(() => db.close());

    test('a fresh install has every column added by a migration', () async {
      expect(await _missingColumns(db), isEmpty);
    });

    test('a fresh install has every table added by a migration', () async {
      final present = await _tables(db);

      expect(_migratedTables.where((t) => !present.contains(t)), isEmpty);
      expect(
        present.contains('proposals_legacy'),
        isFalse,
        reason: 'the v12 rename must not run on a fresh install',
      );
    });

    test('a fresh install accepts a decision record with all fields', () async {
      await db.insert('decision_records', {
        'record_id': 'r1',
        'proposal_id': 'p1',
        'cell_id': 'c1',
        'final_title': 'T',
        'final_description': 'D',
        'result': 'approved',
        'yes_votes': 1,
        'no_votes': 0,
        'abstain_votes': 0,
        'participation': 1.0,
        'decided_at': 0,
        'all_votes': '[]',
        'content_hash': 'h',
        'nostr_event_id': '',
        'result_relation': null,
        'previous_proposal_id': null,
        'option_results_json': null,
        'tie_option_ids_json': null,
        'result_reason': null,
        'eligible_voters_count': 1,
      });

      expect(await db.query('decision_records'), hasLength(1));
    });
  });
}
