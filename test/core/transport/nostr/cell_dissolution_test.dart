import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

/// Relay manager without sockets that records what is published.
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
  String subscribe(Map<String, dynamic> filter) => generateSubId();
  @override
  void closeSubscription(String subId) {}
}

void main() {
  test(
      'dissolving a cell publishes only the deleted announcement, '
      'no Kind-5 that would make relays reject it', () async {
    final relay = _FakeRelayManager();
    final transport = NostrTransport(
        localDid: 'did:key:admin',
        localPseudonym: 'Admin',
        relayManager: relay);
    await transport.start(
        keysOverride: NostrKeys.fromBip39Seed(
            Uint8List.fromList(Bip39.mnemonicToSeed(_mnemonic))));
    relay.published.clear();

    transport.publishCellDissolution({'id': 'cell-1', 'name': 'Testzelle'});

    expect(relay.published, hasLength(1));
    final event = relay.published.single;
    expect(event.kind, NostrKind.cellAnnounce);
    expect(event.kind, isNot(NostrKind.deletion));
    expect(event.tags, contains(equals(['d', 'cell-1'])));
    expect(event.tags, contains(equals(['deleted', 'true'])));
    expect((jsonDecode(event.content) as Map)['deleted'], isTrue);
    await transport.stop();
  });
}
