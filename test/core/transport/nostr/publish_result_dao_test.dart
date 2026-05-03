import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result_dao.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result_status.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Creates a fresh in-memory DB with only the publish_results table
  /// and injects it into PodDatabase.instance.
  ///
  /// Schema is duplicated from pod_database.dart migration v19. If the
  /// real schema changes, this helper must be updated too.
  Future<Database> openTestDb() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE publish_results (
            publish_result_id TEXT PRIMARY KEY,
            local_event_id TEXT NOT NULL,
            nostr_event_id TEXT,
            event_kind INTEGER NOT NULL,
            proposal_id TEXT,
            cell_id TEXT,
            vote_id TEXT,
            status TEXT NOT NULL DEFAULT 'PENDING',
            attempted_at INTEGER NOT NULL,
            ack_received_at INTEGER,
            error_code TEXT,
            error_message TEXT,
            retry_count INTEGER NOT NULL DEFAULT 0,
            next_retry_at INTEGER,
            required_ack_count INTEGER NOT NULL DEFAULT 2,
            accepted_relay_count INTEGER NOT NULL DEFAULT 0,
            failed_relay_count INTEGER NOT NULL DEFAULT 0,
            final_status TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_publish_results_proposal ON publish_results(proposal_id)');
        await db.execute(
            'CREATE INDEX idx_publish_results_status ON publish_results(status)');
        await db.execute(
            'CREATE INDEX idx_publish_results_next_retry ON publish_results(next_retry_at)');
        await db.execute(
            'CREATE INDEX idx_publish_results_local_event ON publish_results(local_event_id)');
      },
    );
    final key = Uint8List(32)..fillRange(0, 32, 0x42);
    PodDatabase.instance.injectDatabase(db, key);
    return db;
  }

  // Helper to build a baseline PENDING PublishResult quickly
  PublishResult makePending({
    String? localEventId,
    int eventKind = 31010,
    String? proposalId,
    String? cellId,
    String? voteId,
    int? attemptedAt,
  }) {
    final now = attemptedAt ?? DateTime.now().millisecondsSinceEpoch;
    final eventId = localEventId ?? 'evt_$now';
    return PublishResult(
      publishResultId: 'publish_$eventId',
      localEventId: eventId,
      eventKind: eventKind,
      proposalId: proposalId,
      cellId: cellId,
      voteId: voteId,
      status: PublishResultStatus.pending,
      attemptedAt: now,
      retryCount: 0,
      requiredAckCount: 2,
      acceptedRelayCount: 0,
      failedRelayCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Group 1: insert + findByLocalEventId ────────────────────────────────

  group('PublishResultDao insert and find', () {
    late Database db;
    setUp(() async {
      db = await openTestDb();
    });
    tearDown(() async {
      await db.close();
    });

    test('insert stores all fields, findByLocalEventId returns equivalent',
        () async {
      final original = makePending(
        localEventId: 'evt_insert_1',
        proposalId: 'prop_1',
        cellId: 'cell_1',
      );
      await PublishResultDao.instance.insert(original);

      final fetched = await PublishResultDao.instance
          .findByLocalEventId('evt_insert_1');

      expect(fetched, isNotNull);
      expect(fetched!.publishResultId, equals(original.publishResultId));
      expect(fetched.localEventId, equals('evt_insert_1'));
      expect(fetched.eventKind, equals(31010));
      expect(fetched.proposalId, equals('prop_1'));
      expect(fetched.cellId, equals('cell_1'));
      expect(fetched.status, equals(PublishResultStatus.pending));
      expect(fetched.retryCount, equals(0));
    });

    test('findByLocalEventId returns null for unknown event', () async {
      final result = await PublishResultDao.instance
          .findByLocalEventId('does_not_exist');
      expect(result, isNull);
    });
  });

  // ── Group 2: update preserves nullable fields ───────────────────────────
  // This validates the UPDATE-Schutz: when a copyWith only sets some fields,
  // null fields in toMap() must NOT overwrite existing DB values.

  group('PublishResultDao update', () {
    late Database db;
    setUp(() async {
      db = await openTestDb();
    });
    tearDown(() async {
      await db.close();
    });

    test('update changes status and counts but preserves other fields',
        () async {
      final pending = makePending(
        localEventId: 'evt_update_1',
        proposalId: 'prop_1',
      );
      await PublishResultDao.instance.insert(pending);

      // Simulate a successful publish: ACCEPTED with 2 relays
      final completedAt = pending.attemptedAt + 1500;
      final updated = pending.copyWith(
        status: PublishResultStatus.accepted,
        finalStatus: PublishResultStatus.accepted,
        acceptedRelayCount: 2,
        ackReceivedAt: completedAt,
        updatedAt: completedAt,
      );
      await PublishResultDao.instance.update(updated);

      final fetched = await PublishResultDao.instance
          .findByLocalEventId('evt_update_1');

      expect(fetched, isNotNull);
      expect(fetched!.status, equals(PublishResultStatus.accepted));
      expect(fetched.finalStatus, equals(PublishResultStatus.accepted));
      expect(fetched.acceptedRelayCount, equals(2));
      expect(fetched.ackReceivedAt, equals(completedAt));
      // Preserved fields:
      expect(fetched.proposalId, equals('prop_1'));
      expect(fetched.localEventId, equals('evt_update_1'));
      expect(fetched.eventKind, equals(31010));
    });

    test('update with null fields does not erase existing values', () async {
      // Insert with proposalId set
      final initial = makePending(
        localEventId: 'evt_update_2',
        proposalId: 'prop_xyz',
        cellId: 'cell_xyz',
      );
      await PublishResultDao.instance.insert(initial);

      // Update only status, leave proposalId/cellId untouched (null in copyWith)
      final updated = initial.copyWith(
        status: PublishResultStatus.retrying,
        retryCount: 1,
        nextRetryAt: initial.attemptedAt + 60000,
      );
      await PublishResultDao.instance.update(updated);

      final fetched = await PublishResultDao.instance
          .findByLocalEventId('evt_update_2');

      expect(fetched, isNotNull);
      expect(fetched!.status, equals(PublishResultStatus.retrying));
      // proposalId und cellId müssen erhalten bleiben:
      expect(fetched.proposalId, equals('prop_xyz'),
          reason: 'proposal_id should not be erased by update with null');
      expect(fetched.cellId, equals('cell_xyz'),
          reason: 'cell_id should not be erased by update with null');
    });
  });

  // ── Group 3: findRetryDue with time filter ──────────────────────────────

  group('PublishResultDao findRetryDue', () {
    late Database db;
    setUp(() async {
      db = await openTestDb();
    });
    tearDown(() async {
      await db.close();
    });

    test('returns only RETRYING entries with nextRetryAt <= now', () async {
      final base = DateTime.now().millisecondsSinceEpoch;

      // 1) RETRYING, due (in past)
      final due = makePending(localEventId: 'evt_due', attemptedAt: base);
      final dueRetry = due.copyWith(
        status: PublishResultStatus.retrying,
        retryCount: 1,
        nextRetryAt: base - 1000, // 1s ago
      );
      await PublishResultDao.instance.insert(dueRetry);

      // 2) RETRYING, not yet due (in future)
      final future =
          makePending(localEventId: 'evt_future', attemptedAt: base);
      final futureRetry = future.copyWith(
        status: PublishResultStatus.retrying,
        retryCount: 1,
        nextRetryAt: base + 60000, // 1min from now
      );
      await PublishResultDao.instance.insert(futureRetry);

      // 3) ACCEPTED — should never appear
      final accepted =
          makePending(localEventId: 'evt_accepted', attemptedAt: base);
      final acceptedFinal = accepted.copyWith(
        status: PublishResultStatus.accepted,
        finalStatus: PublishResultStatus.accepted,
      );
      await PublishResultDao.instance.insert(acceptedFinal);

      // 4) PENDING — should never appear in findRetryDue
      final pending =
          makePending(localEventId: 'evt_pending', attemptedAt: base);
      await PublishResultDao.instance.insert(pending);

      final dueList = await PublishResultDao.instance.findRetryDue(base);

      expect(dueList.length, equals(1),
          reason: 'Only the past-due RETRYING entry should be returned');
      expect(dueList.first.localEventId, equals('evt_due'));
    });

    test('returns empty list when no retries are due', () async {
      final base = DateTime.now().millisecondsSinceEpoch;
      final pending = makePending(
          localEventId: 'evt_pending_only', attemptedAt: base);
      await PublishResultDao.instance.insert(pending);

      final dueList = await PublishResultDao.instance.findRetryDue(base);
      expect(dueList, isEmpty);
    });
  });

  // ── Group 4: findPendingByProposal ──────────────────────────────────────

  group('PublishResultDao findPendingByProposal', () {
    late Database db;
    setUp(() async {
      db = await openTestDb();
    });
    tearDown(() async {
      await db.close();
    });

    test('returns all in-flight entries for a given proposal', () async {
      final base = DateTime.now().millisecondsSinceEpoch;

      // 1) PENDING for our proposal
      final pending1 = makePending(
        localEventId: 'evt_p1',
        proposalId: 'prop_search',
        attemptedAt: base,
      );
      await PublishResultDao.instance.insert(pending1);

      // 2) PARTIAL for our proposal (also in-flight)
      final partial = makePending(
        localEventId: 'evt_p2',
        proposalId: 'prop_search',
        attemptedAt: base + 100,
      );
      final partialUpdated = partial.copyWith(
        status: PublishResultStatus.partial,
        acceptedRelayCount: 1,
        nextRetryAt: base + 60000,
      );
      await PublishResultDao.instance.insert(partialUpdated);

      // 3) ACCEPTED for our proposal — should NOT be in result
      final accepted = makePending(
        localEventId: 'evt_p3',
        proposalId: 'prop_search',
        attemptedAt: base + 200,
      );
      final acceptedFinal = accepted.copyWith(
        status: PublishResultStatus.accepted,
        finalStatus: PublishResultStatus.accepted,
        acceptedRelayCount: 2,
      );
      await PublishResultDao.instance.insert(acceptedFinal);

      // 4) PENDING for a DIFFERENT proposal — should NOT be in result
      final otherPending = makePending(
        localEventId: 'evt_other',
        proposalId: 'prop_other',
        attemptedAt: base + 300,
      );
      await PublishResultDao.instance.insert(otherPending);

      final inFlight = await PublishResultDao.instance
          .findPendingByProposal('prop_search');

      expect(inFlight.length, equals(2),
          reason: 'Only PENDING and PARTIAL of prop_search should match');
      final eventIds = inFlight.map((r) => r.localEventId).toSet();
      expect(eventIds, contains('evt_p1'));
      expect(eventIds, contains('evt_p2'));
      expect(eventIds, isNot(contains('evt_p3')));
      expect(eventIds, isNot(contains('evt_other')));
    });

    test('returns empty list for unknown proposal', () async {
      final inFlight = await PublishResultDao.instance
          .findPendingByProposal('does_not_exist');
      expect(inFlight, isEmpty);
    });
  });
}
