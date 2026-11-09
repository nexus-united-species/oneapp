import 'cell_member.dart';
import 'proposal.dart';

/// TD-37: frozen list of eligible voters, set when voting starts.
///
/// The device that starts the vote freezes its confirmed members (founder
/// included) and sends the list with the proposal event. Every device then
/// tallies against the same list instead of its own, possibly different,
/// member list.

/// Confirmed members plus the founder, sorted for a deterministic wire
/// format and decision-record hash.
List<String> buildEligibleVoterSnapshot(
  List<CellMember> members, {
  String? founderDid,
}) {
  final dids = {
    for (final m in members)
      if (m.isConfirmed) m.did,
    if (founderDid != null && founderDid.isNotEmpty) founderDid,
  };
  return dids.toList()..sort();
}

const _votingStates = {
  ProposalStatus.VOTING,
  ProposalStatus.VOTING_ENDED,
};

/// Adopts the snapshot from a received proposal event into [p], once.
///
/// - The first snapshot stays frozen: later events cannot replace it.
/// - Snapshot and start time are taken together from the same event.
/// - Never after this device has tallied ([Proposal.decidedAt] set): the
///   count is part of the decision-record hash.
/// Only events of the creator or a manager reach this with content; TD-40
/// strips other members' events down to the status. Returns true if [p]
/// changed.
bool adoptVotingSnapshot(
  Proposal p,
  ProposalStatus status,
  Map<String, dynamic> content,
) {
  if (!_votingStates.contains(status) ||
      p.decidedAt != null ||
      p.eligibleVoters != null) {
    return false;
  }
  final raw = content['eligibleVoters'];
  if (raw is! List) return false;
  final dids = raw.whereType<String>().toSet().toList()..sort();
  // Reject malformed lists (non-strings, duplicates, empty).
  if (dids.isEmpty || dids.length != raw.length) return false;
  p.eligibleVoters = dids;
  final startedAt = content['votingStartedAt'];
  if (startedAt is int) {
    p.votingStartedAt =
        DateTime.fromMillisecondsSinceEpoch(startedAt * 1000, isUtc: true);
  }
  return true;
}

/// Differences between a received snapshot and the local member list, for
/// diagnosis only: local lists are incomplete (TD-33), so they cannot be
/// used to reject a snapshot without making tallies device-dependent again.
({List<String> missing, List<String> unknown}) snapshotDifferences(
  List<String> snapshot,
  List<CellMember> localMembers, {
  String? founderDid,
}) {
  final local = buildEligibleVoterSnapshot(localMembers, founderDid: founderDid);
  final listed = snapshot.toSet();
  final known = local.toSet();
  return (
    missing: [for (final did in local) if (!listed.contains(did)) did],
    unknown: [for (final did in snapshot) if (!known.contains(did)) did],
  );
}
