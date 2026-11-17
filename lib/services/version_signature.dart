import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Verifies that `version.json` was signed by N.E.X.U.S., not by whoever
/// controls the hosting URL (audit TD-61).
///
/// The signature covers the canonical JSON of every field except `sig`
/// itself, so any change to version, notes or download URLs invalidates it.
class VersionSignature {
  VersionSignature._();

  /// Public half of the release signing key (not a secret). The matching
  /// private key is kept outside the repository and used only by
  /// `tool/sign_version_json.dart` when preparing a release.
  static const releasePublicKeyHex =
      'b9ede8964803885ec22ca5a67a03f3d2ec9951ce5ae2a188daebdbe546fc59ac';

  static const _signatureKey = 'sig';

  /// The bytes a signature is computed over: the JSON object without
  /// [_signatureKey], with keys in a fixed (sorted) order so signer and
  /// verifier always hash the same bytes regardless of map iteration order.
  static List<int> canonicalBytes(Map<String, dynamic> data) {
    final withoutSig = Map<String, dynamic>.from(data)
      ..remove(_signatureKey);
    final sortedKeys = withoutSig.keys.toList()..sort();
    final ordered = {for (final k in sortedKeys) k: withoutSig[k]};
    return utf8.encode(jsonEncode(ordered));
  }

  /// Whether [data] carries a valid signature by [releasePublicKeyHex]
  /// (or by [publicKeyHexOverride], used only in tests).
  ///
  /// Returns false (never throws) for missing, malformed or wrong
  /// signatures, so a tampered or unsigned `version.json` is silently
  /// treated as "no update available" rather than crashing the check.
  static Future<bool> isValid(Map<String, dynamic> data,
      {String? publicKeyHexOverride}) async {
    final sig = data[_signatureKey];
    if (sig is! String || sig.isEmpty) return false;
    try {
      final signatureBytes = base64Decode(sig);
      if (signatureBytes.length != 64) return false;
      final publicKeyBytes =
          _hexToBytes(publicKeyHexOverride ?? releasePublicKeyHex);
      return await Ed25519().verify(
        canonicalBytes(data),
        signature: Signature(
          signatureBytes,
          publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
        ),
      );
    } on FormatException {
      return false;
    }
  }

  static List<int> _hexToBytes(String hex) => [
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ];
}
