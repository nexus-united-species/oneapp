import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/identity/did.dart';
import 'package:nexus_oneapp/core/identity/identity_proof.dart';
import 'package:nexus_oneapp/core/transport/nexus_message.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result.dart';

const _aliceMnemonic = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';
const _bobMnemonic = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';
const _malloryMnemonic = 'legal winner thank year wave sausage worth useful '
    'legal winner thank yellow';

/// Relay manager without sockets: records publishes, lets tests deliver.
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

  void deliver(NostrEvent e) => _events.add(e);
}

NostrKeys _keys(String mnemonic) => NostrKeys.fromBip39Seed(
    Uint8List.fromList(Bip39.mnemonicToSeed(mnemonic)));

Future<({SimpleKeyPair keyPair, String did})> _identity(int seedByte) async {
  final keyPair =
      await Ed25519().newKeyPairFromSeed(List<int>.filled(32, seedByte));
  final publicKey = await keyPair.extractPublicKey();
  return (keyPair: keyPair, did: DidKey.fromPublicKeyBytes(publicKey.bytes));
}

void main() {
  late NostrKeys aliceKeys;
  late NostrKeys bobKeys;
  late NostrKeys malloryKeys;
  late String aliceDid;
  late String bobDid;
  late Map<String, String> bobProof;

  setUp(() async {
    aliceKeys = _keys(_aliceMnemonic);
    bobKeys = _keys(_bobMnemonic);
    malloryKeys = _keys(_malloryMnemonic);
    aliceDid = (await _identity(1)).did;
    final bob = await _identity(2);
    bobDid = bob.did;
    bobProof = await IdentityProof.create(
        signingKeyPair: bob.keyPair,
        did: bob.did,
        nostrPubkeyHex: bobKeys.publicKeyHex);
  });

  /// Sends [body] to Alice, signed with [keys], claiming to come from Bob.
  Future<NostrEvent> dmToAlice(String body,
      {required NostrKeys keys, Map<String, String>? proof}) async {
    final relay = _FakeRelayManager();
    final sender = NostrTransport(
        localDid: bobDid, localPseudonym: 'Bob', relayManager: relay);
    if (proof != null) sender.setIdentityProof(proof);
    await sender.start(keysOverride: keys);
    sender.registerDidMapping(aliceDid, aliceKeys.publicKeyHex);
    relay.published.clear();
    await sender.sendMessage(
        NexusMessage.create(fromDid: bobDid, toDid: aliceDid, body: body),
        recipientDid: aliceDid);
    await sender.stop();
    return relay.published.singleWhere((e) => e.kind == NostrKind.encryptedDm);
  }

  /// Alice's device; returns transport, relay and the received messages.
  Future<(NostrTransport, _FakeRelayManager, List<NexusMessage>)>
      aliceDevice() async {
    final relay = _FakeRelayManager();
    final alice = NostrTransport(
        localDid: aliceDid, localPseudonym: 'Alice', relayManager: relay);
    final received = <NexusMessage>[];
    alice.onMessageReceived.listen(received.add);
    await alice.start(keysOverride: aliceKeys);
    return (alice, relay, received);
  }

  /// The Nostr key Alice's device would send a reply to Bob to.
  Future<String> replyTarget(NostrTransport alice, _FakeRelayManager relay) async {
    relay.published.clear();
    await alice.sendMessage(
        NexusMessage.create(fromDid: aliceDid, toDid: bobDid, body: 'Antwort'),
        recipientDid: bobDid);
    return relay.published
        .singleWhere((e) => e.kind == NostrKind.encryptedDm)
        .tagValue('p')!;
  }

  group('DM sender check (audit S-1)', () {
    test('a DM with a valid proof is marked verified', () async {
      final event = await dmToAlice('Hallo', keys: bobKeys, proof: bobProof);
      final (alice, relay, received) = await aliceDevice();

      relay.deliver(event);
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single.isSenderUnverified, isFalse);
      expect(received.single.metadata?[NexusMessage.senderCheckMetaKey],
          NexusMessage.senderVerified);
      expect(await replyTarget(alice, relay), bobKeys.publicKeyHex);
      await alice.stop();
    });

    test('a DM without proof is accepted but marked unverified', () async {
      final event = await dmToAlice('Hallo', keys: bobKeys);
      final (alice, relay, received) = await aliceDevice();

      relay.deliver(event);
      await pumpEventQueue();

      expect(received.single.isSenderUnverified, isTrue);
      await alice.stop();
    });

    test('a forged DM for a known contact is dropped and the key kept',
        () async {
      final forged = await dmToAlice('Ich bin Bob', keys: malloryKeys);
      final (alice, relay, received) = await aliceDevice();
      alice.registerDidMapping(bobDid, bobKeys.publicKeyHex);

      relay.deliver(forged);
      await pumpEventQueue();

      expect(received, isEmpty);
      expect(await replyTarget(alice, relay), bobKeys.publicKeyHex);
      await alice.stop();
    });

    test("Bob's proof replayed by another key is dropped", () async {
      final forged =
          await dmToAlice('Ich bin Bob', keys: malloryKeys, proof: bobProof);
      final (alice, relay, received) = await aliceDevice();

      relay.deliver(forged);
      await pumpEventQueue();

      expect(received, isEmpty);
      await alice.stop();
    });

    test('a channel post without proof cannot take over a known key',
        () async {
      final (alice, relay, received) = await aliceDevice();
      alice.registerDidMapping(bobDid, bobKeys.publicKeyHex);

      final post = NostrEvent.create(
        keys: malloryKeys,
        kind: NostrKind.channelMessage,
        content: jsonEncode(NexusMessage.create(
          fromDid: bobDid,
          toDid: NexusMessage.broadcastDid,
          body: 'Ich bin Bob',
          channel: '#test',
          metadata: {
            NexusMessage.senderCheckMetaKey: NexusMessage.senderVerified,
          },
        ).toJson()),
        tags: [
          ['t', 'nexus-channel-test'],
        ],
      );
      relay.deliver(post);
      await pumpEventQueue();

      expect(await replyTarget(alice, relay), bobKeys.publicKeyHex);
      for (final m in received) {
        expect(m.metadata?[NexusMessage.senderCheckMetaKey], isNull,
            reason: 'a check result sent by the author is discarded');
      }
      await alice.stop();
    });
  });
}
