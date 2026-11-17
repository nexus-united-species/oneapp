import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';

const _privHex =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _pubHex =
    '2222222222222222222222222222222222222222222222222222222222222222';

void main() {
  late Map<String, String> store;

  setUp(() {
    store = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(store);
  });

  group('NostrKeys.loadCachedOnly (audit F-004)', () {
    test('returns null and writes nothing when the cache is empty', () async {
      final keys = await NostrKeys.loadCachedOnly(storage: const FlutterSecureStorage());

      expect(keys, isNull);
      expect(store, isEmpty);
    });

    test('returns null when only the public key is cached (partial state)',
        () async {
      store['nostr_public_key'] = _pubHex;

      final keys = await NostrKeys.loadCachedOnly(storage: const FlutterSecureStorage());

      expect(keys, isNull);
      // Must never derive from an empty seed and overwrite the public key.
      expect(store['nostr_public_key'], _pubHex);
      expect(store.containsKey('nostr_private_key'), isFalse);
    });

    test('returns null when only the private key is cached', () async {
      store['nostr_private_key'] = _privHex;

      final keys = await NostrKeys.loadCachedOnly(storage: const FlutterSecureStorage());

      expect(keys, isNull);
    });

    test('returns the cached keys when both are present, writes nothing',
        () async {
      store['nostr_private_key'] = _privHex;
      store['nostr_public_key'] = _pubHex;

      final keys = await NostrKeys.loadCachedOnly(storage: const FlutterSecureStorage());

      expect(keys, isNotNull);
      expect(keys!.publicKeyHex, _pubHex);
      // Unchanged — loadCachedOnly never writes.
      expect(store, {
        'nostr_private_key': _privHex,
        'nostr_public_key': _pubHex,
      });
    });
  });
}
