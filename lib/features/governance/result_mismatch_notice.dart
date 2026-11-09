import 'package:flutter/material.dart';

import 'audit_log_entry.dart';

/// TD-41: notice shown at a decided proposal when another member's device
/// reported a different result than this device's own tally.

String _resultLabel(Object? result) => switch (result) {
      'approved' => 'Angenommen',
      'rejected' => 'Abgelehnt',
      _ => 'Ungültig',
    };

/// User-facing text for the RESULT_MISMATCH entries of one proposal, or
/// null if there are none.
String? resultMismatchText(List<AuditLogEntry> entries) {
  final mismatches = entries
      .where((e) => e.eventType == AuditEventType.RESULT_MISMATCH)
      .toList();
  if (mismatches.isEmpty) return null;
  final latest = mismatches.last;
  final p = latest.payload;
  final who = latest.actorPseudonym.isNotEmpty
      ? latest.actorPseudonym
      : 'Ein anderes Mitglied';
  final more = mismatches.length > 1
      ? ' (insgesamt ${mismatches.length} abweichende Meldungen)'
      : '';
  return '$who meldet ein anderes Ergebnis: ${_resultLabel(p['result'])} '
      '(Ja ${p['yes'] ?? '?'}, Nein ${p['no'] ?? '?'}, '
      'Enthaltung ${p['abstain'] ?? '?'})$more. '
      'Angezeigt wird die Auszählung dieses Geräts. Meist fehlen einem der '
      'Geräte Stimmen.';
}

class ResultMismatchNotice extends StatelessWidget {
  final String text;

  const ResultMismatchNotice({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Colors.orange.shade300;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
