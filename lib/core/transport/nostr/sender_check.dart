import '../../identity/identity_proof.dart';

/// Outcome of checking who really sent a chat message (audit S-1).
enum SenderCheck {
  /// The sender proved that its DID owns the signing Nostr key.
  verified,

  /// No proof attached (older app versions). Accepted during the transition
  /// period and shown with a hint; may not replace a known key.
  unverified,

  /// The proof does not match, or the message claims the DID of a known
  /// contact while being signed by another key. Must be discarded.
  forged,
}

/// Decides how far a received message may be trusted.
///
/// [signerPubkey] is the key that signed the Nostr event (already verified
/// by the relay layer), [claimedDid] the sender DID inside the message, and
/// [knownPubkey] the Nostr key already known for that DID, if any.
Future<SenderCheck> checkSender({
  required Object? proof,
  required String signerPubkey,
  required String claimedDid,
  String? knownPubkey,
}) async {
  if (proof != null) {
    final provenDid = await IdentityProof.verifiedDid(
      proof: proof,
      nostrPubkeyHex: signerPubkey,
    );
    return provenDid != null && provenDid == claimedDid
        ? SenderCheck.verified
        : SenderCheck.forged;
  }
  if (knownPubkey != null && knownPubkey != signerPubkey) {
    return SenderCheck.forged;
  }
  return SenderCheck.unverified;
}
