// One-off helper: generates a new Ed25519 key pair for signing version.json
// (audit TD-61 / Update-Signierung). Run with:
//   dart run tool/generate_release_key.dart
//
// The PRIVATE key must never be committed: copy it straight into the
// release key sicherung (see NEXUS-Schluessel-Sicherung) and discard it
// from the terminal history. The PUBLIC key goes into
// lib/services/version_signature.dart (releasePublicKeyHex).
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final keyPair = await Ed25519().newKeyPair();
  final privateBytes = await keyPair.extractPrivateKeyBytes();
  final publicBytes = (await keyPair.extractPublicKey()).bytes;

  String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  // ignore: avoid_print
  print('PRIVATE_KEY_BASE64 (keep secret, store only in the key sicherung):');
  // ignore: avoid_print
  print(base64.encode(privateBytes));
  // ignore: avoid_print
  print('');
  // ignore: avoid_print
  print('PUBLIC_KEY_HEX (goes into version_signature.dart):');
  // ignore: avoid_print
  print(hex(publicBytes));
}
