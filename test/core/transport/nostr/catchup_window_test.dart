import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';

/// Audit Z-1 / Z-2: the catch-up window after a restart.
class _FakeRelayManager extends NostrRelayManager {
  _FakeRelayManager() : super(relayUrls: const []);

  final Map<String, Map<String, dynamic>> subscriptions = {};

  @override
  Stream<NostrEvent> get onEvent => const Stream.empty();
  @override
  bool get hasConnectedRelay => true;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  void publishFireAndForget(NostrEvent event) {}
  @override
  String subscribe(Map<String, dynamic> filter) {
    final id = generateSubId();
    subscriptions[id] = filter;
    return id;
  }

  @override
  void closeSubscription(String subId) => subscriptions.remove(subId);

  Map<String, dynamic> filterWhere(bool Function(Map<String, dynamic>) test) =>
      subscriptions.values.singleWhere(test);

  Map<String, dynamic> get dmFilter => filterWhere((f) =>
      (f['kinds'] as List?)?.contains(NostrKind.encryptedDm) == true &&
      f.containsKey('#p'));
  Map<String, dynamic> get ownDmFilter => filterWhere((f) =>
      (f['kinds'] as List?)?.contains(NostrKind.encryptedDm) == true &&
      f.containsKey('authors'));
  Map<String, dynamic> get meshFilter => filterWhere((f) =>
      (f['kinds'] as List?)?.contains(NostrKind.textNote) == true &&
      (f['#t'] as List?)?.contains('nexus-mesh') == true);
  Map<String, dynamic> channelFilter(String tag) => filterWhere((f) =>
      (f['kinds'] as List?)?.contains(NostrKind.channelMessage) == true &&
      (f['#t'] as List?)?.contains(tag) == true);
}

int _now() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

void main() {
  final keys = NostrKeys.fromBip39Seed(Uint8List.fromList(Bip39.mnemonicToSeed(
      'abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon about')));
  final overlap = NostrTransport.catchUpOverlap.inSeconds;

  Future<(NostrTransport, _FakeRelayManager)> startWith(int? lastSeen) async {
    final relay = _FakeRelayManager();
    final transport = NostrTransport(
      localDid: 'did:key:ich',
      localPseudonym: 'Ich',
      relayManager: relay,
    );
    if (lastSeen != null) transport.setLastMessageTimestamp(lastSeen);
    await transport.start(keysOverride: keys);
    return (transport, relay);
  }

  test('the overlap covers the outbox retention of the sender', () {
    expect(NostrTransport.catchUpOverlap, greaterThanOrEqualTo(
        const Duration(days: 7)));
  });

  test('DMs and own DMs are fetched with a multi-day overlap (Z-2)',
      () async {
    final last = _now() - 3600;
    final (transport, relay) = await startWith(last);

    expect(relay.dmFilter['since'], last - overlap);
    expect(relay.ownDmFilter['since'], last - overlap);
    await transport.stop();
  });

  test('channels are fetched with the same overlap (Z-2)', () async {
    final last = _now() - 3600;
    final (transport, relay) = await startWith(last);

    transport.subscribeToChannel('nexus-channel-test');

    expect(relay.channelFilter('nexus-channel-test')['since'], last - overlap);
    await transport.stop();
  });

  test('global mesh broadcasts keep the short buffer', () async {
    final last = _now() - 3600;
    final (transport, relay) = await startWith(last);

    expect(relay.meshFilter['since'], last - 60);
    await transport.stop();
  });

  test('a timestamp from the future is capped at now (Z-1)', () async {
    final (transport, relay) =
        await startWith(_now() + const Duration(days: 365).inSeconds);

    final dmSince = relay.dmFilter['since'] as int;
    expect(dmSince, lessThanOrEqualTo(_now() - overlap + 5),
        reason: 'otherwise the device would miss DMs for a year');
    expect(relay.meshFilter['since'] as int, lessThanOrEqualTo(_now()));
    await transport.stop();
  });
}
