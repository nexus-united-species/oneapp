import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/decision_record.dart';
import 'package:nexus_oneapp/features/governance/decision_record_comparison.dart';

DecisionRecord _local() => DecisionRecord(
      recordId: 'rec-1',
      proposalId: 'prop-1',
      cellId: 'cell-1',
      finalTitle: 'Hochbeete',
      finalDescription: 'Test',
      result: 'approved',
      yesVotes: 2,
      noVotes: 1,
      abstainVotes: 0,
      participation: 0.75,
      decidedAt: DateTime.utc(2026, 11, 9, 12),
      allVotes: const [],
      contentHash: 'local-hash',
      previousDecisionHash: 'local-prev',
      nostrEventId: '',
    );

Map<String, dynamic> _received({
  String result = 'approved',
  int yes = 2,
  int no = 1,
  num participation = 0.75,
}) =>
    {
      'result': result,
      'yesVotes': yes,
      'noVotes': no,
      'abstainVotes': 0,
      'participation': participation,
      'optionResultsJson': null,
    };

void main() {
  test('finds no mismatch when both devices tallied the same', () {
    expect(decisionRecordMismatches(_local(), _received()), isEmpty);
  });

  test('ignores rounding below four decimals of participation', () {
    expect(
      decisionRecordMismatches(_local(), _received(participation: 0.750001)),
      isEmpty,
    );
  });

  test('reports a forged result and changed counts', () {
    expect(
      decisionRecordMismatches(
          _local(), _received(result: 'rejected', yes: 0, no: 3)),
      ['result', 'yesVotes', 'noVotes'],
    );
  });

  test('TD-34: compares the eligible count only when both records have it',
      () {
    final local = DecisionRecord.fromMap({
      ..._local().toMap(),
      'eligible_voters_count': 4,
    });

    expect(
      decisionRecordMismatches(
          local, {..._received(), 'eligibleVotersCount': 5}),
      ['eligibleVotersCount'],
    );
    expect(decisionRecordMismatches(local, _received()), isEmpty,
        reason: 'older senders do not send the count');
  });

  test('reports a different participation', () {
    expect(
      decisionRecordMismatches(_local(), _received(participation: 1)),
      ['participation'],
    );
  });
}
