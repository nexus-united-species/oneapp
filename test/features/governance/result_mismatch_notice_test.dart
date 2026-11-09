import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/audit_log_entry.dart';
import 'package:nexus_oneapp/features/governance/result_mismatch_notice.dart';

AuditLogEntry _entry(
  AuditEventType type, {
  String actor = '',
  Map<String, dynamic> payload = const {},
}) =>
    AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: 'prop-1',
      cellId: 'cell-1',
      eventType: type,
      actorDid: actor.isEmpty ? '' : 'did:key:$actor',
      actorPseudonym: actor,
      timestamp: DateTime.utc(2026, 11, 9, 12),
      payload: payload,
    );

const _forged = {'result': 'rejected', 'yes': 0, 'no': 5, 'abstain': 0};

void main() {
  test('shows nothing without a mismatch', () {
    expect(
      resultMismatchText([_entry(AuditEventType.RESULT_CALCULATED)]),
      isNull,
    );
  });

  test('names the sender and the reported numbers', () {
    final text = resultMismatchText([
      _entry(AuditEventType.RESULT_MISMATCH, actor: 'Josh', payload: _forged),
    ])!;

    expect(text, startsWith('Josh meldet ein anderes Ergebnis: Abgelehnt'));
    expect(text, contains('Ja 0, Nein 5, Enthaltung 0'));
    expect(text, contains('Auszählung dieses Geräts'));
  });

  test('falls back to a neutral sender and counts several reports', () {
    final text = resultMismatchText([
      _entry(AuditEventType.RESULT_MISMATCH, payload: _forged),
      _entry(AuditEventType.RESULT_MISMATCH, payload: _forged),
    ])!;

    expect(text, startsWith('Ein anderes Mitglied meldet'));
    expect(text, contains('insgesamt 2 abweichende Meldungen'));
  });

  testWidgets('renders the notice text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ResultMismatchNotice(text: 'Abweichung')),
    ));

    expect(find.text('Abweichung'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
