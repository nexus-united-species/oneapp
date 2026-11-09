import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/did.dart';
import 'package:nexus_oneapp/core/identity/identity_proof.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';
import 'package:nexus_oneapp/features/governance/cell_member.dart';
import 'package:nexus_oneapp/features/governance/governance_authorization.dart';
import 'package:nexus_oneapp/features/governance/proposal.dart';

typedef _Identity = ({String did, String nostr, Map<String, String> proof});

Future<_Identity> _identity(int seedByte) async {
  final keyPair =
      await Ed25519().newKeyPairFromSeed(List<int>.filled(32, seedByte));
  final did =
      DidKey.fromPublicKeyBytes((await keyPair.extractPublicKey()).bytes);
  final nostr = seedByte.toRadixString(16).padLeft(2, '0') * 32;
  final proof = await IdentityProof.create(
    signingKeyPair: keyPair,
    did: did,
    nostrPubkeyHex: nostr,
  );
  return (did: did, nostr: nostr, proof: proof);
}

CellMember _member(String cellId, String did, MemberRole role) => CellMember(
      cellId: cellId,
      did: did,
      joinedAt: DateTime.utc(2026, 11, 8),
      role: role,
    );

void main() {
  late _Identity founder;
  late _Identity creator;
  late _Identity member;
  late _Identity outsider;
  late Cell cell;
  late List<CellMember> members;
  late Proposal proposal;

  setUpAll(() async {
    founder = await _identity(1);
    creator = await _identity(2);
    member = await _identity(3);
    outsider = await _identity(4);
    cell = Cell.create(
      name: 'Gartenzelle',
      description: 'Test',
      createdBy: founder.did,
      cellType: CellType.thematic,
    );
    members = [
      _member(cell.id, founder.did, MemberRole.founder),
      _member(cell.id, creator.did, MemberRole.member),
      _member(cell.id, member.did, MemberRole.member),
    ];
    proposal = Proposal.create(
      title: 'Hochbeete bauen',
      description: 'Vier Hochbeete am Dorfplatz',
      creatorDid: creator.did,
      creatorPseudonym: 'Antragstellerin',
      cellId: cell.id,
    )..status = ProposalStatus.DISCUSSION;
  });

  // Local clock for the deadline checks; votes below end at 10:00.
  final _now = DateTime.utc(2026, 11, 9, 12);
  final _deadline = DateTime.utc(2026, 11, 9, 10);

  Proposal withStatus(ProposalStatus status, {DateTime? endsAt}) =>
      Proposal.fromMap(proposal.toMap())
        ..status = status
        ..votingEndsAt = endsAt ?? _deadline;

  Map<String, dynamic> contentOf(Proposal p, {String? title}) => {
        'title': title ?? p.title,
        'description': p.description,
        'creatorDid': p.creatorDid,
      };

  Future<GovernanceAuthDecision> proposalEvent(
    _Identity signer, {
    Proposal? existing,
    String status = 'discussion',
    String? title,
    Map<String, String>? proof,
    DateTime? now,
  }) =>
      authorizeProposalEvent(
        existing: existing,
        content: contentOf(proposal, title: title),
        statusTag: status,
        cell: cell,
        members: members,
        now: now ?? _now,
        signerPubkey: signer.nostr,
        idProof: proof ?? signer.proof,
      );

  group('authorizeProposalEvent', () {
    test('accepts a new proposal only from its creator', () async {
      expect(await proposalEvent(creator), GovernanceAuthDecision.allowed);
      expect(await proposalEvent(member), GovernanceAuthDecision.notAuthorized);
    });

    test('rejects events whose proof belongs to another key', () async {
      expect(
        await proposalEvent(member, proof: creator.proof),
        GovernanceAuthDecision.missingProof,
      );
    });

    test('lets only the creator edit or withdraw', () async {
      expect(
        await proposalEvent(creator, existing: proposal, title: 'Neu'),
        GovernanceAuthDecision.allowed,
      );
      expect(
        await proposalEvent(founder, existing: proposal, title: 'Neu'),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await proposalEvent(founder, existing: proposal, status: 'withdrawn'),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('lets creator or founder start voting, not a plain member',
        () async {
      expect(
        await proposalEvent(founder, existing: proposal, status: 'voting'),
        GovernanceAuthDecision.allowed,
      );
      expect(
        await proposalEvent(member, existing: proposal, status: 'voting'),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('accepts deadline status changes from members, not outsiders',
        () async {
      final voting = withStatus(ProposalStatus.VOTING);

      expect(
        await proposalEvent(member, existing: voting, status: 'voting_ended'),
        GovernanceAuthDecision.allowedStatusOnly,
      );
      expect(
        await proposalEvent(outsider, existing: voting, status: 'voting_ended'),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects status jumps by plain members', () async {
      expect(
        await proposalEvent(member, existing: proposal, status: 'decided'),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects new proposals from outsiders, even as creator', () async {
      final outsiderProposal = authorizeProposalEvent(
        existing: null,
        content: {
          'title': 'Fremd',
          'description': 'Von außen',
          'creatorDid': outsider.did,
        },
        statusTag: 'discussion',
        cell: cell,
        members: members,
        now: _now,
        signerPubkey: outsider.nostr,
        idProof: outsider.proof,
      );
      expect(await outsiderProposal, GovernanceAuthDecision.notAuthorized);
    });

    test('nobody ends a vote before the local deadline, not even the creator',
        () async {
      final running = withStatus(ProposalStatus.VOTING,
          endsAt: DateTime.utc(2026, 11, 16, 10));

      for (final signer in [creator, founder, member]) {
        expect(
          await proposalEvent(signer,
              existing: running, status: 'voting_ended'),
          GovernanceAuthDecision.notAuthorized,
          reason: signer == creator
              ? 'creator'
              : signer == founder
                  ? 'founder'
                  : 'member',
        );
      }
    });

    test('a received DECIDED is never applied, only the own tally sets it',
        () async {
      final ended = withStatus(ProposalStatus.VOTING_ENDED);

      expect(await proposalEvent(creator, existing: ended, status: 'decided'),
          GovernanceAuthDecision.notAuthorized);
      expect(await proposalEvent(member, existing: ended, status: 'decided'),
          GovernanceAuthDecision.notAuthorized);
    });

    test('archiving needs an own decision first', () async {
      expect(
        await proposalEvent(member,
            existing: withStatus(ProposalStatus.VOTING_ENDED),
            status: 'archived'),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await proposalEvent(member,
            existing: withStatus(ProposalStatus.DECIDED), status: 'archived'),
        GovernanceAuthDecision.allowedStatusOnly,
      );
    });

    test('a replayed older status never moves a proposal backwards',
        () async {
      // Relays replay the creator's "voting started" event on every start.
      for (final current in [
        ProposalStatus.VOTING_ENDED,
        ProposalStatus.DECIDED,
        ProposalStatus.ARCHIVED,
      ]) {
        expect(
          await proposalEvent(creator,
              existing: withStatus(current), status: 'voting'),
          GovernanceAuthDecision.notAuthorized,
          reason: current.name,
        );
      }
      expect(
        await proposalEvent(creator,
            existing: withStatus(ProposalStatus.VOTING), status: 'discussion'),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('a withdrawn proposal stays withdrawn, a decided one is not withdrawn',
        () async {
      expect(
        await proposalEvent(creator,
            existing: withStatus(ProposalStatus.WITHDRAWN), status: 'voting'),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await proposalEvent(creator,
            existing: withStatus(ProposalStatus.DECIDED), status: 'withdrawn'),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('the creator may still withdraw during a running vote', () async {
      final running = withStatus(ProposalStatus.VOTING,
          endsAt: DateTime.utc(2026, 11, 16, 10));

      expect(
        await proposalEvent(creator, existing: running, status: 'withdrawn'),
        GovernanceAuthDecision.allowed,
      );
    });

    test('rejects a withdrawal for a proposal not seen yet', () async {
      expect(
        await proposalEvent(creator, status: 'withdrawn'),
        GovernanceAuthDecision.notAuthorized,
      );
    });
  });

  group('authorizeVote', () {
    test('accepts a vote signed by the named voter', () async {
      expect(
        await authorizeVote(
          content: {'voterDid': member.did},
          signerPubkey: member.nostr,
          idProof: member.proof,
        ),
        GovernanceAuthDecision.allowed,
      );
    });

    test('rejects a vote cast in someone else\'s name', () async {
      expect(
        await authorizeVote(
          content: {'voterDid': member.did},
          signerPubkey: outsider.nostr,
          idProof: outsider.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await authorizeVote(
          content: {'voterDid': member.did},
          signerPubkey: member.nostr,
          idProof: null,
        ),
        GovernanceAuthDecision.missingProof,
      );
    });
  });

  group('authorizeDelegation', () {
    test('only the delegator may publish their delegation', () async {
      final content = {'delegatorDid': member.did, 'delegateDid': creator.did};

      expect(
        await authorizeDelegation(
          content: content,
          signerPubkey: member.nostr,
          idProof: member.proof,
        ),
        GovernanceAuthDecision.allowed,
      );
      expect(
        await authorizeDelegation(
          content: content,
          signerPubkey: creator.nostr,
          idProof: creator.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });
  });

  group('authorizeDecisionRecord', () {
    final deadline = DateTime.utc(2026, 11, 9, 12);

    Proposal votingProposal({
      String? cellId,
      ProposalStatus status = ProposalStatus.VOTING_ENDED,
      bool hasDeadline = true,
    }) =>
        Proposal.create(
          title: 'Hochbeete bauen',
          description: 'Vier Hochbeete am Dorfplatz',
          creatorDid: creator.did,
          creatorPseudonym: 'Antragstellerin',
          cellId: cellId ?? cell.id,
        )
          ..status = status
          ..votingEndsAt = hasDeadline ? deadline : null
          ..gracePeriodHours = 0;

    Future<GovernanceAuthDecision> record(
      _Identity signer, {
      Proposal? localProposal,
      bool noLocalProposal = false,
      String? cellId,
      DateTime? now,
      Map<String, String>? proof,
      bool knownCell = true,
    }) =>
        authorizeDecisionRecord(
          cellId: cellId ?? cell.id,
          cell: knownCell ? cell : null,
          members: members,
          proposal:
              noLocalProposal ? null : (localProposal ?? votingProposal()),
          now: now ?? deadline.add(const Duration(minutes: 1)),
          signerPubkey: signer.nostr,
          idProof: proof ?? signer.proof,
        );

    test('accepts a record from any proven member after the deadline',
        () async {
      expect(
        await record(member, localProposal: votingProposal()),
        GovernanceAuthDecision.allowed,
      );
      expect(await record(founder), GovernanceAuthDecision.allowed);
    });

    test('rejects outsiders and missing proofs', () async {
      expect(
        await record(outsider, localProposal: votingProposal()),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await record(member, proof: creator.proof),
        GovernanceAuthDecision.missingProof,
      );
    });

    test('rejects a record before the voting deadline', () async {
      expect(
        await record(member,
            localProposal: votingProposal(),
            now: deadline.subtract(const Duration(hours: 1))),
        GovernanceAuthDecision.notAuthorized,
      );
      // Not even shortly before: late votes could still arrive.
      expect(
        await record(member,
            localProposal: votingProposal(status: ProposalStatus.VOTING),
            now: deadline.subtract(const Duration(seconds: 30))),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await record(member,
            localProposal: votingProposal(status: ProposalStatus.VOTING),
            now: deadline),
        GovernanceAuthDecision.allowed,
      );
    });

    test('rejects records for proposals without a running or ended vote',
        () async {
      for (final status in [
        ProposalStatus.DISCUSSION,
        ProposalStatus.WITHDRAWN,
        ProposalStatus.DECIDED,
      ]) {
        expect(
          await record(member, localProposal: votingProposal(status: status)),
          GovernanceAuthDecision.notAuthorized,
          reason: status.name,
        );
      }
      expect(
        await record(member,
            localProposal: votingProposal(hasDeadline: false)),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects a record during the grace period for late votes', () async {
      final withGrace = votingProposal()..gracePeriodHours = 12;

      expect(
        await record(member,
            localProposal: withGrace,
            now: deadline.add(const Duration(hours: 1))),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await record(member,
            localProposal: withGrace,
            now: deadline.add(const Duration(hours: 12, minutes: 1))),
        GovernanceAuthDecision.allowed,
      );
    });

    test('rejects records for proposals not known locally', () async {
      expect(
        await record(member, noLocalProposal: true),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects a record for a proposal of another cell', () async {
      expect(
        await record(member, localProposal: votingProposal(cellId: 'other')),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('ignores records for cells I am not a member of', () async {
      expect(
        await record(member, knownCell: false),
        GovernanceAuthDecision.unknownCell,
      );
    });
  });
}
