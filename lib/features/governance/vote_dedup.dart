import 'vote.dart';

/// One vote per person (audit S-2).
///
/// Votes are authorized per DID, but stored and replaced per Nostr key. A
/// member who binds several Nostr keys to their DID could otherwise vote
/// once per key. Keeps the newest vote of each DID (ties broken by the
/// Nostr key, so every device picks the same one) and preserves the order
/// of the kept votes.
List<Vote> latestVotePerDid(List<Vote> votes) {
  final newest = <String, Vote>{};
  for (final v in votes) {
    final current = newest[v.voterDid];
    if (current == null || _isNewer(v, current)) newest[v.voterDid] = v;
  }
  if (newest.length == votes.length) return votes;
  return [
    for (final v in votes)
      if (identical(newest[v.voterDid], v)) v,
  ];
}

bool _isNewer(Vote a, Vote b) {
  final byTime = a.createdAt.compareTo(b.createdAt);
  if (byTime != 0) return byTime > 0;
  return a.voterPubkey.compareTo(b.voterPubkey) > 0;
}
