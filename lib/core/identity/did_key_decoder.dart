import 'dart:typed_data';

/// Reads the Ed25519 public key back out of a `did:key:z6Mk…` identifier.
///
/// Lives beside [DidKey] instead of inside it: did.dart is frozen
/// (docs/current/DO_NOT_TOUCH.md, Sperrstufe 1), additions go around it.
class DidKeyDecoder {
  DidKeyDecoder._();

  static const _alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  static const _prefix = 'did:key:z';

  /// Returns the 32-byte Ed25519 public key, or null for anything that is
  /// not a well-formed Ed25519 did:key.
  static Uint8List? publicKeyBytes(String did) {
    if (!did.startsWith(_prefix)) return null;
    final decoded = _base58Decode(did.substring(_prefix.length));
    if (decoded == null || decoded.length != 34) return null;
    if (decoded[0] != 0xED || decoded[1] != 0x01) return null;
    return Uint8List.fromList(decoded.sublist(2));
  }

  static List<int>? _base58Decode(String input) {
    if (input.isEmpty) return null;
    int leadingOnes = 0;
    while (leadingOnes < input.length && input[leadingOnes] == '1') {
      leadingOnes++;
    }
    // Little-endian base-256 digits.
    final bytes = <int>[0];
    for (final char in input.split('')) {
      final value = _alphabet.indexOf(char);
      if (value < 0) return null;
      int carry = value;
      for (int i = 0; i < bytes.length; i++) {
        carry += bytes[i] * 58;
        bytes[i] = carry & 0xff;
        carry >>= 8;
      }
      while (carry > 0) {
        bytes.add(carry & 0xff);
        carry >>= 8;
      }
    }
    while (bytes.length > 1 && bytes.last == 0) {
      bytes.removeLast();
    }
    final body = bytes.reversed.toList();
    if (body.length == 1 && body[0] == 0) body.clear();
    return [...List<int>.filled(leadingOnes, 0), ...body];
  }
}
