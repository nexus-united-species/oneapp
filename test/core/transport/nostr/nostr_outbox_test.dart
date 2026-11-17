import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_outbox.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result.dart';

/// TD-74: chat events that no relay accepted are kept and published again
/// once a relay is reachable, instead of being lost.

NostrEvent _event({
  int kind = NostrKind.encryptedDm,
  String idChar = 'a',
  Duration age = Duration.zero,
}) =>
    NostrEvent(
      id: idChar * 64,
      pubkey: 'b' * 64,
      createdAt:
          DateTime.now().subtract(age).toUtc().millisecondsSinceEpoch ~/ 1000,
      kind: kind,
      tags: const [],
      content: 'inhalt',
      sig: 'c' * 128,
    );

RelayPublishOutcome _outcome(NostrEvent event, {required bool accepted}) =>
    RelayPublishOutcome(
      eventId: event.id,
      sentToRelays: accepted ? const ['wss://relay'] : const [],
      acceptedRelays: accepted ? const ['wss://relay'] : const [],
      rejections: const {},
      timedOut: !accepted,
    );

void main() {
  late MemoryNostrOutboxStore store;
  late List<String> publishedIds;
  late bool relayAccepts;
  late NostrOutbox outbox;

  setUp(() {
    store = MemoryNostrOutboxStore();
    publishedIds = [];
    relayAccepts = false;
    outbox = NostrOutbox(store, (event) async {
      publishedIds.add(event.id);
      return _outcome(event, accepted: relayAccepts);
    });
  });

  group('publish', () {
    test('keeps a DM that no relay accepted', () async {
      final dm = _event();

      await outbox.publish(dm);

      expect((await store.pending()).map((e) => e.id), [dm.id]);
    });

    test('does not keep an accepted event', () async {
      relayAccepts = true;

      await outbox.publish(_event());

      expect(await store.pending(), isEmpty);
    });

    test('keeps channel posts, reactions and deletions too', () async {
      for (final (kind, idChar) in [
        (NostrKind.channelMessage, '1'),
        (NostrKind.reaction, '2'),
        (NostrKind.deletion, '3'),
      ]) {
        await outbox.publish(_event(kind: kind, idChar: idChar));
      }

      expect(await store.pending(), hasLength(3));
    });

    test('does not keep presence or governance events', () async {
      await outbox.publish(_event(kind: NostrKind.presence, idChar: '4'));
      await outbox.publish(_event(kind: NostrKind.voteEvent, idChar: '5'));

      expect(await store.pending(), isEmpty);
    });

    test('keeps join requests, cell events, profile and feed posts (Z-5)',
        () async {
      for (final (kind, idChar) in [
        (NostrKind.cellJoinRequest, '6'),
        (NostrKind.cellMembershipConfirmed, '7'),
        (NostrKind.cellRoster, '8'),
        (NostrKind.cellAnnounce, '9'),
        (NostrKind.metadata, 'd'),
        (NostrKind.textNote, 'e'),
      ]) {
        await outbox.publish(_event(kind: kind, idChar: idChar));
      }

      expect(await store.pending(), hasLength(6));
    });

    test('keeps the event when publishing throws', () async {
      outbox = NostrOutbox(store, (_) async => throw StateError('offline'));

      await outbox.publish(_event());

      expect(await store.pending(), hasLength(1));
    });
  });

  group('flush', () {
    test('delivers queued events and removes them', () async {
      final dm = _event();
      await outbox.publish(dm);
      relayAccepts = true;
      publishedIds.clear();

      final delivered = await outbox.flush();

      expect(delivered, 1);
      expect(publishedIds, [dm.id]);
      expect(await store.pending(), isEmpty);
    });

    test('keeps events the relay still does not accept', () async {
      await outbox.publish(_event());

      final delivered = await outbox.flush();

      expect(delivered, 0);
      expect(await store.pending(), hasLength(1));
    });

    test('drops events older than the maximum age', () async {
      await store.put(_event(age: NostrOutbox.maxAge + const Duration(hours: 1)));
      relayAccepts = true;

      await outbox.flush();

      expect(publishedIds, isEmpty);
      expect(await store.pending(), isEmpty);
    });

    test('runs only once when several relays connect at the same time',
        () async {
      final dm = _event();
      await store.put(dm);
      relayAccepts = true;

      await Future.wait([outbox.flush(), outbox.flush(), outbox.flush()]);

      expect(publishedIds, [dm.id]);
    });
  });

  group('onAccepted (audit Z-4)', () {
    test('reports an event the relay accepted right away', () async {
      relayAccepts = true;
      final accepted = <String>[];
      outbox.onAccepted.listen(accepted.add);
      final dm = _event();

      await outbox.publish(dm);
      await pumpEventQueue();

      expect(accepted, [dm.id]);
    });

    test('reports nothing while no relay accepts', () async {
      final accepted = <String>[];
      outbox.onAccepted.listen(accepted.add);

      await outbox.publish(_event());
      await pumpEventQueue();

      expect(accepted, isEmpty);
    });

    test('reports a queued event once a relay takes it later', () async {
      final accepted = <String>[];
      outbox.onAccepted.listen(accepted.add);
      final dm = _event();
      await outbox.publish(dm);
      relayAccepts = true;

      await outbox.flush();
      await pumpEventQueue();

      expect(accepted, [dm.id]);
    });
  });

  group('final refusals (device test 16.11.2026)', () {
    RelayPublishOutcome refused(NostrEvent e, String reason) =>
        RelayPublishOutcome(
          eventId: e.id,
          sentToRelays: const ['wss://relay'],
          acceptedRelays: const [],
          rejections: {'wss://relay': reason},
          timedOut: false,
        );

    test('verdictFor sorts relay answers', () {
      final e = _event();
      expect(verdictFor(_outcome(e, accepted: true)), PublishVerdict.accepted);
      expect(verdictFor(refused(e, 'duplicate: already have it')),
          PublishVerdict.accepted);
      expect(verdictFor(refused(e, 'replaced: have newer event')),
          PublishVerdict.final_);
      expect(verdictFor(refused(e, 'invalid: event too large: 642150')),
          PublishVerdict.final_);
      expect(verdictFor(refused(e, 'rate-limited: slow down')),
          PublishVerdict.retry);
      expect(
          verdictFor(refused(e, 'banned: too many rate-limit violations, try again later')),
          PublishVerdict.retry);
      expect(verdictFor(_outcome(e, accepted: false)), PublishVerdict.retry);
    });

    test('a too large event is not queued and is reported', () async {
      final e = _event();
      final rejected = <String>[];
      outbox = NostrOutbox(store, (_) async => refused(e, 'invalid: event too large'));
      outbox.onRejected.listen((r) => rejected.add(r.eventId));

      await outbox.publish(e);
      await pumpEventQueue();

      expect(await store.pending(), isEmpty);
      expect(rejected, [e.id]);
    });

    test('an outdated replaceable event leaves the queue silently', () async {
      final e = _event(kind: NostrKind.cellRoster);
      await store.put(e);
      final rejected = <String>[];
      outbox = NostrOutbox(store, (_) async => refused(e, 'replaced: have newer event'));
      outbox.onRejected.listen((r) => rejected.add(r.eventId));

      await outbox.flush();
      await pumpEventQueue();

      expect(await store.pending(), isEmpty,
          reason: 'resending it forever got the client banned by damus');
      expect(rejected, isEmpty);
    });

    test('flush sends several queued events at once', () async {
      for (var i = 0; i < 10; i++) {
        await store.put(_event(idChar: '$i'));
      }
      var inFlight = 0;
      var maxInFlight = 0;
      outbox = NostrOutbox(store, (event) async {
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return _outcome(event, accepted: true);
      });

      final delivered = await outbox.flush();

      expect(delivered, 10);
      expect(maxInFlight, greaterThan(1));
      expect(maxInFlight, lessThanOrEqualTo(NostrOutbox.flushConcurrency));
    });
  });

  group('oversized events (device test 16.11.2026)', () {
    NostrEvent big() => NostrEvent(
          id: 'f' * 64,
          pubkey: 'b' * 64,
          createdAt: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
          kind: NostrKind.encryptedDm,
          tags: const [],
          content: 'x' * (NostrOutbox.maxEventBytes + 1),
          sig: 'c' * 128,
        );

    test('is never sent, never queued, and reported as refused', () async {
      final rejected = <String>[];
      outbox.onRejected.listen((r) => rejected.add(r.eventId));

      await outbox.publish(big());
      await pumpEventQueue();

      expect(publishedIds, isEmpty,
          reason: 'relays drop the whole connection for such a frame');
      expect(await store.pending(), isEmpty);
      expect(rejected, ['f' * 64]);
    });

    test('an oversized event already in the queue is removed on flush',
        () async {
      await store.put(big());

      await outbox.flush();

      expect(publishedIds, isEmpty);
      expect(await store.pending(), isEmpty);
    });
  });
}
