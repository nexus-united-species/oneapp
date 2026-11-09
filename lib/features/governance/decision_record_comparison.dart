import 'decision_record.dart';

/// TD-41: compares a received Kind-31013 decision record with the record
/// this device tallied itself.
///
/// The content hash cannot be compared: its input includes the sender's
/// previous decision hash, which differs between devices. So the outcome
/// fields are compared one by one. Returns the names of differing fields,
/// empty if both devices reached the same result.
List<String> decisionRecordMismatches(
  DecisionRecord local,
  Map<String, dynamic> received,
) {
  final mismatches = <String>[];
  void check(String field, Object? localValue, Object? receivedValue) {
    if (localValue != receivedValue) mismatches.add(field);
  }

  check('result', local.result, received['result']);
  check('yesVotes', local.yesVotes, received['yesVotes']);
  check('noVotes', local.noVotes, received['noVotes']);
  check('abstainVotes', local.abstainVotes, received['abstainVotes']);
  check(
    'participation',
    local.participation.toStringAsFixed(4),
    (received['participation'] as num?)?.toDouble().toStringAsFixed(4),
  );
  check('optionResultsJson', local.optionResultsJson,
      received['optionResultsJson']);
  // TD-34: older senders do not send the count; compare only if both have it.
  final receivedCount = received['eligibleVotersCount'];
  if (local.eligibleVotersCount != null && receivedCount != null) {
    check('eligibleVotersCount', local.eligibleVotersCount, receivedCount);
  }
  return mismatches;
}
