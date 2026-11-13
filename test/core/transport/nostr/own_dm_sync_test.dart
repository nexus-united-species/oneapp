import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/transport/nexus_message.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result.dart';

const _aliceMnemonic = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';
const _bobMnemonic = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';
const _aliceDid = 'did:key:alice';
const _bobDid = 'did:key:bob';

/// Relay manager without sockets: records publishes and subscriptions and
/// lets tests deliver events.
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

  Iterable<Map<String, dynamic>> dmFilters() => subscriptions.values.where(
      (f) => (f['kinds'] as List?)?.contains(NostrKind.encryptedDm) == true);

  void deliver(NostrEvent e) => _events.add(e);
}

NostrKeys _keys(String mnemonic) => NostrKeys.fromBip39Seed(
    Uint8List.fromList(Bip39.mnemonicToSeed(mnemonic)));

NostrTransport _transport(_FakeRelayManager relay, String did) =>
    NostrTransport(localDid: did, localPseudonym: did, relayManager: relay);

int _now() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

void main() {
  late NostrKeys alice;
  late NostrKeys bob;

  setUp(() {
    alice = _keys(_aliceMnemonic);
    bob = _keys(_bobMnemonic);
  });

  group('subscriptions (TD-57, TD-63)', () {
    test('subscribes to DMs for us and to DMs we sent ourselves', () async {
      final relay = _FakeRelayManager();
      final transport = _transport(relay, _aliceDid);
      await transport.start(keysOverride: alice);

      final filters = relay.dmFilters().toList();
      expect(filters.where((f) => (f['#p'] as List?)?.contains(alice.publicKeyHex) == true),
          hasLength(1));
      expect(filters.where((f) => (f['authors'] as List?)?.contains(alice.publicKeyHex) == true),
          hasLength(1));
      await transport.stop();
    });

    test('a device without history fetches 30 days of DMs', () async {
      final relay = _FakeRelayManager();
      final transport = _transport(relay, _aliceDid);
      await transport.start(keysOverride: alice);

      for (final filter in relay.dmFilters()) {
        final since = filter['since'] as int;
        expect(_now() - since,
            closeTo(NostrTransport.newDeviceDmHistory.inSeconds, 5));
      }
      await transport.stop();
    });

    test('with a known last message both DM filters start there', () async {
      final relay = _FakeRelayManager();
      final transport = _transport(relay, _aliceDid);
      final last = _now() - 3600;
      transport.setLastMessageTimestamp(last);
      await transport.start(keysOverride: alice);

      for (final filter in relay.dmFilters()) {
        expect(filter['since'],
            last - NostrTransport.catchUpOverlap.inSeconds);
      }
      await transport.stop();
    });

    test('membership confirmations are fetched without a time limit',
        () async {
      final relay = _FakeRelayManager();
      final transport = _transport(relay, _aliceDid);
      await transport.start(keysOverride: alice);

      final filter = relay.subscriptions.values.singleWhere((f) =>
          (f['kinds'] as List?)?.contains(NostrKind.cellMembershipConfirmed) ==
          true);
      expect(filter.containsKey('since'), isFalse);
      await transport.stop();
    });
  });

  group('own DMs from the other device (TD-57)', () {
    /// Sends [body] from Alice's phone to Bob and returns the signed event.
    Future<NostrEvent> sendFromPhone(String body, {String fromDid = _aliceDid}) async {
      final relay = _FakeRelayManager();
      final phone = _transport(relay, fromDid);
      await phone.start(keysOverride: alice);
      phone.registerDidMapping(_bobDid, bob.publicKeyHex);
      relay.published.clear();

      await phone.sendMessage(
        NexusMessage.create(fromDid: fromDid, toDid: _bobDid, body: body),
        recipientDid: _bobDid,
      );
      await phone.stop();
      return relay.published.singleWhere((e) => e.kind == NostrKind.encryptedDm);
    }

    test('the other device decrypts it as an outgoing message to Bob',
        () async {
      final event = await sendFromPhone('Hallo Bob');

      final relay = _FakeRelayManager();
      final desktop = _transport(relay, _aliceDid);
      final received = <NexusMessage>[];
      desktop.onMessageReceived.listen(received.add);
      await desktop.start(keysOverride: alice);

      relay.deliver(event);
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single.fromDid, _aliceDid);
      expect(received.single.toDid, _bobDid);
      expect(received.single.body, 'Hallo Bob');
      expect(received.single.nostrEventId, event.id);
      await desktop.stop();
    });

    test('an own-key DM claiming another sender is ignored', () async {
      final event = await sendFromPhone('Fälschung', fromDid: 'did:key:mallory');

      final relay = _FakeRelayManager();
      final desktop = _transport(relay, _aliceDid);
      final received = <NexusMessage>[];
      desktop.onMessageReceived.listen(received.add);
      await desktop.start(keysOverride: alice);

      relay.deliver(event);
      await pumpEventQueue();

      expect(received, isEmpty);
      await desktop.stop();
    });

    test('Bob still receives the DM as before', () async {
      final event = await sendFromPhone('Hallo Bob');

      final relay = _FakeRelayManager();
      final bobDevice = _transport(relay, _bobDid);
      final received = <NexusMessage>[];
      bobDevice.onMessageReceived.listen(received.add);
      await bobDevice.start(keysOverride: bob);

      relay.deliver(event);
      await pumpEventQueue();

      expect(received.map((m) => m.body), ['Hallo Bob']);
      await bobDevice.stop();
    });
  });
}
