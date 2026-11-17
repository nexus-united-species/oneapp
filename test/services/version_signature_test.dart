import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/services/version_signature.dart';

/// Signs [data] with a fresh key pair, returning the signed map and the
/// hex public key, independent of the real release key (audit TD-61).
Future<(Map<String, dynamic>, String)> _signedWith(
    SimpleKeyPair keyPair, Map<String, dynamic> data) async {
  final signature = await Ed25519()
      .sign(VersionSignature.canonicalBytes(data), keyPair: keyPair);
  final publicKey = await keyPair.extractPublicKey();
  final hex =
      publicKey.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return ({...data, 'sig': base64Encode(signature.bytes)}, hex);
}

void main() {
  const payload = {
    'version': '0.3.0',
    'version_code': 13,
    'apk_url': 'https://example.org/app.apk',
  };

  group('VersionSignature.isValid (audit TD-61)', () {
    test('accepts a version.json actually signed with tool/sign_version_json.dart',
        () async {
      // Produced by: dart run tool/sign_version_json.dart with the real
      // release private key, over exactly this payload. If this ever
      // fails, releasePublicKeyHex and the key sicherung have drifted apart.
      final signed = {
        ...payload,
        'sig':
            'D7gmJ8sd3xu6Kt7C0o7cO1ZEWLKWJdEUmjo97RJh3WA+3KU0yguLAyotky/do842'
                'DQOUYVC1Q5wcTeY8QA72Dw==',
      };

      expect(await VersionSignature.isValid(signed), isTrue);
    });

    test('a payload signed with any other key is rejected', () async {
      final keyPair = await Ed25519().newKeyPair();
      final (signed, _) = await _signedWith(keyPair, payload);

      // isValid checks only against the hardcoded release key; a different
      // (even validly formed) signature must not pass.
      expect(await VersionSignature.isValid(signed), isFalse);
    });

    test('an unsigned version.json is rejected, never crashes', () async {
      expect(await VersionSignature.isValid(payload), isFalse);
    });

    test('a changed field after signing invalidates the signature',
        () async {
      final keyPair = await Ed25519().newKeyPair();
      final (signed, _) = await _signedWith(keyPair, payload);
      final tampered = {...signed, 'apk_url': 'https://evil.example/app.apk'};

      expect(await VersionSignature.isValid(tampered), isFalse);
    });

    test('malformed signature values are rejected, not thrown', () async {
      expect(await VersionSignature.isValid({...payload, 'sig': ''}), isFalse);
      expect(
          await VersionSignature.isValid({...payload, 'sig': 'not base64!!'}),
          isFalse);
      expect(await VersionSignature.isValid({...payload, 'sig': 42}), isFalse);
    });

    test('canonicalBytes is independent of key order', () {
      final a = VersionSignature.canonicalBytes({'b': 2, 'a': 1, 'sig': 'x'});
      final b = VersionSignature.canonicalBytes({'a': 1, 'sig': 'y', 'b': 2});
      expect(a, b);
    });
  });
}
