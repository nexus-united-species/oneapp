import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/message_transport.dart';
import 'package:nexus_oneapp/core/transport/nexus_message.dart';
import 'package:nexus_oneapp/core/transport/nexus_peer.dart';
import 'package:nexus_oneapp/core/transport/transport_manager.dart';

/// TD-73: a message delivered over LAN has no Nostr event ID. The manager
/// must hand the event ID of a later Nostr copy to the app instead of
/// silently dropping it as a duplicate, and directed LAN deliveries must
/// also go out over Nostr so such an ID exists at all.

const _eventId =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
const _bobDid = 'did:key:z6MkBobBobBobBobBobBobBobBobBob';

class _Transport implements MessageTransport {
  _Transport(this.type, {this.failSend = false});

  @override
  final TransportType type;
  final bool failSend;
  final sentIds = <String>[];
  final _msgCtrl = StreamController<NexusMessage>.broadcast();
  final _peersCtrl = StreamController<List<NexusPeer>>.broadcast();
  final _peers = <NexusPeer>[];

  @override
  TransportState get state => TransportState.connected;

  @override
  Stream<NexusMessage> get onMessageReceived => _msgCtrl.stream;

  @override
  Stream<List<NexusPeer>> get onPeersChanged => _peersCtrl.stream;

  @override
  List<NexusPeer> get currentPeers => List.unmodifiable(_peers);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> sendMessage(NexusMessage message, {String? recipientDid}) async {
    if (failSend) throw StateError('send failed');
    sentIds.add(message.id);
  }

  void receive(NexusMessage message) => _msgCtrl.add(message);

  void seePeer(String did) {
    _peers.add(NexusPeer(
      did: did,
      pseudonym: 'Bob',
      transportType: type,
      availableTransports: {type},
      lastSeen: DateTime.now(),
    ));
    _peersCtrl.add(List.of(_peers));
  }
}

void main() {
  late TransportManager manager;
  late _Transport lan;
  late _Transport nostr;

  setUp(() async {
    manager = TransportManager.instance..clearTransports();
    lan = _Transport(TransportType.lan);
    nostr = _Transport(TransportType.nostr);
    manager
      ..registerTransport(lan)
      ..registerTransport(nostr);
    await manager.start();
  });

  tearDown(() async {
    await manager.stop();
    manager.clearTransports();
  });

  NexusMessage channelPost() => NexusMessage.create(
        fromDid: _bobDid,
        toDid: NexusMessage.broadcastDid,
        channel: '#kanal',
        body: 'über LAN zuerst',
      );

  group('Nostr copy of an already delivered message', () {
    test('is delivered once and its event ID is handed over', () async {
      final delivered = <String>[];
      final references = <NexusMessage>[];
      final subs = [
        manager.onMessageReceived.listen((m) => delivered.add(m.id)),
        manager.onNostrReference.listen(references.add),
      ];
      final post = channelPost();

      lan.receive(post);
      nostr.receive(post.withNostrEventId(_eventId, authorPubkey: '44' * 32));
      await Future<void>.delayed(Duration.zero);

      expect(delivered, [post.id]);
      expect(references, hasLength(1));
      expect(references.single.id, post.id);
      expect(references.single.nostrEventId, _eventId);
      for (final s in subs) {
        await s.cancel();
      }
    });

    test('a duplicate without event ID is dropped silently', () async {
      final references = <NexusMessage>[];
      final sub = manager.onNostrReference.listen(references.add);
      final post = channelPost();

      lan.receive(post);
      lan.receive(post);
      await Future<void>.delayed(Duration.zero);

      expect(references, isEmpty);
      await sub.cancel();
    });
  });

  group('directed message to a LAN peer', () {
    NexusMessage directToBob() => NexusMessage.create(
          fromDid: 'did:key:z6MkAliceAliceAliceAliceAlice',
          toDid: _bobDid,
          body: 'hallo Bob',
        );

    test('is also sent over Nostr', () async {
      lan.seePeer(_bobDid);
      await Future<void>.delayed(Duration.zero);
      final message = directToBob();

      await manager.sendMessage(message, recipientDid: _bobDid);

      expect(lan.sentIds, [message.id]);
      expect(nostr.sentIds, [message.id]);
    });

    test('still counts as delivered when the Nostr copy fails', () async {
      await manager.stop();
      manager.clearTransports();
      lan = _Transport(TransportType.lan);
      nostr = _Transport(TransportType.nostr, failSend: true);
      manager
        ..registerTransport(lan)
        ..registerTransport(nostr);
      await manager.start();
      lan.seePeer(_bobDid);
      await Future<void>.delayed(Duration.zero);
      final message = directToBob();

      await manager.sendMessage(message, recipientDid: _bobDid);

      expect(lan.sentIds, [message.id]);
    });

    test('goes over Nostr only once when LAN cannot deliver', () async {
      await manager.stop();
      manager.clearTransports();
      lan = _Transport(TransportType.lan, failSend: true);
      nostr = _Transport(TransportType.nostr);
      manager
        ..registerTransport(lan)
        ..registerTransport(nostr);
      await manager.start();
      final message = directToBob();

      await manager.sendMessage(message, recipientDid: _bobDid);

      expect(nostr.sentIds, [message.id]);
    });
  });
}
