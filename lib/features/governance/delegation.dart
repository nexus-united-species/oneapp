import 'dart:math';

/// Phase G2.1.1a: Lifecycle status of a delegation.
///
/// In G2.1, only ACTIVE / REVOKED / SUPERSEDED are persisted to the
/// delegations table. EXPIRED and INVALID are reserved for tally-time
/// evaluation results and audit events; the underlying delegation row is
/// NOT mutated when the tally finds a delegation expired or invalid
/// (D9 Variante A).
enum DelegationStatus {
  ACTIVE,
  REVOKED,
  SUPERSEDED,

  /// Reserved for tally-time evaluation. NOT persisted to DB in G2.1.
  EXPIRED,

  /// Reserved for tally-time evaluation. NOT persisted to DB in G2.1.
  INVALID,
}

/// Parses a [DelegationStatus] from a raw string defensively.
///
/// Unknown or null values fall back to [DelegationStatus.ACTIVE], consistent
/// with the Phase 4.7c2 [OptionStatus] parsing pattern.
DelegationStatus parseDelegationStatus(String? s) {
  if (s == null) return DelegationStatus.ACTIVE;
  try {
    return DelegationStatus.values.byName(s);
  } catch (_) {
    return DelegationStatus.ACTIVE;
  }
}

String _generateDelegationId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
}

/// A delegation of voting rights from one cell member to another for a
/// specific proposal (G2 spec v1.4 §31 — Liquid Democracy).
///
/// Persisted in the `delegations` table (DB schema v23).
///
/// Non-transitive (E4): A's delegation to B counts only when B votes
/// directly. B's own delegation to C does not chain through to A's
/// delegation.
class Delegation {
  final String delegationId;
  final String delegatorDid;
  final String delegateDid;
  final String proposalId;
  final String cellId;
  final DelegationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Nostr event ID assigned after Kind-31012 wire publish (G2.1.2).
  /// Empty string for locally-created delegations before wire publish.
  final String nostrEventId;

  const Delegation({
    required this.delegationId,
    required this.delegatorDid,
    required this.delegateDid,
    required this.proposalId,
    required this.cellId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.nostrEventId = '',
  });

  /// Creates a new [DelegationStatus.ACTIVE] delegation with a generated ID
  /// and UTC timestamps.
  ///
  /// Wire publish and [nostrEventId] assignment happen later in G2.1.2.
  factory Delegation.create({
    required String delegatorDid,
    required String delegateDid,
    required String proposalId,
    required String cellId,
    DelegationStatus status = DelegationStatus.ACTIVE,
  }) {
    final now = DateTime.now().toUtc();
    return Delegation(
      delegationId: _generateDelegationId(),
      delegatorDid: delegatorDid,
      delegateDid: delegateDid,
      proposalId: proposalId,
      cellId: cellId,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Returns a copy with only the specified fields overridden.
  ///
  /// Used by the service layer (G2.1.1b) to transition status or record the
  /// Nostr event ID after a successful publish.
  Delegation copyWith({
    DelegationStatus? status,
    DateTime? updatedAt,
    String? nostrEventId,
  }) {
    return Delegation(
      delegationId: delegationId,
      delegatorDid: delegatorDid,
      delegateDid: delegateDid,
      proposalId: proposalId,
      cellId: cellId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nostrEventId: nostrEventId ?? this.nostrEventId,
    );
  }

  /// Serialises to DB format (snake_case keys, timestamps as ms-since-epoch).
  Map<String, dynamic> toMap() => {
        'delegation_id': delegationId,
        'delegator_did': delegatorDid,
        'delegate_did': delegateDid,
        'proposal_id': proposalId,
        'cell_id': cellId,
        'status': status.name,
        'nostr_event_id': nostrEventId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Delegation.fromMap(Map<String, dynamic> m) => Delegation(
        delegationId: m['delegation_id'] as String,
        delegatorDid: m['delegator_did'] as String,
        delegateDid: m['delegate_did'] as String,
        proposalId: m['proposal_id'] as String,
        cellId: m['cell_id'] as String,
        status: parseDelegationStatus(m['status'] as String?),
        nostrEventId: (m['nostr_event_id'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['created_at'] as num).toInt(),
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updated_at'] as num).toInt(),
          isUtc: true,
        ),
      );
}
