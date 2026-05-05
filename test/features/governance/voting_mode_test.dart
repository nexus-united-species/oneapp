import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/voting_mode.dart';

void main() {
  group('VotingMode enum', () {
    test('has 3 values', () {
      expect(VotingMode.values.length, equals(3));
    });

    test('VotingMode.name produces correct strings for round-trip', () {
      expect(VotingMode.YES_NO_ABSTAIN.name, equals('YES_NO_ABSTAIN'));
      expect(VotingMode.SINGLE_CHOICE.name, equals('SINGLE_CHOICE'));
      expect(VotingMode.CANDIDATE_CHOICE.name, equals('CANDIDATE_CHOICE'));
    });
  });

  group('parseVotingMode', () {
    test('returns YES_NO_ABSTAIN for null', () {
      expect(parseVotingMode(null), equals(VotingMode.YES_NO_ABSTAIN));
    });

    test('returns YES_NO_ABSTAIN for empty string', () {
      expect(parseVotingMode(''), equals(VotingMode.YES_NO_ABSTAIN));
    });

    test('returns YES_NO_ABSTAIN for whitespace-only string', () {
      expect(parseVotingMode('   '), equals(VotingMode.YES_NO_ABSTAIN));
    });

    test('returns YES_NO_ABSTAIN for unknown values', () {
      expect(parseVotingMode('UNKNOWN'), equals(VotingMode.YES_NO_ABSTAIN));
      expect(parseVotingMode('yes_no'), equals(VotingMode.YES_NO_ABSTAIN));
      expect(parseVotingMode('legacy_mode'), equals(VotingMode.YES_NO_ABSTAIN));
    });

    test("returns YES_NO_ABSTAIN for 'YES_NO_ABSTAIN'", () {
      expect(parseVotingMode('YES_NO_ABSTAIN'), equals(VotingMode.YES_NO_ABSTAIN));
    });

    test("returns SINGLE_CHOICE for 'SINGLE_CHOICE'", () {
      expect(parseVotingMode('SINGLE_CHOICE'), equals(VotingMode.SINGLE_CHOICE));
    });

    test("returns CANDIDATE_CHOICE for 'CANDIDATE_CHOICE'", () {
      expect(parseVotingMode('CANDIDATE_CHOICE'), equals(VotingMode.CANDIDATE_CHOICE));
    });

    test('trims whitespace before parsing', () {
      expect(parseVotingMode('  SINGLE_CHOICE  '), equals(VotingMode.SINGLE_CHOICE));
    });
  });
}
