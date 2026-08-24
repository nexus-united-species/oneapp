import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/transport/message_transport.dart';
import 'package:nexus_oneapp/core/transport/nexus_message.dart';
import 'package:nexus_oneapp/core/transport/nexus_peer.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/core/transport/transport_manager.dart';

// ── Fake relay manager (no real WebSocket connections in tests) ───────────────

class FakeRelayManager extends NostrRelayManager {
  FakeRelayManager() : super(relayUrls: []);

  final _eventCtrl = StreamController<NostrEvent>.broadcast();
  final List<NostrEvent> published = [];

  @override
  Stream<NostrEvent> get onEvent => _eventCtrl.stream;

  @override
  bool get hasConnectedRelay => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<RelayPublishOutcome> publish(
    NostrEvent event, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    published.add(event);
    return RelayPublishOutcome(
      eventId: event.id,
      sentToRelays: const [],
      acceptedRelays: const [],
      rejections: const {},
      timedOut: false,
    );
  }

  @override
  String subscribe(Map<String, dynamic> filter) => generateSubId();

  @override
  void closeSubscription(String subId) {}

  void injectEvent(NostrEvent event) => _eventCtrl.add(event);

  Future<void> close() => _eventCtrl.close();
}

// ── Fake transport (reused from transport_manager_test.dart pattern) ──────────

class FakeTransport implements MessageTransport {
  FakeTransport({required this.type});

  @override
  final TransportType type;

  final _msgCtrl = StreamController<NexusMessage>.broadcast();
  final _peersCtrl = StreamController<List<NexusPeer>>.broadcast();
  final List<NexusMessage> sent = [];
  final List<NexusPeer> _currentPeers = [];
  TransportState _state = TransportState.idle;
  bool started = false;

  @override
  TransportState get state => _state;

  @override
  Stream<NexusMessage> get onMessageReceived => _msgCtrl.stream;

  @override
  Stream<List<NexusPeer>> get onPeersChanged => _peersCtrl.stream;

  @override
  List<NexusPeer> get currentPeers => List.unmodifiable(_currentPeers);

  @override
  Future<void> start() async {
    _state = TransportState.scanning;
    started = true;
  }

  @override
  Future<void> stop() async {
    _state = TransportState.idle;
    await _msgCtrl.close();
    await _peersCtrl.close();
  }

  @override
  Future<void> sendMessage(NexusMessage message, {String? recipientDid}) async {
    sent.add(message);
  }

  void injectMessage(NexusMessage msg) => _msgCtrl.add(msg);

  void injectPeers(List<NexusPeer> peers) {
    _currentPeers
      ..clear()
      ..addAll(peers);
    _peersCtrl.add(List.unmodifiable(peers));
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('TransportManager with three transports (BLE + LAN + Nostr)', () {
    late TransportManager manager;
    late FakeTransport ble;
    late FakeTransport lan;
    late FakeTransport nostr;

    setUp(() {
      manager = TransportManager.instance;
      ble = FakeTransport(type: TransportType.ble);
      lan = FakeTransport(type: TransportType.lan);
      nostr = FakeTransport(type: TransportType.nostr);

      manager.clearTransports();
      manager.registerTransport(ble);
      manager.registerTransport(lan);
      manager.registerTransport(nostr);
    });

    tearDown(() async {
      await manager.stop();
    });

    test('all three transports start', () async {
      await manager.start();
      expect(ble.started, isTrue);
      expect(lan.started, isTrue);
      expect(nostr.started, isTrue);
    });

    test('fallback cascade: BLE→LAN→Nostr', () async {
      await manager.start();

      // No peers – BLE is first registered, should receive message
      final msg = NexusMessage.create(
        fromDid: 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
        body: 'test',
      );
      await manager.sendMessage(msg);
      expect(ble.sent, contains(msg));
    });

    test('LAN is preferred when recipient is reachable via LAN', () async {
      await manager.start();

      // Use full-length DIDs to avoid NexusMessage.toString() range errors
      const senderDid = 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
      const recipientDid = 'did:key:z6MkpTHR8VNsBxYAAWHut2Geadd9jSwuias8sisDArDJF69k';
      // Inject peer visible on LAN
      lan.injectPeers([
        NexusPeer(
          did: recipientDid,
          pseudonym: 'Bob',
          transportType: TransportType.lan,
          lastSeen: DateTime.now(),
        ),
      ]);
      await Future.delayed(const Duration(milliseconds: 50));

      final msg = NexusMessage.create(
        fromDid: senderDid,
        toDid: recipientDid,
        body: 'direct',
      );
      await manager.sendMessage(msg, recipientDid: recipientDid);

      // LAN should have sent it, BLE and Nostr should not
      expect(lan.sent, contains(msg));
      expect(ble.sent, isEmpty);
      expect(nostr.sent, isEmpty);
    });

    test('peer merging: same DID visible on both LAN and Nostr', () async {
      await manager.start();

      const did = 'did:key:shared';
      lan.injectPeers([
        NexusPeer(
          did: did,
          pseudonym: 'Alice',
          transportType: TransportType.lan,
          lastSeen: DateTime.now(),
        ),
      ]);
      nostr.injectPeers([
        NexusPeer(
          did: did,
          pseudonym: 'Alice',
          transportType: TransportType.nostr,
          lastSeen: DateTime.now(),
        ),
      ]);
      await Future.delayed(const Duration(milliseconds: 50));

      final peer = manager.peers.firstWhere((p) => p.did == did);
      // Should be merged into one peer with LAN as primary
      expect(peer.transportType, equals(TransportType.lan));
      expect(peer.availableTransports,
          containsAll([TransportType.lan, TransportType.nostr]));
    });

    test('Nostr is fallback when BLE and LAN are error state', () async {
      await manager.start();
      ble._state = TransportState.error;
      lan._state = TransportState.error;

      final msg = NexusMessage.create(
        fromDid: 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
        body: 'nostr fallback',
      );
      await manager.sendMessage(msg);

      expect(nostr.sent, contains(msg));
      expect(ble.sent, isEmpty);
      expect(lan.sent, isEmpty);
    });

    test('messages from Nostr transport are forwarded to stream', () async {
      await manager.start();

      final received = <NexusMessage>[];
      final sub = manager.onMessageReceived.listen(received.add);

      final msg = NexusMessage.create(
        fromDid: 'did:key:z6MkpTHR8VNsBxYAAWHut2Geadd9jSwuias8sisDArDJF69k',
        toDid: 'did:key:z6Mkk7oqU9EA9LcC7MHn4HG3LBgzBLEiMN6FxdmGCYaewKH',
        body: 'from nostr',
      );
      nostr.injectMessage(msg);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(received, contains(msg));
      await sub.cancel();
    });

    test('message deduplication: same ID from two transports delivered once',
        () async {
      await manager.start();

      final received = <NexusMessage>[];
      final sub = manager.onMessageReceived.listen(received.add);

      final msg = NexusMessage.create(
        fromDid: 'did:key:z6MkpTHR8VNsBxYAAWHut2Geadd9jSwuias8sisDArDJF69k',
        body: 'duplicate',
      );

      // Same message injected by both BLE and Nostr
      ble.injectMessage(msg);
      nostr.injectMessage(msg);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(received.where((m) => m.id == msg.id).length, equals(1));
      await sub.cancel();
    });
  });

  group('NIP-04 Encryption round-trip', () {
    test('ECDH shared secret is commutative (pre-condition for NIP-04)', () {
      const m1 = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const m2 = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';

      final seed1 = Uint8List.fromList(Bip39.mnemonicToSeed(m1));
      final seed2 = Uint8List.fromList(Bip39.mnemonicToSeed(m2));

      final keys1 = NostrKeys.fromBip39Seed(seed1);
      final keys2 = NostrKeys.fromBip39Seed(seed2);

      final sharedA = keys1.computeSharedSecret(keys2.publicKey);
      final sharedB = keys2.computeSharedSecret(keys1.publicKey);
      expect(sharedA, equals(sharedB),
          reason: 'ECDH shared secret must be commutative');
    });

    test('NostrTransport start with keysOverride does not connect relays',
        () async {
      const m1 = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final seed1 = Uint8List.fromList(Bip39.mnemonicToSeed(m1));
      final keys1 = NostrKeys.fromBip39Seed(seed1);

      final fakeRelay = FakeRelayManager();
      final transport = NostrTransport(
        localDid: 'did:key:alice',
        localPseudonym: 'Alice',
        relayManager: fakeRelay,
      );

      await transport.start(keysOverride: keys1);
      expect(transport.keys, isNotNull);
      expect(transport.keys!.publicKeyHex, equals(keys1.publicKeyHex));
      await transport.stop();
    });

    test('NostrTransport sends broadcast as Kind 1 event', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final seed = Uint8List.fromList(Bip39.mnemonicToSeed(mnemonic));
      final keys = NostrKeys.fromBip39Seed(seed);

      final fakeRelay = FakeRelayManager();
      final transport = NostrTransport(
        localDid: 'did:key:alice',
        localPseudonym: 'Alice',
        relayManager: fakeRelay,
      );

      await transport.start(keysOverride: keys);
      fakeRelay.published.clear(); // start() publishes a presence event; ignore it

      final msg = NexusMessage.create(
        fromDid: 'did:key:alice',
        toDid: NexusMessage.broadcastDid,
        body: 'hello mesh',
        channel: '#mesh',
      );
      await transport.sendMessage(msg);

      expect(fakeRelay.published, hasLength(1));
      expect(fakeRelay.published.first.kind, equals(NostrKind.textNote));
      expect(fakeRelay.published.first.tagValue('t'), equals('nexus-mesh'));

      await transport.stop();
    });
  });

  group('NostrTransport event references', () {
    const aliceMnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const bobMnemonic =
        'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';
    const validTargetEventId =
        'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

    NostrKeys keysFor(String mnemonic) => NostrKeys.fromBip39Seed(
          Uint8List.fromList(Bip39.mnemonicToSeed(mnemonic)),
        );

    Future<({NostrTransport transport, FakeRelayManager relay})>
        startTransport() async {
      final relay = FakeRelayManager();
      final transport = NostrTransport(
        localDid: 'did:key:alice',
        localPseudonym: 'Alice',
        relayManager: relay,
      );
      await transport.start(keysOverride: keysFor(aliceMnemonic));
      relay.published.clear();
      return (transport: transport, relay: relay);
    }

    Future<void> stopTransport(
      NostrTransport transport,
      FakeRelayManager relay,
    ) async {
      await transport.stop();
      await relay.close();
    }

    test('outgoing Kind-42 associates UUID with its 64-hex wrapper ID',
        () async {
      final (:transport, :relay) = await startTransport();
      final message = NexusMessage.create(
        fromDid: 'did:key:alice',
        toDid: NexusMessage.broadcastDid,
        channel: '#reaktionen',
        body: 'Hallo Kanal',
      );

      await transport.sendMessage(message);

      expect(relay.published, hasLength(1));
      final wrapper = relay.published.single;
      expect(wrapper.kind, NostrKind.channelMessage);
      expect(NostrTransport.isValidNostrEventId(wrapper.id), isTrue);
      expect(transport.consumeSentNostrEventId(message.id), wrapper.id);
      expect(transport.consumeSentNostrEventId(message.id), isNull,
          reason: 'The association is consumed when the provider persists it');

      await stopTransport(transport, relay);
    });

    test('incoming Kind-42 adds wrapper ID without replacing the UUID',
        () async {
      final (:transport, :relay) = await startTransport();
      final original = NexusMessage.create(
        fromDid: 'did:key:bob',
        toDid: NexusMessage.broadcastDid,
        channel: '#reaktionen',
        body: 'Hallo von Bob',
      );
      final wrapper = NostrEvent.create(
        keys: keysFor(bobMnemonic),
        kind: NostrKind.channelMessage,
        content: jsonEncode(original.toJson()),
        tags: const [
          ['t', 'nexus-channel-reaktionen'],
        ],
      );
      final received = Completer<NexusMessage>();
      final subscription = transport.onMessageReceived.listen(received.complete);

      relay.injectEvent(wrapper);
      final enriched = await received.future.timeout(const Duration(seconds: 1));

      expect(enriched.id, original.id);
      expect(enriched.nostrEventId, wrapper.id);
      expect(NostrTransport.isValidNostrEventId(enriched.nostrEventId), isTrue);

      await subscription.cancel();
      await stopTransport(transport, relay);
    });

    test('publishReaction emits one Kind-7 with the exact valid e-tag',
        () async {
      final (:transport, :relay) = await startTransport();

      transport.publishReaction(validTargetEventId, '👍');
      await Future<void>.delayed(Duration.zero);

      expect(relay.published, hasLength(1));
      expect(relay.published.single.kind, NostrKind.reaction);
      expect(relay.published.single.content, '👍');
      expect(relay.published.single.tags, [
        ['e', validTargetEventId],
      ]);

      await stopTransport(transport, relay);
    });

    test('publishReaction rejects empty, UUID, and malformed targets',
        () async {
      final (:transport, :relay) = await startTransport();

      for (final invalidTarget in <String>[
        '',
        '550e8400-e29b-41d4-a716-446655440000',
        'gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg',
        'abc123',
      ]) {
        transport.publishReaction(invalidTarget, '👍');
      }
      await Future<void>.delayed(Duration.zero);

      expect(relay.published, isEmpty);

      await stopTransport(transport, relay);
    });

    test('incoming Kind-7 dispatches only a valid 64-hex e-tag', () async {
      final (:transport, :relay) = await startTransport();
      final reactions = <Map<String, dynamic>>[];
      final subscription = transport.onFeedReaction.listen(reactions.add);
      final bobKeys = keysFor(bobMnemonic);

      NostrEvent reactionWithTags(List<List<String>> tags) => NostrEvent.create(
            keys: bobKeys,
            kind: NostrKind.reaction,
            content: '🔥',
            tags: tags,
          );

      relay.injectEvent(reactionWithTags(const []));
      relay.injectEvent(reactionWithTags(const [
        ['e', '550e8400-e29b-41d4-a716-446655440000'],
      ]));
      relay.injectEvent(reactionWithTags(const [
        ['e', 'not-hex'],
      ]));
      relay.injectEvent(reactionWithTags(const [
        ['e', validTargetEventId],
      ]));
      await Future<void>.delayed(Duration.zero);

      expect(reactions, hasLength(1));
      expect(reactions.single['referencedEventId'], validTargetEventId);
      expect(reactions.single['emoji'], '🔥');
      expect(reactions.single['senderPubkey'], bobKeys.publicKeyHex);

      await subscription.cancel();
      await stopTransport(transport, relay);
    });
  });

  group('NostrTransport - type and initial state', () {
    test('transport type is nostr', () {
      final t = NostrTransport(
        localDid: 'did:key:x',
        localPseudonym: 'X',
      );
      expect(t.type, equals(TransportType.nostr));
    });

    test('initial state is idle', () {
      final t = NostrTransport(
        localDid: 'did:key:x',
        localPseudonym: 'X',
      );
      expect(t.state, equals(TransportState.idle));
    });

    test('currentPeers is empty initially', () {
      final t = NostrTransport(
        localDid: 'did:key:x',
        localPseudonym: 'X',
      );
      expect(t.currentPeers, isEmpty);
    });
  });
}
