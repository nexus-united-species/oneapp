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

    test('does not keep events of other kinds (e.g. presence)', () async {
      await outbox.publish(_event(kind: NostrKind.metadata));

      expect(await store.pending(), isEmpty);
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
}
