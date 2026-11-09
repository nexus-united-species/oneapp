import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/cell_service.dart';
import 'package:nexus_oneapp/features/governance/proposal.dart';
import 'package:nexus_oneapp/features/governance/proposal_service.dart';
import 'package:nexus_oneapp/features/governance/vote.dart';

Vote _vote(String proposalId, String did) => Vote(
      voteId: 'vote-$did',
      proposalId: proposalId,
      voterPubkey: 'pub-$did',
      voterDid: did,
      voterPseudonym: did,
      choice: VoteChoice.YES,
      createdAt: DateTime.utc(2026, 11, 8, 12),
      nostrEventId: 'event-$did',
    );

void main() {
  final votingStart = DateTime.utc(2026, 11, 8, 10);
  late Proposal proposal;

  setUp(() {
    ProposalService.instance.resetForTest();
    CellService.instance.clearForTest();
    proposal = Proposal.create(
      title: 'Hochbeete',
      description: 'Test',
      creatorDid: 'did:key:founder',
      creatorPseudonym: 'Gründerin',
      cellId: 'cell-1',
    )
      ..status = ProposalStatus.VOTING
      ..votingStartedAt = votingStart;
    ProposalService.instance.injectProposalForTest(proposal);
    ProposalService.instance.injectVotesForTest(proposal.id, [
      _vote(proposal.id, 'did:key:founder'),
      _vote(proposal.id, 'did:key:member'),
    ]);
  });

  tearDown(() {
    ProposalService.instance.resetForTest();
    CellService.instance.clearForTest();
  });

  test('counts all votes while nobody has left', () {
    expect(ProposalService.instance.getCountedVotes(proposal.id), hasLength(2));
  });

  test('drops the vote of a member who left after voting started', () {
    CellService.instance.setDepartureForTest('cell-1', 'did:key:member',
        votingStart.add(const Duration(hours: 1)).millisecondsSinceEpoch);

    final counted = ProposalService.instance.getCountedVotes(proposal.id);

    expect(counted.map((v) => v.voterDid), ['did:key:founder']);
    expect(ProposalService.instance.getVotes(proposal.id), hasLength(2),
        reason: 'stored votes stay untouched; only counting changes');
  });

  test('keeps the vote of someone who left and rejoined before the start',
      () {
    CellService.instance.setDepartureForTest('cell-1', 'did:key:member',
        votingStart.subtract(const Duration(days: 1)).millisecondsSinceEpoch);

    expect(ProposalService.instance.getCountedVotes(proposal.id), hasLength(2));
  });

  test('ignores departures recorded for another cell', () {
    CellService.instance.setDepartureForTest('cell-2', 'did:key:member',
        votingStart.add(const Duration(hours: 1)).millisecondsSinceEpoch);

    expect(ProposalService.instance.getCountedVotes(proposal.id), hasLength(2));
  });
}
