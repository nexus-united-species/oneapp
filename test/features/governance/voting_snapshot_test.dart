import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/cell_member.dart';
import 'package:nexus_oneapp/features/governance/cell_service.dart';
import 'package:nexus_oneapp/features/governance/proposal.dart';
import 'package:nexus_oneapp/features/governance/proposal_service.dart';
import 'package:nexus_oneapp/features/governance/vote.dart';
import 'package:nexus_oneapp/features/governance/voting_snapshot.dart';

CellMember _member(String did, MemberRole role) => CellMember(
      cellId: 'cell-1',
      did: did,
      joinedAt: DateTime.utc(2026, 11, 1),
      role: role,
    );

Proposal _proposal() => Proposal.create(
      title: 'Hochbeete',
      description: 'Test',
      creatorDid: 'did:key:founder',
      creatorPseudonym: 'Gründerin',
      cellId: 'cell-1',
    );

Vote _vote(String proposalId, String did) => Vote(
      voteId: 'vote-$did',
      proposalId: proposalId,
      voterPubkey: 'pub-$did',
      voterDid: did,
      voterPseudonym: did,
      choice: VoteChoice.YES,
      createdAt: DateTime.utc(2026, 11, 9, 12),
      nostrEventId: 'event-$did',
    );

void main() {
  group('buildEligibleVoterSnapshot', () {
    test('takes confirmed members and the founder, sorted, without pending',
        () {
      final snapshot = buildEligibleVoterSnapshot(
        [
          _member('did:key:c', MemberRole.member),
          _member('did:key:a', MemberRole.moderator),
          _member('did:key:pending', MemberRole.pending),
        ],
        founderDid: 'did:key:b',
      );

      expect(snapshot, ['did:key:a', 'did:key:b', 'did:key:c']);
    });

    test('does not list the founder twice', () {
      final snapshot = buildEligibleVoterSnapshot(
        [_member('did:key:founder', MemberRole.founder)],
        founderDid: 'did:key:founder',
      );

      expect(snapshot, ['did:key:founder']);
    });
  });

  group('adoptVotingSnapshot', () {
    test('adopts snapshot and start time with a voting event', () {
      final p = _proposal();

      final changed = adoptVotingSnapshot(p, ProposalStatus.VOTING, {
        'eligibleVoters': ['did:key:b', 'did:key:a'],
        'votingStartedAt': 1794222000,
      });

      expect(changed, isTrue);
      expect(p.eligibleVoters, ['did:key:a', 'did:key:b']);
      expect(p.votingStartedAt,
          DateTime.fromMillisecondsSinceEpoch(1794222000 * 1000, isUtc: true));
    });

    test('keeps the first snapshot frozen', () {
      final p = _proposal()..eligibleVoters = ['did:key:a'];

      adoptVotingSnapshot(p, ProposalStatus.VOTING_ENDED, {
        'eligibleVoters': ['did:key:a', 'did:key:intruder'],
      });

      expect(p.eligibleVoters, ['did:key:a']);
    });

    test('ignores snapshots outside a vote', () {
      for (final status in [
        ProposalStatus.DISCUSSION,
        ProposalStatus.DECIDED,
      ]) {
        final p = _proposal();
        expect(
          adoptVotingSnapshot(p, status, {
            'eligibleVoters': ['did:key:a'],
          }),
          isFalse,
          reason: status.name,
        );
        expect(p.eligibleVoters, isNull);
      }
    });

    test('ignores a late snapshot after this device has tallied', () {
      final p = _proposal()..decidedAt = DateTime.utc(2026, 11, 9, 12);

      adoptVotingSnapshot(p, ProposalStatus.VOTING_ENDED, {
        'eligibleVoters': ['did:key:a'],
      });

      expect(p.eligibleVoters, isNull);
    });

    test('takes the start time only together with a snapshot', () {
      final p = _proposal();

      adoptVotingSnapshot(p, ProposalStatus.VOTING, {
        'votingStartedAt': 1794222000,
      });

      expect(p.votingStartedAt, isNull);
    });

    test('rejects malformed lists', () {
      for (final raw in [
        <Object>[],
        ['did:key:a', 'did:key:a'],
        ['did:key:a', 42],
        'did:key:a',
      ]) {
        final p = _proposal();
        adoptVotingSnapshot(p, ProposalStatus.VOTING, {'eligibleVoters': raw});
        expect(p.eligibleVoters, isNull, reason: '$raw');
      }
    });
  });

  group('snapshotDifferences', () {
    test('lists local members missing from the snapshot and unknown DIDs', () {
      final diff = snapshotDifferences(
        ['did:key:founder', 'did:key:stranger'],
        [
          _member('did:key:founder', MemberRole.founder),
          _member('did:key:member', MemberRole.member),
        ],
        founderDid: 'did:key:founder',
      );

      expect(diff.missing, ['did:key:member']);
      expect(diff.unknown, ['did:key:stranger']);
    });
  });

  group('counting with a snapshot', () {
    late Proposal proposal;

    setUp(() {
      ProposalService.instance.resetForTest();
      CellService.instance.clearForTest();
      proposal = _proposal()
        ..status = ProposalStatus.VOTING
        ..votingStartedAt = DateTime.utc(2026, 11, 9, 10);
      ProposalService.instance.injectProposalForTest(proposal);
      ProposalService.instance.injectVotesForTest(proposal.id, [
        _vote(proposal.id, 'did:key:founder'),
        _vote(proposal.id, 'did:key:late-joiner'),
      ]);
    });

    tearDown(() {
      ProposalService.instance.resetForTest();
      CellService.instance.clearForTest();
    });

    test('drops votes of people not on the snapshot', () {
      proposal.eligibleVoters = ['did:key:founder', 'did:key:member'];

      final counted = ProposalService.instance.getCountedVotes(proposal.id);

      expect(counted.map((v) => v.voterDid), ['did:key:founder']);
    });

    test('counts every vote for legacy proposals without a snapshot', () {
      expect(ProposalService.instance.getCountedVotes(proposal.id),
          hasLength(2));
    });
  });
}
