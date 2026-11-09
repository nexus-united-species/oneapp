import '../../core/identity/identity_proof.dart';
import 'cell.dart';
import 'cell_member.dart';
import 'proposal.dart';

/// Result of authorizing a received governance event (TD-40).
enum GovernanceAuthDecision {
  allowed,

  /// Only the status transition may be applied; content, options, category
  /// and deadline from the event must be ignored.
  allowedStatusOnly,

  /// First discovery of a cell announced by an older app version without
  /// identity proof. Shown, but its founder claim is unverified.
  allowedLegacyDiscovery,
  unknownCell,
  missingProof,
  notAuthorized,
}

Future<String?> _provenDid(String signerPubkey, Object? idProof) =>
    IdentityProof.verifiedDid(proof: idProof, nostrPubkeyHex: signerPubkey);

/// Only the founder (`cell.createdBy`) may dissolve a locally known cell.
Future<GovernanceAuthDecision> authorizeCellDissolution({
  required Cell? cell,
  required String signerPubkey,
  required Object? idProof,
}) async {
  if (cell == null) return GovernanceAuthDecision.unknownCell;
  final did = await _provenDid(signerPubkey, idProof);
  if (did == null) return GovernanceAuthDecision.missingProof;
  return did == cell.createdBy
      ? GovernanceAuthDecision.allowed
      : GovernanceAuthDecision.notAuthorized;
}

/// A cell announcement (discovery or rename) must come from the founder.
/// Exception: first discovery without any proof (older app versions).
///
/// For a cell already known locally ([existing]) the founder is taken from
/// the local record and may not be changed by the announcement.
Future<GovernanceAuthDecision> authorizeCellAnnouncement({
  required Cell? existing,
  required Cell incoming,
  required String signerPubkey,
  required Object? idProof,
}) async {
  if (existing != null && existing.createdBy != incoming.createdBy) {
    return GovernanceAuthDecision.notAuthorized;
  }
  if (existing == null && idProof == null) {
    // Older app versions send no proof. Allow plain discovery only; every
    // later change to the cell needs the founder's proof.
    return GovernanceAuthDecision.allowedLegacyDiscovery;
  }
  final did = await _provenDid(signerPubkey, idProof);
  if (did == null) return GovernanceAuthDecision.missingProof;
  return did == incoming.createdBy
      ? GovernanceAuthDecision.allowed
      : GovernanceAuthDecision.notAuthorized;
}

/// Kind-31005 member updates:
/// - `left`: only the member themself.
/// - `joined` / `removed`: the founder or a locally known moderator.
///   The founder can never be removed.
Future<GovernanceAuthDecision> authorizeMemberUpdate({
  required Cell? cell,
  required List<CellMember> members,
  required String action,
  required String targetDid,
  required String signerPubkey,
  required Object? idProof,
}) async {
  if (cell == null) return GovernanceAuthDecision.unknownCell;
  final did = await _provenDid(signerPubkey, idProof);
  if (did == null) return GovernanceAuthDecision.missingProof;
  if (action == 'left') {
    return did == targetDid
        ? GovernanceAuthDecision.allowed
        : GovernanceAuthDecision.notAuthorized;
  }
  if (action == 'removed' && targetDid == cell.createdBy) {
    return GovernanceAuthDecision.notAuthorized;
  }
  if (did == cell.createdBy) return GovernanceAuthDecision.allowed;
  final signer = members.where((m) => m.did == did).firstOrNull;
  if (signer == null || !signer.canManageRequests) {
    return GovernanceAuthDecision.notAuthorized;
  }
  // Moderators may not remove other moderators (as in CellService).
  final target = members.where((m) => m.did == targetDid).firstOrNull;
  if (action == 'removed' && target?.role == MemberRole.moderator) {
    return GovernanceAuthDecision.notAuthorized;
  }
  return GovernanceAuthDecision.allowed;
}

/// Kind-31004 membership confirmations, received by the applicant.
///
/// - Only for a cell I know, am not yet a member of, and have a pending
///   join request for (replays cannot overwrite an existing membership).
/// - The confirmation must name me as a plain member of that cell.
/// - The founder may never change: the cell in the payload must keep the
///   founder of the locally known cell.
/// - The signer must prove the DID given as `confirmedBy`, and that DID must
///   be the founder or a moderator known locally. An applicant does not
///   know the moderators of a cell yet, so in practice the founder confirms.
Future<GovernanceAuthDecision> authorizeMembershipConfirmation({
  required Cell? knownCell,
  required List<CellMember> knownMembers,
  required Cell payloadCell,
  required CellMember member,
  required String myDid,
  required bool isAlreadyMember,
  required bool hasPendingRequest,
  required String signerPubkey,
  required Object? idProof,
}) async {
  if (knownCell == null) return GovernanceAuthDecision.unknownCell;
  final isWellFormed = myDid.isNotEmpty &&
      member.did == myDid &&
      member.cellId == knownCell.id &&
      payloadCell.id == knownCell.id &&
      payloadCell.createdBy == knownCell.createdBy &&
      member.role == MemberRole.member;
  if (!isWellFormed || isAlreadyMember || !hasPendingRequest) {
    return GovernanceAuthDecision.notAuthorized;
  }
  final did = await _provenDid(signerPubkey, idProof);
  if (did == null) return GovernanceAuthDecision.missingProof;
  final isApprover = did != myDid && _isManager(did, knownCell, knownMembers);
  return isApprover && did == member.confirmedBy
      ? GovernanceAuthDecision.allowed
      : GovernanceAuthDecision.notAuthorized;
}

bool _isManager(String did, Cell? cell, List<CellMember> members) =>
    (cell != null && did == cell.createdBy) ||
    members.any((m) => m.did == did && m.canManageRequests);

bool _isMember(String did, Cell? cell, List<CellMember> members) =>
    _isManager(did, cell, members) || members.any((m) => m.did == did);

/// Status transitions every member's device performs on its own when a
/// deadline passes (ProposalScheduler).
const _automaticTransitions = {
  ProposalStatus.VOTING: ProposalStatus.VOTING_ENDED,
  ProposalStatus.VOTING_ENDED: ProposalStatus.DECIDED,
  ProposalStatus.DECIDED: ProposalStatus.ARCHIVED,
};

/// Kind-31010 proposal events.
///
/// - New proposal: only its creator, who must be a known cell member.
/// - Creator: everything (edit, withdraw, status).
/// - Founder/moderator: may start voting (as in the UI).
/// - Any other known member: only the automatic deadline transitions, and
///   only as a status change ([GovernanceAuthDecision.allowedStatusOnly]).
Future<GovernanceAuthDecision> authorizeProposalEvent({
  required Proposal? existing,
  required Map<String, dynamic> content,
  required String? statusTag,
  required Cell? cell,
  required List<CellMember> members,
  required String signerPubkey,
  required Object? idProof,
}) async {
  final did = await _provenDid(signerPubkey, idProof);
  if (did == null) return GovernanceAuthDecision.missingProof;
  final status = ProposalStatus.values
      .where((s) => s.name == (statusTag ?? '').toUpperCase())
      .firstOrNull;

  if (existing == null) {
    final isValidNew = did == content['creatorDid'] &&
        _isMember(did, cell, members) &&
        status != ProposalStatus.WITHDRAWN;
    return isValidNew
        ? GovernanceAuthDecision.allowed
        : GovernanceAuthDecision.notAuthorized;
  }

  if (did == existing.creatorDid) return GovernanceAuthDecision.allowed;

  final title = content['title'] as String? ?? existing.title;
  final description = content['description'] as String? ?? existing.description;
  if (title != existing.title || description != existing.description) {
    return GovernanceAuthDecision.notAuthorized;
  }
  if (status == ProposalStatus.VOTING &&
      existing.status == ProposalStatus.DISCUSSION &&
      _isManager(did, cell, members)) {
    return GovernanceAuthDecision.allowed;
  }
  final isAutomatic = status == existing.status ||
      (status != null && _automaticTransitions[existing.status] == status);
  return isAutomatic && _isMember(did, cell, members)
      ? GovernanceAuthDecision.allowedStatusOnly
      : GovernanceAuthDecision.notAuthorized;
}

/// Kind-31011 votes: the signer must be the voter named in the content.
Future<GovernanceAuthDecision> authorizeVote({
  required Map<String, dynamic> content,
  required String signerPubkey,
  required Object? idProof,
}) async {
  final did = await _provenDid(signerPubkey, idProof);
  if (did == null) return GovernanceAuthDecision.missingProof;
  return did == content['voterDid']
      ? GovernanceAuthDecision.allowed
      : GovernanceAuthDecision.notAuthorized;
}

/// Kind-31013 decision records. Every member device tallies on its own and
/// publishes the same record, so any proven member of the cell may send one.
/// - The proposal must be known locally and belong to the cell named in the
///   event. An unknown proposal is tallied locally once it arrives (a stored
///   record would make the device skip its own tally).
/// - Only for a running or ended vote whose deadline and grace period have
///   passed (an early "result" would cut off votes on receivers).
/// The record's content is not re-checked here; that is the hash check of
/// TD-41.
Future<GovernanceAuthDecision> authorizeDecisionRecord({
  required String cellId,
  required Cell? cell,
  required List<CellMember> members,
  required Proposal? proposal,
  required DateTime now,
  required String signerPubkey,
  required Object? idProof,
}) async {
  if (cell == null || cell.id != cellId) {
    return GovernanceAuthDecision.unknownCell;
  }
  // TD-41: not before the grace period for late votes has ended either;
  // devices tally only then (ProposalScheduler).
  final endsAt = proposal == null
      ? null
      : proposal.votingEndsAt
          ?.add(Duration(hours: proposal.gracePeriodHours));
  final isDue = proposal != null &&
      proposal.cellId == cellId &&
      (proposal.status == ProposalStatus.VOTING ||
          proposal.status == ProposalStatus.VOTING_ENDED) &&
      // No skew allowance: the deadline is this device's own, and an early
      // record would trigger the tally before late votes arrived.
      endsAt != null &&
      !now.isBefore(endsAt);
  if (!isDue) return GovernanceAuthDecision.notAuthorized;
  final did = await _provenDid(signerPubkey, idProof);
  if (did == null) return GovernanceAuthDecision.missingProof;
  return _isMember(did, cell, members)
      ? GovernanceAuthDecision.allowed
      : GovernanceAuthDecision.notAuthorized;
}

/// Kind-31012 delegations: only the delegator creates, revokes or
/// supersedes their own delegation.
Future<GovernanceAuthDecision> authorizeDelegation({
  required Map<String, dynamic> content,
  required String signerPubkey,
  required Object? idProof,
}) async {
  final did = await _provenDid(signerPubkey, idProof);
  if (did == null) return GovernanceAuthDecision.missingProof;
  return did == content['delegatorDid']
      ? GovernanceAuthDecision.allowed
      : GovernanceAuthDecision.notAuthorized;
}
