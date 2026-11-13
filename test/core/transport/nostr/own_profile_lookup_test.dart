import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon about';

/// Relay manager without sockets: records fire-and-forget publishes and
/// open subscriptions, lets tests inject events and EOSE.
class _FakeRelayManager extends NostrRelayManager {
  _FakeRelayManager() : super(relayUrls: const []);

  final _events = StreamController<NostrEvent>.broadcast(sync: true);
  final _eose = StreamController<String>.broadcast(sync: true);
  final List<NostrEvent> fired = [];
  final Map<String, Map<String, dynamic>> subscriptions = {};

  @override
  Stream<NostrEvent> get onEvent => _events.stream;
  @override
  Stream<String> get onEose => _eose.stream;
  @override
  bool get hasConnectedRelay => true;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  void publishFireAndForget(NostrEvent event) => fired.add(event);
  @override
  String subscribe(Map<String, dynamic> filter) {
    final id = generateSubId();
    subscriptions[id] = filter;
    return id;
  }

  @override
  void closeSubscription(String subId) => subscriptions.remove(subId);

  String? subIdFor(String author, int kind) => subscriptions.entries
      .where((e) =>
          (e.value['authors'] as List?)?.contains(author) == true &&
          (e.value['kinds'] as List?)?.contains(kind) == true)
      .map((e) => e.key)
      .firstOrNull;

  void inject(NostrEvent e) => _events.add(e);
  void eose(String subId) => _eose.add(subId);
}

NostrKeys _keys() =>
    NostrKeys.fromBip39Seed(Uint8List.fromList(Bip39.mnemonicToSeed(_mnemonic)));

NostrEvent _ownKind0(NostrKeys keys, String name, DateTime at) =>
    NostrEvent.create(
      keys: keys,
      kind: NostrKind.metadata,
      content: jsonEncode({'name': name, 'about': 'Bio von $name'}),
      timestamp: at,
    );

List<NostrEvent> _kind0(_FakeRelayManager relay) =>
    relay.fired.where((e) => e.kind == NostrKind.metadata).toList();

void main() {
  late NostrKeys keys;

  setUp(() => keys = _keys());

  NostrTransport transportWith(_FakeRelayManager relay, {required bool pending}) =>
      NostrTransport(
        localDid: 'did:key:alice',
        localPseudonym: 'Mutiger Fuchs 42',
        relayManager: relay,
      )..profileRestorePending = pending;

  test('without a pending restore the own Kind-0 is published at start',
      () async {
    final relay = _FakeRelayManager();
    final transport = transportWith(relay, pending: false);

    await transport.start(keysOverride: keys);

    expect(_kind0(relay), hasLength(1));
    expect(relay.subIdFor(keys.publicKeyHex, NostrKind.metadata), isNull);
    await transport.stop();
  });

  test('after a seed restore the own Kind-0 is held back and looked up',
      () async {
    final relay = _FakeRelayManager();
    final transport = transportWith(relay, pending: true);

    await transport.start(keysOverride: keys);
    await transport.republishMetadata();

    expect(_kind0(relay), isEmpty);
    expect(relay.subIdFor(keys.publicKeyHex, NostrKind.metadata), isNotNull);
    await transport.stop();
  });

  test('delivers the newest own Kind-0 after the settle window', () {
    fakeAsync((async) {
      final relay = _FakeRelayManager();
      final transport = transportWith(relay, pending: true);
      final results = <Map<String, dynamic>?>[];
      transport.onOwnProfileLookup.listen(results.add);

      transport.start(keysOverride: keys);
      async.flushMicrotasks();

      relay.inject(_ownKind0(keys, 'Joachim alt', DateTime(2026, 10, 1)));
      relay.inject(_ownKind0(keys, 'Joachim', DateTime(2026, 11, 1)));
      async.flushMicrotasks();
      expect(results, isEmpty, reason: 'still waiting for slower relays');

      async.elapse(NostrTransport.ownProfileSettleDelay);
      async.flushMicrotasks();

      expect(results, hasLength(1));
      expect(results.single!['name'], 'Joachim');
      expect(relay.subIdFor(keys.publicKeyHex, NostrKind.metadata), isNull,
          reason: 'lookup subscription is closed');
      expect(_kind0(relay), isEmpty,
          reason: 'publishing waits for completeProfileRestore');
    });
  });

  test('reports null when the relays only answer with EOSE', () {
    fakeAsync((async) {
      final relay = _FakeRelayManager();
      final transport = transportWith(relay, pending: true);
      final results = <Map<String, dynamic>?>[];
      transport.onOwnProfileLookup.listen(results.add);

      transport.start(keysOverride: keys);
      async.flushMicrotasks();
      relay.eose(relay.subIdFor(keys.publicKeyHex, NostrKind.metadata)!);
      async.elapse(NostrTransport.ownProfileSettleDelay);
      async.flushMicrotasks();

      expect(results, [null]);
    });
  });

  test('stays pending while no relay has answered at all', () {
    fakeAsync((async) {
      final relay = _FakeRelayManager();
      final transport = transportWith(relay, pending: true);
      final results = <Map<String, dynamic>?>[];
      transport.onOwnProfileLookup.listen(results.add);

      transport.start(keysOverride: keys);
      async.elapse(const Duration(minutes: 5));

      expect(results, isEmpty);
      expect(_kind0(relay), isEmpty);
    });
  });

  test('completeProfileRestore publishes the own Kind-0 once', () async {
    final relay = _FakeRelayManager();
    final transport = transportWith(relay, pending: true);
    await transport.start(keysOverride: keys);

    await transport.completeProfileRestore();
    await transport.completeProfileRestore();

    expect(transport.profileRestorePending, isFalse);
    expect(_kind0(relay), hasLength(1));
    await transport.stop();
  });
}
