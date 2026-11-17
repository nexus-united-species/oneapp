import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';

const _aliceMnemonic = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';
const _bobMnemonic = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';

void main() {
  late Map<String, String> store;

  setUp(() {
    store = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(store);
  });

  group('NostrKeys.cacheForBackground (audit TD-65)', () {
    test('writes both keys, overwriting whatever was cached before',
        () async {
      store['nostr_private_key'] = 'stale';
      store['nostr_public_key'] = 'stale';
      final keys = NostrKeys.fromBip39Seed(
          Uint8List.fromList(Bip39.mnemonicToSeed(_aliceMnemonic)));

      await NostrKeys.cacheForBackground(keys,
          storage: const FlutterSecureStorage());

      final cached = await NostrKeys.loadCachedOnly(
          storage: const FlutterSecureStorage());
      expect(cached!.publicKeyHex, keys.publicKeyHex);
      expect(store['nostr_public_key'], isNot('stale'));
    });
  });

  group('NostrTransport.initKeys caches for the background isolate (TD-65)',
      () {
    test('a switch to another identity replaces the cached key, '
        'not just adds to it', () async {
      final alice = NostrTransport(
        localDid: 'did:key:alice',
        localPseudonym: 'Alice',
        relayManager: NostrRelayManager(relayUrls: const []),
      );
      await alice.initKeys(
          Uint8List.fromList(Bip39.mnemonicToSeed(_aliceMnemonic)));
      await Future<void>.delayed(Duration.zero); // the write is best-effort

      final afterAlice = await NostrKeys.loadCachedOnly(
          storage: const FlutterSecureStorage());
      expect(afterAlice!.publicKeyHex, alice.localNostrPubkeyHex);

      // Device switches to a different identity (e.g. restore on the same
      // device): the cache must now hold Bob's key, not a mix of both.
      final bob = NostrTransport(
        localDid: 'did:key:bob',
        localPseudonym: 'Bob',
        relayManager: NostrRelayManager(relayUrls: const []),
      );
      await bob.initKeys(
          Uint8List.fromList(Bip39.mnemonicToSeed(_bobMnemonic)));
      await Future<void>.delayed(Duration.zero);

      final afterBob = await NostrKeys.loadCachedOnly(
          storage: const FlutterSecureStorage());
      expect(afterBob!.publicKeyHex, bob.localNostrPubkeyHex);
      expect(afterBob.publicKeyHex, isNot(afterAlice.publicKeyHex));
    });
  });
}
