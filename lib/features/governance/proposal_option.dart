import 'dart:math';

/// Lifecycle status of a proposal option.
enum OptionStatus { ACTIVE, WITHDRAWN }

String _generateOptionId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
}

OptionStatus _parseOptionStatus(String? s) {
  if (s == null) return OptionStatus.ACTIVE;
  try {
    return OptionStatus.values.byName(s);
  } catch (_) {
    return OptionStatus.ACTIVE;
  }
}

/// A selectable option within a governance proposal.
///
/// Used for SINGLE_CHOICE and CANDIDATE_CHOICE voting modes (G2 spec §9.4).
/// Persisted in the `proposal_options` table (DB schema v20).
class ProposalOption {
  final String optionId;
  final String proposalId;
  final String label;
  final String? description;

  /// Only populated for CANDIDATE_CHOICE proposals.
  final String? candidateDid;
  final String? candidatePseudonym;
  final DateTime? candidateAcceptedAt;
  final DateTime? candidateWithdrawnAt;

  final OptionStatus status;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProposalOption({
    required this.optionId,
    required this.proposalId,
    required this.label,
    this.description,
    this.candidateDid,
    this.candidatePseudonym,
    this.candidateAcceptedAt,
    this.candidateWithdrawnAt,
    this.status = OptionStatus.ACTIVE,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a new ACTIVE option with a generated ID and UTC timestamps.
  factory ProposalOption.create({
    required String proposalId,
    required String label,
    String? description,
    String? candidateDid,
    String? candidatePseudonym,
    int position = 0,
  }) {
    final now = DateTime.now().toUtc();
    return ProposalOption(
      optionId: _generateOptionId(),
      proposalId: proposalId,
      label: label,
      description: description,
      candidateDid: candidateDid,
      candidatePseudonym: candidatePseudonym,
      candidateAcceptedAt: null,
      candidateWithdrawnAt: null,
      status: OptionStatus.ACTIVE,
      position: position,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Serialises to the canonical DB format (snake_case keys, epochs in ms).
  Map<String, dynamic> toMap() => {
        'option_id': optionId,
        'proposal_id': proposalId,
        'label': label,
        'description': description,
        'candidate_did': candidateDid,
        'candidate_pseudonym': candidatePseudonym,
        'candidate_accepted_at': candidateAcceptedAt?.millisecondsSinceEpoch,
        'candidate_withdrawn_at': candidateWithdrawnAt?.millisecondsSinceEpoch,
        'status': status.name,
        'position': position,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory ProposalOption.fromMap(Map<String, dynamic> map) {
    return ProposalOption(
      optionId: map['option_id'] as String,
      proposalId: map['proposal_id'] as String,
      label: map['label'] as String,
      description: map['description'] as String?,
      candidateDid: map['candidate_did'] as String?,
      candidatePseudonym: map['candidate_pseudonym'] as String?,
      candidateAcceptedAt: map['candidate_accepted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['candidate_accepted_at'] as int,
              isUtc: true)
          : null,
      candidateWithdrawnAt: map['candidate_withdrawn_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['candidate_withdrawn_at'] as int,
              isUtc: true)
          : null,
      status: _parseOptionStatus(map['status'] as String?),
      position: map['position'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at'] as int,
          isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          map['updated_at'] as int,
          isUtc: true),
    );
  }
}
