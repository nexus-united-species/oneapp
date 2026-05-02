import 'dart:math';

import 'cell.dart';

/// Approval status of a cell-founding permit.
///
/// NOTE: "expired" is NOT a stored status — use the [CellFoundingPermit.isExpired]
/// computed getter instead.
enum PermitStatus { pending, approved, rejected, used, revoked }

String _generatePermitId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
}

/// A request (and optionally, an approved permit) to found a new NEXUS cell.
///
/// Lifecycle: pending → approved (+ expiresAt set) → used (requester founds cell)
///            pending → rejected
///            approved → revoked (admin revokes before use)
class CellFoundingPermit {
  final String id;
  final String requesterDid;
  final String requesterPseudonym;

  /// The requester's Nostr public key (secp256k1 hex). Used so the admin can
  /// send the approval event back without a contact relationship.
  final String? requesterNostrPubkey;

  /// Nostr pubkey of the admin who will / did decide on this permit.
  final String? adminNostrPubkey;

  final CellType cellType;
  final String? proposedName;
  final String? proposedDescription;
  final String? proposedCategory;

  /// Geographic region hint — required for [CellType.local] cells.
  final String? regionHint;

  final String? requestMessage;
  final PermitStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;

  /// DID of the admin who approved / rejected / revoked this permit.
  final String? decidedBy;

  final String? adminNote;

  /// When the approved permit expires. Computed [isExpired] is derived from this.
  final DateTime? expiresAt;

  final DateTime? usedAt;

  /// ID of the cell that was created when this permit was redeemed.
  final String? createdCellId;

  /// Maximum number of times this permit can be redeemed (default: 1).
  final int maxUses;

  const CellFoundingPermit({
    required this.id,
    required this.requesterDid,
    required this.requesterPseudonym,
    this.requesterNostrPubkey,
    this.adminNostrPubkey,
    required this.cellType,
    this.proposedName,
    this.proposedDescription,
    this.proposedCategory,
    this.regionHint,
    this.requestMessage,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.decidedBy,
    this.adminNote,
    this.expiresAt,
    this.usedAt,
    this.createdCellId,
    this.maxUses = 1,
  });

  // ── Computed getters (NOT persisted) ────────────────────────────────────────

  /// True when [expiresAt] is set and lies in the past (UTC).
  bool get isExpired =>
      expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt!);

  /// True when this permit can still be used: approved and not yet expired.
  bool get isActive => status == PermitStatus.approved && !isExpired;

  // ── Factory constructors ─────────────────────────────────────────────────────

  /// Creates a new founding-permit request.
  ///
  /// Throws [ArgumentError] if any required field is empty or inconsistent.
  factory CellFoundingPermit.createRequest({
    required CellType cellType,
    required String requesterDid,
    required String requesterPseudonym,
    required String requesterNostrPubkey,
    required String proposedName,
    String? adminNostrPubkey,
    String? proposedDescription,
    String? proposedCategory,
    String? regionHint,
    String? requestMessage,
  }) {
    if (requesterDid.isEmpty) {
      throw ArgumentError('requesterDid darf nicht leer sein');
    }
    if (requesterPseudonym.isEmpty) {
      throw ArgumentError('requesterPseudonym darf nicht leer sein');
    }
    if (proposedName.isEmpty) {
      throw ArgumentError('proposedName darf nicht leer sein');
    }
    if (cellType == CellType.local &&
        (regionHint == null || regionHint.isEmpty)) {
      throw ArgumentError('regionHint ist für lokale Zellen Pflicht');
    }
    if (cellType == CellType.thematic &&
        (proposedCategory == null || proposedCategory.isEmpty)) {
      throw ArgumentError('proposedCategory ist für thematische Zellen Pflicht');
    }
    return CellFoundingPermit(
      id: _generatePermitId(),
      requesterDid: requesterDid,
      requesterPseudonym: requesterPseudonym,
      requesterNostrPubkey: requesterNostrPubkey,
      adminNostrPubkey: adminNostrPubkey,
      cellType: cellType,
      proposedName: proposedName,
      proposedDescription: proposedDescription,
      proposedCategory: proposedCategory,
      regionHint: regionHint,
      requestMessage: requestMessage,
      status: PermitStatus.pending,
      requestedAt: DateTime.now().toUtc(),
      maxUses: 1,
    );
  }

  factory CellFoundingPermit.fromJson(Map<String, dynamic> json) =>
      CellFoundingPermit(
        id: json['id'] as String,
        requesterDid: json['requesterDid'] as String,
        requesterPseudonym: json['requesterPseudonym'] as String? ?? '',
        requesterNostrPubkey: json['requesterNostrPubkey'] as String?,
        adminNostrPubkey: json['adminNostrPubkey'] as String?,
        cellType: CellType.values.firstWhere(
          (e) => e.name == (json['cellType'] as String? ?? 'local'),
          orElse: () => CellType.local,
        ),
        proposedName: json['proposedName'] as String?,
        proposedDescription: json['proposedDescription'] as String?,
        proposedCategory: json['proposedCategory'] as String?,
        regionHint: json['regionHint'] as String?,
        requestMessage: json['requestMessage'] as String?,
        status: PermitStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String? ?? 'pending'),
          orElse: () => PermitStatus.pending,
        ),
        requestedAt: DateTime.fromMillisecondsSinceEpoch(
            json['requestedAt'] as int,
            isUtc: true),
        decidedAt: json['decidedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['decidedAt'] as int,
                isUtc: true)
            : null,
        decidedBy: json['decidedBy'] as String?,
        adminNote: json['adminNote'] as String?,
        expiresAt: json['expiresAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int,
                isUtc: true)
            : null,
        usedAt: json['usedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['usedAt'] as int,
                isUtc: true)
            : null,
        createdCellId: json['createdCellId'] as String?,
        maxUses: json['maxUses'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'requesterDid': requesterDid,
        'requesterPseudonym': requesterPseudonym,
        if (requesterNostrPubkey != null)
          'requesterNostrPubkey': requesterNostrPubkey,
        if (adminNostrPubkey != null) 'adminNostrPubkey': adminNostrPubkey,
        'cellType': cellType.name,
        if (proposedName != null) 'proposedName': proposedName,
        if (proposedDescription != null)
          'proposedDescription': proposedDescription,
        if (proposedCategory != null) 'proposedCategory': proposedCategory,
        if (regionHint != null) 'regionHint': regionHint,
        if (requestMessage != null) 'requestMessage': requestMessage,
        'status': status.name,
        'requestedAt': requestedAt.millisecondsSinceEpoch,
        if (decidedAt != null) 'decidedAt': decidedAt!.millisecondsSinceEpoch,
        if (decidedBy != null) 'decidedBy': decidedBy,
        if (adminNote != null) 'adminNote': adminNote,
        if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
        if (usedAt != null) 'usedAt': usedAt!.millisecondsSinceEpoch,
        if (createdCellId != null) 'createdCellId': createdCellId,
        'maxUses': maxUses,
      };

  CellFoundingPermit copyWith({
    String? id,
    String? requesterDid,
    String? requesterPseudonym,
    String? requesterNostrPubkey,
    String? adminNostrPubkey,
    CellType? cellType,
    String? proposedName,
    String? proposedDescription,
    String? proposedCategory,
    String? regionHint,
    String? requestMessage,
    PermitStatus? status,
    DateTime? requestedAt,
    DateTime? decidedAt,
    String? decidedBy,
    String? adminNote,
    DateTime? expiresAt,
    DateTime? usedAt,
    String? createdCellId,
    int? maxUses,
  }) =>
      CellFoundingPermit(
        id: id ?? this.id,
        requesterDid: requesterDid ?? this.requesterDid,
        requesterPseudonym: requesterPseudonym ?? this.requesterPseudonym,
        requesterNostrPubkey: requesterNostrPubkey ?? this.requesterNostrPubkey,
        adminNostrPubkey: adminNostrPubkey ?? this.adminNostrPubkey,
        cellType: cellType ?? this.cellType,
        proposedName: proposedName ?? this.proposedName,
        proposedDescription: proposedDescription ?? this.proposedDescription,
        proposedCategory: proposedCategory ?? this.proposedCategory,
        regionHint: regionHint ?? this.regionHint,
        requestMessage: requestMessage ?? this.requestMessage,
        status: status ?? this.status,
        requestedAt: requestedAt ?? this.requestedAt,
        decidedAt: decidedAt ?? this.decidedAt,
        decidedBy: decidedBy ?? this.decidedBy,
        adminNote: adminNote ?? this.adminNote,
        expiresAt: expiresAt ?? this.expiresAt,
        usedAt: usedAt ?? this.usedAt,
        createdCellId: createdCellId ?? this.createdCellId,
        maxUses: maxUses ?? this.maxUses,
      );
}
