import '../../core/transport/nexus_message.dart';

/// Longest reaction text accepted from the network (UTF-16 code units).
/// Enough for any emoji sequence, too short for abuse as a message channel.
const int maxReactionLength = 32;

/// Normalizes the content of an incoming Kind-7 event (NIP-25).
///
/// Empty or "+" means a like and becomes 👍; "-" is a dislike, which the
/// app does not display, so it returns null. Oversized texts return null.
String? normalizeReactionContent(String? content) {
  final text = content?.trim() ?? '';
  if (text.isEmpty || text == '+') return '👍';
  if (text == '-') return null;
  if (text.length > maxReactionLength) return null;
  return text;
}

/// Decides who an incoming Kind-7 reaction on [message] is recorded for, or
/// returns null when the signer may not react to it (TD-67).
///
/// - Own key → [myDid], so the reaction counts as mine in the UI.
/// - Direct message → only the conversation partner may react; the signer
///   must be the known Nostr key of that contact.
/// - Channel → anyone may react. Known contacts are recorded by DID, unknown
///   signers by their lowercase Nostr public key (as the Dorfplatz does).
String? resolveReactorId({
  required NexusMessage message,
  required bool isChannel,
  required String signerPubkey,
  required String myDid,
  required String? myNostrPubkey,
  required String? Function(String nostrPubkey) contactDidForNostrPubkey,
}) {
  final signer = signerPubkey.toLowerCase();
  if (signer.isEmpty) return null;
  if (myNostrPubkey != null && myNostrPubkey.toLowerCase() == signer) {
    return myDid;
  }
  final contactDid = contactDidForNostrPubkey(signer);
  if (isChannel) return contactDid ?? signer;

  final partnerDid =
      message.fromDid == myDid ? message.toDid : message.fromDid;
  return contactDid != null && contactDid == partnerDid ? contactDid : null;
}

/// All reactor IDs that [resolveReactorId] may have recorded for
/// [signerPubkey]. A Kind-5 signed by this key may only withdraw reactions
/// stored under one of these IDs (TD-71).
Set<String> reactorIdsForSigner({
  required String signerPubkey,
  required String myDid,
  required String? myNostrPubkey,
  required String? Function(String nostrPubkey) contactDidForNostrPubkey,
}) {
  final signer = signerPubkey.toLowerCase();
  if (signer.isEmpty) return const {};
  final contactDid = contactDidForNostrPubkey(signer);
  return {
    signer,
    if (myNostrPubkey != null && myNostrPubkey.toLowerCase() == signer) myDid,
    if (contactDid != null) contactDid,
  };
}
