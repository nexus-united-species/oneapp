import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result_status.dart';

void main() {
  // ── Group 1: PublishResult round-trip ────────────────────────────────────

  group('PublishResult serialization', () {
    test('round-trip preserves all required fields', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final original = PublishResult(
        publishResultId: 'publish_test_1',
        localEventId: 'evt_local_1',
        eventKind: 31010,
        status: PublishResultStatus.pending,
        attemptedAt: now,
        retryCount: 0,
        requiredAckCount: 2,
        acceptedRelayCount: 0,
        failedRelayCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      final restored = PublishResult.fromMap(original.toMap());

      expect(restored.publishResultId, equals(original.publishResultId));
      expect(restored.localEventId, equals(original.localEventId));
      expect(restored.eventKind, equals(original.eventKind));
      expect(restored.status, equals(PublishResultStatus.pending));
      expect(restored.attemptedAt, equals(now));
      expect(restored.retryCount, equals(0));
      expect(restored.requiredAckCount, equals(2));
      expect(restored.acceptedRelayCount, equals(0));
      expect(restored.failedRelayCount, equals(0));
      expect(restored.createdAt, equals(now));
      expect(restored.updatedAt, equals(now));
    });

    test('round-trip preserves all optional nullable fields', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ackTime = now + 1500;
      final original = PublishResult(
        publishResultId: 'publish_test_2',
        localEventId: 'evt_local_2',
        nostrEventId: 'evt_local_2',
        eventKind: 31011,
        proposalId: 'prop_xyz',
        cellId: 'cell_xyz',
        voteId: 'vote_xyz',
        status: PublishResultStatus.accepted,
        attemptedAt: now,
        ackReceivedAt: ackTime,
        retryCount: 1,
        requiredAckCount: 2,
        acceptedRelayCount: 2,
        failedRelayCount: 0,
        finalStatus: PublishResultStatus.accepted,
        createdAt: now,
        updatedAt: ackTime,
      );

      final restored = PublishResult.fromMap(original.toMap());

      expect(restored.nostrEventId, equals(original.nostrEventId));
      expect(restored.proposalId, equals('prop_xyz'));
      expect(restored.cellId, equals('cell_xyz'));
      expect(restored.voteId, equals('vote_xyz'));
      expect(restored.ackReceivedAt, equals(ackTime));
      expect(restored.finalStatus, equals(PublishResultStatus.accepted));
    });

    test('round-trip preserves error fields when status is REJECTED', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final original = PublishResult(
        publishResultId: 'publish_test_3',
        localEventId: 'evt_local_3',
        eventKind: 31010,
        status: PublishResultStatus.rejected,
        finalStatus: PublishResultStatus.rejected,
        attemptedAt: now,
        errorCode: 'rejected_by_relay',
        errorMessage: 'invalid: signature does not verify',
        retryCount: 0,
        requiredAckCount: 2,
        acceptedRelayCount: 0,
        failedRelayCount: 2,
        createdAt: now,
        updatedAt: now,
      );

      final restored = PublishResult.fromMap(original.toMap());

      expect(restored.status, equals(PublishResultStatus.rejected));
      expect(restored.finalStatus, equals(PublishResultStatus.rejected));
      expect(restored.errorCode, equals('rejected_by_relay'));
      expect(restored.errorMessage, contains('signature'));
      expect(restored.failedRelayCount, equals(2));
    });

    test('round-trip preserves retrying status with nextRetryAt', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final nextRetry = now + 60000; // +1 min
      final original = PublishResult(
        publishResultId: 'publish_test_4',
        localEventId: 'evt_local_4',
        eventKind: 31010,
        status: PublishResultStatus.retrying,
        attemptedAt: now,
        retryCount: 1,
        nextRetryAt: nextRetry,
        requiredAckCount: 2,
        acceptedRelayCount: 0,
        failedRelayCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      final restored = PublishResult.fromMap(original.toMap());

      expect(restored.status, equals(PublishResultStatus.retrying));
      expect(restored.retryCount, equals(1));
      expect(restored.nextRetryAt, equals(nextRetry));
      expect(restored.finalStatus, isNull);
    });

    test('null optional fields remain null after round-trip', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final original = PublishResult(
        publishResultId: 'publish_test_5',
        localEventId: 'evt_local_5',
        eventKind: 31010,
        attemptedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final restored = PublishResult.fromMap(original.toMap());

      expect(restored.nostrEventId, isNull);
      expect(restored.proposalId, isNull);
      expect(restored.cellId, isNull);
      expect(restored.voteId, isNull);
      expect(restored.ackReceivedAt, isNull);
      expect(restored.errorCode, isNull);
      expect(restored.errorMessage, isNull);
      expect(restored.nextRetryAt, isNull);
      expect(restored.finalStatus, isNull);
    });
  });

  // ── Group 2: PublishResult.copyWith immutability ─────────────────────────

  group('PublishResult.copyWith', () {
    test('copyWith returns new instance, original unchanged', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final original = PublishResult(
        publishResultId: 'publish_cw_1',
        localEventId: 'evt_cw_1',
        eventKind: 31010,
        status: PublishResultStatus.pending,
        attemptedAt: now,
        retryCount: 0,
        requiredAckCount: 2,
        acceptedRelayCount: 0,
        failedRelayCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        status: PublishResultStatus.accepted,
        acceptedRelayCount: 2,
        ackReceivedAt: now + 1000,
      );

      // Updated has new values
      expect(updated.status, equals(PublishResultStatus.accepted));
      expect(updated.acceptedRelayCount, equals(2));
      expect(updated.ackReceivedAt, equals(now + 1000));

      // Original is unchanged
      expect(original.status, equals(PublishResultStatus.pending));
      expect(original.acceptedRelayCount, equals(0));
      expect(original.ackReceivedAt, isNull);

      // Other fields are preserved on the updated copy
      expect(updated.publishResultId, equals(original.publishResultId));
      expect(updated.localEventId, equals(original.localEventId));
      expect(updated.eventKind, equals(original.eventKind));
    });

    test('copyWith with no arguments returns equivalent object', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final original = PublishResult(
        publishResultId: 'publish_cw_2',
        localEventId: 'evt_cw_2',
        eventKind: 31010,
        status: PublishResultStatus.partial,
        attemptedAt: now,
        retryCount: 1,
        requiredAckCount: 2,
        acceptedRelayCount: 1,
        failedRelayCount: 1,
        createdAt: now,
        updatedAt: now,
      );

      final copy = original.copyWith();

      expect(copy.publishResultId, equals(original.publishResultId));
      expect(copy.status, equals(original.status));
      expect(copy.retryCount, equals(original.retryCount));
      expect(copy.acceptedRelayCount, equals(original.acceptedRelayCount));
      expect(copy.failedRelayCount, equals(original.failedRelayCount));
    });

    test('copyWith can advance status through lifecycle', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pending = PublishResult(
        publishResultId: 'publish_cw_3',
        localEventId: 'evt_cw_3',
        eventKind: 31010,
        status: PublishResultStatus.pending,
        attemptedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final retrying = pending.copyWith(
        status: PublishResultStatus.retrying,
        retryCount: 1,
        nextRetryAt: now + 30000,
        updatedAt: now + 5000,
      );

      final failed = retrying.copyWith(
        status: PublishResultStatus.failed,
        finalStatus: PublishResultStatus.failed,
        retryCount: 5,
        nextRetryAt: null,
        updatedAt: now + 90000,
      );

      expect(retrying.status, equals(PublishResultStatus.retrying));
      expect(retrying.retryCount, equals(1));
      expect(retrying.nextRetryAt, equals(now + 30000));

      // Note: copyWith(nextRetryAt: null) won't clear the field since
      // null is indistinguishable from "not provided" in this pattern.
      // We only verify the status transition and retryCount here.
      expect(failed.status, equals(PublishResultStatus.failed));
      expect(failed.finalStatus, equals(PublishResultStatus.failed));
      expect(failed.retryCount, equals(5));

      // publishResultId stays constant across copies
      expect(retrying.publishResultId, equals(pending.publishResultId));
      expect(failed.publishResultId, equals(pending.publishResultId));
    });
  });

  // ── Group 3: RelayPublishOutcome computed properties ─────────────────────

  group('RelayPublishOutcome', () {
    test('acceptedCount equals length of acceptedRelays', () {
      final outcome = RelayPublishOutcome(
        eventId: 'evt_1',
        sentToRelays: ['relay1', 'relay2', 'relay3'],
        acceptedRelays: ['relay1', 'relay2'],
        rejections: {'relay3': 'invalid'},
        timedOut: false,
      );
      expect(outcome.acceptedCount, equals(2));
    });

    test('rejectedCount equals length of rejections map', () {
      final outcome = RelayPublishOutcome(
        eventId: 'evt_2',
        sentToRelays: ['r1', 'r2', 'r3'],
        acceptedRelays: const [],
        rejections: {'r1': 'x', 'r2': 'y', 'r3': 'z'},
        timedOut: false,
      );
      expect(outcome.rejectedCount, equals(3));
    });

    test('pendingCount = sent - accepted - rejected', () {
      final outcome = RelayPublishOutcome(
        eventId: 'evt_3',
        sentToRelays: ['r1', 'r2', 'r3', 'r4'],
        acceptedRelays: ['r1'],
        rejections: {'r2': 'reason'},
        timedOut: true,
      );
      // 4 sent - 1 accepted - 1 rejected = 2 pending
      expect(outcome.pendingCount, equals(2));
    });

    test('zero relays: all counts are zero, timedOut true', () {
      final outcome = RelayPublishOutcome(
        eventId: 'evt_4',
        sentToRelays: const [],
        acceptedRelays: const [],
        rejections: const {},
        timedOut: true,
      );
      expect(outcome.acceptedCount, equals(0));
      expect(outcome.rejectedCount, equals(0));
      expect(outcome.pendingCount, equals(0));
      expect(outcome.timedOut, isTrue);
    });

    test('all accepted, no pending, no timeout', () {
      final outcome = RelayPublishOutcome(
        eventId: 'evt_5',
        sentToRelays: ['r1', 'r2'],
        acceptedRelays: ['r1', 'r2'],
        rejections: const {},
        timedOut: false,
      );
      expect(outcome.acceptedCount, equals(2));
      expect(outcome.pendingCount, equals(0));
      expect(outcome.timedOut, isFalse);
    });

    test('single relay accepted satisfies quorum check of 1', () {
      final outcome = RelayPublishOutcome(
        eventId: 'evt_6',
        sentToRelays: ['r1'],
        acceptedRelays: ['r1'],
        rejections: const {},
        timedOut: false,
      );
      expect(outcome.acceptedCount >= 1, isTrue);
      expect(outcome.rejectedCount, equals(0));
      expect(outcome.pendingCount, equals(0));
    });
  });

  // ── Group 4: PublishResultStatus set consistency ─────────────────────────
  // PublishResultStatus.all / .inFlight / .terminal existieren als
  // const Set<String> — alle Tests werden ausgeführt.

  group('PublishResultStatus sets', () {
    test('all set contains all 6 status values', () {
      expect(PublishResultStatus.all, contains(PublishResultStatus.pending));
      expect(PublishResultStatus.all, contains(PublishResultStatus.partial));
      expect(PublishResultStatus.all, contains(PublishResultStatus.accepted));
      expect(PublishResultStatus.all, contains(PublishResultStatus.rejected));
      expect(PublishResultStatus.all, contains(PublishResultStatus.retrying));
      expect(PublishResultStatus.all, contains(PublishResultStatus.failed));
      expect(PublishResultStatus.all.length, equals(6));
    });

    test('inFlight contains only non-terminal statuses', () {
      expect(
          PublishResultStatus.inFlight, contains(PublishResultStatus.pending));
      expect(
          PublishResultStatus.inFlight, contains(PublishResultStatus.partial));
      expect(
          PublishResultStatus.inFlight, contains(PublishResultStatus.retrying));
      expect(PublishResultStatus.inFlight,
          isNot(contains(PublishResultStatus.accepted)));
      expect(PublishResultStatus.inFlight,
          isNot(contains(PublishResultStatus.rejected)));
      expect(PublishResultStatus.inFlight,
          isNot(contains(PublishResultStatus.failed)));
    });

    test('terminal contains only final statuses', () {
      expect(PublishResultStatus.terminal,
          contains(PublishResultStatus.accepted));
      expect(PublishResultStatus.terminal,
          contains(PublishResultStatus.rejected));
      expect(
          PublishResultStatus.terminal, contains(PublishResultStatus.failed));
      expect(PublishResultStatus.terminal,
          isNot(contains(PublishResultStatus.pending)));
      expect(PublishResultStatus.terminal,
          isNot(contains(PublishResultStatus.partial)));
      expect(PublishResultStatus.terminal,
          isNot(contains(PublishResultStatus.retrying)));
    });

    test('inFlight and terminal are disjoint', () {
      final intersection =
          PublishResultStatus.inFlight.intersection(PublishResultStatus.terminal);
      expect(intersection, isEmpty);
    });

    test('inFlight + terminal cover all statuses', () {
      final union =
          PublishResultStatus.inFlight.union(PublishResultStatus.terminal);
      expect(union, equals(PublishResultStatus.all));
    });

    test('status string values match expected constants', () {
      expect(PublishResultStatus.pending, equals('PENDING'));
      expect(PublishResultStatus.partial, equals('PARTIAL'));
      expect(PublishResultStatus.accepted, equals('ACCEPTED'));
      expect(PublishResultStatus.rejected, equals('REJECTED'));
      expect(PublishResultStatus.retrying, equals('RETRYING'));
      expect(PublishResultStatus.failed, equals('FAILED'));
    });
  });
}
