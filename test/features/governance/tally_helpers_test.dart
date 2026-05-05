import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/proposal_option.dart';
import 'package:nexus_oneapp/features/governance/tally_helpers.dart';
import 'package:nexus_oneapp/features/governance/vote.dart';

void main() {
  // ── Group 1: ResultReason constants ─────────────────────────────────────────

  group('ResultReason constants', () {
    test('all 8 values are present in ResultReason.all', () {
      expect(ResultReason.all.length, equals(8));
      expect(ResultReason.all, contains(ResultReason.quorumNotMet));
      expect(ResultReason.all, contains(ResultReason.noValidVotes));
      expect(ResultReason.all, contains(ResultReason.allAbstain));
      expect(ResultReason.all, contains(ResultReason.tieRequiresRunoff));
      expect(ResultReason.all, contains(ResultReason.winnerWithdrawn));
      expect(ResultReason.all, contains(ResultReason.allCandidatesWithdrawn));
      expect(ResultReason.all, contains(ResultReason.withdrawnDuringVoting));
      expect(ResultReason.all, contains(ResultReason.withdrawnByModeration));
    });

    test('ResultReason string values match G2 §20.8 spec', () {
      expect(ResultReason.quorumNotMet, equals('QUORUM_NOT_MET'));
      expect(ResultReason.noValidVotes, equals('NO_VALID_VOTES'));
      expect(ResultReason.allAbstain, equals('ALL_ABSTAIN'));
      expect(ResultReason.tieRequiresRunoff, equals('TIE_REQUIRES_RUNOFF'));
      expect(ResultReason.winnerWithdrawn, equals('WINNER_WITHDRAWN'));
      expect(ResultReason.allCandidatesWithdrawn,
          equals('ALL_CANDIDATES_WITHDRAWN'));
      expect(ResultReason.withdrawnDuringVoting,
          equals('WITHDRAWN_DURING_VOTING'));
      expect(ResultReason.withdrawnByModeration,
          equals('WITHDRAWN_BY_MODERATION'));
    });
  });

  // ── Group 2: sortVotesDeterministic ─────────────────────────────────────────

  group('sortVotesDeterministic', () {
    Vote _makeVote(String voteId, DateTime createdAt) => Vote(
          voteId: voteId,
          proposalId: 'p1',
          voterPubkey: 'pk',
          voterDid: 'did:key:z1',
          voterPseudonym: 'Tester',
          choice: VoteChoice.YES,
          createdAt: createdAt,
          nostrEventId: 'nostr_$voteId',
        );

    test('sorts by createdAt ascending', () {
      final t1 = DateTime.utc(2026, 5, 1, 10, 0, 0);
      final t2 = DateTime.utc(2026, 5, 1, 11, 0, 0);
      final t3 = DateTime.utc(2026, 5, 1, 12, 0, 0);

      final votes = [
        _makeVote('v3', t3),
        _makeVote('v1', t1),
        _makeVote('v2', t2),
      ];

      final sorted = sortVotesDeterministic(votes);

      expect(sorted[0].voteId, equals('v1'));
      expect(sorted[1].voteId, equals('v2'));
      expect(sorted[2].voteId, equals('v3'));
    });

    test('uses voteId as tiebreaker for equal createdAt', () {
      final t = DateTime.utc(2026, 5, 1, 10, 0, 0);

      final votes = [
        _makeVote('zzz', t),
        _makeVote('aaa', t),
        _makeVote('mmm', t),
      ];

      final sorted = sortVotesDeterministic(votes);

      expect(sorted[0].voteId, equals('aaa'));
      expect(sorted[1].voteId, equals('mmm'));
      expect(sorted[2].voteId, equals('zzz'));
    });

    test('preserves order when all timestamps and IDs are already sorted', () {
      final t1 = DateTime.utc(2026, 5, 1, 10, 0, 0);
      final t2 = DateTime.utc(2026, 5, 1, 11, 0, 0);

      final votes = [
        _makeVote('a1', t1),
        _makeVote('b2', t2),
      ];

      final sorted = sortVotesDeterministic(votes);

      expect(sorted[0].voteId, equals('a1'));
      expect(sorted[1].voteId, equals('b2'));
    });

    test('does not mutate the original list', () {
      final t1 = DateTime.utc(2026, 5, 1, 12, 0, 0);
      final t2 = DateTime.utc(2026, 5, 1, 10, 0, 0);

      final votes = [
        _makeVote('v_first', t1),
        _makeVote('v_second', t2),
      ];

      sortVotesDeterministic(votes);

      // Original order must be preserved
      expect(votes[0].voteId, equals('v_first'));
      expect(votes[1].voteId, equals('v_second'));
    });
  });

  // ── Group 3: sortOptionsDeterministic ───────────────────────────────────────

  group('sortOptionsDeterministic', () {
    ProposalOption _makeOption(String optionId, int position) =>
        ProposalOption(
          optionId: optionId,
          proposalId: 'p1',
          label: 'Option $optionId',
          position: position,
          createdAt: DateTime.utc(2026, 5, 1),
          updatedAt: DateTime.utc(2026, 5, 1),
        );

    test('sorts by position ascending', () {
      final options = [
        _makeOption('o3', 3),
        _makeOption('o1', 1),
        _makeOption('o2', 2),
      ];

      final sorted = sortOptionsDeterministic(options);

      expect(sorted[0].optionId, equals('o1'));
      expect(sorted[1].optionId, equals('o2'));
      expect(sorted[2].optionId, equals('o3'));
    });

    test('uses optionId as tiebreaker for equal position', () {
      final options = [
        _makeOption('zzz', 1),
        _makeOption('aaa', 1),
        _makeOption('mmm', 1),
      ];

      final sorted = sortOptionsDeterministic(options);

      expect(sorted[0].optionId, equals('aaa'));
      expect(sorted[1].optionId, equals('mmm'));
      expect(sorted[2].optionId, equals('zzz'));
    });

    test('does not mutate the original list', () {
      final options = [
        _makeOption('b', 2),
        _makeOption('a', 1),
      ];

      sortOptionsDeterministic(options);

      expect(options[0].optionId, equals('b'));
      expect(options[1].optionId, equals('a'));
    });
  });

  // ── Group 4: canonicalJsonEncode ─────────────────────────────────────────────

  group('canonicalJsonEncode', () {
    test('encodes null as "null"', () {
      expect(canonicalJsonEncode(null), equals('null'));
    });

    test('encodes true as "true"', () {
      expect(canonicalJsonEncode(true), equals('true'));
    });

    test('encodes false as "false"', () {
      expect(canonicalJsonEncode(false), equals('false'));
    });

    test('encodes integer without decimal point', () {
      expect(canonicalJsonEncode(7), equals('7'));
      expect(canonicalJsonEncode(0), equals('0'));
      expect(canonicalJsonEncode(-42), equals('-42'));
    });

    test('encodes empty list as "[]"', () {
      expect(canonicalJsonEncode([]), equals('[]'));
    });

    test('encodes empty map as "{}"', () {
      expect(canonicalJsonEncode(<String, dynamic>{}), equals('{}'));
    });

    test('sorts single-level map keys alphabetically', () {
      final result = canonicalJsonEncode({
        'z': 1,
        'a': 2,
        'm': 3,
      });
      expect(result, equals('{"a":2,"m":3,"z":1}'));
    });

    test('sorts nested map keys alphabetically (recursive)', () {
      final result = canonicalJsonEncode({
        'outer_z': {'inner_z': 1, 'inner_a': 2},
        'outer_a': 'value',
      });
      expect(
        result,
        equals('{"outer_a":"value","outer_z":{"inner_a":2,"inner_z":1}}'),
      );
    });

    test('preserves list order', () {
      final result = canonicalJsonEncode(['c', 'a', 'b']);
      expect(result, equals('["c","a","b"]'));
    });

    test('encodes string with double-quote escaping', () {
      final result = canonicalJsonEncode('say "hello"');
      expect(result, equals('"say \\"hello\\""'));
    });

    test('encodes string with backslash escaping', () {
      final result = canonicalJsonEncode('path\\to\\file');
      expect(result, equals('"path\\\\to\\\\file"'));
    });

    test('encodes string with newline escaping', () {
      final result = canonicalJsonEncode('line1\nline2');
      expect(result, equals('"line1\\nline2"'));
    });

    test('produces no whitespace', () {
      final result = canonicalJsonEncode({
        'a': [1, 2, 3],
        'b': {'c': true},
      });
      expect(result, isNot(contains(' ')));
      expect(result, isNot(contains('\n')));
      expect(result, isNot(contains('\t')));
    });

    test('throws ArgumentError on DateTime input', () {
      expect(
        () => canonicalJsonEncode(DateTime.utc(2026, 5, 4)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError on custom class instance', () {
      // A custom class that is not String/num/bool/null/List/Map
      final customObj = _CustomClass();
      expect(
        () => canonicalJsonEncode(customObj),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError on Map with non-String key (int key)', () {
      // Präzisierung: Nicht-String-Keys müssen ArgumentError werfen,
      // nicht stillschweigend via toString() konvertiert werden.
      expect(
        () => canonicalJsonEncode({1: 'value', 2: 'other'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError on Map with non-String key (symbol key)', () {
      expect(
        () => canonicalJsonEncode({#mySymbol: 'value'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('encodes nested list in map', () {
      final result = canonicalJsonEncode({
        'items': [1, 2, 3],
        'name': 'test',
      });
      expect(result, equals('{"items":[1,2,3],"name":"test"}'));
    });

    test('encodes null values within map', () {
      final result = canonicalJsonEncode({
        'a': null,
        'b': 'hello',
      });
      expect(result, equals('{"a":null,"b":"hello"}'));
    });
  });

  // ── Group 5: computeContentHash ─────────────────────────────────────────────

  group('computeContentHash', () {
    /// V9 Test-Vektor-Daten (Phase 4.0 Architekturbericht).
    /// participation als String mit fester Präzision (Präzisierung 5).
    final Map<String, dynamic> dataA = {
      'proposalId': 'p1',
      'cellId': 'c1',
      'votingMode': 'YES_NO_ABSTAIN',
      'result': 'ACCEPTED',
      'resultReason': null,
      'resultRelation': null,
      'yesVotes': 7,
      'noVotes': 2,
      'abstainVotes': 1,
      'participation': '1.0000',
      'eligibleVotersCount': 10,
      'decidedAt': '2026-05-04T12:00:00.000Z',
      'previousProposalId': null,
      'previousDecisionHash': null,
      'finalTitle': 'Test',
      'finalDescription': 'Test description',
      'optionResultsJson': null,
      'tieOptionIdsJson': null,
    };

    test('same input produces same hash (idempotent)', () {
      final hash1 = computeContentHash(dataA);
      final hash2 = computeContentHash(dataA);
      expect(hash1, equals(hash2));
    });

    test('V9: different key order in input map produces same hash', () {
      // Kanonische Sortierung muss Map-Insertions-Reihenfolge ignorieren.
      final dataReordered = <String, dynamic>{
        'finalTitle': 'Test',
        'cellId': 'c1',
        'tieOptionIdsJson': null,
        'proposalId': 'p1',
        'eligibleVotersCount': 10,
        'votingMode': 'YES_NO_ABSTAIN',
        'result': 'ACCEPTED',
        'abstainVotes': 1,
        'noVotes': 2,
        'yesVotes': 7,
        'participation': '1.0000',
        'previousDecisionHash': null,
        'decidedAt': '2026-05-04T12:00:00.000Z',
        'previousProposalId': null,
        'resultReason': null,
        'resultRelation': null,
        'finalDescription': 'Test description',
        'optionResultsJson': null,
      };

      expect(
        computeContentHash(dataReordered),
        equals(computeContentHash(dataA)),
      );
    });

    test('V9: changing a single field changes the hash', () {
      final modified = Map<String, dynamic>.from(dataA);
      modified['yesVotes'] = 8;

      expect(
        computeContentHash(modified),
        isNot(equals(computeContentHash(dataA))),
      );
    });

    test('null vs absent key produces different hashes', () {
      // null-Felder müssen explizit in der Map stehen.
      final withNull = <String, dynamic>{
        'proposalId': 'p1',
        'resultReason': null,
      };
      final withoutKey = <String, dynamic>{
        'proposalId': 'p1',
        // resultReason deliberately omitted
      };

      expect(
        computeContentHash(withNull),
        isNot(equals(computeContentHash(withoutKey))),
      );
    });

    test('hash output is exactly 64 characters', () {
      final hash = computeContentHash(dataA);
      expect(hash.length, equals(64));
    });

    test('hash output is lowercase hex', () {
      final hash = computeContentHash(dataA);
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('hash of empty map is consistent', () {
      final hash1 = computeContentHash({});
      final hash2 = computeContentHash({});
      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64));
      expect(hash1, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('changing null to a value in a field changes the hash', () {
      final baseData = <String, dynamic>{
        'proposalId': 'p1',
        'resultReason': null,
      };
      final withReason = <String, dynamic>{
        'proposalId': 'p1',
        'resultReason': ResultReason.quorumNotMet,
      };

      expect(
        computeContentHash(baseData),
        isNot(equals(computeContentHash(withReason))),
      );
    });

    test('different proposalId produces different hash', () {
      final dataB = Map<String, dynamic>.from(dataA);
      dataB['proposalId'] = 'p2';

      expect(
        computeContentHash(dataB),
        isNot(equals(computeContentHash(dataA))),
      );
    });

    test('V9: full decision-record-like map — hash is deterministic across '
        'multiple calls and key orderings', () {
      final hash = computeContentHash(dataA);

      // Same content, shuffled insertion order
      final dataShuffled = <String, dynamic>{
        'yesVotes': 7,
        'abstainVotes': 1,
        'previousDecisionHash': null,
        'resultReason': null,
        'optionResultsJson': null,
        'eligibleVotersCount': 10,
        'finalDescription': 'Test description',
        'decidedAt': '2026-05-04T12:00:00.000Z',
        'noVotes': 2,
        'resultRelation': null,
        'proposalId': 'p1',
        'tieOptionIdsJson': null,
        'participation': '1.0000',
        'cellId': 'c1',
        'finalTitle': 'Test',
        'previousProposalId': null,
        'result': 'ACCEPTED',
        'votingMode': 'YES_NO_ABSTAIN',
      };

      expect(computeContentHash(dataShuffled), equals(hash));
      expect(computeContentHash(dataA), equals(hash)); // idempotent
      expect(hash.length, equals(64));
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });
}

// ── Helper ───────────────────────────────────────────────────────────────────

/// A custom class used to verify that [canonicalJsonEncode] rejects
/// unsupported types with an [ArgumentError].
class _CustomClass {}
