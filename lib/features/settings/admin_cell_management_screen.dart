import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/contacts/contact_service.dart';
import '../../core/identity/identity_service.dart';
import '../../features/chat/chat_provider.dart';
import '../../features/governance/cell.dart';
import '../../features/governance/cell_founding_permit.dart';
import '../../features/governance/cell_founding_permit_service.dart';
import '../../features/governance/cell_service.dart';
import '../../services/role_service.dart';
import '../../shared/theme/app_theme.dart';

/// Superadmin screen to view all cells in the local DB, identify orphaned
/// cells (founded by an unknown DID), and delete them with a Kind-5 Nostr
/// dissolution event.
///
/// Also shows pending cell-founding-permit requests and active permits for
/// admin approval / rejection / revocation.
class AdminCellManagementScreen extends StatefulWidget {
  const AdminCellManagementScreen({super.key});

  @override
  State<AdminCellManagementScreen> createState() =>
      _AdminCellManagementScreenState();
}

class _AdminCellManagementScreenState
    extends State<AdminCellManagementScreen> {
  List<Cell> _cells = [];
  List<CellFoundingPermit> _permits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCells();
  }

  Future<void> _loadCells() async {
    // Re-load so the lists are fresh even if services were loaded earlier.
    await CellService.instance.load();
    await CellFoundingPermitService.instance.load();
    if (!mounted) return;
    setState(() {
      _cells = List.from(CellService.instance.myCells);
      _permits =
          List.from(CellFoundingPermitService.instance.allReceivedPermits);
      _loading = false;
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// A cell is "orphaned" when its founder DID is neither the current user
  /// nor any known contact.
  bool _isOrphaned(Cell cell) {
    final myDid = IdentityService.instance.currentIdentity?.did ?? '';
    if (cell.createdBy == myDid) return false;
    return !ContactService.instance.contacts
        .any((c) => c.did == cell.createdBy);
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _shortDid(String did) =>
      did.length > 28 ? '${did.substring(0, 16)}…${did.substring(did.length - 8)}' : did;

  String _cellTypeLabel(CellType t) =>
      t == CellType.local ? 'Lokal' : 'Thematisch';

  // ── Permit actions ────────────────────────────────────────────────────────

  Future<void> _approvePermit(
      BuildContext context, CellFoundingPermit permit) async {
    final noteCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final chatProvider = context.read<ChatProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Gründungsantrag genehmigen?',
          style: TextStyle(color: Colors.green),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Antrag von ${permit.requesterPseudonym}',
              style: const TextStyle(color: AppColors.onDark),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLength: 300,
              maxLines: 3,
              style: const TextStyle(color: AppColors.onDark),
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Genehmigen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await CellFoundingPermitService.instance
          .approvePermit(permit.id, adminNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());

      // Fetch updated permit from service — do not re-use the old object.
      final updated =
          CellFoundingPermitService.instance.findById(permit.id);
      if (updated != null) {
        final published = await chatProvider.publishPermitDecision(
          updated,
          action: 'approve',
        );
        if (!published && mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text(
                'Freigabe lokal gespeichert, konnte aber nicht gesendet werden.'),
            backgroundColor: Colors.orange,
          ));
        }
      }

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content:
            Text('Gründungsantrag von ${permit.requesterPseudonym} genehmigt.'),
        backgroundColor: Colors.green,
      ));
      setState(() => _loading = true);
      _loadCells();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _rejectPermit(
      BuildContext context, CellFoundingPermit permit) async {
    final noteCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final chatProvider = context.read<ChatProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Antrag ablehnen?',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Antrag von ${permit.requesterPseudonym}',
              style: const TextStyle(color: AppColors.onDark),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLength: 300,
              maxLines: 3,
              style: const TextStyle(color: AppColors.onDark),
              decoration: const InputDecoration(
                labelText: 'Ablehnungsgrund (optional)',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ablehnen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await CellFoundingPermitService.instance
          .rejectPermit(permit.id, adminNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());

      final updated =
          CellFoundingPermitService.instance.findById(permit.id);
      if (updated != null) {
        final published = await chatProvider.publishPermitDecision(
          updated,
          action: 'reject',
        );
        if (!published && mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text(
                'Entscheidung lokal gespeichert, konnte aber nicht gesendet werden.'),
            backgroundColor: Colors.orange,
          ));
        }
      }

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Antrag abgelehnt.'),
        backgroundColor: Colors.redAccent,
      ));
      setState(() => _loading = true);
      _loadCells();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _revokePermit(
      BuildContext context, CellFoundingPermit permit) async {
    final messenger = ScaffoldMessenger.of(context);
    final chatProvider = context.read<ChatProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Freigabe widerrufen?',
          style: TextStyle(color: Colors.orange),
        ),
        content: Text(
          'Die aktive Freigabe für ${permit.requesterPseudonym} wird widerrufen. '
          'Diese Aktion kann nicht rückgängig gemacht werden.',
          style: const TextStyle(color: AppColors.onDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Widerrufen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await CellFoundingPermitService.instance.revokePermit(permit.id);

      final updated =
          CellFoundingPermitService.instance.findById(permit.id);
      if (updated != null) {
        final published = await chatProvider.publishPermitDecision(
          updated,
          action: 'revoke',
        );
        if (!published && mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text(
                'Freigabe lokal widerrufen, konnte aber nicht gesendet werden.'),
            backgroundColor: Colors.orange,
          ));
        }
      }

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Freigabe widerrufen.'),
        backgroundColor: Colors.orange,
      ));
      setState(() => _loading = true);
      _loadCells();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _deleteCell(BuildContext context, Cell cell) async {
    final chatProvider = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Gemeinschaft "${cell.name}" löschen?',
          style: const TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'ID: ${cell.id}\n\n'
          'Die Gemeinschaft wird aus der lokalen Datenbank gelöscht und ein '
          'Kind-5 Nostr-Dissolution-Event wird als Superadmin gesendet.',
          style: const TextStyle(color: AppColors.onDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Abbrechen', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen & Kind-5 senden'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await CellService.instance.deleteCell(cell.id);
      await chatProvider.deleteCellChannels(cell.id);

      // Kind-5: asks relays to delete the original announcement.
      chatProvider.publishNostrCellDeletion(cell.id, cell.name);
      // Kind-30000 with deleted:true: notifies all member devices.
      chatProvider.publishNostrCellDissolution(cell.toJson());

      if (!mounted) return;
      setState(() => _cells.removeWhere((c) => c.id == cell.id));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gemeinschaft "${cell.name}" gelöscht · Kind-5 gesendet.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final myDid = IdentityService.instance.currentIdentity?.did ?? '';
    final isAdmin = RoleService.instance.isSystemAdmin(myDid);
    final orphanCount = _cells.where(_isOrphaned).length;

    final pendingPermits =
        _permits.where((p) => p.status == PermitStatus.pending).toList();
    final activePermits =
        _permits.where((p) => p.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemeinschaften verwalten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu laden',
            onPressed: () {
              setState(() => _loading = true);
              _loadCells();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Gründungsanträge (admin only) ──────────────────────
                  if (isAdmin) ...[
                    _buildPendingPermitsSection(
                        context, pendingPermits),
                    _buildActivePermitsSection(context, activePermits),
                  ],

                  // ── Zellenübersicht ────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: AppColors.surfaceVariant,
                    child: Text(
                      '${_cells.length} Gemeinschaften gesamt'
                      '${orphanCount > 0 ? ' · $orphanCount verwaist' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: orphanCount > 0
                            ? Colors.orange
                            : AppColors.onDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  if (_cells.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 32),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hexagon_outlined,
                                size: 48, color: Colors.grey[700]),
                            const SizedBox(height: 12),
                            const Text(
                              'Keine Gemeinschaften in der Datenbank.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _cells.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.surfaceVariant,
                      ),
                      itemBuilder: (ctx, i) {
                        final cell = _cells[i];
                        final orphaned = _isOrphaned(cell);
                        final isOwn = cell.createdBy == myDid;
                        final founderLabel = isOwn
                            ? 'Ich (eigene Gemeinschaft)'
                            : cell.createdBy.length > 28
                                ? '${cell.createdBy.substring(0, 20)}…'
                                : cell.createdBy;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: orphaned
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : AppColors.gold.withValues(alpha: 0.12),
                            child: Icon(
                              orphaned
                                  ? Icons.warning_amber_rounded
                                  : Icons.hexagon_outlined,
                              color:
                                  orphaned ? Colors.redAccent : AppColors.gold,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cell.name,
                                  style: TextStyle(
                                    color: orphaned
                                        ? Colors.redAccent
                                        : AppColors.onDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (orphaned)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'VERWAIST',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.redAccent,
                                        letterSpacing: 0.5),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID: ${cell.id.substring(0, 12)}…',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                              Text(
                                'Gegründet von: $founderLabel',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: orphaned
                                        ? Colors.orange
                                        : Colors.grey),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            tooltip: 'Gemeinschaft löschen',
                            onPressed: () => _deleteCell(context, cell),
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  // ── Permit section widgets ────────────────────────────────────────────────

  Widget _buildPendingPermitsSection(
      BuildContext context, List<CellFoundingPermit> pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surfaceVariant,
          child: Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 16, color: AppColors.gold),
              const SizedBox(width: 8),
              const Text(
                'Gründungsanträge',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (pending.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pending.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),

        if (pending.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Keine offenen Anträge.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          ...pending.map((p) => _buildPermitRequestTile(context, p)),

        const Divider(height: 1, color: AppColors.surfaceVariant),
      ],
    );
  }

  Widget _buildPermitRequestTile(
      BuildContext context, CellFoundingPermit permit) {
    final hasReason =
        permit.requestMessage != null && permit.requestMessage!.isNotEmpty;
    final locationInfo = permit.cellType == CellType.local
        ? permit.regionHint ?? '–'
        : permit.proposedCategory ?? '–';
    final locationLabel =
        permit.cellType == CellType.local ? 'Region' : 'Kategorie';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Requester info + type badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        permit.requesterPseudonym,
                        style: const TextStyle(
                          color: AppColors.onDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _shortDid(permit.requesterDid),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: permit.cellType == CellType.local
                        ? Colors.blue.withValues(alpha: 0.15)
                        : Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _cellTypeLabel(permit.cellType),
                    style: TextStyle(
                      fontSize: 11,
                      color: permit.cellType == CellType.local
                          ? Colors.blue
                          : Colors.purple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Proposed name
            Text(
              permit.proposedName ?? '–',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),

            // Region / category
            Text(
              '$locationLabel: $locationInfo',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

            // Date
            Text(
              'Eingereicht: ${_formatDate(permit.requestedAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),

            // Reason — collapsible
            if (hasReason) ...[
              const SizedBox(height: 4),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Begründung',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        permit.requestMessage!,
                        style: const TextStyle(
                            color: AppColors.onDark, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _rejectPermit(context, permit),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Ablehnen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _approvePermit(context, permit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Genehmigen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePermitsSection(
      BuildContext context, List<CellFoundingPermit> active) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsible section via ExpansionTile
        Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            backgroundColor: AppColors.surface,
            collapsedBackgroundColor: AppColors.surfaceVariant,
            leading: const Icon(Icons.verified_outlined,
                size: 18, color: AppColors.gold),
            title: Row(
              children: [
                const Text(
                  'Aktive Freigaben',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                if (active.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${active.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            children: active.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Text(
                        'Keine aktiven Freigaben.',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ]
                : active
                    .map((p) => _buildActivePermitTile(context, p))
                    .toList(),
          ),
        ),
        const Divider(height: 1, color: AppColors.surfaceVariant),
      ],
    );
  }

  Widget _buildActivePermitTile(
      BuildContext context, CellFoundingPermit permit) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Colors.green.withValues(alpha: 0.12),
        child: const Icon(Icons.check_circle_outline,
            color: Colors.green, size: 20),
      ),
      title: Text(
        permit.requesterPseudonym,
        style: const TextStyle(
            color: AppColors.onDark,
            fontWeight: FontWeight.w500,
            fontSize: 13),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_cellTypeLabel(permit.cellType)} · ${permit.proposedName ?? '–'}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (permit.expiresAt != null)
            Text(
              'Gültig bis: ${_formatDate(permit.expiresAt!)}',
              style: const TextStyle(
                  color: Colors.green, fontSize: 11),
            ),
        ],
      ),
      trailing: TextButton(
        onPressed: () => _revokePermit(context, permit),
        style: TextButton.styleFrom(foregroundColor: Colors.orange),
        child: const Text('Widerrufen'),
      ),
      isThreeLine: true,
    );
  }
}
