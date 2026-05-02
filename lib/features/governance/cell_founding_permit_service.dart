import 'package:flutter/foundation.dart';

import '../../core/config/system_config.dart';
import '../../core/identity/identity_service.dart';
import '../../core/storage/pod_database.dart';
import '../../services/notification_service.dart';
import '../../services/role_service.dart';
import 'cell.dart';
import 'cell_founding_permit.dart';

/// Manages cell-founding permits — requests, approvals, rejections, and redemption.
///
/// Singleton, analogous to [CellService].
///
/// Two lists are kept in memory:
///   [_sentPermits]    — permits the local user requested (is_sent = 1 in DB)
///   [_receivedPermits] — incoming requests visible to admins (is_sent = 0 in DB)
class CellFoundingPermitService extends ChangeNotifier {
  CellFoundingPermitService._();
  static final instance = CellFoundingPermitService._();

  final List<CellFoundingPermit> _sentPermits = [];
  final List<CellFoundingPermit> _receivedPermits = [];

  /// Must be set by the app layer (e.g. ChatProvider) once [NostrTransport] is
  /// initialized. Returns the local secp256k1 Nostr pubkey hex, or null when
  /// Nostr is not yet ready.
  String? Function()? getMyNostrPubkeyHex;

  // ── Queries ──────────────────────────────────────────────────────────────────

  /// Outgoing requests with status [PermitStatus.pending].
  List<CellFoundingPermit> get myPendingRequests =>
      _sentPermits.where((p) => p.status == PermitStatus.pending).toList();

  /// Outgoing permits that are currently active (approved + not expired).
  List<CellFoundingPermit> get myApprovedPermits =>
      _sentPermits.where((p) => p.isActive).toList();

  /// Incoming requests that still need an admin decision.
  List<CellFoundingPermit> get pendingRequests =>
      _receivedPermits.where((p) => p.status == PermitStatus.pending).toList();

  /// All incoming permits regardless of status.
  List<CellFoundingPermit> get allReceivedPermits =>
      List.unmodifiable(_receivedPermits);

  /// Looks up a permit by ID across both lists.
  CellFoundingPermit? findById(String id) {
    for (final p in _sentPermits) {
      if (p.id == id) return p;
    }
    for (final p in _receivedPermits) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Returns the first active permit for [did] of the given [cellType], or null.
  CellFoundingPermit? getActivePermitForType(String did, CellType cellType) =>
      _sentPermits
          .where((p) =>
              p.requesterDid == did &&
              p.cellType == cellType &&
              p.isActive)
          .firstOrNull;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Loads all permits from the encrypted DB and partitions them into the two
  /// in-memory lists.
  Future<void> load() async {
    final rows = await PodDatabase.instance.loadAllCellFoundingPermits();
    _sentPermits.clear();
    _receivedPermits.clear();
    for (final row in rows) {
      try {
        final permit = CellFoundingPermit.fromJson(row);
        if ((row['is_sent'] as int?) == 1) {
          _sentPermits.add(permit);
        } else {
          _receivedPermits.add(permit);
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  // ── Mutations ────────────────────────────────────────────────────────────────

  /// Creates and persists a new founding-permit request for the current user.
  ///
  /// Throws [StateError] when no identity or Nostr key is available.
  /// Throws [ArgumentError] (from [CellFoundingPermit.createRequest]) on
  /// invalid combinations (e.g. local cell without regionHint).
  Future<CellFoundingPermit> requestPermit({
    required CellType cellType,
    required String proposedName,
    String? regionHint,
    String? proposedCategory,
    String? proposedDescription,
    String? requestMessage,
  }) async {
    final identity = IdentityService.instance.currentIdentity;
    if (identity == null) {
      throw StateError('Keine Identität geladen.');
    }
    final nostrPubkey = getMyNostrPubkeyHex?.call();
    if (nostrPubkey == null) {
      throw StateError('Nostr-Schlüssel noch nicht initialisiert.');
    }
    final adminPubkey =
        SystemConfig.instance.bootstrapCellAuthors.firstOrNull;

    final permit = CellFoundingPermit.createRequest(
      cellType: cellType,
      requesterDid: identity.did,
      requesterPseudonym: identity.pseudonym,
      requesterNostrPubkey: nostrPubkey,
      proposedName: proposedName,
      adminNostrPubkey: adminPubkey,
      proposedDescription: proposedDescription,
      proposedCategory: proposedCategory,
      regionHint: regionHint,
      requestMessage: requestMessage,
    );

    // AETHER SYNC-RULE: update in-memory BEFORE first await
    _sentPermits.add(permit);
    notifyListeners();

    await PodDatabase.instance.upsertCellFoundingPermit(
      permit.id,
      permit.toJson(),
      isSent: true,
    );
    return permit;
  }

  /// Approves a pending permit. Admin-only.
  ///
  /// [validity] controls how long the permit stays active after approval
  /// (default: 7 days).
  Future<void> approvePermit(
    String permitId, {
    String? adminNote,
    Duration validity = const Duration(days: 7),
  }) async {
    _assertIsAdmin();
    final idx = _indexInReceived(permitId);
    if (idx == -1) throw StateError('[PERMIT] $permitId nicht gefunden.');
    final now = DateTime.now().toUtc();
    final adminDid = IdentityService.instance.currentIdentity!.did;
    final updated = _receivedPermits[idx].copyWith(
      status: PermitStatus.approved,
      decidedAt: now,
      decidedBy: adminDid,
      adminNote: adminNote,
      expiresAt: now.add(validity),
    );

    // AETHER SYNC-RULE
    _receivedPermits[idx] = updated;
    notifyListeners();

    await PodDatabase.instance.upsertCellFoundingPermit(
      updated.id,
      updated.toJson(),
      isSent: false,
    );
    print('[PERMIT-APPROVE] ${updated.id} genehmigt bis ${updated.expiresAt}');
  }

  /// Rejects a pending permit. Admin-only.
  Future<void> rejectPermit(String permitId, {String? adminNote}) async {
    _assertIsAdmin();
    final idx = _indexInReceived(permitId);
    if (idx == -1) throw StateError('[PERMIT] $permitId nicht gefunden.');
    final now = DateTime.now().toUtc();
    final adminDid = IdentityService.instance.currentIdentity!.did;
    final updated = _receivedPermits[idx].copyWith(
      status: PermitStatus.rejected,
      decidedAt: now,
      decidedBy: adminDid,
      adminNote: adminNote,
    );

    // AETHER SYNC-RULE
    _receivedPermits[idx] = updated;
    notifyListeners();

    await PodDatabase.instance.upsertCellFoundingPermit(
      updated.id,
      updated.toJson(),
      isSent: false,
    );
    print('[PERMIT-REJECT] ${updated.id}');
  }

  /// Revokes a previously approved permit. Admin-only.
  Future<void> revokePermit(String permitId, {String? adminNote}) async {
    _assertIsAdmin();
    final idx = _indexInReceived(permitId);
    if (idx == -1) throw StateError('[PERMIT] $permitId nicht gefunden.');
    final now = DateTime.now().toUtc();
    final adminDid = IdentityService.instance.currentIdentity!.did;
    final updated = _receivedPermits[idx].copyWith(
      status: PermitStatus.revoked,
      decidedAt: now,
      decidedBy: adminDid,
      adminNote: adminNote,
    );

    // AETHER SYNC-RULE
    _receivedPermits[idx] = updated;
    notifyListeners();

    await PodDatabase.instance.upsertCellFoundingPermit(
      updated.id,
      updated.toJson(),
      isSent: false,
    );
    print('[PERMIT-REVOKE] ${updated.id}');
  }

  /// Marks a permit as used after successfully founding a cell.
  ///
  /// Checks in order:
  ///   1. Permit must exist in [_sentPermits].
  ///   2. Permit must be [isActive] (approved + not expired).
  ///   3. Caller's DID must match [CellFoundingPermit.requesterDid].
  Future<void> markPermitUsed(String permitId, String createdCellId) async {
    final idx = _indexInSent(permitId);
    if (idx == -1) throw StateError('[PERMIT] $permitId nicht gefunden.');

    final permit = _sentPermits[idx];

    // Check validity before identity so the test can inject a non-active permit
    // and observe the correct StateError without needing an initialised identity.
    if (!permit.isActive) {
      throw StateError(
          '[PERMIT] Permit ist nicht aktiv (Status: ${permit.status.name}).');
    }

    final identity = IdentityService.instance.currentIdentity;
    if (identity == null || permit.requesterDid != identity.did) {
      throw StateError('[PERMIT] Nur der Antragsteller kann das Permit einlösen.');
    }

    final updated = permit.copyWith(
      status: PermitStatus.used,
      usedAt: DateTime.now().toUtc(),
      createdCellId: createdCellId,
    );

    // AETHER SYNC-RULE
    _sentPermits[idx] = updated;
    notifyListeners();

    await PodDatabase.instance.upsertCellFoundingPermit(
      updated.id,
      updated.toJson(),
      isSent: true,
    );
    print('[PERMIT-USED] ${updated.id} → Zelle $createdCellId');
  }

  /// Upserts a permit received via Nostr relay.
  ///
  /// Routing logic:
  ///   - If [permit.requesterDid] matches the local DID → goes into [_sentPermits]
  ///     (requester receives their own approved/rejected permit back).
  ///   - Otherwise → goes into [_receivedPermits] (admin sees incoming request).
  Future<void> handleIncomingPermitEvent(CellFoundingPermit permit) async {
    final myDid = IdentityService.instance.currentIdentity?.did;
    final isMine = permit.requesterDid == myDid;

    if (isMine) {
      final idx = _indexInSent(permit.id);
      // AETHER SYNC-RULE: in-memory update before await
      if (idx != -1) {
        _sentPermits[idx] = permit;
      } else {
        _sentPermits.add(permit);
      }
    } else {
      final idx = _indexInReceived(permit.id);
      if (idx != -1) {
        _receivedPermits[idx] = permit;
      } else {
        _receivedPermits.add(permit);

        // Notify admins about new incoming permit requests.
        // Conditions: new permit (idx == -1), not own request, pending status, local user is admin.
        if (permit.status == PermitStatus.pending &&
            myDid != null &&
            RoleService.instance.isSystemAdmin(myDid)) {
          final typeLabel =
              permit.cellType == CellType.local ? 'lokale' : 'thematische';
          await NotificationService.instance.showGenericNotification(
            title: 'Neuer Zellgründungsantrag',
            body:
                '${permit.requesterPseudonym} möchte eine $typeLabel Zelle gründen.',
            payload: 'cell_founding_permit:${permit.id}',
          );
        }
      }
    }
    notifyListeners();

    await PodDatabase.instance.upsertCellFoundingPermit(
      permit.id,
      permit.toJson(),
      isSent: isMine,
    );
  }

  // ── Test helpers ─────────────────────────────────────────────────────────────

  /// Directly injects permits for unit tests. Not for use in production code.
  @visibleForTesting
  void injectPermitsForTest({
    List<CellFoundingPermit> sent = const [],
    List<CellFoundingPermit> received = const [],
  }) {
    _sentPermits
      ..clear()
      ..addAll(sent);
    _receivedPermits
      ..clear()
      ..addAll(received);
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  void _assertIsAdmin() {
    final did = IdentityService.instance.currentIdentity?.did;
    if (did == null || !RoleService.instance.isSystemAdmin(did)) {
      throw StateError('Nur Administratoren können Permits verwalten.');
    }
  }

  int _indexInSent(String id) => _sentPermits.indexWhere((p) => p.id == id);

  int _indexInReceived(String id) =>
      _receivedPermits.indexWhere((p) => p.id == id);
}
