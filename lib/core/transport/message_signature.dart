import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../identity/did_key_decoder.dart';
import 'nexus_message.dart';

/// Whether [message] carries a valid Ed25519 signature by the key of its
/// sender DID (audit S-3).
///
/// Every outgoing message is signed by [TransportManager] over
/// [NexusMessage.toSignableBytes]; `did:key` DIDs contain the public key,
/// so the check needs no further lookup. Used for LAN and BLE, where no
/// Nostr event signature binds the sender.
Future<bool> hasValidSenderSignature(NexusMessage message) async {
  final signature = message.signature;
  if (signature == null || signature.isEmpty) return false;
  final publicKey = DidKeyDecoder.publicKeyBytes(message.fromDid);
  if (publicKey == null) return false;
  try {
    final signatureBytes = base64Decode(signature);
    if (signatureBytes.length != 64) return false;
    return await Ed25519().verify(
      message.toSignableBytes(),
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
  } on FormatException {
    return false;
  }
}
