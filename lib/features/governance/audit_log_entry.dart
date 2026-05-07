import 'dart:convert';
import 'dart:math';

/// The type of event recorded in the audit log.
enum AuditEventType {
  PROPOSAL_CREATED,
  PROPOSAL_EDITED,
  PROPOSAL_STATUS_CHANGED,
  PROPOSAL_WITHDRAWN,
  VOTE_CAST,
  VOTE_CHANGED,
  VOTE_LATE_ACCEPTED,
  VOTE_LATE_REJECTED,
  RESULT_CALCULATED,
  PROPOSAL_ARCHIVED,
  // Phase G2.1.1a — delegation audit types (emitted starting from G2.1.1b).
  DELEGATION_CREATED,
  DELEGATION_REVOKED,
  DELEGATION_REVOKED_BY_DIRECT_VOTE,
  DELEGATION_SUPERSEDED,
  DELEGATION_EXPIRED,
  DELEGATION_INVALIDATED,
}

/// An immutable audit trail entry for a governance event.
class AuditLogEntry {
  final String entryId;
  final String proposalId;
  final String cellId;
  final AuditEventType eventType;
  final String actorDid;
  final String actorPseudonym;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  final String? nostrEventId;

  AuditLogEntry({
    required this.entryId,
    required this.proposalId,
    required this.cellId,
    required this.eventType,
    required this.actorDid,
    required this.actorPseudonym,
    required this.timestamp,
    required this.payload,
    this.nostrEventId,
  });

  static String generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Map<String, dynamic> toMap() => {
        'entry_id': entryId,
        'proposal_id': proposalId,
        'cell_id': cellId,
        'event_type': eventType.name,
        'actor_did': actorDid,
        'actor_pseudonym': actorPseudonym,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'payload': jsonEncode(payload),
        'nostr_event_id': nostrEventId,
      };

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    AuditEventType eventType;
    try {
      eventType = AuditEventType.values.byName(map['event_type'] as String);
    } catch (_) {
      // Defensive fallback: unknown event_type values (e.g. from a future
      // schema version read by older code) do not crash the app.
      eventType = AuditEventType.PROPOSAL_CREATED;
    }
    return AuditLogEntry(
        entryId: map['entry_id'] as String,
        proposalId: map['proposal_id'] as String,
        cellId: map['cell_id'] as String,
        eventType: eventType,
        actorDid: map['actor_did'] as String,
        actorPseudonym: map['actor_pseudonym'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            map['timestamp'] as int,
            isUtc: true),
        payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
        nostrEventId: map['nostr_event_id'] as String?,
      );
  }
}
