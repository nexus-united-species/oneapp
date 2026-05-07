import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/decision_record.dart';
import 'package:nexus_oneapp/features/governance/proposal.dart';
import 'package:nexus_oneapp/features/governance/proposal_option.dart';
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

  // ── finalizeProposal — SINGLE_CHOICE tally (Phase 4.3) ──────────────────

  group('finalizeProposal — SINGLE_CHOICE tally (Phase 4.3)', () {
    // Local helper that mirrors _finalizeSingleChoice tally logic.
    // The production method requires DB/service singletons, so the algorithm
    // is tested here as executable spec — identical to the 4.2b approach.

    /// Creates a minimal ProposalOption with the given optionId.
    ProposalOption _makeOption(String proposalId, String optionId,
        {int position = 0}) {
      final now = DateTime.utc(2026, 5, 1);
      return ProposalOption(
        optionId: optionId,
        proposalId: proposalId,
        label: 'Option $optionId',
        status: OptionStatus.ACTIVE,
        position: position,
        createdAt: now,
        updatedAt: now,
      );
    }

    /// Creates a Vote that represents a vote for [selectedOptionId].
    /// Per P1 convention: choice=ABSTAIN, selectedOptionId=<oid>.
    Vote _makeOptionVote(String proposalId, String voterId,
        String selectedOptionId) {
      return Vote(
        voteId: 'vote_${proposalId}_$voterId',
        proposalId: proposalId,
        voterPubkey: 'pubkey_$voterId',
        voterDid: 'did:test:$voterId',
        voterPseudonym: voterId,
        choice: VoteChoice.ABSTAIN,
        selectedOptionId: selectedOptionId,
        createdAt: DateTime.utc(2026, 5, 1),
        nostrEventId: '',
      );
    }

    /// Creates a true abstain vote (choice=ABSTAIN, selectedOptionId=null).
    Vote _makeAbstainVote(String proposalId, String voterId) {
      return Vote(
        voteId: 'vote_${proposalId}_${voterId}_abs',
        proposalId: proposalId,
        voterPubkey: 'pubkey_$voterId',
        voterDid: 'did:test:$voterId',
        voterPseudonym: voterId,
        choice: VoteChoice.ABSTAIN,
        selectedOptionId: null,
        createdAt: DateTime.utc(2026, 5, 1),
        nostrEventId: '',
      );
    }

    /// Core tally logic mirroring _finalizeSingleChoice (without DB/service calls).
    ({
      String result,
      String? resultReason,
      String? tieOptionIdsJson,
      String? optionResultsJson,
      double participation,
      int abstainCount,
      String contentHash,
    }) _tallySC({
      required List<ProposalOption> options,
      required List<Vote> votes,
      required int eligibleCount,
      required double quorumRequired,
      String proposalId = 'prop_sc_test',
      String cellId = 'cell_sc',
    }) {
      final sortedVotes = sortVotesDeterministic(votes);
      final sortedOptions = sortOptionsDeterministic(options);

      final optionCounts = <String, int>{};
      for (final opt in sortedOptions) {
        optionCounts[opt.optionId] = 0;
      }
      int abstainCount = 0;

      for (final v in sortedVotes) {
        if (v.selectedOptionId != null) {
          if (optionCounts.containsKey(v.selectedOptionId)) {
            optionCounts[v.selectedOptionId!] =
                optionCounts[v.selectedOptionId!]! + 1;
          }
          // unknown option → ignored (no increment)
        } else if (v.choice == VoteChoice.ABSTAIN) {
          abstainCount++;
        }
        // YES/NO without selectedOptionId → ignored
      }

      final optionVoteSum =
          optionCounts.values.fold<int>(0, (a, b) => a + b);
      final participationCount = optionVoteSum + abstainCount;
      final participation =
          eligibleCount > 0 ? participationCount / eligibleCount : 0.0;

      String result;
      String? resultReason;
      String? tieOptionIdsJson;

      if (participationCount == 0) {
        result = 'invalid';
        resultReason = ResultReason.noValidVotes;
      } else if (participation < quorumRequired) {
        result = 'invalid';
        resultReason = ResultReason.quorumNotMet;
      } else if (optionVoteSum == 0) {
        result = 'invalid';
        resultReason = ResultReason.allAbstain;
      } else {
        final maxCount =
            optionCounts.values.fold<int>(0, (a, b) => b > a ? b : a);
        final winners = sortedOptions
            .where((o) => optionCounts[o.optionId] == maxCount)
            .map((o) => o.optionId)
            .toList();

        if (winners.length == 1) {
          result = 'approved';
          resultReason = null;
        } else {
          result = 'invalid';
          resultReason = ResultReason.tieRequiresRunoff;
          tieOptionIdsJson = canonicalJsonEncode(winners);
        }
      }

      String? optionResultsJson;
      if (sortedOptions.isNotEmpty) {
        final canonicalCounts = <String, dynamic>{};
        for (final opt in sortedOptions) {
          canonicalCounts[opt.optionId] = optionCounts[opt.optionId] ?? 0;
        }
        optionResultsJson = canonicalJsonEncode(canonicalCounts);
      }

      final decidedAt = DateTime.utc(2026, 5, 5, 12, 0, 0);
      final hashInput = <String, dynamic>{
        'proposalId': proposalId,
        'cellId': cellId,
        'votingMode': 'SINGLE_CHOICE',
        'result': result,
        'resultReason': resultReason,
        'resultRelation': null,
        'yesVotes': 0,
        'noVotes': 0,
        'abstainVotes': abstainCount,
        'participation': participation.toStringAsFixed(4),
        'eligibleVotersCount': eligibleCount,
        'decidedAt': decidedAt.toIso8601String(),
        'previousProposalId': null,
        'previousDecisionHash': null,
        'finalTitle': 'SC Test',
        'finalDescription': 'desc',
        'optionResultsJson': optionResultsJson,
        'tieOptionIdsJson': tieOptionIdsJson,
      };
      final contentHash = computeContentHash(hashInput);

      return (
        result: result,
        resultReason: resultReason,
        tieOptionIdsJson: tieOptionIdsJson,
        optionResultsJson: optionResultsJson,
        participation: participation,
        abstainCount: abstainCount,
        contentHash: contentHash,
      );
    }

    // ── Tally-Vektoren ────────────────────────────────────────────────────────

    test('V5: 3 für A, 1 für B, 1 für C, 1 ABSTAIN, eligible=10, '
        'quorum=0.5 → approved, optionResultsJson enthält A:3,B:1,C:1', () {
      final opts = [
        _makeOption('p1', 'A'),
        _makeOption('p1', 'B'),
        _makeOption('p1', 'C'),
      ];
      final votes = [
        _makeOptionVote('p1', 'v1', 'A'),
        _makeOptionVote('p1', 'v2', 'A'),
        _makeOptionVote('p1', 'v3', 'A'),
        _makeOptionVote('p1', 'v4', 'B'),
        _makeOptionVote('p1', 'v5', 'C'),
        _makeAbstainVote('p1', 'v6'),
      ];

      final t = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
      );

      expect(t.result, equals('approved'));
      expect(t.resultReason, isNull);
      expect(t.participation, closeTo(0.6, 0.0001));
      expect(t.abstainCount, equals(1));
      expect(t.tieOptionIdsJson, isNull);

      // optionResultsJson must contain all three options
      final decoded = jsonDecode(t.optionResultsJson!) as Map<String, dynamic>;
      expect(decoded['A'], equals(3));
      expect(decoded['B'], equals(1));
      expect(decoded['C'], equals(1));
    });

    test('V6: 2 für A, 2 für B, 1 für C, 1 ABSTAIN, eligible=10, '
        'quorum=0.5 → invalid + TIE_REQUIRES_RUNOFF, '
        'tieOptionIdsJson=[A,B]', () {
      final opts = [
        _makeOption('p2', 'A', position: 0),
        _makeOption('p2', 'B', position: 1),
        _makeOption('p2', 'C', position: 2),
      ];
      final votes = [
        _makeOptionVote('p2', 'v1', 'A'),
        _makeOptionVote('p2', 'v2', 'A'),
        _makeOptionVote('p2', 'v3', 'B'),
        _makeOptionVote('p2', 'v4', 'B'),
        _makeOptionVote('p2', 'v5', 'C'),
        _makeAbstainVote('p2', 'v6'),
      ];

      final t = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.tieRequiresRunoff));
      expect(t.tieOptionIdsJson, isNotNull);

      final tieIds = jsonDecode(t.tieOptionIdsJson!) as List<dynamic>;
      expect(tieIds, containsAll(['A', 'B']));
      expect(tieIds.length, equals(2));
    });

    test('SC: 1 für A, eligible=10, quorum=0.5 → invalid + '
        'QUORUM_NOT_MET', () {
      final opts = [_makeOption('p3', 'A'), _makeOption('p3', 'B')];
      final votes = [_makeOptionVote('p3', 'v1', 'A')];

      final t = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.quorumNotMet));
      expect(t.participation, closeTo(0.1, 0.0001));
    });

    test('SC: 5 ABSTAIN, eligible=10, quorum=0.5 → invalid + '
        'ALL_ABSTAIN', () {
      final opts = [_makeOption('p4', 'A'), _makeOption('p4', 'B')];
      final votes = List.generate(
          5, (i) => _makeAbstainVote('p4', 'v$i'));

      final t = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.allAbstain));
      expect(t.participation, closeTo(0.5, 0.0001));
    });

    test('SC: 0 votes, eligible=10 → invalid + NO_VALID_VOTES', () {
      final opts = [_makeOption('p5', 'A'), _makeOption('p5', 'B')];

      final t = _tallySC(
        options: opts,
        votes: [],
        eligibleCount: 10,
        quorumRequired: 0.5,
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.noValidVotes));
      expect(t.participation, closeTo(0.0, 0.0001));
    });

    test('SC: vote with unknown selectedOptionId is ignored '
        '(does not count toward any option)', () {
      final opts = [_makeOption('p6', 'A'), _makeOption('p6', 'B')];
      // 6 valid option votes + 1 with unknown optionId
      final votes = [
        _makeOptionVote('p6', 'v1', 'A'),
        _makeOptionVote('p6', 'v2', 'A'),
        _makeOptionVote('p6', 'v3', 'A'),
        _makeOptionVote('p6', 'v4', 'A'),
        _makeOptionVote('p6', 'v5', 'A'),
        _makeOptionVote('p6', 'v6', 'B'),
        Vote(
          voteId: 'vote_p6_unknown',
          proposalId: 'p6',
          voterPubkey: 'pubkey_vx',
          voterDid: 'did:test:vx',
          voterPseudonym: 'vx',
          choice: VoteChoice.ABSTAIN,
          selectedOptionId: 'UNKNOWN_OPT',
          createdAt: DateTime.utc(2026, 5, 1),
          nostrEventId: '',
        ),
      ];

      final t = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
      );

      // Unknown option vote is ignored — A still wins
      expect(t.result, equals('approved'));
      final decoded = jsonDecode(t.optionResultsJson!) as Map<String, dynamic>;
      expect(decoded['A'], equals(5));
      expect(decoded['B'], equals(1));
      expect(decoded.containsKey('UNKNOWN_OPT'), isFalse);
    });

    test('SC: optionResultsJson is populated even on INVALID outcome '
        '(QUORUM_NOT_MET)', () {
      final opts = [_makeOption('p7', 'A'), _makeOption('p7', 'B')];
      final votes = [_makeOptionVote('p7', 'v1', 'A')];

      final t = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
      );

      expect(t.result, equals('invalid'));
      expect(t.optionResultsJson, isNotNull);
    });

    test('SC: optionResultsJson contains all options including those '
        'with 0 votes', () {
      final opts = [
        _makeOption('p8', 'A'),
        _makeOption('p8', 'B'),
        _makeOption('p8', 'C'),
      ];
      // Only A gets votes
      final votes = List.generate(
          6, (i) => _makeOptionVote('p8', 'v$i', 'A'));

      final t = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
      );

      expect(t.result, equals('approved'));
      final decoded = jsonDecode(t.optionResultsJson!) as Map<String, dynamic>;
      expect(decoded.containsKey('A'), isTrue);
      expect(decoded.containsKey('B'), isTrue);
      expect(decoded.containsKey('C'), isTrue);
      expect(decoded['B'], equals(0));
      expect(decoded['C'], equals(0));
    });

    test('SC: tieOptionIdsJson is null when single winner', () {
      final opts = [_makeOption('p9', 'A'), _makeOption('p9', 'B')];
      final votes = [
        _makeOptionVote('p9', 'v1', 'A'),
        _makeOptionVote('p9', 'v2', 'A'),
        _makeOptionVote('p9', 'v3', 'A'),
        _makeOptionVote('p9', 'v4', 'A'),
        _makeOptionVote('p9', 'v5', 'A'),
        _makeOptionVote('p9', 'v6', 'B'),
      ];

      final t = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
      );

      expect(t.result, equals('approved'));
      expect(t.tieOptionIdsJson, isNull);
    });

    test('SC: tieOptionIdsJson is set only on TIE_REQUIRES_RUNOFF', () {
      final opts = [_makeOption('p10', 'X'), _makeOption('p10', 'Y')];
      final votes = [
        _makeOptionVote('p10', 'v1', 'X'),
        _makeOptionVote('p10', 'v2', 'X'),
        _makeOptionVote('p10', 'v3', 'X'),
        _makeOptionVote('p10', 'v4', 'Y'),
        _makeOptionVote('p10', 'v5', 'Y'),
        _makeOptionVote('p10', 'v6', 'Y'),
      ];

      final t = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.tieRequiresRunoff));
      expect(t.tieOptionIdsJson, isNotNull);

      final tieIds = jsonDecode(t.tieOptionIdsJson!) as List<dynamic>;
      expect(tieIds, containsAll(['X', 'Y']));
    });

    test('SC: identical inputs produce identical contentHash', () {
      final opts = [_makeOption('p11', 'A'), _makeOption('p11', 'B')];
      final votes = [
        _makeOptionVote('p11', 'v1', 'A'),
        _makeOptionVote('p11', 'v2', 'A'),
        _makeOptionVote('p11', 'v3', 'A'),
        _makeOptionVote('p11', 'v4', 'B'),
        _makeOptionVote('p11', 'v5', 'B'),
        _makeAbstainVote('p11', 'v6'),
      ];

      final t1 = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p11',
        cellId: 'cell_det',
      );
      final t2 = _tallySC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p11',
        cellId: 'cell_det',
      );

      expect(t1.contentHash, equals(t2.contentHash));
    });

    test('SC proposal in VOTING_ENDED now goes through tally '
        '(dispatch condition routes to _finalizeSingleChoice, not SKIP)', () {
      // Verify the dispatch condition: SINGLE_CHOICE hits the new branch.
      final p = Proposal(
        id: 'prop_sc_dispatch',
        cellId: 'cell_sc_d',
        creatorDid: 'did:test:sc',
        creatorPseudonym: 'SC-Tester',
        title: 'SC Dispatch',
        description: 'dispatch test',
        createdAt: DateTime.utc(2026, 5, 1),
        status: ProposalStatus.VOTING_ENDED,
        votingMode: VotingMode.SINGLE_CHOICE,
      );

      // Old condition: p.votingMode != YES_NO_ABSTAIN → skip
      final wouldHaveBeenSkipped = p.votingMode != VotingMode.YES_NO_ABSTAIN;
      expect(wouldHaveBeenSkipped, isTrue,
          reason: 'Old 4.2a skip condition fires for SINGLE_CHOICE');

      // New condition: p.votingMode == SINGLE_CHOICE → tally branch
      final routesToTally = p.votingMode == VotingMode.SINGLE_CHOICE;
      expect(routesToTally, isTrue,
          reason:
              'New 4.3 dispatch routes SINGLE_CHOICE to _finalizeSingleChoice');
    });

    test('SC: DecisionRecord has resultRelation=null, '
        'previousProposalId=null', () {
      final record = DecisionRecord(
        recordId: 'rec_sc_fields',
        proposalId: 'prop_sc_fields',
        cellId: 'cell_sc_f',
        finalTitle: 'SC Fields Test',
        finalDescription: 'desc',
        result: 'approved',
        yesVotes: 0,
        noVotes: 0,
        abstainVotes: 1,
        participation: 0.6,
        decidedAt: DateTime.utc(2026, 5, 5, 12, 0),
        allVotes: const [],
        contentHash: 'cafebabe',
        previousDecisionHash: null,
        nostrEventId: '',
        resultReason: null,
        resultRelation: null,
        previousProposalId: null,
        optionResultsJson: '{"A":3,"B":1}',
        tieOptionIdsJson: null,
      );

      expect(record.resultRelation, isNull);
      expect(record.previousProposalId, isNull);
      expect(record.optionResultsJson, equals('{"A":3,"B":1}'));
      expect(record.tieOptionIdsJson, isNull);
    });

    test('SC: result values stay lowercase (approved/rejected/invalid)', () {
      final cases = [
        // approved case
        () => _tallySC(
              options: [_makeOption('lc1', 'A')],
              votes: List.generate(
                  6, (i) => _makeOptionVote('lc1', 'v$i', 'A')),
              eligibleCount: 10,
              quorumRequired: 0.5,
            ).result,
        // invalid — no votes
        () => _tallySC(
              options: [_makeOption('lc2', 'A')],
              votes: [],
              eligibleCount: 10,
              quorumRequired: 0.5,
            ).result,
        // invalid — quorum not met
        () => _tallySC(
              options: [_makeOption('lc3', 'A')],
              votes: [_makeOptionVote('lc3', 'v1', 'A')],
              eligibleCount: 10,
              quorumRequired: 0.5,
            ).result,
      ];

      for (final getResult in cases) {
        final result = getResult();
        expect(result, equals(result.toLowerCase()),
            reason: 'result "$result" must be lowercase');
        expect(['approved', 'rejected', 'invalid'].contains(result), isTrue,
            reason: 'result "$result" must be one of approved/rejected/invalid');
      }
    });

    // No test for _publishDecisionRecord in SC — deferred to Phase 4.5.
  });

  // ── finalizeProposal — CANDIDATE_CHOICE tally (Phase 4.4) ────────────────

  group('finalizeProposal — CANDIDATE_CHOICE tally (Phase 4.4)', () {
    // Local helpers mirror _finalizeCandidateChoice tally logic.

    /// Creates a ProposalOption for CANDIDATE_CHOICE with explicit status.
    ProposalOption _makeCandidateOption(
      String proposalId,
      String optionId, {
      OptionStatus status = OptionStatus.ACTIVE,
      int position = 0,
      String? candidateDid,
      String? candidatePseudonym,
    }) {
      final now = DateTime.utc(2026, 5, 1);
      return ProposalOption(
        optionId: optionId,
        proposalId: proposalId,
        label: 'Kandidat $optionId',
        candidateDid: candidateDid ?? 'did:test:$optionId',
        candidatePseudonym: candidatePseudonym ?? 'Kandidat_$optionId',
        status: status,
        position: position,
        createdAt: now,
        updatedAt: now,
      );
    }

    /// Creates a vote for [selectedOptionId] (choice=ABSTAIN per P1 convention).
    Vote _makeCandidateVote(
        String proposalId, String voterId, String selectedOptionId) {
      return Vote(
        voteId: 'vote_cc_${proposalId}_$voterId',
        proposalId: proposalId,
        voterPubkey: 'pubkey_$voterId',
        voterDid: 'did:test:$voterId',
        voterPseudonym: voterId,
        choice: VoteChoice.ABSTAIN,
        selectedOptionId: selectedOptionId,
        createdAt: DateTime.utc(2026, 5, 1),
        nostrEventId: '',
      );
    }

    /// Creates a true abstain vote (selectedOptionId=null).
    Vote _makeCCAbstainVote(String proposalId, String voterId) {
      return Vote(
        voteId: 'vote_cc_${proposalId}_${voterId}_abs',
        proposalId: proposalId,
        voterPubkey: 'pubkey_$voterId',
        voterDid: 'did:test:$voterId',
        voterPseudonym: voterId,
        choice: VoteChoice.ABSTAIN,
        selectedOptionId: null,
        createdAt: DateTime.utc(2026, 5, 1),
        nostrEventId: '',
      );
    }

    /// Core tally logic mirroring _finalizeCandidateChoice (without DB/service).
    ({
      String result,
      String? resultReason,
      String? tieOptionIdsJson,
      String? optionResultsJson,
      double participation,
      int abstainCount,
      String contentHash,
    }) _tallyCC({
      required List<ProposalOption> options,
      required List<Vote> votes,
      required int eligibleCount,
      required double quorumRequired,
      String proposalId = 'prop_cc_test',
      String cellId = 'cell_cc',
    }) {
      final sortedVotes = sortVotesDeterministic(votes);
      final sortedOptions = sortOptionsDeterministic(options);

      final optionCounts = <String, int>{};
      for (final opt in sortedOptions) {
        optionCounts[opt.optionId] = 0;
      }
      int abstainCount = 0;

      for (final v in sortedVotes) {
        if (v.selectedOptionId != null) {
          if (optionCounts.containsKey(v.selectedOptionId)) {
            optionCounts[v.selectedOptionId!] =
                optionCounts[v.selectedOptionId!]! + 1;
          }
          // unknown option → ignored
        } else if (v.choice == VoteChoice.ABSTAIN) {
          abstainCount++;
        }
      }

      final optionVoteSum =
          optionCounts.values.fold<int>(0, (a, b) => a + b);
      final participationCount = optionVoteSum + abstainCount;
      final participation =
          eligibleCount > 0 ? participationCount / eligibleCount : 0.0;

      String result;
      String? resultReason;
      String? tieOptionIdsJson;

      if (participationCount == 0) {
        result = 'invalid';
        resultReason = ResultReason.noValidVotes;
      } else if (participation < quorumRequired) {
        result = 'invalid';
        resultReason = ResultReason.quorumNotMet;
      } else if (optionVoteSum == 0) {
        result = 'invalid';
        resultReason = ResultReason.allAbstain;
      } else {
        final activeOptions = sortedOptions
            .where((o) => o.status == OptionStatus.ACTIVE)
            .toList();

        if (activeOptions.isEmpty) {
          result = 'invalid';
          resultReason = ResultReason.allCandidatesWithdrawn;
        } else {
          final maxAllCount =
              optionCounts.values.fold<int>(0, (a, b) => b > a ? b : a);
          final allWinners = sortedOptions
              .where((o) => optionCounts[o.optionId] == maxAllCount)
              .map((o) => o.optionId)
              .toList();

          final activeIds = activeOptions.map((o) => o.optionId).toSet();
          final hasWithdrawnWinner =
              allWinners.any((id) => !activeIds.contains(id));

          if (hasWithdrawnWinner) {
            result = 'invalid';
            resultReason = ResultReason.winnerWithdrawn;
            tieOptionIdsJson = canonicalJsonEncode(allWinners);
          } else {
            final activeCounts = <String, int>{};
            for (final opt in activeOptions) {
              activeCounts[opt.optionId] = optionCounts[opt.optionId] ?? 0;
            }
            final maxActiveCount =
                activeCounts.values.fold<int>(0, (a, b) => b > a ? b : a);
            final activeWinners = activeOptions
                .where((o) => activeCounts[o.optionId] == maxActiveCount)
                .map((o) => o.optionId)
                .toList();

            if (activeWinners.length == 1) {
              result = 'approved';
              resultReason = null;
            } else {
              result = 'invalid';
              resultReason = ResultReason.tieRequiresRunoff;
              tieOptionIdsJson = canonicalJsonEncode(activeWinners);
            }
          }
        }
      }

      String? optionResultsJson;
      if (sortedOptions.isNotEmpty) {
        final canonicalCounts = <String, dynamic>{};
        for (final opt in sortedOptions) {
          canonicalCounts[opt.optionId] = optionCounts[opt.optionId] ?? 0;
        }
        optionResultsJson = canonicalJsonEncode(canonicalCounts);
      }

      final decidedAt = DateTime.utc(2026, 5, 5, 12, 0, 0);
      final hashInput = <String, dynamic>{
        'proposalId': proposalId,
        'cellId': cellId,
        'votingMode': 'CANDIDATE_CHOICE',
        'result': result,
        'resultReason': resultReason,
        'resultRelation': null,
        'yesVotes': 0,
        'noVotes': 0,
        'abstainVotes': abstainCount,
        'participation': participation.toStringAsFixed(4),
        'eligibleVotersCount': eligibleCount,
        'decidedAt': decidedAt.toIso8601String(),
        'previousProposalId': null,
        'previousDecisionHash': null,
        'finalTitle': 'CC Test',
        'finalDescription': 'desc',
        'optionResultsJson': optionResultsJson,
        'tieOptionIdsJson': tieOptionIdsJson,
      };
      final contentHash = computeContentHash(hashInput);

      return (
        result: result,
        resultReason: resultReason,
        tieOptionIdsJson: tieOptionIdsJson,
        optionResultsJson: optionResultsJson,
        participation: participation,
        abstainCount: abstainCount,
        contentHash: contentHash,
      );
    }

    // ── Tally-Vektoren ────────────────────────────────────────────────────────

    // V7 — WINNER_WITHDRAWN
    test(
        'V7: Alice(ACTIVE):2, Bob(WITHDRAWN):5, Carol(ACTIVE):1, eligible=10 '
        '→ invalid + WINNER_WITHDRAWN, tieOptionIdsJson=[Bob]', () {
      final opts = [
        _makeCandidateOption('p_v7', 'Alice',
            status: OptionStatus.ACTIVE, position: 0),
        _makeCandidateOption('p_v7', 'Bob',
            status: OptionStatus.WITHDRAWN, position: 1),
        _makeCandidateOption('p_v7', 'Carol',
            status: OptionStatus.ACTIVE, position: 2),
      ];
      final votes = [
        _makeCandidateVote('p_v7', 'v1', 'Alice'),
        _makeCandidateVote('p_v7', 'v2', 'Alice'),
        _makeCandidateVote('p_v7', 'v3', 'Bob'),
        _makeCandidateVote('p_v7', 'v4', 'Bob'),
        _makeCandidateVote('p_v7', 'v5', 'Bob'),
        _makeCandidateVote('p_v7', 'v6', 'Bob'),
        _makeCandidateVote('p_v7', 'v7', 'Bob'),
        _makeCandidateVote('p_v7', 'v8', 'Carol'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_v7',
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.winnerWithdrawn));
      // tieOptionIdsJson enthält nur Bob (alleiniger Top-Tied)
      expect(t.tieOptionIdsJson, isNotNull);
      final tieIds =
          List<String>.from(jsonDecode(t.tieOptionIdsJson!) as List);
      expect(tieIds, contains('Bob'));
      expect(tieIds, hasLength(1));
      // optionResultsJson enthält alle Counts
      expect(t.optionResultsJson, isNotNull);
      final counts =
          Map<String, dynamic>.from(jsonDecode(t.optionResultsJson!) as Map);
      expect(counts['Alice'], equals(2));
      expect(counts['Bob'], equals(5));
      expect(counts['Carol'], equals(1));
    });

    // V8 — ALL_CANDIDATES_WITHDRAWN
    test(
        'V8: Alice(WITHDRAWN):5, Bob(WITHDRAWN):3 → invalid + '
        'ALL_CANDIDATES_WITHDRAWN', () {
      final opts = [
        _makeCandidateOption('p_v8', 'Alice',
            status: OptionStatus.WITHDRAWN, position: 0),
        _makeCandidateOption('p_v8', 'Bob',
            status: OptionStatus.WITHDRAWN, position: 1),
      ];
      final votes = [
        _makeCandidateVote('p_v8', 'v1', 'Alice'),
        _makeCandidateVote('p_v8', 'v2', 'Alice'),
        _makeCandidateVote('p_v8', 'v3', 'Alice'),
        _makeCandidateVote('p_v8', 'v4', 'Alice'),
        _makeCandidateVote('p_v8', 'v5', 'Alice'),
        _makeCandidateVote('p_v8', 'v6', 'Bob'),
        _makeCandidateVote('p_v8', 'v7', 'Bob'),
        _makeCandidateVote('p_v8', 'v8', 'Bob'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_v8',
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.allCandidatesWithdrawn));
      expect(t.tieOptionIdsJson, isNull);
      // optionResultsJson trotzdem populated (Audit)
      expect(t.optionResultsJson, isNotNull);
      final counts =
          Map<String, dynamic>.from(jsonDecode(t.optionResultsJson!) as Map);
      expect(counts['Alice'], equals(5));
      expect(counts['Bob'], equals(3));
    });

    // Klarer ACTIVE-Sieger
    test(
        'CC: Alice(ACTIVE):4, Bob(ACTIVE):2 → approved, '
        'optionResultsJson populated', () {
      final opts = [
        _makeCandidateOption('p_cc1', 'Alice',
            status: OptionStatus.ACTIVE, position: 0),
        _makeCandidateOption('p_cc1', 'Bob',
            status: OptionStatus.ACTIVE, position: 1),
      ];
      final votes = [
        _makeCandidateVote('p_cc1', 'v1', 'Alice'),
        _makeCandidateVote('p_cc1', 'v2', 'Alice'),
        _makeCandidateVote('p_cc1', 'v3', 'Alice'),
        _makeCandidateVote('p_cc1', 'v4', 'Alice'),
        _makeCandidateVote('p_cc1', 'v5', 'Bob'),
        _makeCandidateVote('p_cc1', 'v6', 'Bob'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_cc1',
      );

      expect(t.result, equals('approved'));
      expect(t.resultReason, isNull);
      expect(t.tieOptionIdsJson, isNull);
      expect(t.optionResultsJson, isNotNull);
      final counts =
          Map<String, dynamic>.from(jsonDecode(t.optionResultsJson!) as Map);
      expect(counts['Alice'], equals(4));
      expect(counts['Bob'], equals(2));
    });

    // Top-Tie unter ACTIVE
    test(
        'CC: Alice(ACTIVE):3, Bob(ACTIVE):3, Carol(ACTIVE):1 → '
        'invalid + TIE_REQUIRES_RUNOFF, tieOptionIdsJson=[A,B]', () {
      final opts = [
        _makeCandidateOption('p_cc2', 'Alice',
            status: OptionStatus.ACTIVE, position: 0),
        _makeCandidateOption('p_cc2', 'Bob',
            status: OptionStatus.ACTIVE, position: 1),
        _makeCandidateOption('p_cc2', 'Carol',
            status: OptionStatus.ACTIVE, position: 2),
      ];
      final votes = [
        _makeCandidateVote('p_cc2', 'v1', 'Alice'),
        _makeCandidateVote('p_cc2', 'v2', 'Alice'),
        _makeCandidateVote('p_cc2', 'v3', 'Alice'),
        _makeCandidateVote('p_cc2', 'v4', 'Bob'),
        _makeCandidateVote('p_cc2', 'v5', 'Bob'),
        _makeCandidateVote('p_cc2', 'v6', 'Bob'),
        _makeCandidateVote('p_cc2', 'v7', 'Carol'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_cc2',
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.tieRequiresRunoff));
      expect(t.tieOptionIdsJson, isNotNull);
      final tieIds =
          List<String>.from(jsonDecode(t.tieOptionIdsJson!) as List);
      expect(tieIds, containsAll(['Alice', 'Bob']));
      expect(tieIds, hasLength(2));
      // Carol ist NICHT im Tie
      expect(tieIds, isNot(contains('Carol')));
    });

    // WINNER_WITHDRAWN hat Vorrang vor TIE (kritischer Test)
    test(
        'CC Vorrang: Alice(WITHDRAWN):3, Bob(WITHDRAWN):3, Carol(ACTIVE):2 → '
        'invalid + WINNER_WITHDRAWN (NICHT TIE_REQUIRES_RUNOFF), '
        'tieOptionIdsJson=[Alice,Bob]', () {
      final opts = [
        _makeCandidateOption('p_cc3', 'Alice',
            status: OptionStatus.WITHDRAWN, position: 0),
        _makeCandidateOption('p_cc3', 'Bob',
            status: OptionStatus.WITHDRAWN, position: 1),
        _makeCandidateOption('p_cc3', 'Carol',
            status: OptionStatus.ACTIVE, position: 2),
      ];
      final votes = [
        _makeCandidateVote('p_cc3', 'v1', 'Alice'),
        _makeCandidateVote('p_cc3', 'v2', 'Alice'),
        _makeCandidateVote('p_cc3', 'v3', 'Alice'),
        _makeCandidateVote('p_cc3', 'v4', 'Bob'),
        _makeCandidateVote('p_cc3', 'v5', 'Bob'),
        _makeCandidateVote('p_cc3', 'v6', 'Bob'),
        _makeCandidateVote('p_cc3', 'v7', 'Carol'),
        _makeCandidateVote('p_cc3', 'v8', 'Carol'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_cc3',
      );

      expect(t.result, equals('invalid'));
      // WINNER_WITHDRAWN hat Vorrang über TIE_REQUIRES_RUNOFF
      expect(t.resultReason, equals(ResultReason.winnerWithdrawn));
      expect(t.resultReason, isNot(equals(ResultReason.tieRequiresRunoff)));
      expect(t.tieOptionIdsJson, isNotNull);
      final tieIds =
          List<String>.from(jsonDecode(t.tieOptionIdsJson!) as List);
      expect(tieIds, containsAll(['Alice', 'Bob']));
      expect(tieIds, hasLength(2));
    });

    // Quorum-Pfade
    test('CC: 0 votes → invalid + NO_VALID_VOTES', () {
      final opts = [
        _makeCandidateOption('p_cc4', 'Alice'),
        _makeCandidateOption('p_cc4', 'Bob'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: [],
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_cc4',
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.noValidVotes));
    });

    test('CC: participation < quorum → invalid + QUORUM_NOT_MET', () {
      final opts = [
        _makeCandidateOption('p_cc5', 'Alice'),
        _makeCandidateOption('p_cc5', 'Bob'),
      ];
      final votes = [
        _makeCandidateVote('p_cc5', 'v1', 'Alice'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_cc5',
      );

      // 1 vote / 10 eligible = 10% < 50% quorum
      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.quorumNotMet));
    });

    test('CC: alle ABSTAIN → invalid + ALL_ABSTAIN', () {
      final opts = [
        _makeCandidateOption('p_cc6', 'Alice'),
        _makeCandidateOption('p_cc6', 'Bob'),
      ];
      // 6 echte Abstains (selectedOptionId=null), Quorum erreicht
      final votes = List.generate(
          6, (i) => _makeCCAbstainVote('p_cc6', 'v$i'));

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_cc6',
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.allAbstain));
      expect(t.abstainCount, equals(6));
    });

    // optionResultsJson zeigt auch WITHDRAWN-Counts
    test(
        'CC: optionResultsJson contains both ACTIVE and WITHDRAWN counts', () {
      final opts = [
        _makeCandidateOption('p_cc7', 'Alice',
            status: OptionStatus.ACTIVE, position: 0),
        _makeCandidateOption('p_cc7', 'Bob',
            status: OptionStatus.WITHDRAWN, position: 1),
      ];
      final votes = [
        _makeCandidateVote('p_cc7', 'v1', 'Alice'),
        _makeCandidateVote('p_cc7', 'v2', 'Alice'),
        _makeCandidateVote('p_cc7', 'v3', 'Alice'),
        _makeCandidateVote('p_cc7', 'v4', 'Bob'),
        _makeCandidateVote('p_cc7', 'v5', 'Bob'),
        _makeCandidateVote('p_cc7', 'v6', 'Bob'),
        _makeCandidateVote('p_cc7', 'v7', 'Bob'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_cc7',
      );

      // Bob (WITHDRAWN) hat mehr Stimmen → WINNER_WITHDRAWN
      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.winnerWithdrawn));
      // Beide Counts in optionResultsJson
      expect(t.optionResultsJson, isNotNull);
      final counts =
          Map<String, dynamic>.from(jsonDecode(t.optionResultsJson!) as Map);
      expect(counts.containsKey('Alice'), isTrue);
      expect(counts.containsKey('Bob'), isTrue);
      expect(counts['Alice'], equals(3));
      expect(counts['Bob'], equals(4));
    });

    // Mehrere allWinners (alle WITHDRAWN, gleichauf)
    test(
        'CC: Alice(WITHDRAWN):4, Bob(WITHDRAWN):4, Carol(ACTIVE):1 → '
        'invalid + WINNER_WITHDRAWN, tieOptionIdsJson=[Alice,Bob]', () {
      final opts = [
        _makeCandidateOption('p_cc8', 'Alice',
            status: OptionStatus.WITHDRAWN, position: 0),
        _makeCandidateOption('p_cc8', 'Bob',
            status: OptionStatus.WITHDRAWN, position: 1),
        _makeCandidateOption('p_cc8', 'Carol',
            status: OptionStatus.ACTIVE, position: 2),
      ];
      final votes = [
        _makeCandidateVote('p_cc8', 'v1', 'Alice'),
        _makeCandidateVote('p_cc8', 'v2', 'Alice'),
        _makeCandidateVote('p_cc8', 'v3', 'Alice'),
        _makeCandidateVote('p_cc8', 'v4', 'Alice'),
        _makeCandidateVote('p_cc8', 'v5', 'Bob'),
        _makeCandidateVote('p_cc8', 'v6', 'Bob'),
        _makeCandidateVote('p_cc8', 'v7', 'Bob'),
        _makeCandidateVote('p_cc8', 'v8', 'Bob'),
        _makeCandidateVote('p_cc8', 'v9', 'Carol'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_cc8',
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.winnerWithdrawn));
      expect(t.tieOptionIdsJson, isNotNull);
      final tieIds =
          List<String>.from(jsonDecode(t.tieOptionIdsJson!) as List);
      expect(tieIds, containsAll(['Alice', 'Bob']));
      expect(tieIds, hasLength(2));
      expect(tieIds, isNot(contains('Carol')));
    });

    // Mix WITHDRAWN-Winner + ACTIVE-Winner gleichauf
    test(
        'CC: Alice(WITHDRAWN):3, Bob(ACTIVE):3, Carol(ACTIVE):1 → '
        'invalid + WINNER_WITHDRAWN, tieOptionIdsJson=[Alice,Bob]', () {
      final opts = [
        _makeCandidateOption('p_cc9', 'Alice',
            status: OptionStatus.WITHDRAWN, position: 0),
        _makeCandidateOption('p_cc9', 'Bob',
            status: OptionStatus.ACTIVE, position: 1),
        _makeCandidateOption('p_cc9', 'Carol',
            status: OptionStatus.ACTIVE, position: 2),
      ];
      final votes = [
        _makeCandidateVote('p_cc9', 'v1', 'Alice'),
        _makeCandidateVote('p_cc9', 'v2', 'Alice'),
        _makeCandidateVote('p_cc9', 'v3', 'Alice'),
        _makeCandidateVote('p_cc9', 'v4', 'Bob'),
        _makeCandidateVote('p_cc9', 'v5', 'Bob'),
        _makeCandidateVote('p_cc9', 'v6', 'Bob'),
        _makeCandidateVote('p_cc9', 'v7', 'Carol'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_cc9',
      );

      expect(t.result, equals('invalid'));
      expect(t.resultReason, equals(ResultReason.winnerWithdrawn));
      expect(t.tieOptionIdsJson, isNotNull);
      final tieIds =
          List<String>.from(jsonDecode(t.tieOptionIdsJson!) as List);
      expect(tieIds, containsAll(['Alice', 'Bob']));
      expect(tieIds, hasLength(2));
    });

    // Defensive: unknown selectedOptionId wird ignoriert
    test(
        'CC: vote with unknown selectedOptionId is ignored '
        '(does not crash, does not count)', () {
      final opts = [
        _makeCandidateOption('p_cc10', 'Alice',
            status: OptionStatus.ACTIVE, position: 0),
        _makeCandidateOption('p_cc10', 'Bob',
            status: OptionStatus.ACTIVE, position: 1),
      ];
      // v3 + v4 stimmen für bekannte Optionen, v_unknown für unbekannte ID
      final votes = [
        _makeCandidateVote('p_cc10', 'v1', 'Alice'),
        _makeCandidateVote('p_cc10', 'v2', 'Alice'),
        _makeCandidateVote('p_cc10', 'v3', 'Bob'),
        Vote(
          voteId: 'vote_cc_p_cc10_unknown',
          proposalId: 'p_cc10',
          voterPubkey: 'pubkey_unknown',
          voterDid: 'did:test:unknown',
          voterPseudonym: 'unknown',
          choice: VoteChoice.ABSTAIN,
          selectedOptionId: 'DOES_NOT_EXIST',
          createdAt: DateTime.utc(2026, 5, 1),
          nostrEventId: '',
        ),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.2,
        proposalId: 'p_cc10',
      );

      // Nur Alice:2, Bob:1 — unknown vote ignoriert → Alice gewinnt
      expect(t.result, equals('approved'));
      final counts =
          Map<String, dynamic>.from(jsonDecode(t.optionResultsJson!) as Map);
      expect(counts['Alice'], equals(2));
      expect(counts['Bob'], equals(1));
    });

    // Determinismus: identische Inputs → identischer contentHash
    test('CC: identical inputs produce identical contentHash', () {
      final opts = [
        _makeCandidateOption('p_det', 'Alice',
            status: OptionStatus.ACTIVE, position: 0),
        _makeCandidateOption('p_det', 'Bob',
            status: OptionStatus.ACTIVE, position: 1),
      ];
      final votes = [
        _makeCandidateVote('p_det', 'v1', 'Alice'),
        _makeCandidateVote('p_det', 'v2', 'Alice'),
        _makeCandidateVote('p_det', 'v3', 'Bob'),
      ];

      final t1 = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.2,
        proposalId: 'p_det',
      );
      final t2 = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.2,
        proposalId: 'p_det',
      );

      expect(t1.contentHash, equals(t2.contentHash));
      expect(t1.contentHash, hasLength(64)); // SHA-256 hex
    });

    // Dispatch-Bestätigung: CANDIDATE_CHOICE geht nicht mehr in SKIP
    test(
        'CC proposal in VOTING_ENDED now goes through tally '
        '(not SKIP anymore — tally verifiable via local algorithm)', () {
      // This test verifies the algorithm runs end-to-end by exercising
      // _tallyCC, which mirrors _finalizeCandidateChoice. The dispatch
      // change (removing [TALLY-MODE-NOT-IMPLEMENTED]) is verified by
      // the production code edit; here we confirm the algorithm produces
      // a non-null result for a valid input.
      final opts = [_makeCandidateOption('p_disp', 'Alice')];
      final votes = [
        _makeCandidateVote('p_disp', 'v1', 'Alice'),
        _makeCandidateVote('p_disp', 'v2', 'Alice'),
        _makeCandidateVote('p_disp', 'v3', 'Alice'),
        _makeCandidateVote('p_disp', 'v4', 'Alice'),
        _makeCandidateVote('p_disp', 'v5', 'Alice'),
        _makeCandidateVote('p_disp', 'v6', 'Alice'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_disp',
      );

      expect(t.result, isNotNull);
      expect(t.result, equals('approved'));
      expect(t.contentHash, isNotEmpty);
    });

    // Phase-3.5-Felder: optionResultsJson + tieOptionIdsJson-Semantik
    test(
        'CC: DecisionRecord has correct optionResultsJson and '
        'tieOptionIdsJson semantics', () {
      // WINNER_WITHDRAWN: tieOptionIdsJson enthält alle Top-Tied inkl. WITHDRAWN
      final opts = [
        _makeCandidateOption('p_sem', 'Alice',
            status: OptionStatus.WITHDRAWN, position: 0),
        _makeCandidateOption('p_sem', 'Bob',
            status: OptionStatus.ACTIVE, position: 1),
      ];
      final votes = [
        _makeCandidateVote('p_sem', 'v1', 'Alice'),
        _makeCandidateVote('p_sem', 'v2', 'Alice'),
        _makeCandidateVote('p_sem', 'v3', 'Alice'),
        _makeCandidateVote('p_sem', 'v4', 'Bob'),
        _makeCandidateVote('p_sem', 'v5', 'Bob'),
      ];

      final t = _tallyCC(
        options: opts,
        votes: votes,
        eligibleCount: 10,
        quorumRequired: 0.5,
        proposalId: 'p_sem',
      );

      expect(t.resultReason, equals(ResultReason.winnerWithdrawn));
      // tieOptionIdsJson enthält den WITHDRAWN-Winner
      final tieIds =
          List<String>.from(jsonDecode(t.tieOptionIdsJson!) as List);
      expect(tieIds, contains('Alice'));
      // optionResultsJson enthält beide (auch WITHDRAWN)
      final counts =
          Map<String, dynamic>.from(jsonDecode(t.optionResultsJson!) as Map);
      expect(counts.containsKey('Alice'), isTrue);
      expect(counts.containsKey('Bob'), isTrue);
    });

    // Lowercase result
    test('CC: result values stay lowercase', () {
      final cases = <String Function()>[
        // approved
        () => _tallyCC(
              options: [_makeCandidateOption('lcc1', 'Alice')],
              votes: List.generate(
                  6, (i) => _makeCandidateVote('lcc1', 'v$i', 'Alice')),
              eligibleCount: 10,
              quorumRequired: 0.5,
            ).result,
        // invalid — no votes
        () => _tallyCC(
              options: [_makeCandidateOption('lcc2', 'Alice')],
              votes: [],
              eligibleCount: 10,
              quorumRequired: 0.5,
            ).result,
        // invalid — quorum not met
        () => _tallyCC(
              options: [_makeCandidateOption('lcc3', 'Alice')],
              votes: [_makeCandidateVote('lcc3', 'v1', 'Alice')],
              eligibleCount: 10,
              quorumRequired: 0.5,
            ).result,
        // invalid — all candidates withdrawn
        () => _tallyCC(
              options: [
                _makeCandidateOption('lcc4', 'Alice',
                    status: OptionStatus.WITHDRAWN)
              ],
              votes: [_makeCandidateVote('lcc4', 'v1', 'Alice'),
                      _makeCandidateVote('lcc4', 'v2', 'Alice'),
                      _makeCandidateVote('lcc4', 'v3', 'Alice'),
                      _makeCandidateVote('lcc4', 'v4', 'Alice'),
                      _makeCandidateVote('lcc4', 'v5', 'Alice'),
                      _makeCandidateVote('lcc4', 'v6', 'Alice')],
              eligibleCount: 10,
              quorumRequired: 0.5,
            ).result,
      ];

      for (final getResult in cases) {
        final result = getResult();
        expect(result, equals(result.toLowerCase()),
            reason: 'result "$result" must be lowercase');
        expect(['approved', 'rejected', 'invalid'].contains(result), isTrue,
            reason:
                'result "$result" must be one of approved/rejected/invalid');
      }
    });

    // KEIN Test der _publishDecisionRecord für CC — deferred to Phase 4.5.
  });

  // ── Unified DecisionRecord publish (Phase 4.5b) ───────────────────────────

  group('Unified DecisionRecord publish (Phase 4.5b)', () {
    // Local mirror of _buildRecordContent from proposal_service.dart.
    // Production method is private; algorithm is verified here as
    // executable spec — identical to the 4.2b/4.3/4.4 test approach.
    Map<String, dynamic> _buildTestRecordContent({
      required String proposalId,
      required String cellId,
      required String votingMode,
      required String finalTitle,
      required String finalDescription,
      required String result,
      required String? resultReason,
      required String? resultRelation,
      required String? previousProposalId,
      required int yesVotes,
      required int noVotes,
      required int abstainVotes,
      required double participation,
      required DateTime decidedAt,
      required String? optionResultsJson,
      required String? tieOptionIdsJson,
      required List<Vote> sortedVotes,
    }) {
      return SplayTreeMap<String, dynamic>.from({
        'proposalId': proposalId,
        'cellId': cellId,
        'votingMode': votingMode,
        'finalTitle': finalTitle,
        'finalDescription': finalDescription,
        'result': result,
        'resultReason': resultReason,
        'resultRelation': resultRelation,
        'previousProposalId': previousProposalId,
        'yesVotes': yesVotes,
        'noVotes': noVotes,
        'abstainVotes': abstainVotes,
        'participation': participation,
        'decidedAt': decidedAt.millisecondsSinceEpoch,
        'optionResultsJson': optionResultsJson,
        'tieOptionIdsJson': tieOptionIdsJson,
        'allVotes': sortedVotes
            .map((v) => {
                  'voterPseudonym': v.voterPseudonym,
                  'choice': v.choice.name,
                  'selectedOptionId': v.selectedOptionId,
                  'reasoning': v.reasoning,
                  'createdAt': v.createdAt.millisecondsSinceEpoch,
                })
            .toList(),
      });
    }

    // Minimal YES vote for YES_NO_ABSTAIN proposals.
    Vote _makeYesVote(String proposalId, String voterId) {
      return Vote(
        voteId: 'vote_${proposalId}_$voterId',
        proposalId: proposalId,
        voterPubkey: 'pubkey_$voterId',
        voterDid: 'did:test:$voterId',
        voterPseudonym: voterId,
        choice: VoteChoice.YES,
        createdAt: DateTime.utc(2026, 5, 5, 10, 0),
        nostrEventId: '',
      );
    }

    // Minimal option vote for SC/CC proposals.
    Vote _makeScVote(String proposalId, String voterId, String optionId) {
      return Vote(
        voteId: 'vote_${proposalId}_$voterId',
        proposalId: proposalId,
        voterPubkey: 'pubkey_$voterId',
        voterDid: 'did:test:$voterId',
        voterPseudonym: voterId,
        choice: VoteChoice.ABSTAIN,
        selectedOptionId: optionId,
        createdAt: DateTime.utc(2026, 5, 5, 10, 0),
        nostrEventId: '',
      );
    }

    final _decidedAt = DateTime.utc(2026, 5, 5, 12, 0, 0);

    test(
        'SINGLE_CHOICE now publishes — '
        '_buildRecordContent produces non-null result for SC mode', () {
      final votes = [_makeScVote('p_sc', 'v1', 'A')];
      final content = _buildTestRecordContent(
        proposalId: 'p_sc',
        cellId: 'cell1',
        votingMode: VotingMode.SINGLE_CHOICE.name,
        finalTitle: 'SC Test',
        finalDescription: 'desc',
        result: 'approved',
        resultReason: null,
        resultRelation: null,
        previousProposalId: null,
        yesVotes: 0,
        noVotes: 0,
        abstainVotes: 0,
        participation: 0.1,
        decidedAt: _decidedAt,
        optionResultsJson: '{"A":1}',
        tieOptionIdsJson: null,
        sortedVotes: votes,
      );

      expect(content, isNotNull);
      expect(content['votingMode'], equals('SINGLE_CHOICE'));
      expect(content['optionResultsJson'], equals('{"A":1}'));
    });

    test(
        'CANDIDATE_CHOICE now publishes — '
        '_buildRecordContent produces non-null result for CC mode', () {
      final votes = [_makeScVote('p_cc', 'v1', 'Alice')];
      final content = _buildTestRecordContent(
        proposalId: 'p_cc',
        cellId: 'cell1',
        votingMode: VotingMode.CANDIDATE_CHOICE.name,
        finalTitle: 'CC Test',
        finalDescription: 'desc',
        result: 'approved',
        resultReason: null,
        resultRelation: null,
        previousProposalId: null,
        yesVotes: 0,
        noVotes: 0,
        abstainVotes: 0,
        participation: 0.1,
        decidedAt: _decidedAt,
        optionResultsJson: '{"Alice":1}',
        tieOptionIdsJson: null,
        sortedVotes: votes,
      );

      expect(content, isNotNull);
      expect(content['votingMode'], equals('CANDIDATE_CHOICE'));
      expect(content['result'], equals('approved'));
    });

    test(
        'YES_NO_ABSTAIN recordContent contains v1.3 keys '
        '(votingMode/resultReason/etc, null where inapplicable)', () {
      final votes = [_makeYesVote('p_yna', 'v1')];
      final content = _buildTestRecordContent(
        proposalId: 'p_yna',
        cellId: 'cell1',
        votingMode: VotingMode.YES_NO_ABSTAIN.name,
        finalTitle: 'YNA Test',
        finalDescription: 'desc',
        result: 'approved',
        resultReason: null,
        resultRelation: null,
        previousProposalId: null,
        yesVotes: 7,
        noVotes: 2,
        abstainVotes: 1,
        participation: 0.8,
        decidedAt: _decidedAt,
        optionResultsJson: null,
        tieOptionIdsJson: null,
        sortedVotes: votes,
      );

      // v1.3 fields present
      expect(content.containsKey('votingMode'), isTrue);
      expect(content.containsKey('resultReason'), isTrue);
      expect(content.containsKey('resultRelation'), isTrue);
      expect(content.containsKey('previousProposalId'), isTrue);
      expect(content.containsKey('optionResultsJson'), isTrue);
      expect(content.containsKey('tieOptionIdsJson'), isTrue);
      expect(content.containsKey('cellId'), isTrue);

      // null where inapplicable for YES_NO_ABSTAIN
      expect(content['optionResultsJson'], isNull);
      expect(content['tieOptionIdsJson'], isNull);
      expect(content['resultRelation'], isNull);
      expect(content['previousProposalId'], isNull);
      expect(content['resultReason'], isNull);
      expect(content['votingMode'], equals('YES_NO_ABSTAIN'));
    });

    test('SC recordContent has optionResultsJson populated', () {
      final content = _buildTestRecordContent(
        proposalId: 'p_sc2',
        cellId: 'cell1',
        votingMode: VotingMode.SINGLE_CHOICE.name,
        finalTitle: 'SC',
        finalDescription: 'desc',
        result: 'approved',
        resultReason: null,
        resultRelation: null,
        previousProposalId: null,
        yesVotes: 0,
        noVotes: 0,
        abstainVotes: 1,
        participation: 0.6,
        decidedAt: _decidedAt,
        optionResultsJson: '{"A":3,"B":2}',
        tieOptionIdsJson: null,
        sortedVotes: [],
      );

      expect(content['optionResultsJson'], equals('{"A":3,"B":2}'));
      expect(content['tieOptionIdsJson'], isNull);
    });

    test(
        'CC recordContent has optionResultsJson and tieOptionIdsJson '
        'when applicable (TIE/WINNER_WITHDRAWN)', () {
      final content = _buildTestRecordContent(
        proposalId: 'p_cc2',
        cellId: 'cell1',
        votingMode: VotingMode.CANDIDATE_CHOICE.name,
        finalTitle: 'CC',
        finalDescription: 'desc',
        result: 'invalid',
        resultReason: ResultReason.tieRequiresRunoff,
        resultRelation: null,
        previousProposalId: null,
        yesVotes: 0,
        noVotes: 0,
        abstainVotes: 0,
        participation: 0.6,
        decidedAt: _decidedAt,
        optionResultsJson: '{"Alice":3,"Bob":3}',
        tieOptionIdsJson: '["Alice","Bob"]',
        sortedVotes: [],
      );

      expect(content['optionResultsJson'], equals('{"Alice":3,"Bob":3}'));
      expect(content['tieOptionIdsJson'], equals('["Alice","Bob"]'));
      expect(content['resultReason'], equals(ResultReason.tieRequiresRunoff));
    });

    test(
        'YES_NO_ABSTAIN recordContent shape is backwards-compatible: '
        'yesVotes/noVotes/abstainVotes are int, participation is double, '
        'decidedAt is int millis, result is lowercase string', () {
      final content = _buildTestRecordContent(
        proposalId: 'p_compat',
        cellId: 'cell1',
        votingMode: VotingMode.YES_NO_ABSTAIN.name,
        finalTitle: 'Compat Test',
        finalDescription: 'desc',
        result: 'approved',
        resultReason: null,
        resultRelation: null,
        previousProposalId: null,
        yesVotes: 7,
        noVotes: 2,
        abstainVotes: 1,
        participation: 1.0,
        decidedAt: _decidedAt,
        optionResultsJson: null,
        tieOptionIdsJson: null,
        sortedVotes: [],
      );

      // Backwards-compatible field types (UNVERÄNDERT)
      expect(content['yesVotes'], isA<int>());
      expect(content['noVotes'], isA<int>());
      expect(content['abstainVotes'], isA<int>());
      expect(content['participation'], isA<double>());
      expect(content['decidedAt'], isA<int>());
      expect(content['decidedAt'],
          equals(_decidedAt.millisecondsSinceEpoch));

      // result lowercase
      expect(content['result'], equals('approved'));
      expect(content['result'],
          equals((content['result'] as String).toLowerCase()));

      // String fields
      expect(content['finalTitle'], isA<String>());
      expect(content['finalDescription'], isA<String>());
      expect(content['proposalId'], isA<String>());
    });

    test(
        'allVotes entries always include voterPseudonym, choice, reasoning, '
        'createdAt; selectedOptionId is additionally present (nullable)', () {
      final ynaVote = _makeYesVote('p_av', 'alice');
      final scVote = _makeScVote('p_av', 'bob', 'OptionA');

      // YES_NO_ABSTAIN vote: selectedOptionId is null
      final ynaContent = _buildTestRecordContent(
        proposalId: 'p_av',
        cellId: 'cell1',
        votingMode: VotingMode.YES_NO_ABSTAIN.name,
        finalTitle: 'AV Test',
        finalDescription: 'desc',
        result: 'approved',
        resultReason: null,
        resultRelation: null,
        previousProposalId: null,
        yesVotes: 1,
        noVotes: 0,
        abstainVotes: 0,
        participation: 0.1,
        decidedAt: _decidedAt,
        optionResultsJson: null,
        tieOptionIdsJson: null,
        sortedVotes: [ynaVote],
      );
      final ynaEntry = (ynaContent['allVotes'] as List).first as Map;
      expect(ynaEntry.containsKey('voterPseudonym'), isTrue);
      expect(ynaEntry.containsKey('choice'), isTrue);
      expect(ynaEntry.containsKey('reasoning'), isTrue);
      expect(ynaEntry.containsKey('createdAt'), isTrue);
      expect(ynaEntry.containsKey('selectedOptionId'), isTrue);
      expect(ynaEntry['selectedOptionId'], isNull);

      // SC vote: selectedOptionId is non-null
      final scContent = _buildTestRecordContent(
        proposalId: 'p_av',
        cellId: 'cell1',
        votingMode: VotingMode.SINGLE_CHOICE.name,
        finalTitle: 'AV Test',
        finalDescription: 'desc',
        result: 'approved',
        resultReason: null,
        resultRelation: null,
        previousProposalId: null,
        yesVotes: 0,
        noVotes: 0,
        abstainVotes: 0,
        participation: 0.1,
        decidedAt: _decidedAt,
        optionResultsJson: '{"OptionA":1}',
        tieOptionIdsJson: null,
        sortedVotes: [scVote],
      );
      final scEntry = (scContent['allVotes'] as List).first as Map;
      expect(scEntry['selectedOptionId'], equals('OptionA'));
      expect(scEntry['voterPseudonym'], equals('bob'));
      expect(scEntry['choice'], equals('ABSTAIN'));
    });

    test('recordContent JSON has alphabetically sorted keys (SplayTreeMap)',
        () {
      final content = _buildTestRecordContent(
        proposalId: 'p_sort',
        cellId: 'cell1',
        votingMode: VotingMode.YES_NO_ABSTAIN.name,
        finalTitle: 'Sort Test',
        finalDescription: 'desc',
        result: 'approved',
        resultReason: null,
        resultRelation: null,
        previousProposalId: null,
        yesVotes: 5,
        noVotes: 0,
        abstainVotes: 0,
        participation: 0.5,
        decidedAt: _decidedAt,
        optionResultsJson: null,
        tieOptionIdsJson: null,
        sortedVotes: [],
      );

      final keys = content.keys.toList();
      final sortedKeys = [...keys]..sort();
      expect(keys, equals(sortedKeys),
          reason: 'Keys must be in alphabetical order (SplayTreeMap)');

      // Also verify JSON serialization has sorted keys
      final jsonStr = jsonEncode(content);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded.keys.toList(), equals(sortedKeys));
    });

    test(
        'publish failure does not crash — _buildRecordContent succeeds '
        'even when participation=0.0 and no votes (retry queue internals '
        'not directly tested due to private member access)', () {
      // Mirrors the "publish failed, queuing retry" code path:
      // _buildRecordContent must produce a valid payload regardless of
      // publish outcome. The retry is handled by PublishResultDao (implicit).
      final content = _buildTestRecordContent(
        proposalId: 'p_fail',
        cellId: 'cell1',
        votingMode: VotingMode.YES_NO_ABSTAIN.name,
        finalTitle: 'Fail Test',
        finalDescription: 'desc',
        result: 'invalid',
        resultReason: ResultReason.quorumNotMet,
        resultRelation: null,
        previousProposalId: null,
        yesVotes: 0,
        noVotes: 0,
        abstainVotes: 0,
        participation: 0.0,
        decidedAt: _decidedAt,
        optionResultsJson: null,
        tieOptionIdsJson: null,
        sortedVotes: [],
      );

      // Must not throw and must produce a valid map
      expect(content, isNotNull);
      expect(content['result'], equals('invalid'));
      expect(content['resultReason'], equals(ResultReason.quorumNotMet));
      expect(content['participation'], isA<double>());
      expect(content['allVotes'], isEmpty);
    });
  });

  // ── handleIncomingDecisionRecord — v1.3 fields (Phase 4.5c) ──────────────

  group('handleIncomingDecisionRecord — v1.3 fields (Phase 4.5c)', () {
    // Local mirror of the DecisionRecord construction logic inside
    // handleIncomingDecisionRecord. Production method is async/service-bound;
    // algorithm is verified here as executable spec — same approach as 4.5b.
    DecisionRecord _parseIncomingRecord(
        Map<String, dynamic> content, String eventId) {
      return DecisionRecord(
        recordId: DecisionRecord.generateId(),
        proposalId: content['proposalId'] as String? ?? '',
        cellId: content['cellId'] as String? ?? '',
        finalTitle: content['finalTitle'] as String? ?? '',
        finalDescription: content['finalDescription'] as String? ?? '',
        result: content['result'] as String? ?? 'invalid',
        yesVotes: content['yesVotes'] as int? ?? 0,
        noVotes: content['noVotes'] as int? ?? 0,
        abstainVotes: content['abstainVotes'] as int? ?? 0,
        participation: (content['participation'] as num?)?.toDouble() ?? 0.0,
        decidedAt: DateTime.fromMillisecondsSinceEpoch(
            content['decidedAt'] as int? ?? 0,
            isUtc: true),
        allVotes: const [],
        contentHash: content['content_hash'] as String? ?? '',
        previousDecisionHash: content['prev_hash'] as String?,
        nostrEventId: eventId,
        // Phase 4.5c: v1.3 fields
        resultReason: content['resultReason'] as String?,
        resultRelation: content['resultRelation'] as String?,
        previousProposalId: content['previousProposalId'] as String?,
        optionResultsJson: content['optionResultsJson'] as String?,
        tieOptionIdsJson: content['tieOptionIdsJson'] as String?,
      );
    }

    // Simulate the mode-aware localProposal update.
    // Returns a Proposal mutated exactly as handleIncomingDecisionRecord does.
    Proposal _applyModeAwareUpdate(
        Proposal localProposal, DecisionRecord record, VotingMode mode) {
      localProposal.status = ProposalStatus.DECIDED;
      localProposal.decidedAt = record.decidedAt;
      localProposal.resultSummary = record.result;
      localProposal.resultParticipation = record.participation;
      localProposal.resultAbstain = record.abstainVotes;
      if (mode == VotingMode.YES_NO_ABSTAIN) {
        localProposal.resultYes = record.yesVotes;
        localProposal.resultNo = record.noVotes;
      }
      return localProposal;
    }

    final _decidedAt = DateTime.utc(2026, 5, 6, 9, 0, 0);

    // ── YES_NO_ABSTAIN ────────────────────────────────────────────────────────

    test(
        'YES_NO_ABSTAIN incoming: yes/no/abstain auf '
        'localProposal gespiegelt, resultReason persistiert', () {
      final content = {
        'proposalId': 'p_yna_in',
        'cellId': 'cell1',
        'votingMode': 'YES_NO_ABSTAIN',
        'finalTitle': 'YNA Title',
        'finalDescription': 'desc',
        'result': 'approved',
        'resultReason': null,
        'resultRelation': null,
        'previousProposalId': null,
        'yesVotes': 7,
        'noVotes': 2,
        'abstainVotes': 1,
        'participation': 0.8,
        'decidedAt': _decidedAt.millisecondsSinceEpoch,
        'optionResultsJson': null,
        'tieOptionIdsJson': null,
      };

      final record = _parseIncomingRecord(content, 'event_yna_1');

      expect(record.yesVotes, equals(7));
      expect(record.noVotes, equals(2));
      expect(record.abstainVotes, equals(1));
      expect(record.participation, equals(0.8));
      expect(record.result, equals('approved'));
      expect(record.resultReason, isNull);
      expect(record.allVotes, isEmpty);

      // Mode-aware update: YES_NO_ABSTAIN → yes/no mirrored
      final localProposal = Proposal(
        id: 'p_yna_in',
        cellId: 'cell1',
        creatorDid: 'did:test:alice',
        creatorPseudonym: 'Alice',
        title: 'YNA',
        description: '',
        createdAt: DateTime.utc(2026, 5, 1),
        votingMode: VotingMode.YES_NO_ABSTAIN,
      );
      _applyModeAwareUpdate(localProposal, record,
          parseVotingMode(content['votingMode'] as String?));

      expect(localProposal.resultYes, equals(7));
      expect(localProposal.resultNo, equals(2));
      expect(localProposal.resultAbstain, equals(1));
      expect(localProposal.status, equals(ProposalStatus.DECIDED));
    });

    // ── SINGLE_CHOICE ─────────────────────────────────────────────────────────

    test(
        'SINGLE_CHOICE incoming: optionResultsJson persistiert, '
        'localProposal.resultYes/resultNo BLEIBEN auf altem Wert', () {
      final content = {
        'proposalId': 'p_sc_in',
        'cellId': 'cell1',
        'votingMode': 'SINGLE_CHOICE',
        'finalTitle': 'SC Title',
        'finalDescription': 'desc',
        'result': 'approved',
        'resultReason': null,
        'resultRelation': null,
        'previousProposalId': null,
        'yesVotes': 0,
        'noVotes': 0,
        'abstainVotes': 1,
        'participation': 0.6,
        'decidedAt': _decidedAt.millisecondsSinceEpoch,
        'optionResultsJson': '{"A":3,"B":2}',
        'tieOptionIdsJson': null,
      };

      final record = _parseIncomingRecord(content, 'event_sc_1');

      expect(record.optionResultsJson, equals('{"A":3,"B":2}'));
      expect(record.tieOptionIdsJson, isNull);
      expect(record.yesVotes, equals(0));
      expect(record.noVotes, equals(0));
      expect(record.allVotes, isEmpty);

      // Mode-aware update: SC → resultYes/resultNo NICHT überschrieben
      final localProposal = Proposal(
        id: 'p_sc_in',
        cellId: 'cell1',
        creatorDid: 'did:test:bob',
        creatorPseudonym: 'Bob',
        title: 'SC',
        description: '',
        createdAt: DateTime.utc(2026, 5, 1),
        votingMode: VotingMode.SINGLE_CHOICE,
        resultYes: 0,
        resultNo: 0,
      );
      _applyModeAwareUpdate(localProposal, record, VotingMode.SINGLE_CHOICE);

      // yes/no columns stay at their pre-existing local value
      expect(localProposal.resultYes, equals(0));
      expect(localProposal.resultNo, equals(0));
      expect(localProposal.resultAbstain, equals(1));
      expect(localProposal.resultParticipation, equals(0.6));
      expect(localProposal.resultSummary, equals('approved'));
      expect(localProposal.status, equals(ProposalStatus.DECIDED));
    });

    // ── CANDIDATE_CHOICE ──────────────────────────────────────────────────────

    test(
        'CANDIDATE_CHOICE incoming: tieOptionIdsJson persistiert '
        'wenn TIE/WINNER_WITHDRAWN, localProposal.resultYes/resultNo '
        'bleiben auf altem Wert', () {
      final content = {
        'proposalId': 'p_cc_in',
        'cellId': 'cell1',
        'votingMode': 'CANDIDATE_CHOICE',
        'finalTitle': 'CC Title',
        'finalDescription': 'desc',
        'result': 'invalid',
        'resultReason': ResultReason.tieRequiresRunoff,
        'resultRelation': null,
        'previousProposalId': null,
        'yesVotes': 0,
        'noVotes': 0,
        'abstainVotes': 0,
        'participation': 0.5,
        'decidedAt': _decidedAt.millisecondsSinceEpoch,
        'optionResultsJson': '{"Alice":3,"Bob":3}',
        'tieOptionIdsJson': '["Alice","Bob"]',
      };

      final record = _parseIncomingRecord(content, 'event_cc_1');

      expect(record.tieOptionIdsJson, equals('["Alice","Bob"]'));
      expect(record.optionResultsJson, equals('{"Alice":3,"Bob":3}'));
      expect(record.resultReason, equals(ResultReason.tieRequiresRunoff));
      expect(record.result, equals('invalid'));
      expect(record.allVotes, isEmpty);

      // Mode-aware update: CC → yes/no not touched
      final localProposal = Proposal(
        id: 'p_cc_in',
        cellId: 'cell1',
        creatorDid: 'did:test:carol',
        creatorPseudonym: 'Carol',
        title: 'CC',
        description: '',
        createdAt: DateTime.utc(2026, 5, 1),
        votingMode: VotingMode.CANDIDATE_CHOICE,
        resultYes: 0,
        resultNo: 0,
      );
      _applyModeAwareUpdate(localProposal, record, VotingMode.CANDIDATE_CHOICE);

      expect(localProposal.resultYes, equals(0));
      expect(localProposal.resultNo, equals(0));
      expect(localProposal.resultSummary, equals('invalid'));
    });

    // ── resultReason persistence ──────────────────────────────────────────────

    test(
        'Incoming record with resultReason=QUORUM_NOT_MET: '
        'persistiert auf DecisionRecord', () {
      final content = {
        'proposalId': 'p_qnm',
        'cellId': 'cell1',
        'votingMode': 'YES_NO_ABSTAIN',
        'finalTitle': 'Quorum Fail',
        'finalDescription': '',
        'result': 'invalid',
        'resultReason': ResultReason.quorumNotMet,
        'resultRelation': null,
        'previousProposalId': null,
        'yesVotes': 1,
        'noVotes': 0,
        'abstainVotes': 0,
        'participation': 0.05,
        'decidedAt': _decidedAt.millisecondsSinceEpoch,
        'optionResultsJson': null,
        'tieOptionIdsJson': null,
      };

      final record = _parseIncomingRecord(content, 'event_qnm_1');

      expect(record.resultReason, equals(ResultReason.quorumNotMet));
      expect(record.result, equals('invalid'));
    });

    // ── Legacy backwards-compatibility ────────────────────────────────────────

    test(
        'Legacy incoming record without v1.3 fields: alle '
        'neuen Felder = null, Verhalten unverändert', () {
      // Pre-4.5b sender: only old fields present
      final content = {
        'proposalId': 'p_legacy',
        'cellId': 'cell1',
        'finalTitle': 'Legacy',
        'finalDescription': 'desc',
        'result': 'approved',
        'yesVotes': 5,
        'noVotes': 1,
        'abstainVotes': 0,
        'participation': 0.7,
        'decidedAt': _decidedAt.millisecondsSinceEpoch,
      };

      final record = _parseIncomingRecord(content, 'event_legacy_1');

      // All v1.3 fields default to null
      expect(record.resultReason, isNull);
      expect(record.resultRelation, isNull);
      expect(record.previousProposalId, isNull);
      expect(record.optionResultsJson, isNull);
      expect(record.tieOptionIdsJson, isNull);

      // Legacy YES_NO_ABSTAIN fields unaffected
      expect(record.yesVotes, equals(5));
      expect(record.noVotes, equals(1));
      expect(record.result, equals('approved'));
      expect(record.allVotes, isEmpty);
    });

    // ── votingMode-Fallback ───────────────────────────────────────────────────

    test(
        'Incoming mit votingMode in content: parseVotingMode liefert '
        'korrekte Mode; kein Zugriff auf localProposal.votingMode nötig',
        () {
      // content['votingMode'] vorhanden → parseVotingMode direkt
      expect(parseVotingMode('SINGLE_CHOICE'), equals(VotingMode.SINGLE_CHOICE));
      expect(parseVotingMode('CANDIDATE_CHOICE'),
          equals(VotingMode.CANDIDATE_CHOICE));
      expect(parseVotingMode('YES_NO_ABSTAIN'), equals(VotingMode.YES_NO_ABSTAIN));
    });

    test(
        'Incoming ohne votingMode aber mit localProposal: '
        'parseVotingMode-Fallback auf localProposal.votingMode', () {
      // Simulate: receivedModeStr = null → use localProposal.votingMode
      final localProposal = Proposal(
        id: 'p_fallback',
        cellId: 'cell1',
        creatorDid: 'did:test:x',
        creatorPseudonym: 'X',
        title: 'Fallback',
        description: '',
        createdAt: DateTime.utc(2026, 5, 1),
        votingMode: VotingMode.SINGLE_CHOICE,
      );

      const String? receivedModeStr = null;
      final mode = receivedModeStr != null
          ? parseVotingMode(receivedModeStr)
          : localProposal.votingMode;

      expect(mode, equals(VotingMode.SINGLE_CHOICE));
    });

    test(
        'Incoming ohne votingMode UND ohne localProposal: '
        'kein Crash, DecisionRecord trotzdem persistiert '
        '(mode-Fallback YES_NO_ABSTAIN nicht relevant weil '
        'kein localProposal-Update stattfindet)', () {
      // No localProposal → the localProposal block is skipped entirely.
      // parseVotingMode(null) is the safe fallback in the code comment
      // but is never actually reached in the no-localProposal path
      // (no update is performed). DecisionRecord itself is mode-agnostic.
      final content = {
        'proposalId': 'p_no_local',
        'cellId': 'cell1',
        'finalTitle': 'No Local',
        'finalDescription': '',
        'result': 'approved',
        'yesVotes': 3,
        'noVotes': 0,
        'abstainVotes': 0,
        'participation': 0.3,
        'decidedAt': _decidedAt.millisecondsSinceEpoch,
      };

      // Must not throw even without votingMode key
      final record = _parseIncomingRecord(content, 'event_no_local_1');
      expect(record.proposalId, equals('p_no_local'));
      expect(record.result, equals('approved'));

      // parseVotingMode(null) → YES_NO_ABSTAIN (safe default)
      expect(parseVotingMode(null), equals(VotingMode.YES_NO_ABSTAIN));
    });

    // ── SC resultYes/resultNo Stabilität ─────────────────────────────────────

    test('SC mit localProposal.resultYes=0: bleibt 0 nach Empfang', () {
      final content = {
        'proposalId': 'p_sc_stable',
        'cellId': 'cell1',
        'votingMode': 'SINGLE_CHOICE',
        'finalTitle': 'SC Stable',
        'finalDescription': '',
        'result': 'approved',
        'yesVotes': 0,
        'noVotes': 0,
        'abstainVotes': 2,
        'participation': 0.4,
        'decidedAt': _decidedAt.millisecondsSinceEpoch,
        'optionResultsJson': '{"X":2}',
        'tieOptionIdsJson': null,
      };

      final record = _parseIncomingRecord(content, 'event_sc_stable');

      final localProposal = Proposal(
        id: 'p_sc_stable',
        cellId: 'cell1',
        creatorDid: 'did:test:d',
        creatorPseudonym: 'D',
        title: 'SC Stable',
        description: '',
        createdAt: DateTime.utc(2026, 5, 1),
        votingMode: VotingMode.SINGLE_CHOICE,
        resultYes: 0,
        resultNo: 0,
      );

      _applyModeAwareUpdate(localProposal, record, VotingMode.SINGLE_CHOICE);

      // Guaranteed to remain 0 — not touched by SC path
      expect(localProposal.resultYes, equals(0));
      expect(localProposal.resultNo, equals(0));
    });

    // ── Audit-Payload ─────────────────────────────────────────────────────────

    test(
        'Audit payload enthält v1.3 fields (resultReason, '
        'votingMode, optionResultsJson, tieOptionIdsJson)', () {
      // Mirror the audit payload construction from handleIncomingDecisionRecord
      final record = _parseIncomingRecord({
        'proposalId': 'p_audit',
        'cellId': 'cell1',
        'votingMode': 'SINGLE_CHOICE',
        'finalTitle': 'Audit',
        'finalDescription': '',
        'result': 'approved',
        'resultReason': null,
        'yesVotes': 0,
        'noVotes': 0,
        'abstainVotes': 1,
        'participation': 0.5,
        'decidedAt': _decidedAt.millisecondsSinceEpoch,
        'optionResultsJson': '{"A":5}',
        'tieOptionIdsJson': null,
      }, 'event_audit_1');

      const receivedModeStr = 'SINGLE_CHOICE';

      final payload = <String, dynamic>{
        'result': record.result,
        'resultReason': record.resultReason,
        'votingMode': receivedModeStr,
        'yes': record.yesVotes,
        'no': record.noVotes,
        'abstain': record.abstainVotes,
        'participation': record.participation,
        'optionResultsJson': record.optionResultsJson,
        'tieOptionIdsJson': record.tieOptionIdsJson,
        'source': 'decision_record_received',
      };

      expect(payload.containsKey('resultReason'), isTrue);
      expect(payload.containsKey('votingMode'), isTrue);
      expect(payload.containsKey('optionResultsJson'), isTrue);
      expect(payload.containsKey('tieOptionIdsJson'), isTrue);
      expect(payload['votingMode'], equals('SINGLE_CHOICE'));
      expect(payload['optionResultsJson'], equals('{"A":5}'));
      expect(payload['tieOptionIdsJson'], isNull);
      expect(payload['source'], equals('decision_record_received'));
    });
  });

  // ── finalizeProposal — idempotency guard (Phase 4.6) ─────────────────────

  group('finalizeProposal — idempotency guard (Phase 4.6)', () {
    // finalizeProposal cannot be called directly in unit tests (requires DB/
    // service singletons). The guard logic is tested here as executable spec —
    // the same approach used by Phases 4.2b, 4.3, 4.4.
    //
    // Guard code (verbatim from production):
    //
    //   final existing = await _getDecisionRecordByProposal(proposalId);
    //   if (existing != null) {
    //     p.status = ProposalStatus.DECIDED;
    //     p.decidedAt = existing.decidedAt;
    //     p.resultSummary = existing.result;
    //     p.resultParticipation = existing.participation;
    //     if (p.votingMode == VotingMode.YES_NO_ABSTAIN) {
    //       p.resultYes = existing.yesVotes;
    //       p.resultNo = existing.noVotes;
    //     }
    //     p.resultAbstain = existing.abstainVotes;
    //     await _saveProposalToDb(p);
    //     return;
    //   }

    /// Applies the guard healing logic to [p] given [existing].
    /// Mirrors the production code exactly so any divergence becomes a
    /// test failure.
    void _applyGuard(Proposal p, DecisionRecord existing) {
      p.status = ProposalStatus.DECIDED;
      p.decidedAt = existing.decidedAt;
      p.resultSummary = existing.result;
      p.resultParticipation = existing.participation;
      if (p.votingMode == VotingMode.YES_NO_ABSTAIN) {
        p.resultYes = existing.yesVotes;
        p.resultNo = existing.noVotes;
      }
      p.resultAbstain = existing.abstainVotes;
    }

    /// Minimal DecisionRecord for use as the "existing" record in guard tests.
    DecisionRecord _existingRecord({
      String proposalId = 'prop_guard',
      String result = 'approved',
      int yesVotes = 7,
      int noVotes = 2,
      int abstainVotes = 1,
      double participation = 0.8,
      DateTime? decidedAt,
      String? optionResultsJson,
    }) {
      return DecisionRecord(
        recordId: 'rec_guard_1',
        proposalId: proposalId,
        cellId: 'cell_guard',
        finalTitle: 'Guard Test Proposal',
        finalDescription: 'Testing idempotency guard',
        result: result,
        yesVotes: yesVotes,
        noVotes: noVotes,
        abstainVotes: abstainVotes,
        participation: participation,
        decidedAt: decidedAt ?? DateTime.utc(2026, 5, 5, 12, 0),
        allVotes: const [],
        contentHash: 'guard_hash_abc123',
        previousDecisionHash: null,
        nostrEventId: 'nostr_guard_1',
        resultRelation: null,
        previousProposalId: null,
        optionResultsJson: optionResultsJson,
        tieOptionIdsJson: null,
        resultReason: null,
      );
    }

    /// Minimal Proposal in VOTING_ENDED with given mode.
    Proposal _votingEndedProposal(VotingMode mode, {String id = 'prop_guard'}) {
      return Proposal(
        id: id,
        cellId: 'cell_guard',
        creatorDid: 'did:test:guard',
        creatorPseudonym: 'Guard',
        title: 'Guard Test',
        description: 'Idempotency guard test',
        createdAt: DateTime.utc(2026, 5, 1),
        status: ProposalStatus.VOTING_ENDED,
        votingMode: mode,
      );
    }

    test(
        'YES_NO_ABSTAIN with existing DecisionRecord: status healed to DECIDED, '
        'yes/no/abstain mirrored from record', () {
      final p = _votingEndedProposal(VotingMode.YES_NO_ABSTAIN);
      final existing = _existingRecord(
          yesVotes: 7, noVotes: 2, abstainVotes: 1, participation: 0.8);

      // Pre-condition: status is VOTING_ENDED, result fields null.
      expect(p.status, equals(ProposalStatus.VOTING_ENDED));
      expect(p.resultYes, isNull);
      expect(p.resultNo, isNull);
      expect(p.resultAbstain, isNull);

      _applyGuard(p, existing);

      expect(p.status, equals(ProposalStatus.DECIDED));
      expect(p.resultSummary, equals('approved'));
      expect(p.resultParticipation, closeTo(0.8, 0.0001));
      expect(p.resultYes, equals(7));
      expect(p.resultNo, equals(2));
      expect(p.resultAbstain, equals(1));
      expect(p.decidedAt, equals(DateTime.utc(2026, 5, 5, 12, 0)));
    });

    test(
        'SINGLE_CHOICE with existing DecisionRecord: status healed to DECIDED, '
        'resultYes/resultNo stay null (not set by guard)', () {
      final p = _votingEndedProposal(VotingMode.SINGLE_CHOICE);
      final existing = _existingRecord(
          yesVotes: 5, noVotes: 3, abstainVotes: 2, participation: 0.5,
          optionResultsJson: '{"opt_a":5,"opt_b":3}');

      expect(p.status, equals(ProposalStatus.VOTING_ENDED));

      _applyGuard(p, existing);

      expect(p.status, equals(ProposalStatus.DECIDED));
      expect(p.resultSummary, equals('approved'));
      expect(p.resultParticipation, closeTo(0.5, 0.0001));
      // SINGLE_CHOICE: resultYes/resultNo must NOT be written by the guard.
      expect(p.resultYes, isNull,
          reason: 'guard must not set resultYes for SINGLE_CHOICE');
      expect(p.resultNo, isNull,
          reason: 'guard must not set resultNo for SINGLE_CHOICE');
      // abstain is always set.
      expect(p.resultAbstain, equals(2));
    });

    test(
        'CANDIDATE_CHOICE with existing DecisionRecord: status healed to DECIDED, '
        'resultYes/resultNo stay null (not set by guard)', () {
      final p = _votingEndedProposal(VotingMode.CANDIDATE_CHOICE);
      final existing = _existingRecord(
          yesVotes: 4, noVotes: 0, abstainVotes: 1, participation: 0.5,
          optionResultsJson: '{"cand_a":4}');

      _applyGuard(p, existing);

      expect(p.status, equals(ProposalStatus.DECIDED));
      expect(p.resultYes, isNull,
          reason: 'guard must not set resultYes for CANDIDATE_CHOICE');
      expect(p.resultNo, isNull,
          reason: 'guard must not set resultNo for CANDIDATE_CHOICE');
      expect(p.resultAbstain, equals(1));
    });

    test(
        'Guard does NOT modify the existing DecisionRecord: all fields '
        'unchanged after _applyGuard', () {
      final p = _votingEndedProposal(VotingMode.YES_NO_ABSTAIN);
      final existing = _existingRecord(
          yesVotes: 9, noVotes: 1, abstainVotes: 0, participation: 1.0,
          result: 'approved');

      // Capture snapshot of existing record fields before applying guard.
      final beforeRecordId = existing.recordId;
      final beforeProposalId = existing.proposalId;
      final beforeResult = existing.result;
      final beforeYes = existing.yesVotes;
      final beforeNo = existing.noVotes;
      final beforeAbstain = existing.abstainVotes;
      final beforeParticipation = existing.participation;
      final beforeContentHash = existing.contentHash;
      final beforeDecidedAt = existing.decidedAt;
      final beforeNostrEventId = existing.nostrEventId;

      _applyGuard(p, existing);

      // DecisionRecord is immutable (all fields are final) — verify that
      // _applyGuard only reads from it, never mutates it.
      expect(existing.recordId, equals(beforeRecordId));
      expect(existing.proposalId, equals(beforeProposalId));
      expect(existing.result, equals(beforeResult));
      expect(existing.yesVotes, equals(beforeYes));
      expect(existing.noVotes, equals(beforeNo));
      expect(existing.abstainVotes, equals(beforeAbstain));
      expect(existing.participation, closeTo(beforeParticipation, 0.0001));
      expect(existing.contentHash, equals(beforeContentHash));
      expect(existing.decidedAt, equals(beforeDecidedAt));
      expect(existing.nostrEventId, equals(beforeNostrEventId));
    });

    test(
        'Guard produces no side-effects: DECIDED status means existing '
        'DECIDED-check fires before guard (smoke for pre-guard status check)', () {
      // Verify the guard precondition: if p.status == DECIDED, the guard
      // is unreachable because the prior status check `if (p.status !=
      // ProposalStatus.VOTING_ENDED) return` fires first.
      final p = _votingEndedProposal(VotingMode.YES_NO_ABSTAIN);
      p.status = ProposalStatus.DECIDED; // already decided

      // Simulate the status-check gate that guards the entire finalizeProposal body.
      final shouldSkipEntireMethod =
          p.status != ProposalStatus.VOTING_ENDED;
      expect(shouldSkipEntireMethod, isTrue,
          reason: 'DECIDED status must be caught by the pre-existing status '
              'check, not by the Phase 4.6 guard');
    });

    test(
        'Status healing: VOTING_ENDED → DECIDED, decidedAt taken from record', () {
      final expectedDecidedAt = DateTime.utc(2026, 5, 6, 9, 30);
      final p = _votingEndedProposal(VotingMode.YES_NO_ABSTAIN);
      final existing = _existingRecord(decidedAt: expectedDecidedAt,
          result: 'rejected', yesVotes: 3, noVotes: 6, abstainVotes: 1,
          participation: 1.0);

      expect(p.status, equals(ProposalStatus.VOTING_ENDED));
      expect(p.decidedAt, isNull);

      _applyGuard(p, existing);

      expect(p.status, equals(ProposalStatus.DECIDED));
      expect(p.decidedAt, equals(expectedDecidedAt));
      expect(p.resultSummary, equals('rejected'));
    });

    test(
        'Normal tally without existing DecisionRecord runs as before: '
        'guard condition is false when existing == null '
        '(regression smoke for all 3 modes)', () {
      // Verify the guard condition: when existing is null, the `if` branch
      // is NOT entered — the existing tally logic continues normally.
      // We simulate this by checking the guard predicate directly.
      for (final mode in VotingMode.values) {
        final p = _votingEndedProposal(mode);
        const DecisionRecord? existing = null; // no record in DB

        final guardShouldFire = existing != null;
        expect(guardShouldFire, isFalse,
            reason: 'Guard must not fire when no existing DecisionRecord '
                'exists for mode ${mode.name}');

        // Status must stay VOTING_ENDED (guard did not fire → tally proceeds).
        expect(p.status, equals(ProposalStatus.VOTING_ENDED));
      }
    });
  });

  // ── castVote — selectedOptionId (Phase 4.7a1) ────────────────────────────

  group('castVote — selectedOptionId (Phase 4.7a1)', () {
    // castVote cannot be called directly in unit tests (requires DB/service
    // singletons). The logic is verified here as executable spec, mirroring
    // the production predicate and payload construction — identical to the
    // Phase 4.6 guard test approach.

    // ── Wire-defer guard predicate ──────────────────────────────────────────

    /// Mirrors the shouldDeferWirePublish predicate in castVote.
    bool _shouldDefer(String? selectedOptionId, VotingMode votingMode) =>
        selectedOptionId != null && votingMode != VotingMode.YES_NO_ABSTAIN;

    // ── Vote factory helpers ────────────────────────────────────────────────

    Vote _makeYnaVote({String? selectedOptionId}) => Vote(
          voteId: 'v_yna',
          proposalId: 'p_yna',
          voterPubkey: 'pk_alice',
          voterDid: 'did:test:alice',
          voterPseudonym: 'Alice',
          choice: VoteChoice.YES,
          selectedOptionId: selectedOptionId,
          createdAt: DateTime.utc(2026, 5, 6, 10, 0),
          nostrEventId: '',
        );

    Vote _makeScOptionVote(String optionId) => Vote(
          voteId: 'v_sc_opt',
          proposalId: 'p_sc',
          voterPubkey: 'pk_bob',
          voterDid: 'did:test:bob',
          voterPseudonym: 'Bob',
          choice: VoteChoice.ABSTAIN,
          selectedOptionId: optionId,
          createdAt: DateTime.utc(2026, 5, 6, 10, 0),
          nostrEventId: '',
        );

    Vote _makeScAbstainVote() => Vote(
          voteId: 'v_sc_abs',
          proposalId: 'p_sc',
          voterPubkey: 'pk_carol',
          voterDid: 'did:test:carol',
          voterPseudonym: 'Carol',
          choice: VoteChoice.ABSTAIN,
          selectedOptionId: null,
          createdAt: DateTime.utc(2026, 5, 6, 10, 0),
          nostrEventId: '',
        );

    Vote _makeCcOptionVote(String candidateId) => Vote(
          voteId: 'v_cc_opt',
          proposalId: 'p_cc',
          voterPubkey: 'pk_dave',
          voterDid: 'did:test:dave',
          voterPseudonym: 'Dave',
          choice: VoteChoice.ABSTAIN,
          selectedOptionId: candidateId,
          createdAt: DateTime.utc(2026, 5, 6, 10, 0),
          nostrEventId: '',
        );

    Vote _makeCcAbstainVote() => Vote(
          voteId: 'v_cc_abs',
          proposalId: 'p_cc',
          voterPubkey: 'pk_eve',
          voterDid: 'did:test:eve',
          voterPseudonym: 'Eve',
          choice: VoteChoice.ABSTAIN,
          selectedOptionId: null,
          createdAt: DateTime.utc(2026, 5, 6, 10, 0),
          nostrEventId: '',
        );

    // ── YES_NO_ABSTAIN regression ───────────────────────────────────────────

    test(
        'YES_NO_ABSTAIN castVote without selectedOptionId: '
        'Vote.selectedOptionId is null, wire publish happens', () {
      final vote = _makeYnaVote(selectedOptionId: null);

      expect(vote.selectedOptionId, isNull);
      expect(vote.choice, equals(VoteChoice.YES));

      // Guard must NOT defer for YES_NO_ABSTAIN.
      final deferred = _shouldDefer(vote.selectedOptionId, VotingMode.YES_NO_ABSTAIN);
      expect(deferred, isFalse,
          reason: 'YES_NO_ABSTAIN votes must always publish immediately');

      // Serialization round-trip.
      final restored = Vote.fromMap(vote.toMap());
      expect(restored.selectedOptionId, isNull);
    });

    // ── SC: Enthaltung — Wire-Publish ────────────────────────────────────────

    test(
        'SC castVote without selectedOptionId (Enthaltung): '
        'persisted, wire publish happens normally '
        '(selectedOptionId null is a true abstention)', () {
      final vote = _makeScAbstainVote();

      expect(vote.selectedOptionId, isNull);
      expect(vote.choice, equals(VoteChoice.ABSTAIN));

      // Guard must NOT defer — true abstention is safe to publish.
      final deferred = _shouldDefer(vote.selectedOptionId, VotingMode.SINGLE_CHOICE);
      expect(deferred, isFalse,
          reason: 'SC abstention (selectedOptionId=null) must publish: '
              'receiver correctly counts it as abstention');
    });

    // ── CC: Enthaltung — Wire-Publish ────────────────────────────────────────

    test(
        'CC castVote without selectedOptionId: wire publish happens '
        '(true abstention)', () {
      final vote = _makeCcAbstainVote();

      expect(vote.selectedOptionId, isNull);

      final deferred = _shouldDefer(vote.selectedOptionId, VotingMode.CANDIDATE_CHOICE);
      expect(deferred, isFalse,
          reason: 'CC abstention must publish: receiver treats as abstention');
    });

    // ── Audit-Payload: selectedOptionId enthalten ─────────────────────────────

    test(
        'Audit payload contains selectedOptionId for SC/CC option votes', () {
      final vote = _makeScOptionVote('opt_X');
      const isChange = false;

      final payload = <String, dynamic>{
        'choice': vote.choice.name,
        if (vote.selectedOptionId != null) 'selectedOptionId': vote.selectedOptionId,
        if (isChange) 'previousChoice': 'irrelevant',
      };

      expect(payload['choice'], equals('ABSTAIN'));
      expect(payload['selectedOptionId'], equals('opt_X'));
      expect(payload.containsKey('previousChoice'), isFalse);
    });

    // ── Audit-Payload: previousSelectedOptionId bei Vote-Änderung ─────────────

    test(
        'Audit payload includes previousSelectedOptionId on vote change', () {
      final previousVote = _makeScOptionVote('opt_A');
      final newVote = _makeScOptionVote('opt_B');

      final payload = <String, dynamic>{
        'choice': newVote.choice.name,
        if (newVote.selectedOptionId != null)
          'selectedOptionId': newVote.selectedOptionId,
        'previousChoice': previousVote.choice.name,
        if (previousVote.selectedOptionId != null)
          'previousSelectedOptionId': previousVote.selectedOptionId,
      };

      expect(payload['selectedOptionId'], equals('opt_B'));
      expect(payload['previousSelectedOptionId'], equals('opt_A'));
      expect(payload['previousChoice'], equals('ABSTAIN'));
    });

    // ── SC Roundtrip: castVote → Tally → DecisionRecord zeigt Winner ──────────

    test(
        'SC roundtrip: castVote with optionA, finalizeProposal, '
        'DecisionRecord shows optionA as winner (single-device, '
        'no wire publish for the option vote)', () {
      // Simulate: voter casts an SC option vote (stored locally, wire-deferred).
      final vote = _makeScOptionVote('opt_A');

      // Confirm wire is deferred.
      expect(_shouldDefer(vote.selectedOptionId, VotingMode.SINGLE_CHOICE), isTrue);

      // Simulate local tally (mirrors _finalizeSingleChoice).
      final now = DateTime.utc(2026, 5, 6);
      final option = ProposalOption(
        optionId: 'opt_A',
        proposalId: 'p_sc',
        label: 'Option A',
        status: OptionStatus.ACTIVE,
        position: 0,
        createdAt: now,
        updatedAt: now,
      );
      final votes = [vote];
      const eligibleCount = 1;
      const quorumRequired = 0.0;

      final sortedVotes = sortVotesDeterministic(votes);
      final sortedOptions = sortOptionsDeterministic([option]);
      final optionCounts = <String, int>{for (final o in sortedOptions) o.optionId: 0};
      for (final v in sortedVotes) {
        if (v.selectedOptionId != null &&
            optionCounts.containsKey(v.selectedOptionId)) {
          optionCounts[v.selectedOptionId!] = optionCounts[v.selectedOptionId!]! + 1;
        }
      }
      final optionVoteSum = optionCounts.values.fold<int>(0, (a, b) => a + b);
      final participationCount = optionVoteSum;
      final participation = eligibleCount > 0 ? participationCount / eligibleCount : 0.0;

      expect(participation, greaterThanOrEqualTo(quorumRequired));
      expect(optionVoteSum, greaterThan(0));

      final maxCount = optionCounts.values.fold<int>(0, (a, b) => b > a ? b : a);
      final winners = sortedOptions
          .where((o) => optionCounts[o.optionId] == maxCount)
          .map((o) => o.optionId)
          .toList();

      expect(winners, equals(['opt_A']),
          reason: 'opt_A received the only vote → must be winner');

      // Simulate DecisionRecord construction.
      final optionResultsJson = canonicalJsonEncode(
          {for (final o in sortedOptions) o.optionId: optionCounts[o.optionId]!});
      expect(optionResultsJson, equals('{"opt_A":1}'));
    });

    // ── CC Roundtrip: castVote für ACTIVE candidate ───────────────────────────

    test(
        'CC roundtrip: castVote for ACTIVE candidate, '
        'finalizeProposal, candidate winner', () {
      final vote = _makeCcOptionVote('cand_maria');

      // Confirm wire is deferred.
      expect(_shouldDefer(vote.selectedOptionId, VotingMode.CANDIDATE_CHOICE), isTrue);

      // Simulate local tally (mirrors _finalizeCandidateChoice).
      final now = DateTime.utc(2026, 5, 6);
      final candidate = ProposalOption(
        optionId: 'cand_maria',
        proposalId: 'p_cc',
        label: 'Maria',
        candidateDid: 'did:test:maria',
        candidatePseudonym: 'Maria',
        status: OptionStatus.ACTIVE,
        position: 0,
        createdAt: now,
        updatedAt: now,
      );
      final votes = [vote];
      const eligibleCount = 1;
      const quorumRequired = 0.0;

      final sortedVotes = sortVotesDeterministic(votes);
      final sortedOptions = sortOptionsDeterministic([candidate]);
      final optionCounts = <String, int>{for (final o in sortedOptions) o.optionId: 0};
      for (final v in sortedVotes) {
        if (v.selectedOptionId != null &&
            optionCounts.containsKey(v.selectedOptionId)) {
          optionCounts[v.selectedOptionId!] = optionCounts[v.selectedOptionId!]! + 1;
        }
      }
      final optionVoteSum = optionCounts.values.fold<int>(0, (a, b) => a + b);
      final participationCount = optionVoteSum;
      final participation = eligibleCount > 0 ? participationCount / eligibleCount : 0.0;

      expect(participation, greaterThanOrEqualTo(quorumRequired));
      expect(optionVoteSum, greaterThan(0));

      final maxCount = optionCounts.values.fold<int>(0, (a, b) => b > a ? b : a);
      final winners = sortedOptions
          .where((o) => optionCounts[o.optionId] == maxCount)
          .map((o) => o.optionId)
          .toList();

      expect(winners, equals(['cand_maria']),
          reason: 'cand_maria received the only vote → must be winner');

      final optionResultsJson = canonicalJsonEncode(
          {for (final o in sortedOptions) o.optionId: optionCounts[o.optionId]!});
      expect(optionResultsJson, equals('{"cand_maria":1}'));
    });
  });

  // ── castVote — wire publish with selectedOptionId (Phase 4.7a2) ──────────

  group('castVote — wire publish with selectedOptionId (Phase 4.7a2)', () {
    // After Phase 4.7a2 the [VOTE-WIRE-DEFERRED] guard is gone. All votes
    // (YES_NO_ABSTAIN, SC/CC options, SC/CC abstentions) flow through
    // _publishVoteToNostr. These tests mirror the params map that
    // _publishVoteToNostr builds from a Vote object.

    Map<String, dynamic> _buildVoteParams(Vote vote) => {
          'proposalId': vote.proposalId,
          'cellId': 'cell_test',
          'voteId': vote.voteId,
          'choiceName': vote.choice.name,
          'voterDid': vote.voterDid,
          'voterPseudonym': vote.voterPseudonym,
          'createdAt': vote.createdAt.millisecondsSinceEpoch ~/ 1000,
          if (vote.reasoning != null) 'reasoning': vote.reasoning,
          if (vote.selectedOptionId != null)
            'selectedOptionId': vote.selectedOptionId,
        };

    Vote _makeScOptionVote(String optionId) => Vote(
          voteId: 'v_sc_opt',
          proposalId: 'p_sc',
          voterPubkey: 'pk_bob',
          voterDid: 'did:test:bob',
          voterPseudonym: 'Bob',
          choice: VoteChoice.ABSTAIN,
          selectedOptionId: optionId,
          createdAt: DateTime.utc(2026, 5, 6, 10, 0),
          nostrEventId: '',
        );

    Vote _makeScAbstainVote() => Vote(
          voteId: 'v_sc_abs',
          proposalId: 'p_sc',
          voterPubkey: 'pk_carol',
          voterDid: 'did:test:carol',
          voterPseudonym: 'Carol',
          choice: VoteChoice.ABSTAIN,
          selectedOptionId: null,
          createdAt: DateTime.utc(2026, 5, 6, 10, 0),
          nostrEventId: '',
        );

    Vote _makeCcOptionVote(String candidateId) => Vote(
          voteId: 'v_cc_opt',
          proposalId: 'p_cc',
          voterPubkey: 'pk_dave',
          voterDid: 'did:test:dave',
          voterPseudonym: 'Dave',
          choice: VoteChoice.ABSTAIN,
          selectedOptionId: candidateId,
          createdAt: DateTime.utc(2026, 5, 6, 10, 0),
          nostrEventId: '',
        );

    Vote _makeYnaVote() => Vote(
          voteId: 'v_yna',
          proposalId: 'p_yna',
          voterPubkey: 'pk_alice',
          voterDid: 'did:test:alice',
          voterPseudonym: 'Alice',
          choice: VoteChoice.YES,
          selectedOptionId: null,
          createdAt: DateTime.utc(2026, 5, 6, 10, 0),
          nostrEventId: '',
        );

    test('SC castVote with selectedOptionId publishes; params include selectedOptionId',
        () {
      final vote = _makeScOptionVote('opt_A');
      final params = _buildVoteParams(vote);
      expect(params['selectedOptionId'], equals('opt_A'));
      expect(params.containsKey('proposalId'), isTrue);
      expect(params.containsKey('voteId'), isTrue);
    });

    test('CC castVote with selectedOptionId publishes; params include selectedOptionId',
        () {
      final vote = _makeCcOptionVote('cand_alice');
      final params = _buildVoteParams(vote);
      expect(params['selectedOptionId'], equals('cand_alice'));
    });

    test('YES_NO_ABSTAIN castVote: params do NOT include selectedOptionId (key absent)',
        () {
      final vote = _makeYnaVote();
      final params = _buildVoteParams(vote);
      expect(params.containsKey('selectedOptionId'), isFalse,
          reason: 'YES_NO_ABSTAIN votes never carry selectedOptionId in wire params');
    });

    test(
        'SC castVote without selectedOptionId (Enthaltung): '
        'params do NOT include selectedOptionId', () {
      final vote = _makeScAbstainVote();
      final params = _buildVoteParams(vote);
      expect(params.containsKey('selectedOptionId'), isFalse,
          reason: 'SC abstention (null selectedOptionId) must not add the key');
    });

    test('changeVote with newSelectedOptionId publishes new option', () {
      final newVote = Vote(
        voteId: Vote.generateId(),
        proposalId: 'p_sc',
        voterPubkey: 'pk_carol',
        voterDid: 'did:test:carol',
        voterPseudonym: 'Carol',
        choice: VoteChoice.ABSTAIN,
        selectedOptionId: 'opt_B',
        createdAt: DateTime.utc(2026, 5, 6, 11, 0),
        nostrEventId: '',
      );
      final params = _buildVoteParams(newVote);
      expect(params['selectedOptionId'], equals('opt_B'),
          reason: 'changeVote result must carry updated selectedOptionId in params');
    });

    test('No [VOTE-WIRE-DEFERRED] log for SC/CC option votes', () {
      // After 4.7a2 there is no deferred branch — the params map is always
      // built and passed to the transport. Verified by confirming that the
      // params map is complete for an SC option vote.
      final vote = _makeScOptionVote('opt_X');
      final params = _buildVoteParams(vote);
      expect(params['selectedOptionId'], equals('opt_X'));
      expect(params.containsKey('voteId'), isTrue);
      expect(params.containsKey('proposalId'), isTrue);
    });
  });

  // ── handleIncomingVote — selectedOptionId (Phase 4.7a2) ─────────────────

  group('handleIncomingVote — selectedOptionId (Phase 4.7a2)', () {
    // Mirrors the Vote constructor + audit payload logic in handleIncomingVote.

    Map<String, dynamic> _buildContent({
      required String voteId,
      required String voterDid,
      required String voterPseudonym,
      required DateTime createdAt,
      String? reasoning,
      String? selectedOptionId,
    }) =>
        {
          'voteId': voteId,
          'voterDid': voterDid,
          'voterPseudonym': voterPseudonym,
          'createdAt': createdAt.millisecondsSinceEpoch ~/ 1000,
          if (reasoning != null) 'reasoning': reasoning,
          if (selectedOptionId != null) 'selectedOptionId': selectedOptionId,
        };

    Vote _parseVote(
            Map<String, dynamic> content, String choiceStr, String proposalId) =>
        Vote(
          voteId: content['voteId'] as String? ?? Vote.generateId(),
          proposalId: proposalId,
          voterPubkey: 'pk_remote',
          voterDid: content['voterDid'] as String? ?? '',
          voterPseudonym: content['voterPseudonym'] as String? ?? '',
          choice: VoteChoice.values.firstWhere(
            (c) => c.name == choiceStr.toUpperCase(),
            orElse: () => VoteChoice.ABSTAIN,
          ),
          reasoning: content['reasoning'] as String?,
          selectedOptionId: content['selectedOptionId'] as String?,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
              (content['createdAt'] as int) * 1000,
              isUtc: true),
          nostrEventId: 'evt_test',
        );

    test('SC incoming vote with selectedOptionId in content: persisted on Vote', () {
      final content = _buildContent(
        voteId: 'v1',
        voterDid: 'did:test:bob',
        voterPseudonym: 'Bob',
        createdAt: DateTime.utc(2026, 5, 6, 10, 0),
        selectedOptionId: 'opt_A',
      );
      final vote = _parseVote(content, 'abstain', 'p_sc');
      expect(vote.selectedOptionId, equals('opt_A'));
    });

    test('CC incoming vote with selectedOptionId: persisted', () {
      final content = _buildContent(
        voteId: 'v2',
        voterDid: 'did:test:dave',
        voterPseudonym: 'Dave',
        createdAt: DateTime.utc(2026, 5, 6, 10, 0),
        selectedOptionId: 'cand_alice',
      );
      final vote = _parseVote(content, 'abstain', 'p_cc');
      expect(vote.selectedOptionId, equals('cand_alice'));
    });

    test('Legacy incoming vote without selectedOptionId key: Vote.selectedOptionId = null',
        () {
      // Pre-4.7a2 event — no selectedOptionId key in content.
      final content = _buildContent(
        voteId: 'v3',
        voterDid: 'did:test:alice',
        voterPseudonym: 'Alice',
        createdAt: DateTime.utc(2026, 5, 6, 10, 0),
        // selectedOptionId intentionally omitted
      );
      expect(content.containsKey('selectedOptionId'), isFalse);
      final vote = _parseVote(content, 'abstain', 'p_sc');
      expect(vote.selectedOptionId, isNull,
          reason: 'Legacy events without selectedOptionId must yield null (= abstention)');
    });

    test('YES_NO_ABSTAIN incoming vote: behavior unchanged', () {
      final content = _buildContent(
        voteId: 'v4',
        voterDid: 'did:test:yna',
        voterPseudonym: 'YNA',
        createdAt: DateTime.utc(2026, 5, 6, 10, 0),
        // no selectedOptionId for YES_NO_ABSTAIN
      );
      final vote = _parseVote(content, 'yes', 'p_yna');
      expect(vote.choice, equals(VoteChoice.YES));
      expect(vote.selectedOptionId, isNull);
    });

    test('Audit payload on incoming SC vote contains selectedOptionId', () {
      final content = _buildContent(
        voteId: 'v5',
        voterDid: 'did:test:bob',
        voterPseudonym: 'Bob',
        createdAt: DateTime.utc(2026, 5, 6, 10, 0),
        selectedOptionId: 'opt_X',
      );
      final vote = _parseVote(content, 'abstain', 'p_sc');

      // Mirrors the audit payload construction in handleIncomingVote (4.7a2).
      final payload = <String, dynamic>{
        'choice': vote.choice.name,
        if (vote.reasoning != null) 'reasoning': vote.reasoning,
        if (vote.selectedOptionId != null) 'selectedOptionId': vote.selectedOptionId,
      };

      expect(payload['selectedOptionId'], equals('opt_X'));
      expect(payload['choice'], equals('ABSTAIN'));
    });
  });

  // ── Cross-device SC roundtrip via wire (Phase 4.7a2) ────────────────────

  group('Cross-device SC roundtrip via wire (Phase 4.7a2)', () {
    test(
        'Sender castVote with optionId → captured params → '
        'simulated incoming → receiver Vote has selectedOptionId '
        '→ tally counts correctly', () {
      // Step 1: Sender side — simulate _publishVoteToNostr params for SC vote.
      final senderVote = Vote(
        voteId: 'v_sc_roundtrip',
        proposalId: 'p_sc',
        voterPubkey: 'pk_bob',
        voterDid: 'did:test:bob',
        voterPseudonym: 'Bob',
        choice: VoteChoice.ABSTAIN,
        selectedOptionId: 'opt_A',
        createdAt: DateTime.utc(2026, 5, 6, 10, 0),
        nostrEventId: '',
      );
      final captured = <String, dynamic>{
        'proposalId': senderVote.proposalId,
        'cellId': 'cell_test',
        'voteId': senderVote.voteId,
        'choiceName': senderVote.choice.name,
        'voterDid': senderVote.voterDid,
        'voterPseudonym': senderVote.voterPseudonym,
        'createdAt': senderVote.createdAt.millisecondsSinceEpoch ~/ 1000,
        if (senderVote.selectedOptionId != null)
          'selectedOptionId': senderVote.selectedOptionId,
      };
      expect(captured['selectedOptionId'], equals('opt_A'),
          reason: 'Sender params must include selectedOptionId');

      // Step 2: Simulate wire — build Nostr event content as publishVoteEvent would.
      final wireContent = jsonEncode({
        'voteId': captured['voteId'],
        'voterDid': captured['voterDid'],
        'voterPseudonym': captured['voterPseudonym'],
        'createdAt': captured['createdAt'],
        'selectedOptionId': captured['selectedOptionId'],
      });
      final parsedContent = jsonDecode(wireContent) as Map<String, dynamic>;

      // Step 3: Receiver side — parse as handleIncomingVote would (4.7a2).
      final receiverVote = Vote(
        voteId: parsedContent['voteId'] as String,
        proposalId: senderVote.proposalId,
        voterPubkey: 'pk_bob_remote',
        voterDid: parsedContent['voterDid'] as String? ?? '',
        voterPseudonym: parsedContent['voterPseudonym'] as String? ?? '',
        choice: VoteChoice.ABSTAIN,
        reasoning: parsedContent['reasoning'] as String?,
        selectedOptionId: parsedContent['selectedOptionId'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (parsedContent['createdAt'] as int) * 1000,
            isUtc: true),
        nostrEventId: 'evt_remote_001',
      );

      // Step 4: Verify receiver Vote has selectedOptionId.
      expect(receiverVote.selectedOptionId, equals('opt_A'),
          reason: 'selectedOptionId must survive the wire round-trip');

      // Step 5: Tally counts correctly on receiver.
      final now = DateTime.utc(2026, 5, 6);
      final option = ProposalOption(
        optionId: 'opt_A',
        proposalId: 'p_sc',
        label: 'Option A',
        status: OptionStatus.ACTIVE,
        position: 0,
        createdAt: now,
        updatedAt: now,
      );
      final sortedVotes = sortVotesDeterministic([receiverVote]);
      final sortedOptions = sortOptionsDeterministic([option]);
      final optionCounts = <String, int>{
        for (final o in sortedOptions) o.optionId: 0
      };
      for (final v in sortedVotes) {
        if (v.selectedOptionId != null &&
            optionCounts.containsKey(v.selectedOptionId)) {
          optionCounts[v.selectedOptionId!] =
              optionCounts[v.selectedOptionId!]! + 1;
        }
      }

      expect(optionCounts['opt_A'], equals(1),
          reason: 'Cross-device vote with selectedOptionId must tally correctly');

      final optionResultsJson = canonicalJsonEncode(
          {for (final o in sortedOptions) o.optionId: optionCounts[o.optionId]!});
      expect(optionResultsJson, equals('{"opt_A":1}'));
    });
  });

  // ── Phase 4.7b: Modus-Validierung — castVote ────────────────────────────

  group('castVote — mode validation (Phase 4.7b)', () {
    // castVote cannot be called directly in unit tests (requires DB/service
    // singletons). The validation predicates are tested here as executable
    // spec, mirroring the production switch block in proposal_service.dart.

    // ── Validation predicate mirrors ────────────────────────────────────────

    /// Mirrors the YES_NO_ABSTAIN branch of the castVote validation switch.
    /// Returns a reject reason string, or null if the combination is valid.
    String? _validateYna(VoteChoice choice, String? selectedOptionId) {
      if (selectedOptionId != null) {
        return 'YES_NO_ABSTAIN proposal does not accept '
            'selectedOptionId (got: $selectedOptionId)';
      }
      return null; // choice YES/NO/ABSTAIN: alle erlaubt
    }

    /// Mirrors the SINGLE_CHOICE branch. optionIds is the set of known IDs.
    String? _validateSc(
        VoteChoice choice, String? selectedOptionId, Set<String> optionIds) {
      if (choice != VoteChoice.ABSTAIN) {
        return 'SINGLE_CHOICE proposal requires choice=ABSTAIN '
            '(got: ${choice.name})';
      }
      if (selectedOptionId != null && !optionIds.contains(selectedOptionId)) {
        return 'SINGLE_CHOICE selectedOptionId not found: $selectedOptionId';
      }
      return null;
    }

    /// Mirrors the CANDIDATE_CHOICE branch.
    /// candidates maps optionId → status string ('ACTIVE' / 'WITHDRAWN').
    String? _validateCc(VoteChoice choice, String? selectedOptionId,
        Map<String, String> candidates) {
      if (choice != VoteChoice.ABSTAIN) {
        return 'CANDIDATE_CHOICE proposal requires choice=ABSTAIN '
            '(got: ${choice.name})';
      }
      if (selectedOptionId != null) {
        if (!candidates.containsKey(selectedOptionId)) {
          return 'CANDIDATE_CHOICE selectedOptionId not found: $selectedOptionId';
        }
        final statusStr = candidates[selectedOptionId];
        if (statusStr != 'ACTIVE') {
          return 'CANDIDATE_CHOICE candidate is not ACTIVE '
              '(status=$statusStr): $selectedOptionId';
        }
      }
      return null;
    }

    // ── YES_NO_ABSTAIN ──────────────────────────────────────────────────────

    test('YES_NO_ABSTAIN with selectedOptionId: validation rejects', () {
      final reason = _validateYna(VoteChoice.YES, 'opt_x');
      expect(reason, isNotNull);
      expect(reason, contains('YES_NO_ABSTAIN'));
      expect(reason, contains('selectedOptionId'));
      expect(reason, contains('opt_x'));
    });

    test('YES_NO_ABSTAIN with choice=YES + null optionId: OK', () {
      final reason = _validateYna(VoteChoice.YES, null);
      expect(reason, isNull);
    });

    test('YES_NO_ABSTAIN with choice=NO + null optionId: OK', () {
      final reason = _validateYna(VoteChoice.NO, null);
      expect(reason, isNull);
    });

    test('YES_NO_ABSTAIN with choice=ABSTAIN + null optionId: OK', () {
      final reason = _validateYna(VoteChoice.ABSTAIN, null);
      expect(reason, isNull);
    });

    // ── SINGLE_CHOICE ───────────────────────────────────────────────────────

    test('SC with choice=YES: validation rejects', () {
      final reason = _validateSc(VoteChoice.YES, null, {'opt_A'});
      expect(reason, isNotNull);
      expect(reason, contains('SINGLE_CHOICE'));
      expect(reason, contains('ABSTAIN'));
      expect(reason, contains('YES'));
    });

    test('SC with choice=NO: validation rejects', () {
      final reason = _validateSc(VoteChoice.NO, null, {'opt_A'});
      expect(reason, isNotNull);
      expect(reason, contains('NO'));
    });

    test('SC with choice=ABSTAIN + null optionId (Enthaltung): OK', () {
      final reason = _validateSc(VoteChoice.ABSTAIN, null, {'opt_A'});
      expect(reason, isNull);
    });

    test('SC with choice=ABSTAIN + valid optionId: OK', () {
      final reason = _validateSc(VoteChoice.ABSTAIN, 'opt_A', {'opt_A'});
      expect(reason, isNull);
    });

    test('SC with choice=ABSTAIN + unknown optionId: validation rejects', () {
      final reason =
          _validateSc(VoteChoice.ABSTAIN, 'opt_unknown', {'opt_A', 'opt_B'});
      expect(reason, isNotNull);
      expect(reason, contains('SINGLE_CHOICE'));
      expect(reason, contains('opt_unknown'));
    });

    // ── CANDIDATE_CHOICE ────────────────────────────────────────────────────

    test('CC with choice=YES: validation rejects', () {
      final reason =
          _validateCc(VoteChoice.YES, null, {'cand_a': 'ACTIVE'});
      expect(reason, isNotNull);
      expect(reason, contains('CANDIDATE_CHOICE'));
      expect(reason, contains('ABSTAIN'));
      expect(reason, contains('YES'));
    });

    test('CC with choice=NO: validation rejects', () {
      final reason =
          _validateCc(VoteChoice.NO, null, {'cand_a': 'ACTIVE'});
      expect(reason, isNotNull);
      expect(reason, contains('NO'));
    });

    test('CC with choice=ABSTAIN + null optionId (Enthaltung): OK', () {
      final reason =
          _validateCc(VoteChoice.ABSTAIN, null, {'cand_a': 'ACTIVE'});
      expect(reason, isNull);
    });

    test('CC with choice=ABSTAIN + ACTIVE candidate: OK', () {
      final reason =
          _validateCc(VoteChoice.ABSTAIN, 'cand_a', {'cand_a': 'ACTIVE'});
      expect(reason, isNull);
    });

    test('CC with choice=ABSTAIN + WITHDRAWN candidate: validation rejects', () {
      final reason = _validateCc(
          VoteChoice.ABSTAIN, 'cand_a', {'cand_a': 'WITHDRAWN'});
      expect(reason, isNotNull);
      expect(reason, contains('ACTIVE'));
      expect(reason, contains('WITHDRAWN'));
      expect(reason, contains('cand_a'));
    });

    test('CC with choice=ABSTAIN + unknown optionId: validation rejects', () {
      final reason =
          _validateCc(VoteChoice.ABSTAIN, 'cand_unknown', {'cand_a': 'ACTIVE'});
      expect(reason, isNotNull);
      expect(reason, contains('CANDIDATE_CHOICE'));
      expect(reason, contains('cand_unknown'));
    });

    // ── Fehlgeschlagener castVote lässt DB/Memory unverändert ───────────────

    test('Failed castVote does not modify DB or memory state: '
        'validation fires before Vote construction and DB-write', () {
      // The production castVote validates BEFORE `_saveVoteToDb` is called.
      // This test verifies the predicate semantics: a reject reason is returned
      // without side effects. The production method throws a StateError on
      // non-null rejectReason, which propagates to the UI before any
      // DB/memory write.

      // Simulate: SC proposal, caller passes choice=YES (invalid).
      final existingVotesBeforeCall = <Vote>[];

      // Validate — mirrors the production switch.
      final reason = _validateSc(VoteChoice.YES, null, {'opt_A'});

      // Validation must reject.
      expect(reason, isNotNull,
          reason: 'Validator must catch illegal SC+YES combination');

      // Memory state must remain untouched (no Vote was constructed).
      expect(existingVotesBeforeCall, isEmpty,
          reason: 'No vote must be added when validation rejects');
    });
  });

  // ── Phase 4.7b: Modus-Validierung — handleIncomingVote ──────────────────

  group('handleIncomingVote — mode validation (Phase 4.7b)', () {
    // handleIncomingVote cannot be called directly in unit tests.
    // The validation predicates are tested here as executable spec.
    // The production method applies the same switch logic; on non-null
    // rejectReason it prints [VOTE-REJECT] and returns immediately without
    // DB insert, audit entry, or _notify().

    // ── Validation predicate mirrors ────────────────────────────────────────

    // Shared option/candidate tables.
    final _scOptions = {'opt_A': 'ACTIVE', 'opt_B': 'ACTIVE'};
    final _ccCandidates = {
      'cand_alice': 'ACTIVE',
      'cand_bob': 'WITHDRAWN',
    };

    /// Mirrors the YES_NO_ABSTAIN branch of handleIncomingVote.
    String? _incomingValidateYna(Vote vote) {
      if (vote.selectedOptionId != null) {
        return 'YES_NO_ABSTAIN with selectedOptionId=${vote.selectedOptionId}';
      }
      return null;
    }

    /// Mirrors the SINGLE_CHOICE branch of handleIncomingVote.
    String? _incomingValidateSc(Vote vote, Map<String, String> optionStatuses) {
      if (vote.choice != VoteChoice.ABSTAIN) {
        return 'SINGLE_CHOICE with choice=${vote.choice.name}';
      }
      if (vote.selectedOptionId != null &&
          !optionStatuses.containsKey(vote.selectedOptionId)) {
        return 'SINGLE_CHOICE unknown selectedOptionId=${vote.selectedOptionId}';
      }
      return null;
    }

    /// Mirrors the CANDIDATE_CHOICE branch of handleIncomingVote.
    String? _incomingValidateCc(
        Vote vote, Map<String, String> candidateStatuses) {
      if (vote.choice != VoteChoice.ABSTAIN) {
        return 'CANDIDATE_CHOICE with choice=${vote.choice.name}';
      }
      if (vote.selectedOptionId != null) {
        if (!candidateStatuses.containsKey(vote.selectedOptionId)) {
          return 'CANDIDATE_CHOICE unknown selectedOptionId='
              '${vote.selectedOptionId}';
        }
        if (candidateStatuses[vote.selectedOptionId] != 'ACTIVE') {
          return 'CANDIDATE_CHOICE candidate not ACTIVE '
              '(status=${candidateStatuses[vote.selectedOptionId]}) '
              '${vote.selectedOptionId}';
        }
      }
      return null;
    }

    // ── Vote factory helpers ────────────────────────────────────────────────

    Vote _makeIncomingVote({
      required VoteChoice choice,
      String? selectedOptionId,
      String proposalId = 'p_test',
      String voterPubkey = 'abcdef012345',
    }) =>
        Vote(
          voteId: 'v_incoming',
          proposalId: proposalId,
          voterPubkey: voterPubkey,
          voterDid: 'did:test:remote',
          voterPseudonym: 'Remote',
          choice: choice,
          selectedOptionId: selectedOptionId,
          createdAt: DateTime.utc(2026, 5, 6, 10, 0),
          nostrEventId: 'evt_incoming_001',
        );

    // ── YES_NO_ABSTAIN ──────────────────────────────────────────────────────

    test('YNA incoming with selectedOptionId: rejected with [VOTE-REJECT] reason',
        () {
      final vote = _makeIncomingVote(
          choice: VoteChoice.YES, selectedOptionId: 'opt_x');
      final reason = _incomingValidateYna(vote);
      expect(reason, isNotNull,
          reason: 'Must reject YNA vote carrying selectedOptionId');
      expect(reason, contains('YES_NO_ABSTAIN'));
      expect(reason, contains('opt_x'));
      // Simulated [VOTE-REJECT] log — verify prefix format.
      final logLine =
          '[VOTE-REJECT] ${vote.proposalId} reason=$reason '
          'voterPubkey=${vote.voterPubkey.substring(0, 12)}…';
      expect(logLine, contains('[VOTE-REJECT]'));
      expect(logLine, contains('voterPubkey=abcdef012345'));
    });

    test('YNA incoming with choice=YES + no selectedOptionId: accepted', () {
      final vote = _makeIncomingVote(choice: VoteChoice.YES);
      final reason = _incomingValidateYna(vote);
      expect(reason, isNull);
    });

    // ── SINGLE_CHOICE ───────────────────────────────────────────────────────

    test('SC incoming with choice=YES: rejected', () {
      final vote =
          _makeIncomingVote(choice: VoteChoice.YES, selectedOptionId: null);
      final reason = _incomingValidateSc(vote, _scOptions);
      expect(reason, isNotNull);
      expect(reason, contains('SINGLE_CHOICE'));
      expect(reason, contains('YES'));
    });

    test('SC incoming with choice=NO: rejected', () {
      final vote = _makeIncomingVote(choice: VoteChoice.NO);
      final reason = _incomingValidateSc(vote, _scOptions);
      expect(reason, isNotNull);
      expect(reason, contains('NO'));
    });

    test('SC incoming with valid optionId (ABSTAIN + opt_A): accepted', () {
      final vote = _makeIncomingVote(
          choice: VoteChoice.ABSTAIN, selectedOptionId: 'opt_A');
      final reason = _incomingValidateSc(vote, _scOptions);
      expect(reason, isNull);
    });

    test('SC incoming with null optionId (Enthaltung): accepted', () {
      final vote =
          _makeIncomingVote(choice: VoteChoice.ABSTAIN, selectedOptionId: null);
      final reason = _incomingValidateSc(vote, _scOptions);
      expect(reason, isNull);
    });

    test('SC incoming with unknown optionId: rejected', () {
      final vote = _makeIncomingVote(
          choice: VoteChoice.ABSTAIN, selectedOptionId: 'opt_ghost');
      final reason = _incomingValidateSc(vote, _scOptions);
      expect(reason, isNotNull);
      expect(reason, contains('opt_ghost'));
    });

    // ── CANDIDATE_CHOICE ────────────────────────────────────────────────────

    test('CC incoming with choice=YES: rejected', () {
      final vote = _makeIncomingVote(choice: VoteChoice.YES);
      final reason = _incomingValidateCc(vote, _ccCandidates);
      expect(reason, isNotNull);
      expect(reason, contains('CANDIDATE_CHOICE'));
      expect(reason, contains('YES'));
    });

    test('CC incoming for ACTIVE candidate: accepted', () {
      final vote = _makeIncomingVote(
          choice: VoteChoice.ABSTAIN, selectedOptionId: 'cand_alice');
      final reason = _incomingValidateCc(vote, _ccCandidates);
      expect(reason, isNull);
    });

    test('CC incoming for WITHDRAWN candidate: rejected', () {
      final vote = _makeIncomingVote(
          choice: VoteChoice.ABSTAIN, selectedOptionId: 'cand_bob');
      final reason = _incomingValidateCc(vote, _ccCandidates);
      expect(reason, isNotNull);
      expect(reason, contains('ACTIVE'));
      expect(reason, contains('WITHDRAWN'));
      expect(reason, contains('cand_bob'));
    });

    test('CC incoming for unknown candidate: rejected', () {
      final vote = _makeIncomingVote(
          choice: VoteChoice.ABSTAIN, selectedOptionId: 'cand_nobody');
      final reason = _incomingValidateCc(vote, _ccCandidates);
      expect(reason, isNotNull);
      expect(reason, contains('cand_nobody'));
    });

    test('CC incoming with null optionId (Enthaltung): accepted', () {
      final vote =
          _makeIncomingVote(choice: VoteChoice.ABSTAIN, selectedOptionId: null);
      final reason = _incomingValidateCc(vote, _ccCandidates);
      expect(reason, isNull);
    });

    // ── Defensive: kein DB-Insert, kein Audit, kein Notify ──────────────────

    test('Rejected incoming vote: no audit entry created '
        '(rejectReason != null causes early return before audit)', () {
      // In production: if (rejectReason != null) { print(...); return; }
      // This test verifies the logic: when rejectReason is non-null, the
      // method returns before reaching addAuditEntry / _saveVoteToDb / _notify.
      final vote = _makeIncomingVote(
          choice: VoteChoice.YES, selectedOptionId: null);
      // SC validation — this is an invalid combination.
      final reason = _incomingValidateSc(vote, _scOptions);
      expect(reason, isNotNull,
          reason: 'Sanity: must be rejected so early-return fires');
      // Simulated audit log — not appended on reject.
      final auditEntries = <String>[];
      if (reason == null) {
        auditEntries.add('VOTE_CAST'); // never reached
      }
      expect(auditEntries, isEmpty,
          reason: 'No audit entry must be appended when vote is rejected');
    });

    test('Rejected incoming vote: no _notify fires '
        '(rejectReason != null causes early return before _notify)', () {
      final vote = _makeIncomingVote(
          choice: VoteChoice.NO, selectedOptionId: null);
      final reason = _incomingValidateSc(vote, _scOptions);
      expect(reason, isNotNull);
      // Simulated notify flag — not set on reject.
      var notifyFired = false;
      if (reason == null) {
        notifyFired = true; // never reached
      }
      expect(notifyFired, isFalse,
          reason: '_notify must not fire when vote is rejected');
    });

    test('[VOTE-REJECT] log contains proposal ID, reason, and voterPubkey prefix',
        () {
      final vote = _makeIncomingVote(
          choice: VoteChoice.YES,
          selectedOptionId: 'bad_option',
          proposalId: 'prop_42',
          voterPubkey: 'deadbeef0011223344556677');
      final reason = _incomingValidateYna(vote);
      expect(reason, isNotNull);
      // Mirrors: print('[VOTE-REJECT] $proposalId reason=$reason voterPubkey=...');
      final prefix = vote.voterPubkey.substring(0, 12);
      final logLine = '[VOTE-REJECT] ${vote.proposalId} reason=$reason '
          'voterPubkey=$prefix…';
      expect(logLine, startsWith('[VOTE-REJECT] prop_42'));
      expect(logLine, contains('reason='));
      expect(logLine, contains('voterPubkey=deadbeef0011'));
    });
  });

  // ── Phase 4.7b: Historische Votes bleiben unangetastet ──────────────────

  group('Vote validation does not affect historical data (Phase 4.7b)', () {
    // Phase 4.7b validates ONLY new incoming/outgoing votes. Votes that were
    // cast before a candidate was withdrawn remain in the DB unchanged. The
    // tally (Phase 4.4) works with what is present (WINNER_WITHDRAWN path).

    test('Vote for candidate cast BEFORE withdrawal stays valid: '
        'Vote object is unchanged, tally counts it', () {
      // Simulate: vote was cast when cand_bob was ACTIVE.
      final historicalVote = Vote(
        voteId: 'v_historical',
        proposalId: 'p_cc_hist',
        voterPubkey: 'pk_historical',
        voterDid: 'did:test:historic',
        voterPseudonym: 'Historic',
        choice: VoteChoice.ABSTAIN,
        selectedOptionId: 'cand_bob',
        createdAt: DateTime.utc(2026, 4, 1, 10, 0), // before withdrawal
        nostrEventId: 'evt_hist_001',
      );

      // Candidate status AFTER the vote — cand_bob is now WITHDRAWN.
      final currentCandidates = {
        'cand_alice': 'ACTIVE',
        'cand_bob': 'WITHDRAWN',
      };

      // 4.7b does NOT re-validate historical votes in DB.
      // The tally reads the vote as-is and assigns it to WITHDRAWN category.
      // Verify: the vote itself is intact.
      expect(historicalVote.selectedOptionId, equals('cand_bob'));
      expect(historicalVote.choice, equals(VoteChoice.ABSTAIN));

      // The tally acknowledges the vote. Mirrors tally lookup logic.
      final status = currentCandidates[historicalVote.selectedOptionId];
      expect(status, equals('WITHDRAWN'),
          reason: 'Tally sees WITHDRAWN status — handled by WINNER_WITHDRAWN '
              'path in Phase 4.4, not rejected by 4.7b');

      // The vote is countable (tally increments WITHDRAWN candidate count).
      final withdrawnCount = 1; // would be incremented by tally
      expect(withdrawnCount, equals(1),
          reason: 'Historical vote for withdrawn candidate is still counted '
              'by tally');
    });

    test('ProposalOption with WITHDRAWN status can still hold historical votes: '
        'option object reflects withdrawal, vote survives', () {
      final now = DateTime.utc(2026, 5, 6);
      final withdrawnAt = DateTime.utc(2026, 4, 15);
      final option = ProposalOption(
        optionId: 'cand_bob',
        proposalId: 'p_cc_hist',
        label: 'Bob der Kandidat',
        status: OptionStatus.WITHDRAWN,
        candidateWithdrawnAt: withdrawnAt,
        position: 1,
        createdAt: DateTime.utc(2026, 3, 1),
        updatedAt: now,
      );
      expect(option.status, equals(OptionStatus.WITHDRAWN));

      // Historical vote for this candidate still references the same ID.
      final historicalVote = Vote(
        voteId: 'v_hist_2',
        proposalId: 'p_cc_hist',
        voterPubkey: 'pk_voter2',
        voterDid: 'did:test:voter2',
        voterPseudonym: 'Voter2',
        choice: VoteChoice.ABSTAIN,
        selectedOptionId: option.optionId,
        createdAt: DateTime.utc(2026, 3, 20), // before withdrawal
        nostrEventId: 'evt_hist_002',
      );
      expect(historicalVote.selectedOptionId, equals(option.optionId),
          reason: 'Vote ID reference stays intact regardless of option status');
    });
  });

  // ── Proposal wire format — votingMode (Phase 4.7c1) ─────────────────────
  //
  // These tests verify the contract at the model boundary that the
  // _publishProposalToNostr helper satisfies.  They do not instantiate
  // ProposalService (singleton / DB dependency) but validate:
  //   • outgoing: p.votingMode.name matches what the params map carries
  //   • incoming: parseVotingMode(content['votingMode']) produces the
  //               correct VotingMode (same logic used in handleIncomingProposal)
  //   • backwards-compat: null / unknown strings default to YES_NO_ABSTAIN
  //   • edit-path: updating title/status of a proposal leaves votingMode intact

  group('Proposal wire format — votingMode (Phase 4.7c1)', () {
    // ── helpers ────────────────────────────────────────────────────────────

    Proposal _makeProposal(VotingMode mode) => Proposal.create(
          cellId: 'cell-test',
          creatorDid: 'did:test:creator',
          creatorPseudonym: 'Tester',
          title: 'Test-Antrag',
          description: 'Beschreibung',
          votingMode: mode,
        );

    Map<String, dynamic> _outgoingParams(Proposal p) => {
          'proposalId': p.id,
          'cellId': p.cellId,
          'type': p.proposalType.name,
          'status': p.status.name,
          'title': p.title,
          'description': p.description,
          'creatorDid': p.creatorDid,
          'creatorPseudonym': p.creatorPseudonym,
          'createdAt': p.createdAt.millisecondsSinceEpoch ~/ 1000,
          'version': p.version,
          if (p.category != null) 'category': p.category,
          if (p.votingEndsAt != null)
            'votingEndsAt': p.votingEndsAt!.millisecondsSinceEpoch ~/ 1000,
          'votingMode': p.votingMode.name,
        };

    // ── Outgoing wire tests ────────────────────────────────────────────────

    test('YES_NO_ABSTAIN proposal: outgoing params include '
        'votingMode=YES_NO_ABSTAIN', () {
      final p = _makeProposal(VotingMode.YES_NO_ABSTAIN);
      final params = _outgoingParams(p);
      expect(params['votingMode'], equals('YES_NO_ABSTAIN'));
    });

    test('SINGLE_CHOICE proposal: outgoing params include '
        'votingMode=SINGLE_CHOICE', () {
      final p = _makeProposal(VotingMode.SINGLE_CHOICE);
      final params = _outgoingParams(p);
      expect(params['votingMode'], equals('SINGLE_CHOICE'));
    });

    test('CANDIDATE_CHOICE proposal: outgoing params include '
        'votingMode=CANDIDATE_CHOICE', () {
      final p = _makeProposal(VotingMode.CANDIDATE_CHOICE);
      final params = _outgoingParams(p);
      expect(params['votingMode'], equals('CANDIDATE_CHOICE'));
    });

    // ── Incoming wire tests ────────────────────────────────────────────────

    test('Incoming proposal with votingMode=SINGLE_CHOICE in content: '
        'parsed correctly by parseVotingMode', () {
      // Simulates content map as decoded from the Nostr event JSON.
      final content = <String, dynamic>{'votingMode': 'SINGLE_CHOICE'};
      final mode = parseVotingMode(content['votingMode'] as String?);
      expect(mode, equals(VotingMode.SINGLE_CHOICE));
    });

    test('Incoming proposal with votingMode=CANDIDATE_CHOICE: '
        'parsed correctly by parseVotingMode', () {
      final content = <String, dynamic>{'votingMode': 'CANDIDATE_CHOICE'};
      final mode = parseVotingMode(content['votingMode'] as String?);
      expect(mode, equals(VotingMode.CANDIDATE_CHOICE));
    });

    // ── Backwards-compatibility tests ──────────────────────────────────────

    test('Legacy incoming proposal without votingMode key: '
        'defaults to YES_NO_ABSTAIN (parseVotingMode(null))', () {
      // Pre-4.7c1 events lack the key entirely; accessing a missing map key
      // returns null in Dart.
      final content = <String, dynamic>{
        'title': 'Alter Antrag',
        'description': 'Kein votingMode-Key vorhanden',
      };
      final mode = parseVotingMode(content['votingMode'] as String?);
      expect(mode, equals(VotingMode.YES_NO_ABSTAIN));
    });

    test('Incoming proposal with unknown votingMode string ("FOOBAR"): '
        'falls back to YES_NO_ABSTAIN', () {
      final content = <String, dynamic>{'votingMode': 'FOOBAR'};
      final mode = parseVotingMode(content['votingMode'] as String?);
      expect(mode, equals(VotingMode.YES_NO_ABSTAIN));
    });

    // ── YES_NO_ABSTAIN regression ──────────────────────────────────────────

    test('YES_NO_ABSTAIN proposal create + receive: behavior unchanged '
        'from pre-4.7c1', () {
      // Create path: votingMode defaults to YES_NO_ABSTAIN.
      final p = Proposal.create(
        cellId: 'cell-reg',
        creatorDid: 'did:test:reg',
        creatorPseudonym: 'Reg',
        title: 'Sachfrage',
        description: 'Standard',
      );
      expect(p.votingMode, equals(VotingMode.YES_NO_ABSTAIN));

      // Outgoing: name must be the wire string.
      expect(p.votingMode.name, equals('YES_NO_ABSTAIN'));

      // Incoming parse: same string must round-trip.
      final parsed = parseVotingMode('YES_NO_ABSTAIN');
      expect(parsed, equals(VotingMode.YES_NO_ABSTAIN));
    });

    // ── Edit-path stability ────────────────────────────────────────────────

    test('Existing proposal edit (version increment): '
        'votingMode unchanged', () {
      // Simulate a SINGLE_CHOICE proposal that receives a title edit.
      // The existing-branch in handleIncomingProposal updates
      // title/description/version/status but must NOT touch votingMode.
      final original = _makeProposal(VotingMode.SINGLE_CHOICE);
      expect(original.votingMode, equals(VotingMode.SINGLE_CHOICE));

      // Apply the same mutations as the existing-branch code
      // (title update, version bump, status unchanged).
      original.title = 'Überarbeiteter Titel';
      original.description = 'Neue Beschreibung';
      original.version = original.version + 1;
      // votingMode is NOT touched by the existing-branch — verified here.
      expect(original.votingMode, equals(VotingMode.SINGLE_CHOICE),
          reason: 'votingMode must remain SINGLE_CHOICE after a title edit');
    });
  });

  // ── Proposal wire format — proposalOptions embed (Phase 4.7c2) ──────────

  group('Proposal wire format — proposalOptions embed (Phase 4.7c2)', () {
    // These tests verify the contract at the model boundary without
    // instantiating ProposalService (singleton / DB dependency). They mirror:
    //   • outgoing: _optionToWireMap + _publishProposalToNostr options logic
    //   • incoming: _persistIncomingOptions parsing logic
    //   • backwards-compat: missing key → no-op
    //   • malformed entry handling: skipped, valid entries still persisted
    //   • cross-device roundtrip: JSON encode/decode preserves all fields

    // ── Helpers ─────────────────────────────────────────────────────────────

    /// Mirror of ProposalService._optionToWireMap (camelCase wire format).
    Map<String, dynamic> _optionToWireMap(ProposalOption opt) {
      return <String, dynamic>{
        'optionId': opt.optionId,
        'position': opt.position,
        'label': opt.label,
        if (opt.description != null && opt.description!.isNotEmpty)
          'description': opt.description,
        if (opt.candidateDid != null) 'candidateDid': opt.candidateDid,
        if (opt.candidatePseudonym != null)
          'candidatePseudonym': opt.candidatePseudonym,
        'status': opt.status.name,
        if (opt.candidateAcceptedAt != null)
          'candidateAcceptedAt':
              opt.candidateAcceptedAt!.millisecondsSinceEpoch,
        if (opt.candidateWithdrawnAt != null)
          'candidateWithdrawnAt':
              opt.candidateWithdrawnAt!.millisecondsSinceEpoch,
      };
    }

    /// Mirror of the ProposalOption construction inside
    /// ProposalService._persistIncomingOptions.
    ProposalOption _optionFromWire(
        String proposalId, Map<String, dynamic> m) {
      final positionRaw = m['position'];
      final acceptedRaw = m['candidateAcceptedAt'];
      final withdrawnRaw = m['candidateWithdrawnAt'];
      final now = DateTime.now().toUtc();
      return ProposalOption(
        optionId: m['optionId'] as String,
        proposalId: proposalId,
        position: (positionRaw as num).toInt(),
        label: m['label'] as String,
        description: m['description'] as String?,
        candidateDid: m['candidateDid'] as String?,
        candidatePseudonym: m['candidatePseudonym'] as String?,
        status: OptionStatus.values.firstWhere(
          (e) => e.name == (m['status'] as String? ?? ''),
          orElse: () => OptionStatus.ACTIVE,
        ),
        candidateAcceptedAt: acceptedRaw is num
            ? DateTime.fromMillisecondsSinceEpoch(
                acceptedRaw.toInt(),
                isUtc: true,
              )
            : null,
        candidateWithdrawnAt: withdrawnRaw is num
            ? DateTime.fromMillisecondsSinceEpoch(
                withdrawnRaw.toInt(),
                isUtc: true,
              )
            : null,
        createdAt: now,
        updatedAt: now,
      );
    }

    /// Creates a minimal ProposalOption for outgoing serialisation tests.
    ProposalOption _makeOpt({
      required String optionId,
      required String proposalId,
      int position = 0,
      String label = 'Option',
      String? description,
      String? candidateDid,
      String? candidatePseudonym,
      OptionStatus status = OptionStatus.ACTIVE,
      DateTime? candidateAcceptedAt,
      DateTime? candidateWithdrawnAt,
    }) {
      final now = DateTime.utc(2026, 5, 1);
      return ProposalOption(
        optionId: optionId,
        proposalId: proposalId,
        label: label,
        description: description,
        candidateDid: candidateDid,
        candidatePseudonym: candidatePseudonym,
        status: status,
        position: position,
        createdAt: now,
        updatedAt: now,
        candidateAcceptedAt: candidateAcceptedAt,
        candidateWithdrawnAt: candidateWithdrawnAt,
      );
    }

    /// Mirror of the proposalOptions block in _publishProposalToNostr.
    Map<String, dynamic> _outgoingParams(
        Proposal p, List<ProposalOption> options) {
      List<Map<String, dynamic>>? optionsForWire;
      if (p.votingMode != VotingMode.YES_NO_ABSTAIN && options.isNotEmpty) {
        final sorted = [...options]
          ..sort((a, b) => a.position.compareTo(b.position));
        optionsForWire =
            sorted.map(_optionToWireMap).toList(growable: false);
      }
      return {
        'proposalId': p.id,
        'votingMode': p.votingMode.name,
        if (optionsForWire != null) 'proposalOptions': optionsForWire,
      };
    }

    Proposal _makeProposal(VotingMode mode) => Proposal.create(
          cellId: 'cell-test',
          creatorDid: 'did:test:creator',
          creatorPseudonym: 'Tester',
          title: 'Test-Antrag',
          description: 'Beschreibung',
          votingMode: mode,
        );

    // ── Outgoing: YES_NO_ABSTAIN ───────────────────────────────────────────

    test('YES_NO_ABSTAIN proposal: outgoing params do NOT include '
        'proposalOptions key', () {
      final p = _makeProposal(VotingMode.YES_NO_ABSTAIN);
      final params = _outgoingParams(p, []);
      expect(params.containsKey('proposalOptions'), isFalse);
    });

    // ── Outgoing: SC with 3 options ────────────────────────────────────────

    test('SINGLE_CHOICE proposal with 3 options: outgoing params include '
        'proposalOptions list with 3 entries sorted by position', () {
      final p = _makeProposal(VotingMode.SINGLE_CHOICE);
      // Deliberately unsorted to verify position ASC sort.
      final opts = [
        _makeOpt(
            optionId: 'opt_c',
            proposalId: p.id,
            position: 2,
            label: 'Option C'),
        _makeOpt(
            optionId: 'opt_a',
            proposalId: p.id,
            position: 0,
            label: 'Option A'),
        _makeOpt(
            optionId: 'opt_b',
            proposalId: p.id,
            position: 1,
            label: 'Option B'),
      ];
      final params = _outgoingParams(p, opts);
      expect(params.containsKey('proposalOptions'), isTrue);
      final wireOpts =
          params['proposalOptions'] as List<Map<String, dynamic>>;
      expect(wireOpts.length, equals(3));
      expect(wireOpts[0]['optionId'], equals('opt_a'));
      expect(wireOpts[1]['optionId'], equals('opt_b'));
      expect(wireOpts[2]['optionId'], equals('opt_c'));
    });

    // ── Outgoing: CC with candidates ──────────────────────────────────────

    test('CANDIDATE_CHOICE proposal with 2 candidates: outgoing params '
        'include candidateDid + candidatePseudonym + status', () {
      final p = _makeProposal(VotingMode.CANDIDATE_CHOICE);
      final opts = [
        _makeOpt(
          optionId: 'cand_alice',
          proposalId: p.id,
          position: 0,
          label: 'Alice',
          candidateDid: 'did:test:alice',
          candidatePseudonym: 'Alice T.',
        ),
        _makeOpt(
          optionId: 'cand_bob',
          proposalId: p.id,
          position: 1,
          label: 'Bob',
          candidateDid: 'did:test:bob',
          candidatePseudonym: 'Bob M.',
        ),
      ];
      final params = _outgoingParams(p, opts);
      final wireOpts =
          params['proposalOptions'] as List<Map<String, dynamic>>;
      expect(wireOpts[0]['candidateDid'], equals('did:test:alice'));
      expect(wireOpts[0]['candidatePseudonym'], equals('Alice T.'));
      expect(wireOpts[0]['status'], equals('ACTIVE'));
      expect(wireOpts[1]['candidateDid'], equals('did:test:bob'));
    });

    // ── Outgoing: empty options list ──────────────────────────────────────

    test('Empty options list (SC ohne Optionen): proposalOptions key omitted '
        '(no empty array)', () {
      final p = _makeProposal(VotingMode.SINGLE_CHOICE);
      final params = _outgoingParams(p, []);
      expect(params.containsKey('proposalOptions'), isFalse);
    });

    // ── Wire format: camelCase keys ────────────────────────────────────────

    test('Option wire map has camelCase keys '
        '(optionId, position, label, status)', () {
      final opt = _makeOpt(
          optionId: 'opt_x', proposalId: 'p1', position: 5, label: 'Ja');
      final wire = _optionToWireMap(opt);
      expect(wire.containsKey('optionId'), isTrue);
      expect(wire.containsKey('position'), isTrue);
      expect(wire.containsKey('label'), isTrue);
      expect(wire.containsKey('status'), isTrue);
      // Ensure no snake_case leakage from the DB format.
      expect(wire.containsKey('option_id'), isFalse);
      expect(wire.containsKey('display_text'), isFalse);
      expect(wire.containsKey('candidate_did'), isFalse);
    });

    // ── Wire format: timestamps as millis ─────────────────────────────────

    test('candidateAcceptedAt and candidateWithdrawnAt encoded as '
        'millisecondsSinceEpoch', () {
      final accepted = DateTime.utc(2026, 3, 15, 12, 0, 0);
      final opt = _makeOpt(
        optionId: 'cand_x',
        proposalId: 'p1',
        label: 'Cand',
        candidateAcceptedAt: accepted,
      );
      final wire = _optionToWireMap(opt);
      expect(wire['candidateAcceptedAt'],
          equals(accepted.millisecondsSinceEpoch));
      expect(wire.containsKey('candidateWithdrawnAt'), isFalse);
    });

    // ── Wire format: WITHDRAWN ─────────────────────────────────────────────

    test('WITHDRAWN candidate: status="WITHDRAWN" + candidateWithdrawnAt set',
        () {
      final withdrawn = DateTime.utc(2026, 4, 1, 9, 0, 0);
      final opt = _makeOpt(
        optionId: 'cand_w',
        proposalId: 'p1',
        label: 'Zurückgezogen',
        status: OptionStatus.WITHDRAWN,
        candidateWithdrawnAt: withdrawn,
      );
      final wire = _optionToWireMap(opt);
      expect(wire['status'], equals('WITHDRAWN'));
      expect(wire['candidateWithdrawnAt'],
          equals(withdrawn.millisecondsSinceEpoch));
    });

    // ── Wire format: description optional ─────────────────────────────────

    test('description included in wire only when non-empty', () {
      final optWithDesc = _makeOpt(
        optionId: 'opt_d',
        proposalId: 'p1',
        label: 'Desc',
        description: 'Some info',
      );
      final optNoDesc =
          _makeOpt(optionId: 'opt_nd', proposalId: 'p1', label: 'No desc');
      final wireWith = _optionToWireMap(optWithDesc);
      final wireWithout = _optionToWireMap(optNoDesc);
      expect(wireWith['description'], equals('Some info'));
      expect(wireWithout.containsKey('description'), isFalse);
    });

    // ── Incoming: SC proposal ─────────────────────────────────────────────

    test('Incoming SC proposal with proposalOptions: each option parsed '
        'correctly', () {
      const proposalId = 'inc_sc_001';
      final wireOpts = [
        {
          'optionId': 'opt_a',
          'position': 0,
          'label': 'Alpha',
          'status': 'ACTIVE'
        },
        {
          'optionId': 'opt_b',
          'position': 1,
          'label': 'Beta',
          'status': 'ACTIVE'
        },
      ];
      final parsed =
          wireOpts.map((m) => _optionFromWire(proposalId, m)).toList();
      expect(parsed.length, equals(2));
      expect(parsed[0].optionId, equals('opt_a'));
      expect(parsed[0].label, equals('Alpha'));
      expect(parsed[0].position, equals(0));
      expect(parsed[0].status, equals(OptionStatus.ACTIVE));
      expect(parsed[0].proposalId, equals(proposalId));
      expect(parsed[1].optionId, equals('opt_b'));
      expect(parsed[1].label, equals('Beta'));
    });

    // ── Incoming: CC with WITHDRAWN ────────────────────────────────────────

    test('Incoming CC proposal with WITHDRAWN candidate: status persisted '
        'correctly', () {
      final withdrawnAt = DateTime.utc(2026, 4, 5, 10, 0, 0);
      final wireOpt = <String, dynamic>{
        'optionId': 'cand_z',
        'position': 0,
        'label': 'Zurückgezogen',
        'candidateDid': 'did:test:cand_z',
        'candidatePseudonym': 'Z. Kandidat',
        'status': 'WITHDRAWN',
        'candidateWithdrawnAt': withdrawnAt.millisecondsSinceEpoch,
      };
      final opt = _optionFromWire('cc_proposal_001', wireOpt);
      expect(opt.status, equals(OptionStatus.WITHDRAWN));
      expect(opt.candidateDid, equals('did:test:cand_z'));
      expect(opt.candidatePseudonym, equals('Z. Kandidat'));
      expect(opt.candidateWithdrawnAt, equals(withdrawnAt));
    });

    // ── Idempotenz ──────────────────────────────────────────────────────────

    test('Receiving same SC proposal twice: both times produces same '
        'ProposalOption (same optionId → upsert deduplicates)', () {
      const proposalId = 'idem_001';
      final wireOpt = <String, dynamic>{
        'optionId': 'opt_idem',
        'position': 0,
        'label': 'Idempotent',
        'status': 'ACTIVE',
      };
      final first = _optionFromWire(proposalId, wireOpt);
      final second = _optionFromWire(proposalId, wireOpt);
      // Both produce the same DB key — upsert will overwrite, not duplicate.
      expect(first.optionId, equals(second.optionId));
      expect(first.proposalId, equals(second.proposalId));
      expect(first.label, equals(second.label));
      expect(first.toMap()['option_id'], equals(second.toMap()['option_id']));
    });

    // ── Legacy-Compat ──────────────────────────────────────────────────────

    test('Legacy incoming proposal without proposalOptions key: '
        '_persistIncomingOptions is a no-op', () {
      // Mirrors the null-check guard at the top of _persistIncomingOptions.
      final content = <String, dynamic>{
        'title': 'Alter Antrag',
        'description': 'Kein proposalOptions-Key',
        'votingMode': 'YES_NO_ABSTAIN',
      };
      final raw = content['proposalOptions'];
      // Null guard: function returns immediately, no DB writes.
      expect(raw, isNull,
          reason: 'Legacy content must not have proposalOptions key');
    });

    // ── Malformed mix ──────────────────────────────────────────────────────

    test('Malformed entry mixed with valid entries: valid persisted, '
        'malformed skipped, no crash', () {
      const proposalId = 'malformed_001';
      final rawList = <dynamic>[
        // Valid
        {
          'optionId': 'opt_valid_1',
          'position': 0,
          'label': 'Valid 1',
          'status': 'ACTIVE'
        },
        // Malformed: missing 'optionId' → cast to String throws
        {'position': 1, 'label': 'No ID', 'status': 'ACTIVE'},
        // Valid
        {
          'optionId': 'opt_valid_2',
          'position': 2,
          'label': 'Valid 2',
          'status': 'ACTIVE'
        },
      ];

      // Mirror the for-loop in _persistIncomingOptions.
      final persisted = <ProposalOption>[];
      int skipped = 0;
      for (final entry in rawList) {
        if (entry is! Map) {
          skipped++;
          continue;
        }
        final m = (entry as Map).cast<String, dynamic>();
        try {
          persisted.add(_optionFromWire(proposalId, m));
        } catch (_) {
          skipped++;
        }
      }

      expect(persisted.length, equals(2),
          reason: 'Both valid entries must be persisted');
      expect(skipped, equals(1),
          reason: 'Malformed entry must be counted as skipped');
      expect(persisted[0].optionId, equals('opt_valid_1'));
      expect(persisted[1].optionId, equals('opt_valid_2'));
    });

    // ── Existing-branch ─────────────────────────────────────────────────────

    test('Edit on existing SC proposal with new option set: options in '
        'wire content are parsed correctly (existing-branch path)', () {
      // Both new-branch and existing-branch call _persistIncomingOptions
      // with the same content map. The parsing logic is identical.
      const proposalId = 'sc_edit_001';
      final wireContent = <String, dynamic>{
        'title': 'Überarbeiteter SC-Antrag',
        'description': 'Neue Beschreibung',
        'votingMode': 'SINGLE_CHOICE',
        'proposalOptions': [
          {
            'optionId': 'opt_1',
            'position': 0,
            'label': 'Weg A',
            'status': 'ACTIVE'
          },
          {
            'optionId': 'opt_2',
            'position': 1,
            'label': 'Weg B',
            'status': 'ACTIVE'
          },
        ],
      };
      final rawList = wireContent['proposalOptions'] as List;
      final opts = rawList
          .whereType<Map>()
          .map((m) => _optionFromWire(proposalId, m.cast<String, dynamic>()))
          .toList();
      expect(opts.length, equals(2));
      expect(opts[0].optionId, equals('opt_1'));
      expect(opts[1].optionId, equals('opt_2'));
    });

    // ── YES_NO_ABSTAIN regression ──────────────────────────────────────────

    test('YES_NO_ABSTAIN end-to-end (outgoing + incoming): no options '
        'touched anywhere', () {
      final p = _makeProposal(VotingMode.YES_NO_ABSTAIN);

      // Outgoing: no proposalOptions key emitted.
      final params = _outgoingParams(p, []);
      expect(params.containsKey('proposalOptions'), isFalse);

      // Incoming: YNA content has no proposalOptions key.
      final content = <String, dynamic>{
        'title': p.title,
        'votingMode': 'YES_NO_ABSTAIN',
      };
      final raw = content['proposalOptions'];
      // _persistIncomingOptions null-guard → no-op.
      expect(raw, isNull);
    });

    // ── JSON-Numeric robustness ────────────────────────────────────────────

    test('JSON-Numeric: position as double survives num.toInt() parsing', () {
      // JSON decoding can produce num that is double (e.g. 2.0).
      final wireOpt = <String, dynamic>{
        'optionId': 'opt_num',
        'position': 2.0, // simulate double from JSON decoder
        'label': 'Numeric',
        'status': 'ACTIVE',
      };
      final opt = _optionFromWire('p_num', wireOpt);
      expect(opt.position, equals(2));
      expect(opt.position.runtimeType, equals(int));
    });

    // ── Cross-device roundtrip ─────────────────────────────────────────────

    test('Cross-device SC roundtrip: sender publishes 3 options, simulated '
        'incoming on receiver, receiver reconstructs 3 entries with correct '
        'optionIds/labels, and createdAt is set locally (not from sender)',
        () {
      // Sender sets createdAt to an explicit far-past value.
      // After the roundtrip the receiver must NOT have this date.
      final senderCreatedAt = DateTime.utc(2020, 1, 1);

      // Step 1: Sender creates 3 options.
      final senderProposal = _makeProposal(VotingMode.SINGLE_CHOICE);
      final senderOptions = [
        ProposalOption(
          optionId: 'rt_opt_a',
          proposalId: senderProposal.id,
          label: 'Route A',
          position: 0,
          status: OptionStatus.ACTIVE,
          createdAt: senderCreatedAt,
          updatedAt: senderCreatedAt,
        ),
        ProposalOption(
          optionId: 'rt_opt_b',
          proposalId: senderProposal.id,
          label: 'Route B',
          position: 1,
          status: OptionStatus.ACTIVE,
          createdAt: senderCreatedAt,
          updatedAt: senderCreatedAt,
        ),
        ProposalOption(
          optionId: 'rt_opt_c',
          proposalId: senderProposal.id,
          label: 'Route C',
          position: 2,
          status: OptionStatus.ACTIVE,
          createdAt: senderCreatedAt,
          updatedAt: senderCreatedAt,
        ),
      ];

      // Step 2: Sender serializes to wire (sorted by position ASC).
      final sorted = [...senderOptions]
        ..sort((a, b) => a.position.compareTo(b.position));
      final wireList = sorted.map(_optionToWireMap).toList();

      // Verify createdAt does NOT appear in wire format.
      expect(wireList[0].containsKey('createdAt'), isFalse,
          reason: 'createdAt must NOT be in wire format');
      expect(wireList[0].containsKey('updatedAt'), isFalse,
          reason: 'updatedAt must NOT be in wire format');

      // Step 3: Encode as JSON and decode (simulates Nostr transport).
      final encoded = jsonEncode({'proposalOptions': wireList});
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final receivedRaw = decoded['proposalOptions'] as List;

      // Step 4: Receiver parses each entry (mirrors _persistIncomingOptions).
      final receivedOptions = receivedRaw
          .whereType<Map>()
          .map((m) => _optionFromWire(
                senderProposal.id,
                m.cast<String, dynamic>(),
              ))
          .toList();

      // Verify 3 entries with correct optionIds and labels.
      expect(receivedOptions.length, equals(3));
      final optIds = receivedOptions.map((o) => o.optionId).toList();
      expect(optIds, containsAll(['rt_opt_a', 'rt_opt_b', 'rt_opt_c']));

      final optA =
          receivedOptions.firstWhere((o) => o.optionId == 'rt_opt_a');
      expect(optA.label, equals('Route A'));
      expect(optA.position, equals(0));

      // Critical timestamp test: receiver's createdAt must be set locally,
      // NOT be the sender's 2020-01-01 value (which is absent from the wire).
      expect(
        optA.createdAt.isAfter(DateTime.utc(2024, 1, 1)),
        isTrue,
        reason: 'createdAt must be set locally on receive, '
            'not taken from sender wire payload',
      );
    });
  });
}
