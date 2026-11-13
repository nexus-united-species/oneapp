import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/cell_service.dart';
import 'package:nexus_oneapp/features/governance/proposal.dart';
import 'package:nexus_oneapp/features/governance/proposal_service.dart';
import 'package:nexus_oneapp/features/governance/vote.dart';
import 'package:nexus_oneapp/features/governance/vote_dedup.dart';

/// Audit S-2: one member binds several Nostr keys to their DID and votes
/// once per key. Only one vote per DID may count – the newest.
Vote _vote(
  String proposalId,
  String did,
  String pubkey,
  VoteChoice choice,
  DateTime at,
) =>
    Vote(
      voteId: 'vote-$pubkey',
      proposalId: proposalId,
      voterPubkey: pubkey,
      voterDid: did,
      voterPseudonym: did,
      choice: choice,
      createdAt: at,
      nostrEventId: 'event-$pubkey',
    );

void main() {
  final t = DateTime.utc(2026, 11, 8, 12);

  group('latestVotePerDid', () {
    test('keeps only the newest vote of each DID', () {
      final votes = [
        _vote('p', 'did:key:mallory', 'k1', VoteChoice.YES, t),
        _vote('p', 'did:key:mallory', 'k2', VoteChoice.NO,
            t.add(const Duration(minutes: 5))),
        _vote('p', 'did:key:mallory', 'k3', VoteChoice.YES,
            t.add(const Duration(minutes: 1))),
        _vote('p', 'did:key:anna', 'k4', VoteChoice.YES, t),
      ];

      final counted = latestVotePerDid(votes);

      expect(counted, hasLength(2));
      expect(counted.singleWhere((v) => v.voterDid == 'did:key:mallory').choice,
          VoteChoice.NO);
    });

    test('is deterministic for votes with the same time', () {
      final a = _vote('p', 'did:key:m', 'aaa', VoteChoice.YES, t);
      final b = _vote('p', 'did:key:m', 'bbb', VoteChoice.NO, t);

      expect(latestVotePerDid([a, b]).single.voterPubkey,
          latestVotePerDid([b, a]).single.voterPubkey);
    });

    test('keeps the order of the remaining votes', () {
      final votes = [
        _vote('p', 'did:key:a', 'k1', VoteChoice.YES, t),
        _vote('p', 'did:key:b', 'k2', VoteChoice.NO, t),
      ];
      expect(latestVotePerDid(votes).map((v) => v.voterDid),
          ['did:key:a', 'did:key:b']);
    });
  });

  group('ProposalService counts one vote per DID', () {
    late Proposal proposal;

    setUp(() {
      ProposalService.instance.resetForTest();
      CellService.instance.clearForTest();
      proposal = Proposal.create(
        title: 'Hochbeete',
        description: 'Test',
        creatorDid: 'did:key:anna',
        creatorPseudonym: 'Anna',
        cellId: 'cell-1',
      )
        ..status = ProposalStatus.VOTING
        ..votingStartedAt = DateTime.utc(2026, 11, 8, 10);
      ProposalService.instance.injectProposalForTest(proposal);
    });

    tearDown(() {
      ProposalService.instance.resetForTest();
      CellService.instance.clearForTest();
    });

    test('three keys of one member count as one vote', () {
      ProposalService.instance.injectVotesForTest(proposal.id, [
        _vote(proposal.id, 'did:key:mallory', 'k1', VoteChoice.YES, t),
        _vote(proposal.id, 'did:key:mallory', 'k2', VoteChoice.YES,
            t.add(const Duration(minutes: 1))),
        _vote(proposal.id, 'did:key:mallory', 'k3', VoteChoice.YES,
            t.add(const Duration(minutes: 2))),
        _vote(proposal.id, 'did:key:anna', 'k4', VoteChoice.NO, t),
      ]);

      final counted = ProposalService.instance.getCountedVotes(proposal.id);

      expect(counted, hasLength(2));
      expect(counted.where((v) => v.choice == VoteChoice.YES), hasLength(1));
    });
  });
}
