import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'did_key_decoder.dart';

/// Signed claim that a Nostr public key belongs to a NEXUS DID (ADR-0001).
///
/// The DID's Ed25519 key signs the domain-separated string
/// `nexus-identity-binding:v1:<did>:<nostrPubkeyHex>`. A receiver that has
/// already verified the Nostr event signature can then trust that the event
/// was published on behalf of that DID.
///
/// The claim carries no timestamp on purpose: it only states key ownership,
/// and replaying it is useless without the matching Nostr private key.
class IdentityProof {
  IdentityProof._();

  /// JSON field name used inside event content.
  static const contentKey = '_idProof';

  static const _domain = 'nexus-identity-binding:v1';

  static List<int> _message(String did, String nostrPubkeyHex) =>
      utf8.encode('$_domain:$did:${nostrPubkeyHex.toLowerCase()}');

  /// Creates a proof binding [nostrPubkeyHex] to [did].
  static Future<Map<String, String>> create({
    required SimpleKeyPair signingKeyPair,
    required String did,
    required String nostrPubkeyHex,
  }) async {
    final signature = await Ed25519().sign(
      _message(did, nostrPubkeyHex),
      keyPair: signingKeyPair,
    );
    return {'did': did, 'sig': base64Encode(signature.bytes)};
  }

  /// Returns the DID proven to own [nostrPubkeyHex], or null when [proof] is
  /// missing, malformed or does not verify.
  static Future<String?> verifiedDid({
    required Object? proof,
    required String nostrPubkeyHex,
  }) async {
    if (proof is! Map) return null;
    final did = proof['did'];
    final sig = proof['sig'];
    if (did is! String || sig is! String) return null;
    final publicKey = DidKeyDecoder.publicKeyBytes(did);
    if (publicKey == null) return null;
    try {
      final signatureBytes = base64Decode(sig);
      if (signatureBytes.length != 64) return null;
      final isValid = await Ed25519().verify(
        _message(did, nostrPubkeyHex),
        signature: Signature(
          signatureBytes,
          publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
        ),
      );
      return isValid ? did : null;
    } on FormatException {
      return null;
    }
  }
}
