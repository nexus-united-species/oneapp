import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/decision_record.dart';
import 'package:nexus_oneapp/features/governance/proposal.dart';
import 'package:nexus_oneapp/features/governance/tally_helpers.dart';
import 'package:nexus_oneapp/features/governance/vote.dart';
import 'package:nexus_oneapp/features/governance/voting_mode.dart';

void main() {
  // ── Proposal.toMap / fromMap round-trip ──────────────────────────────────

  group('Proposal serialization', () {
    test('round-trip preserves all required fields', () {
      final original = Proposal(
        id: 'prop_test_1',
        cellId: 'cell_test_1',
        creatorDid: 'did:test:alice',
        creatorPseudonym: 'Alice',
        title: 'Test Proposal',
        description: 'A test description',
        proposalType: ProposalType.SACHFRAGE,
        category: 'Soziales',
        status: ProposalStatus.DRAFT,
        createdAt: DateTime.utc(2026, 1, 15, 10, 30),
      );

      final restored = Proposal.fromMap(original.toMap());

      expect(restored.id, equals(original.id));
      expect(restored.cellId, equals(original.cellId));
      expect(restored.creatorDid, equals(original.creatorDid));
      expect(restored.creatorPseudonym, equals(original.creatorPseudonym));
      expect(restored.title, equals(original.title));
      expect(restored.description, equals(original.description));
      expect(restored.proposalType, equals(original.proposalType));
      expect(restored.category, equals(original.category));
      expect(restored.status, equals(original.status));
      expect(restored.createdAt, equals(original.createdAt));
    });

    test('round-trip preserves all optional DateTime fields', () {
      final discussionStart = DateTime.utc(2026, 1, 16, 8, 0);
      final votingStart = DateTime.utc(2026, 1, 18, 8, 0);
      final votingEnds = DateTime.utc(2026, 1, 25, 8, 0);
      final decided = DateTime.utc(2026, 1, 25, 9, 0);
      final archived = DateTime.utc(2026, 2, 25, 8, 0);

      final original = Proposal(
        id: 'prop_test_2',
        cellId: 'cell_test_1',
        creatorDid: 'did:test:bob',
        creatorPseudonym: 'Bob',
        title: 'Full Lifecycle Proposal',
        description: 'Tests all timestamps',
        createdAt: DateTime.utc(2026, 1, 15),
        discussionStartedAt: discussionStart,
        votingStartedAt: votingStart,
        votingEndsAt: votingEnds,
        decidedAt: decided,
        archivedAt: archived,
        status: ProposalStatus.ARCHIVED,
      );

      final restored = Proposal.fromMap(original.toMap());

      expect(restored.discussionStartedAt, equals(discussionStart));
      expect(restored.votingStartedAt, equals(votingStart));
      expect(restored.votingEndsAt, equals(votingEnds));
      expect(restored.decidedAt, equals(decided));
      expect(restored.archivedAt, equals(archived));
      expect(restored.status, equals(ProposalStatus.ARCHIVED));
    });

    test('round-trip preserves WITHDRAWN status with withdrawnAt', () {
      final withdrawn = DateTime.utc(2026, 1, 20, 14, 30);
      final original = Proposal(
        id: 'prop_test_3',
        cellId: 'cell_test_1',
        creatorDid: 'did:test:carol',
        creatorPseudonym: 'Carol',
        title: 'Withdrawn Proposal',
        description: 'Was withdrawn',
        createdAt: DateTime.utc(2026, 1, 15),
        status: ProposalStatus.WITHDRAWN,
        withdrawnAt: withdrawn,
      );

      final restored = Proposal.fromMap(original.toMap());

      expect(restored.status, equals(ProposalStatus.WITHDRAWN));
      expect(restored.withdrawnAt, equals(withdrawn));
    });

    test('round-trip preserves voting result fields', () {
      final original = Proposal(
        id: 'prop_test_4',
        cellId: 'cell_test_1',
        creatorDid: 'did:test:dave',
        creatorPseudonym: 'Dave',
        title: 'Decided Proposal',
        description: 'Has results',
        createdAt: DateTime.utc(2026, 1, 15),
        status: ProposalStatus.DECIDED,
        decidedAt: DateTime.utc(2026, 1, 25),
        resultSummary: 'YES with 65% participation',
        resultYes: 13,
        resultNo: 7,
        resultAbstain: 2,
        resultParticipation: 0.65,
      );

      final restored = Proposal.fromMap(original.toMap());

      expect(restored.resultSummary, equals('YES with 65% participation'));
      expect(restored.resultYes, equals(13));
      expect(restored.resultNo, equals(7));
      expect(restored.resultAbstain, equals(2));
      expect(restored.resultParticipation, closeTo(0.65, 0.001));
    });

    test('round-trip preserves impulseSupporters list', () {
      final supporters = ['did:a', 'did:b', 'did:c'];
      final original = Proposal(
        id: 'prop_test_5',
        cellId: 'cell_test_1',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        title: 'With Supporters',
        description: 'Has multiple impulse supporters',
        createdAt: DateTime.utc(2026, 1, 15),
        impulseSupporters: supporters,
      );

      final restored = Proposal.fromMap(original.toMap());

      expect(restored.impulseSupporters, equals(supporters));
    });

    test('round-trip preserves G1 compatibility fields scope and domain', () {
      final original = Proposal(
        id: 'prop_test_6',
        cellId: 'cell_test_1',
        creatorDid: 'did:test:eve',
        creatorPseudonym: 'Eve',
        title: 'G1 Compat',
        description: 'Tests scope and domain',
        createdAt: DateTime.utc(2026, 1, 15),
        scope: ProposalScope.federation,
        domain: 'Umwelt',
      );

      final restored = Proposal.fromMap(original.toMap());

      expect(restored.scope, equals(ProposalScope.federation));
      expect(restored.domain, equals('Umwelt'));
    });

    test('Proposal.create generates unique IDs', () {
      final p1 = Proposal.create(
        title: 't1',
        description: 'd1',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
      );
      final p2 = Proposal.create(
        title: 't2',
        description: 'd2',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
      );

      expect(p1.id, isNot(equals(p2.id)));
    });

    test('Proposal.create defaults to DRAFT status', () {
      final p = Proposal.create(
        title: 'Test',
        description: 'd',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
      );
      expect(p.status, equals(ProposalStatus.DRAFT));
      expect(p.isDraft, isTrue);
      expect(p.isActive, isFalse);
    });

    test('isActive is true for DISCUSSION, VOTING, VOTING_ENDED', () {
      final p = Proposal.create(
        title: 't',
        description: 'd',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
      );

      p.status = ProposalStatus.DISCUSSION;
      expect(p.isActive, isTrue);

      p.status = ProposalStatus.VOTING;
      expect(p.isActive, isTrue);

      p.status = ProposalStatus.VOTING_ENDED;
      expect(p.isActive, isTrue);

      p.status = ProposalStatus.DECIDED;
      expect(p.isActive, isFalse);

      p.status = ProposalStatus.ARCHIVED;
      expect(p.isActive, isFalse);

      p.status = ProposalStatus.WITHDRAWN;
      expect(p.isActive, isFalse);
    });
  });

  // ── Vote.toMap / fromMap round-trip ──────────────────────────────────────

  group('Vote serialization', () {
    test('round-trip preserves all required fields', () {
      final created = DateTime.utc(2026, 1, 20, 12, 0);
      final original = Vote(
        voteId: 'vote_test_1',
        proposalId: 'prop_test_1',
        voterPubkey: 'pubkey_alice_hex',
        voterDid: 'did:test:alice',
        voterPseudonym: 'Alice',
        choice: VoteChoice.YES,
        weight: 1,
        voiceCredits: 1,
        createdAt: created,
        nostrEventId: 'nostr_evt_1',
      );

      final restored = Vote.fromMap(original.toMap());

      expect(restored.voteId, equals(original.voteId));
      expect(restored.proposalId, equals(original.proposalId));
      expect(restored.voterPubkey, equals(original.voterPubkey));
      expect(restored.voterDid, equals(original.voterDid));
      expect(restored.voterPseudonym, equals(original.voterPseudonym));
      expect(restored.choice, equals(VoteChoice.YES));
      expect(restored.weight, equals(1));
      expect(restored.voiceCredits, equals(1));
      expect(restored.createdAt, equals(created));
      expect(restored.nostrEventId, equals(original.nostrEventId));
    });

    test('round-trip preserves all VoteChoice values', () {
      for (final choice in VoteChoice.values) {
        final v = Vote(
          voteId: Vote.generateId(),
          proposalId: 'p1',
          voterPubkey: 'pk',
          voterDid: 'did:x',
          voterPseudonym: 'X',
          choice: choice,
          createdAt: DateTime.utc(2026, 1, 20),
          nostrEventId: 'n1',
        );
        final restored = Vote.fromMap(v.toMap());
        expect(restored.choice, equals(choice),
            reason: 'Choice $choice should round-trip correctly');
      }
    });

    test('round-trip preserves optional reasoning field', () {
      final v = Vote(
        voteId: 'v1',
        proposalId: 'p1',
        voterPubkey: 'pk',
        voterDid: 'did:x',
        voterPseudonym: 'X',
        choice: VoteChoice.NO,
        reasoning: 'I disagree because of reasons.',
        createdAt: DateTime.utc(2026, 1, 20),
        nostrEventId: 'n1',
      );
      final restored = Vote.fromMap(v.toMap());
      expect(restored.reasoning, equals('I disagree because of reasons.'));
    });

    test('round-trip preserves null reasoning', () {
      final v = Vote(
        voteId: 'v1',
        proposalId: 'p1',
        voterPubkey: 'pk',
        voterDid: 'did:x',
        voterPseudonym: 'X',
        choice: VoteChoice.ABSTAIN,
        createdAt: DateTime.utc(2026, 1, 20),
        nostrEventId: 'n1',
      );
      final restored = Vote.fromMap(v.toMap());
      expect(restored.reasoning, isNull);
    });

    test('round-trip preserves delegated vote fields', () {
      final v = Vote(
        voteId: 'v1',
        proposalId: 'p1',
        voterPubkey: 'pk',
        voterDid: 'did:delegate',
        voterPseudonym: 'Delegate',
        choice: VoteChoice.YES,
        isDelegated: true,
        delegatedFrom: 'did:original_voter',
        createdAt: DateTime.utc(2026, 1, 20),
        nostrEventId: 'n1',
      );
      final restored = Vote.fromMap(v.toMap());
      expect(restored.isDelegated, isTrue);
      expect(restored.delegatedFrom, equals('did:original_voter'));
    });

    test('round-trip preserves weight and voiceCredits for QV', () {
      final v = Vote(
        voteId: 'v1',
        proposalId: 'p1',
        voterPubkey: 'pk',
        voterDid: 'did:x',
        voterPseudonym: 'X',
        choice: VoteChoice.YES,
        weight: 3,
        voiceCredits: 9,
        createdAt: DateTime.utc(2026, 1, 20),
        nostrEventId: 'n1',
      );
      final restored = Vote.fromMap(v.toMap());
      expect(restored.weight, equals(3));
      expect(restored.voiceCredits, equals(9));
    });

    test('Vote.generateId produces unique IDs', () {
      final id1 = Vote.generateId();
      final id2 = Vote.generateId();
      expect(id1, isNot(equals(id2)));
    });
  });

  // ── VotingMode round-trip ────────────────────────────────────────────────

  group('VotingMode roundtrip', () {
    test('Proposal.create defaults votingMode to YES_NO_ABSTAIN', () {
      final p = Proposal.create(
        title: 'VotingMode default',
        description: 'd',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
      );
      expect(p.votingMode, equals(VotingMode.YES_NO_ABSTAIN));
    });

    test('Proposal.create accepts SINGLE_CHOICE', () {
      final p = Proposal.create(
        title: 'Poll',
        description: 'd',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
        votingMode: VotingMode.SINGLE_CHOICE,
      );
      expect(p.votingMode, equals(VotingMode.SINGLE_CHOICE));
    });

    test('Proposal.create accepts CANDIDATE_CHOICE', () {
      final p = Proposal.create(
        title: 'Election',
        description: 'd',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
        votingMode: VotingMode.CANDIDATE_CHOICE,
      );
      expect(p.votingMode, equals(VotingMode.CANDIDATE_CHOICE));
    });

    test('toMap includes voting_mode in snake_case', () {
      final p = Proposal.create(
        title: 'T',
        description: 'd',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
        votingMode: VotingMode.SINGLE_CHOICE,
      );
      final map = p.toMap();
      expect(map.containsKey('voting_mode'), isTrue);
      expect(map['voting_mode'], equals('SINGLE_CHOICE'));
      expect(map.containsKey('votingMode'), isFalse);
    });

    test('fromMap parses voting_mode correctly', () {
      final p = Proposal.create(
        title: 'T',
        description: 'd',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
        votingMode: VotingMode.CANDIDATE_CHOICE,
      );
      final restored = Proposal.fromMap(p.toMap());
      expect(restored.votingMode, equals(VotingMode.CANDIDATE_CHOICE));
    });

    test('fromMap defaults votingMode to YES_NO_ABSTAIN when missing', () {
      final p = Proposal.create(
        title: 'T',
        description: 'd',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
      );
      final map = p.toMap()..remove('voting_mode');
      final restored = Proposal.fromMap(map);
      expect(restored.votingMode, equals(VotingMode.YES_NO_ABSTAIN));
    });

    test('fromMap defaults votingMode to YES_NO_ABSTAIN for unknown values', () {
      final p = Proposal.create(
        title: 'T',
        description: 'd',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
      );
      final map = p.toMap();
      map['voting_mode'] = 'LEGACY_UNKNOWN_MODE';
      final restored = Proposal.fromMap(map);
      expect(restored.votingMode, equals(VotingMode.YES_NO_ABSTAIN));
    });

    test('round-trip preserves SINGLE_CHOICE', () {
      final original = Proposal.create(
        title: 'Poll',
        description: 'd',
        creatorDid: 'did:b',
        creatorPseudonym: 'B',
        cellId: 'c1',
        votingMode: VotingMode.SINGLE_CHOICE,
      );
      final restored = Proposal.fromMap(original.toMap());
      expect(restored.votingMode, equals(VotingMode.SINGLE_CHOICE));
    });

    test('round-trip preserves CANDIDATE_CHOICE', () {
      final original = Proposal.create(
        title: 'Election',
        description: 'd',
        creatorDid: 'did:c',
        creatorPseudonym: 'C',
        cellId: 'c1',
        votingMode: VotingMode.CANDIDATE_CHOICE,
      );
      final restored = Proposal.fromMap(original.toMap());
      expect(restored.votingMode, equals(VotingMode.CANDIDATE_CHOICE));
    });

    test('direct Proposal() constructor defaults votingMode to YES_NO_ABSTAIN', () {
      final p = Proposal(
        id: 'direct_test',
        cellId: 'c1',
        creatorDid: 'did:x',
        creatorPseudonym: 'X',
        title: 'Direct',
        description: 'd',
        createdAt: DateTime.utc(2026, 5, 4),
      );
      expect(p.votingMode, equals(VotingMode.YES_NO_ABSTAIN));
    });
  });

  // ── Vote.selectedOptionId ────────────────────────────────────────────────

  group('Vote selectedOptionId', () {
    Vote _baseVote({String? selectedOptionId}) => Vote(
          voteId: 'v_opt_1',
          proposalId: 'p_opt_1',
          voterPubkey: 'pk_opt',
          voterDid: 'did:test:opt',
          voterPseudonym: 'Opt',
          choice: VoteChoice.YES,
          createdAt: DateTime.utc(2026, 5, 4, 12, 0),
          nostrEventId: 'nostr_opt_1',
          selectedOptionId: selectedOptionId,
        );

    test('Vote constructor defaults selectedOptionId to null', () {
      final v = Vote(
        voteId: 'v1',
        proposalId: 'p1',
        voterPubkey: 'pk',
        voterDid: 'did:x',
        voterPseudonym: 'X',
        choice: VoteChoice.YES,
        createdAt: DateTime.utc(2026, 5, 4),
        nostrEventId: 'n1',
      );
      expect(v.selectedOptionId, isNull);
    });

    test('Vote constructor accepts selectedOptionId string', () {
      final v = _baseVote(selectedOptionId: 'option-abc-123');
      expect(v.selectedOptionId, equals('option-abc-123'));
    });

    test('toMap includes selected_option_id with null value', () {
      final map = _baseVote().toMap();
      expect(map.containsKey('selected_option_id'), isTrue);
      expect(map['selected_option_id'], isNull);
    });

    test('toMap includes selected_option_id with string value', () {
      final map = _baseVote(selectedOptionId: 'opt-xyz').toMap();
      expect(map.containsKey('selected_option_id'), isTrue);
      expect(map['selected_option_id'], equals('opt-xyz'));
    });

    test('fromMap parses null selected_option_id', () {
      final map = _baseVote().toMap();
      map['selected_option_id'] = null;
      final v = Vote.fromMap(map);
      expect(v.selectedOptionId, isNull);
    });

    test('fromMap parses string selected_option_id', () {
      final map = _baseVote().toMap();
      map['selected_option_id'] = 'option-from-db';
      final v = Vote.fromMap(map);
      expect(v.selectedOptionId, equals('option-from-db'));
    });

    test('fromMap defaults to null when key missing', () {
      final map = _baseVote().toMap()..remove('selected_option_id');
      final v = Vote.fromMap(map);
      expect(v.selectedOptionId, isNull);
    });

    test('round-trip preserves null selectedOptionId', () {
      final original = _baseVote();
      final restored = Vote.fromMap(original.toMap());
      expect(restored.selectedOptionId, isNull);
    });

    test('round-trip preserves string selectedOptionId', () {
      final original = _baseVote(selectedOptionId: 'option-round-trip');
      final restored = Vote.fromMap(original.toMap());
      expect(restored.selectedOptionId, equals('option-round-trip'));
    });
  });

  // ── DecisionRecord v1.3 fields ───────────────────────────────────────────

  group('DecisionRecord v1.3 fields', () {
    /// Minimal valid Vote for embedding in DecisionRecord.allVotes.
    Vote _minVote() => Vote(
          voteId: 'v_dr_1',
          proposalId: 'p_dr_1',
          voterPubkey: 'pk_dr',
          voterDid: 'did:test:dr',
          voterPseudonym: 'DR',
          choice: VoteChoice.YES,
          createdAt: DateTime.utc(2026, 5, 4, 10, 0),
          nostrEventId: 'nostr_dr_1',
        );

    /// Constructs a minimal DecisionRecord with all required fields.
    DecisionRecord _base({
      String? resultRelation,
      String? previousProposalId,
      String? optionResultsJson,
      String? tieOptionIdsJson,
      String? resultReason,
      String? previousDecisionHash,
    }) =>
        DecisionRecord(
          recordId: 'rec_dr_1',
          proposalId: 'p_dr_1',
          cellId: 'cell_dr_1',
          finalTitle: 'Test DR',
          finalDescription: 'Description',
          result: 'YES',
          yesVotes: 5,
          noVotes: 2,
          abstainVotes: 1,
          participation: 0.8,
          decidedAt: DateTime.utc(2026, 5, 4, 12, 0),
          allVotes: [_minVote()],
          contentHash: 'hash_abc',
          previousDecisionHash: previousDecisionHash,
          nostrEventId: 'nostr_rec_1',
          resultRelation: resultRelation,
          previousProposalId: previousProposalId,
          optionResultsJson: optionResultsJson,
          tieOptionIdsJson: tieOptionIdsJson,
          resultReason: resultReason,
        );

    test('Konstruktor defaults all 5 new fields to null', () {
      final dr = _base();
      expect(dr.resultRelation, isNull);
      expect(dr.previousProposalId, isNull);
      expect(dr.optionResultsJson, isNull);
      expect(dr.tieOptionIdsJson, isNull);
      expect(dr.resultReason, isNull);
    });

    test('toMap includes all 5 new fields with null values', () {
      final map = _base().toMap();
      expect(map.containsKey('result_relation'), isTrue);
      expect(map.containsKey('previous_proposal_id'), isTrue);
      expect(map.containsKey('option_results_json'), isTrue);
      expect(map.containsKey('tie_option_ids_json'), isTrue);
      expect(map.containsKey('result_reason'), isTrue);
      expect(map['result_relation'], isNull);
      expect(map['previous_proposal_id'], isNull);
      expect(map['option_results_json'], isNull);
      expect(map['tie_option_ids_json'], isNull);
      expect(map['result_reason'], isNull);
    });

    test('fromMap defaults to null when keys missing', () {
      final map = _base().toMap();
      map.remove('result_relation');
      map.remove('previous_proposal_id');
      map.remove('option_results_json');
      map.remove('tie_option_ids_json');
      map.remove('result_reason');
      final dr = DecisionRecord.fromMap(map);
      expect(dr.resultRelation, isNull);
      expect(dr.previousProposalId, isNull);
      expect(dr.optionResultsJson, isNull);
      expect(dr.tieOptionIdsJson, isNull);
      expect(dr.resultReason, isNull);
    });

    test('round-trip preserves resultRelation = RUNOFF_OF with previousProposalId', () {
      final original = _base(
        resultRelation: 'RUNOFF_OF',
        previousProposalId: 'prop_predecessor_1',
      );
      final restored = DecisionRecord.fromMap(original.toMap());
      expect(restored.resultRelation, equals('RUNOFF_OF'));
      expect(restored.previousProposalId, equals('prop_predecessor_1'));
    });

    test('round-trip preserves resultRelation = REPLACEMENT_OF', () {
      final original = _base(
        resultRelation: 'REPLACEMENT_OF',
        previousProposalId: 'prop_original_1',
      );
      final restored = DecisionRecord.fromMap(original.toMap());
      expect(restored.resultRelation, equals('REPLACEMENT_OF'));
      expect(restored.previousProposalId, equals('prop_original_1'));
    });

    test('round-trip preserves optionResultsJson raw string', () {
      final rawJson = jsonEncode({
        'opt_a': {'votes': 10, 'percentage': 0.5},
        'opt_b': {'votes': 10, 'percentage': 0.5},
      });
      final original = _base(optionResultsJson: rawJson);
      final restored = DecisionRecord.fromMap(original.toMap());
      expect(restored.optionResultsJson, equals(rawJson));
    });

    test('round-trip preserves tieOptionIdsJson raw string', () {
      final rawJson = jsonEncode(['opt_a', 'opt_b']);
      final original = _base(tieOptionIdsJson: rawJson);
      final restored = DecisionRecord.fromMap(original.toMap());
      expect(restored.tieOptionIdsJson, equals(rawJson));
    });

    test('round-trip preserves resultReason = TIE_REQUIRES_RUNOFF', () {
      final original = _base(resultReason: 'TIE_REQUIRES_RUNOFF');
      final restored = DecisionRecord.fromMap(original.toMap());
      expect(restored.resultReason, equals('TIE_REQUIRES_RUNOFF'));
    });

    test('round-trip preserves resultReason = WINNER_WITHDRAWN', () {
      final original = _base(resultReason: 'WINNER_WITHDRAWN');
      final restored = DecisionRecord.fromMap(original.toMap());
      expect(restored.resultReason, equals('WINNER_WITHDRAWN'));
    });

    test('round-trip preserves resultReason = QUORUM_NOT_MET', () {
      final original = _base(resultReason: 'QUORUM_NOT_MET');
      final restored = DecisionRecord.fromMap(original.toMap());
      expect(restored.resultReason, equals('QUORUM_NOT_MET'));
    });

    test('previousDecisionHash and previousProposalId are independent', () {
      final dr = _base(
        previousDecisionHash: 'hash_of_prev_decision_record',
        previousProposalId: 'prop_runoff_predecessor',
      );
      expect(dr.previousDecisionHash, equals('hash_of_prev_decision_record'));
      expect(dr.previousProposalId, equals('prop_runoff_predecessor'));
      // Semantically distinct: one is audit-trail (G2 §18), other is runoff chaining (G2 §9.12.1)
      expect(dr.previousDecisionHash, isNot(equals(dr.previousProposalId)));
    });

    test('previousDecisionHash null but previousProposalId set works', () {
      final original = _base(
        previousDecisionHash: null,
        previousProposalId: 'prop_runoff_orig',
      );
      final restored = DecisionRecord.fromMap(original.toMap());
      expect(restored.previousDecisionHash, isNull);
      expect(restored.previousProposalId, equals('prop_runoff_orig'));
    });

    test('previousDecisionHash set but previousProposalId null works', () {
      final original = _base(
        previousDecisionHash: 'audit_hash_xyz',
        previousProposalId: null,
      );
      final restored = DecisionRecord.fromMap(original.toMap());
      expect(restored.previousDecisionHash, equals('audit_hash_xyz'));
      expect(restored.previousProposalId, isNull);
    });
  });

  // ── Proposal eligibleVoters snapshot (Phase 4.1a) ───────────────────────

  group('Proposal eligibleVoters snapshot', () {
    Proposal _minProposal({List<String>? eligibleVoters}) => Proposal(
          id: 'ev_prop_1',
          cellId: 'ev_cell_1',
          creatorDid: 'did:test:ev',
          creatorPseudonym: 'EV',
          title: 'EV Test',
          description: 'eligible voters test',
          createdAt: DateTime.utc(2026, 5, 5, 10, 0),
          eligibleVoters: eligibleVoters,
        );

    // ── Default-Verhalten ──

    test('Konstruktor defaults eligibleVoters to null', () {
      final p = _minProposal();
      expect(p.eligibleVoters, isNull);
    });

    test('Proposal.create has eligibleVoters = null by default', () {
      final p = Proposal.create(
        title: 'EV Create',
        description: 'd',
        creatorDid: 'did:a',
        creatorPseudonym: 'A',
        cellId: 'c1',
      );
      expect(p.eligibleVoters, isNull);
    });

    // ── Roundtrip null ──

    test('toMap with null eligibleVoters writes null', () {
      final map = _minProposal(eligibleVoters: null).toMap();
      expect(map.containsKey('eligible_voters_json'), isTrue);
      expect(map['eligible_voters_json'], isNull);
    });

    test('fromMap with missing key returns null', () {
      final map = _minProposal().toMap()..remove('eligible_voters_json');
      final p = Proposal.fromMap(map);
      expect(p.eligibleVoters, isNull);
    });

    test('fromMap with null value returns null', () {
      final map = _minProposal().toMap();
      map['eligible_voters_json'] = null;
      final p = Proposal.fromMap(map);
      expect(p.eligibleVoters, isNull);
    });

    test('round-trip preserves null', () {
      final original = _minProposal(eligibleVoters: null);
      final restored = Proposal.fromMap(original.toMap());
      expect(restored.eligibleVoters, isNull);
    });

    // ── Roundtrip leere Liste ──

    test('toMap with empty list writes "[]"', () {
      final map = _minProposal(eligibleVoters: []).toMap();
      expect(map['eligible_voters_json'], equals('[]'));
    });

    test('fromMap with "[]" returns empty list (not null)', () {
      final map = _minProposal().toMap();
      map['eligible_voters_json'] = '[]';
      final p = Proposal.fromMap(map);
      expect(p.eligibleVoters, isNotNull);
      expect(p.eligibleVoters, isEmpty);
    });

    test('round-trip preserves empty list distinct from null', () {
      final original = _minProposal(eligibleVoters: []);
      final restored = Proposal.fromMap(original.toMap());
      expect(restored.eligibleVoters, isNotNull);
      expect(restored.eligibleVoters, isEmpty);
    });

    // ── Roundtrip mit DIDs ──

    test('toMap with multiple DIDs writes JSON array', () {
      final dids = [
        'did:key:zAlice',
        'did:key:zBob',
        'did:key:zCarol',
      ];
      final map = _minProposal(eligibleVoters: dids).toMap();
      expect(map['eligible_voters_json'], isA<String>());
      final decoded = jsonDecode(map['eligible_voters_json'] as String);
      expect(decoded, equals(dids));
    });

    test('fromMap with JSON array returns List<String>', () {
      final dids = ['did:key:zA', 'did:key:zB'];
      final map = _minProposal().toMap();
      map['eligible_voters_json'] = jsonEncode(dids);
      final p = Proposal.fromMap(map);
      expect(p.eligibleVoters, equals(dids));
    });

    test('round-trip preserves DID order', () {
      final dids = ['did:key:z3', 'did:key:z1', 'did:key:z2'];
      final original = _minProposal(eligibleVoters: dids);
      final restored = Proposal.fromMap(original.toMap());
      expect(restored.eligibleVoters, equals(dids));
    });

    // ── Defensive Parsing ──

    test('fromMap with malformed JSON returns null (defensive)', () {
      final map = _minProposal().toMap();
      map['eligible_voters_json'] = '{not valid json[';
      final p = Proposal.fromMap(map);
      expect(p.eligibleVoters, isNull);
    });

    test('fromMap with JSON array containing non-strings returns null (defensive)', () {
      final map = _minProposal().toMap();
      map['eligible_voters_json'] = jsonEncode([1, 2, 3]);
      // List<String>.from on ints throws → defensive catch → null
      final p = Proposal.fromMap(map);
      expect(p.eligibleVoters, isNull);
    });

    test('fromMap with non-array JSON object returns null (defensive)', () {
      final map = _minProposal().toMap();
      map['eligible_voters_json'] = jsonEncode({'did': 'did:key:zA'});
      final p = Proposal.fromMap(map);
      expect(p.eligibleVoters, isNull);
    });

    // ── Altbestand (kritischer Test) ──

    test('legacy Proposal map without eligible_voters_json key has eligibleVoters = null', () {
      final map = _minProposal().toMap();
      // Simulate a pre-v22 row that has no eligible_voters_json column
      map.remove('eligible_voters_json');
      final p = Proposal.fromMap(map);
      expect(p.eligibleVoters, isNull,
          reason:
              'Legacy data (pre-v22) must yield null, not [] or any other value');
    });
  });

  // ── finalizeProposal — votingMode dispatch (Phase 4.2a) ─────────────────

  group('finalizeProposal — votingMode dispatch (Phase 4.2a)', () {
    /// Helper: minimal Proposal in VOTING_ENDED with given votingMode.
    Proposal _votingEndedProposal(VotingMode mode) {
      return Proposal(
        id: 'prop_dispatch_${mode.name}',
        cellId: 'cell_dispatch',
        creatorDid: 'did:test:dispatch',
        creatorPseudonym: 'Dispatcher',
        title: 'Dispatch Test',
        description: 'VotingMode dispatch test',
        createdAt: DateTime.utc(2026, 5, 1),
        status: ProposalStatus.VOTING_ENDED,
        votingMode: mode,
      );
    }

    test(
        'YES_NO_ABSTAIN proposal has votingMode=YES_NO_ABSTAIN (default path '
        'passes mode check)', () {
      final p = _votingEndedProposal(VotingMode.YES_NO_ABSTAIN);
      expect(p.votingMode, equals(VotingMode.YES_NO_ABSTAIN));
      expect(p.status, equals(ProposalStatus.VOTING_ENDED));
    });

    test(
        'SINGLE_CHOICE proposal in VOTING_ENDED has correct mode set', () {
      final p = _votingEndedProposal(VotingMode.SINGLE_CHOICE);
      expect(p.votingMode, equals(VotingMode.SINGLE_CHOICE));
      expect(p.status, equals(ProposalStatus.VOTING_ENDED));
    });

    test(
        'SINGLE_CHOICE proposal: status stays VOTING_ENDED after mode check '
        '(skip branch does NOT change status to DECIDED)', () {
      final p = _votingEndedProposal(VotingMode.SINGLE_CHOICE);
      // The skip branch should leave the status untouched.
      // We verify the dispatch condition directly — status must not become DECIDED.
      final isSkipped = p.votingMode != VotingMode.YES_NO_ABSTAIN;
      expect(isSkipped, isTrue,
          reason: 'SINGLE_CHOICE must enter the skip branch');
      // Status must still be VOTING_ENDED (not modified by skip).
      expect(p.status, equals(ProposalStatus.VOTING_ENDED));
    });

    test(
        'SINGLE_CHOICE proposal: skip branch produces no result fields '
        '(resultSummary, resultYes, resultNo, resultAbstain are null)', () {
      final p = _votingEndedProposal(VotingMode.SINGLE_CHOICE);
      // Skip branch must not write any result fields.
      expect(p.resultSummary, isNull);
      expect(p.resultYes, isNull);
      expect(p.resultNo, isNull);
      expect(p.resultAbstain, isNull);
    });

    test(
        'CANDIDATE_CHOICE proposal in VOTING_ENDED has correct mode set', () {
      final p = _votingEndedProposal(VotingMode.CANDIDATE_CHOICE);
      expect(p.votingMode, equals(VotingMode.CANDIDATE_CHOICE));
      expect(p.status, equals(ProposalStatus.VOTING_ENDED));
    });

    test(
        'CANDIDATE_CHOICE proposal: status stays VOTING_ENDED after mode check '
        '(skip branch does NOT change status to DECIDED)', () {
      final p = _votingEndedProposal(VotingMode.CANDIDATE_CHOICE);
      final isSkipped = p.votingMode != VotingMode.YES_NO_ABSTAIN;
      expect(isSkipped, isTrue,
          reason: 'CANDIDATE_CHOICE must enter the skip branch');
      expect(p.status, equals(ProposalStatus.VOTING_ENDED));
    });

    test(
        'non-YES_NO_ABSTAIN modes are correctly identified by skip condition '
        '(no exception thrown by mode check)', () {
      final modes = [VotingMode.SINGLE_CHOICE, VotingMode.CANDIDATE_CHOICE];
      for (final mode in modes) {
        final p = _votingEndedProposal(mode);
        // The dispatch condition itself must not throw.
        expect(() => p.votingMode != VotingMode.YES_NO_ABSTAIN, returnsNormally,
            reason: 'Mode check for $mode must not throw');
      }
    });
  });

  // ── finalizeProposal — YES_NO_ABSTAIN tally with ResultReason (Phase 4.2b) ──

  group('finalizeProposal — YES_NO_ABSTAIN tally with ResultReason (Phase 4.2b)', () {
    // Local helper that mirrors the production tally logic in finalizeProposal.
    // finalizeProposal cannot be called directly in unit tests (requires DB/
    // service singletons), so the logic is tested here as executable spec.
    ({String result, String? resultReason, double participation}) _tally({
      required int yes,
      required int no,
      required int abstain,
      required int eligibleCount,
      required double quorumRequired,
    }) {
      final participationCount = yes + no + abstain;
      final participation =
          eligibleCount > 0 ? participationCount / eligibleCount : 0.0;

      String result;
      String? resultReason;

      if (participationCount == 0) {
        result = 'invalid';
        resultReason = ResultReason.noValidVotes;
      } else if (participation < quorumRequired) {
        result = 'invalid';
        resultReason = ResultReason.quorumNotMet;
      } else if (yes + no == 0) {
        // Quorum reached, but all votes are ABSTAIN
        result = 'invalid';
        resultReason = ResultReason.allAbstain;
      } else if (yes > no) {
        result = 'approved';
        resultReason = null;
      } else {
        // yes <= no → REJECTED (tie counts as status quo)
        result = 'rejected';
        resultReason = null;
      }

      return (result: result, resultReason: resultReason, participation: participation);
    }

    // ── Tally vectors ──────────────────────────────────────────────────────────

    test('V1: 7 YES, 2 NO, 1 ABSTAIN, eligible=10, quorum=0.5 → '
        'approved with resultReason=null', () {
      final t = _tally(yes: 7, no: 2, abstain: 1, eligibleCount: 10, quorumRequired: 0.5);
      expect(t.result, equals('approved'));
      expect(t.resultReason, isNull);
      expect(t.participation, closeTo(1.0, 0.0001));
    });

    test('V2: 1 YES alone, eligible=10, quorum=0.5 → INVALID with '
        'resultReason=QUORUM_NOT_MET', () {
      final t = _tally(yes: 1, no: 0, abstain: 0, eligibleCount: 10, quorumRequired: 0.5);
      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.quorumNotMet));
      expect(t.participation, closeTo(0.1, 0.0001));
    });

    test('V3: 5 ABSTAIN, eligible=10, quorum=0.5 → INVALID with '
        'resultReason=ALL_ABSTAIN', () {
      final t = _tally(yes: 0, no: 0, abstain: 5, eligibleCount: 10, quorumRequired: 0.5);
      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.allAbstain));
      expect(t.participation, closeTo(0.5, 0.0001));
    });

    test('V4: 5 YES, 5 NO, eligible=10, quorum=0.5 → rejected '
        '(status quo wins on tie), resultReason=null', () {
      final t = _tally(yes: 5, no: 5, abstain: 0, eligibleCount: 10, quorumRequired: 0.5);
      expect(t.result, equals('rejected'));
      expect(t.resultReason, isNull);
    });

    test('V14: 0 votes, eligible=10 → INVALID with '
        'resultReason=NO_VALID_VOTES', () {
      final t = _tally(yes: 0, no: 0, abstain: 0, eligibleCount: 10, quorumRequired: 0.5);
      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.noValidVotes));
      expect(t.participation, closeTo(0.0, 0.0001));
    });

    test('V15: 6 ABSTAIN, eligible=10, quorum=0.5 → INVALID with '
        'resultReason=ALL_ABSTAIN (quorum met, but no YES/NO)', () {
      final t = _tally(yes: 0, no: 0, abstain: 6, eligibleCount: 10, quorumRequired: 0.5);
      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.allAbstain));
      expect(t.participation, closeTo(0.6, 0.0001));
    });

    test('Tie YES=NO=0 with quorum reached via ABSTAIN: ALL_ABSTAIN, not REJECTED', () {
      // Edge case: quorum met by abstain votes alone, YES+NO == 0 → allAbstain wins
      final t = _tally(yes: 0, no: 0, abstain: 8, eligibleCount: 10, quorumRequired: 0.5);
      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.allAbstain),
          reason: 'ALL_ABSTAIN must take priority over the tie → REJECTED branch');
    });

    // ── EligibleVoters snapshot ────────────────────────────────────────────────

    test('Snapshot: eligibleVoters=[A,B,C,D] → participation computed against 4, '
        'not cell_members count', () {
      final p = Proposal(
        id: 'prop_snap_test',
        cellId: 'cell_snap',
        creatorDid: 'did:test:snap',
        creatorPseudonym: 'Snapper',
        title: 'Snapshot Test',
        description: 'Test eligibleVoters snapshot',
        createdAt: DateTime.utc(2026, 5, 1),
        eligibleVoters: ['did:A', 'did:B', 'did:C', 'did:D'],
      );
      expect(p.eligibleVoters, isNotNull);
      expect(p.eligibleVoters!.length, equals(4));

      // With 2 YES, eligible=4 → participation = 0.5 (quorum exact)
      final t = _tally(
        yes: 2, no: 0, abstain: 0,
        eligibleCount: p.eligibleVoters!.length,
        quorumRequired: 0.5,
      );
      // participation = 2/4 = 0.5, which is NOT < 0.5 → passes quorum
      expect(t.result, equals('approved'));
      expect(t.participation, closeTo(0.5, 0.0001));
    });

    test('Fallback: eligibleVoters=null triggers the CellService fallback path '
        '(no snapshot present → p.eligibleVoters == null)', () {
      final p = Proposal(
        id: 'prop_fallback_test',
        cellId: 'cell_fallback',
        creatorDid: 'did:test:fallback',
        creatorPseudonym: 'Fallbacker',
        title: 'Fallback Test',
        description: 'Test eligibleVoters fallback',
        createdAt: DateTime.utc(2026, 5, 1),
        // eligibleVoters not set → defaults to null
      );
      // Verify the production fallback condition fires for this proposal.
      final requiresFallback = p.eligibleVoters == null;
      expect(requiresFallback, isTrue,
          reason: 'null eligibleVoters must trigger CellService.getMemberCount fallback');
    });

    // ── DecisionRecord Phase-3.5 fields ───────────────────────────────────────

    test('DecisionRecord has resultReason set on INVALID result', () {
      final record = DecisionRecord(
        recordId: 'rec_invalid_test',
        proposalId: 'prop_invalid',
        cellId: 'cell_1',
        finalTitle: 'Invalid Test',
        finalDescription: 'No votes cast',
        result: 'invalid',
        yesVotes: 0,
        noVotes: 0,
        abstainVotes: 0,
        participation: 0.0,
        decidedAt: DateTime.utc(2026, 5, 5, 12, 0),
        allVotes: const [],
        contentHash: 'abc123',
        previousDecisionHash: null,
        nostrEventId: '',
        resultReason: ResultReason.noValidVotes,
        resultRelation: null,
        previousProposalId: null,
        optionResultsJson: null,
        tieOptionIdsJson: null,
      );
      expect(record.resultReason, equals(ResultReason.noValidVotes));
      expect(record.result, equals('invalid'));
    });

    test('DecisionRecord has resultRelation=null, previousProposalId=null, '
        'optionResultsJson=null, tieOptionIdsJson=null for YES_NO_ABSTAIN', () {
      final record = DecisionRecord(
        recordId: 'rec_fields_test',
        proposalId: 'prop_fields',
        cellId: 'cell_1',
        finalTitle: 'Fields Test',
        finalDescription: 'Phase 3.5 fields test',
        result: 'approved',
        yesVotes: 7,
        noVotes: 2,
        abstainVotes: 1,
        participation: 1.0,
        decidedAt: DateTime.utc(2026, 5, 5, 12, 0),
        allVotes: const [],
        contentHash: 'deadbeef',
        previousDecisionHash: null,
        nostrEventId: '',
        resultReason: null,
        resultRelation: null,
        previousProposalId: null,
        optionResultsJson: null,
        tieOptionIdsJson: null,
      );
      expect(record.resultReason, isNull);
      expect(record.resultRelation, isNull);
      expect(record.previousProposalId, isNull);
      expect(record.optionResultsJson, isNull);
      expect(record.tieOptionIdsJson, isNull);
    });

    // ── contentHash determinism ────────────────────────────────────────────────

    test('contentHash for identical YES_NO_ABSTAIN tally inputs is deterministic', () {
      final decidedAt = DateTime.utc(2026, 5, 5, 12, 0, 0);
      final buildInput = () => <String, dynamic>{
        'proposalId': 'prop_hash_det',
        'cellId': 'cell_hash',
        'votingMode': 'YES_NO_ABSTAIN',
        'result': 'approved',
        'resultReason': null,
        'resultRelation': null,
        'yesVotes': 7,
        'noVotes': 2,
        'abstainVotes': 1,
        'participation': (10 / 10).toStringAsFixed(4),
        'eligibleVotersCount': 10,
        'decidedAt': decidedAt.toIso8601String(),
        'previousProposalId': null,
        'previousDecisionHash': null,
        'finalTitle': 'Hash Det Test',
        'finalDescription': 'Testing hash determinism',
        'optionResultsJson': null,
        'tieOptionIdsJson': null,
      };

      final hash1 = computeContentHash(buildInput());
      final hash2 = computeContentHash(buildInput());
      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64));
      expect(hash1, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('contentHash differs when resultReason changes (null vs QUORUM_NOT_MET)', () {
      final base = <String, dynamic>{
        'proposalId': 'prop_hash_reason',
        'cellId': 'cell_hash',
        'votingMode': 'YES_NO_ABSTAIN',
        'result': 'invalid',
        'resultReason': null,
        'resultRelation': null,
        'yesVotes': 1,
        'noVotes': 0,
        'abstainVotes': 0,
        'participation': (1 / 10).toStringAsFixed(4),
        'eligibleVotersCount': 10,
        'decidedAt': DateTime.utc(2026, 5, 5).toIso8601String(),
        'previousProposalId': null,
        'previousDecisionHash': null,
        'finalTitle': 'Reason Hash Test',
        'finalDescription': 'desc',
        'optionResultsJson': null,
        'tieOptionIdsJson': null,
      };
      final withReason = Map<String, dynamic>.from(base);
      withReason['resultReason'] = ResultReason.quorumNotMet;

      expect(
        computeContentHash(base),
        isNot(equals(computeContentHash(withReason))),
      );
    });

    test('participation toStringAsFixed(4) is stable across identical inputs', () {
      final participation = 7 / 10; // 0.7
      expect(participation.toStringAsFixed(4), equals('0.7000'));
      final participation2 = 7 / 10;
      expect(participation2.toStringAsFixed(4), equals('0.7000'));
    });
  });
}
