import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/contacts/contact_sync.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result.dart';

class _FakeRelayManager extends NostrRelayManager {
  _FakeRelayManager() : super(relayUrls: const []);

  final _events = StreamController<NostrEvent>.broadcast(sync: true);
  final List<NostrEvent> published = [];
  final Map<String, Map<String, dynamic>> subscriptions = {};

  @override
  Stream<NostrEvent> get onEvent => _events.stream;
  @override
  bool get hasConnectedRelay => true;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  void publishFireAndForget(NostrEvent event) => published.add(event);
  @override
  Future<RelayPublishOutcome> publish(
    NostrEvent event, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    published.add(event);
    return RelayPublishOutcome(
      eventId: event.id,
      sentToRelays: const ['wss://fake.relay'],
      acceptedRelays: const ['wss://fake.relay'],
      rejections: const {},
      timedOut: false,
    );
  }

  @override
  String subscribe(Map<String, dynamic> filter) {
    final id = generateSubId();
    subscriptions[id] = filter;
    return id;
  }

  @override
  void closeSubscription(String subId) => subscriptions.remove(subId);

  void deliver(NostrEvent e) => _events.add(e);
}

NostrKeys _keys(String mnemonic) => NostrKeys.fromBip39Seed(
    Uint8List.fromList(Bip39.mnemonicToSeed(mnemonic)));

void main() {
  final alice = _keys('abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about');
  final mallory = _keys('zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong');

  Future<(NostrTransport, _FakeRelayManager)> started() async {
    final relay = _FakeRelayManager();
    final transport = NostrTransport(
      localDid: 'did:key:alice',
      localPseudonym: 'Alice',
      relayManager: relay,
    );
    await transport.start(keysOverride: alice);
    return (transport, relay);
  }

  test('subscribes to the own contact list without a time limit', () async {
    final (transport, relay) = await started();

    final filter = relay.subscriptions.values.singleWhere(
        (f) => (f['#d'] as List?)?.contains(contactSyncDTag) == true);
    expect(filter['authors'], [alice.publicKeyHex]);
    expect(filter['kinds'], [NostrKind.presence]);
    expect(filter.containsKey('since'), isFalse);
    await transport.stop();
  });

  test('publishes the list as a replaceable kind-30078 event', () async {
    final (transport, relay) = await started();
    relay.published.clear();

    expect(await transport.publishContactSync('verschluesselt'), isTrue);

    final event = relay.published.single;
    expect(event.kind, NostrKind.presence);
    expect(event.tagValue('d'), contactSyncDTag);
    expect(event.tagValue('t'), isNull,
        reason: 'must not look like a presence announcement');
    expect(event.content, 'verschluesselt');
    await transport.stop();
  });

  test('forwards only lists signed with our own key', () async {
    final (transport, relay) = await started();
    final received = <String>[];
    transport.onContactSync.listen((l) => received.add(l.content));

    NostrEvent list(NostrKeys keys, String content) => NostrEvent.create(
          keys: keys,
          kind: NostrKind.presence,
          content: content,
          tags: [
            ['d', contactSyncDTag],
          ],
        );
    relay.deliver(list(mallory, 'fremd'));
    relay.deliver(list(alice, 'eigen'));
    await pumpEventQueue();

    expect(received, ['eigen']);
    await transport.stop();
  });
}
