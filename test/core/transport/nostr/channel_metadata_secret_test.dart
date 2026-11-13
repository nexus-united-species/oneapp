import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

class _FakeRelayManager extends NostrRelayManager {
  _FakeRelayManager() : super(relayUrls: const []);

  final _events = StreamController<NostrEvent>.broadcast(sync: true);
  final List<NostrEvent> published = [];

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
  String subscribe(Map<String, dynamic> filter) => generateSubId();
  @override
  void closeSubscription(String subId) {}
}

void main() {
  test('channel metadata never carries the current or earlier secrets',
      () async {
    final relay = _FakeRelayManager();
    final transport = NostrTransport(
        localDid: 'did:key:admin', localPseudonym: 'Admin', relayManager: relay);
    await transport.start(
        keysOverride: NostrKeys.fromBip39Seed(
            Uint8List.fromList(Bip39.mnemonicToSeed(_mnemonic))));
    relay.published.clear();

    transport.publishChannelMetadata({
      'id': 'c1',
      'name': '#geheim',
      'nostrTag': 'nexus-channel-geheim',
      'isPublic': false,
      'channelSecret': 'aktuell-geheim',
      'previousSecrets': ['frueher-geheim'],
      'members': ['did:key:a'],
    });

    final content = relay.published.single.content;
    expect(content, isNot(contains('aktuell-geheim')));
    expect(content, isNot(contains('frueher-geheim')));
    await transport.stop();
  });
}
