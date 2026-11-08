import '../../core/transport/nexus_message.dart';

/// Decides whether a Kind-5 deletion signed by [signerPubkey] may remove
/// [message] (NIP-09: only the author's own key can delete an event).
///
/// The author key is taken, in this order, from:
///   1. the signing key recorded when the message was received
///      ([NexusMessage.nostrAuthorPubkey]),
///   2. the own key, for own messages without that record,
///   3. the contact's known Nostr key, for legacy received messages.
///
/// If none is known, the deletion is refused rather than guessed.
bool isAuthorizedMessageDeleter({
  required NexusMessage message,
  required String signerPubkey,
  required String myDid,
  required String? myNostrPubkey,
  required String? Function(String did) contactNostrPubkey,
}) =>
    isAuthorizedAuthorKey(
      recordedAuthorPubkey: message.nostrAuthorPubkey,
      authorDid: message.fromDid,
      signerPubkey: signerPubkey,
      myDid: myDid,
      myNostrPubkey: myNostrPubkey,
      contactNostrPubkey: contactNostrPubkey,
    );

/// Generic form of [isAuthorizedMessageDeleter] for any authored item
/// (chat message, Dorfplatz post): true only if [signerPubkey] is the
/// author's key, resolved from [recordedAuthorPubkey], the own key or the
/// contact's key for [authorDid].
bool isAuthorizedAuthorKey({
  required String? recordedAuthorPubkey,
  required String authorDid,
  required String signerPubkey,
  required String myDid,
  required String? myNostrPubkey,
  required String? Function(String did) contactNostrPubkey,
}) {
  if (signerPubkey.isEmpty) return false;
  final expected = (recordedAuthorPubkey?.isNotEmpty ?? false)
      ? recordedAuthorPubkey
      : (authorDid == myDid ? myNostrPubkey : null) ??
          contactNostrPubkey(authorDid);
  if (expected == null || expected.isEmpty) return false;
  return expected.toLowerCase() == signerPubkey.toLowerCase();
}
