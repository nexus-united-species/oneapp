import 'package:flutter/material.dart';

import '../../core/contacts/contact_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/help_icon.dart';
import 'cell_member.dart';
import 'cell_service.dart';

/// Phase G2.1.4: Bottom sheet for selecting a confirmed cell member to
/// delegate one's vote to. Returns the selected member's DID via
/// [Navigator.pop], or null if dismissed without a selection.
class DelegateSelectSheet extends StatelessWidget {
  final String cellId;
  final String myDid;

  const DelegateSelectSheet({
    super.key,
    required this.cellId,
    required this.myDid,
  });

  /// Opens the sheet modally and returns the chosen member's DID, or null.
  static Future<String?> show(
    BuildContext context, {
    required String cellId,
    required String myDid,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DelegateSelectSheet(cellId: cellId, myDid: myDid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = CellService.instance.membersOf(cellId);
    final candidates = members
        .where((m) => m.did != myDid && m.isConfirmed)
        .toList();

    // Alphabetisch nach Anzeigename sortieren — deterministisch.
    candidates.sort((a, b) {
      final na =
          ContactService.instance.getDisplayName(a.did).toLowerCase();
      final nb =
          ContactService.instance.getDisplayName(b.did).toLowerCase();
      return na.compareTo(nb);
    });

    final height = MediaQuery.sizeOf(context).height * 0.6;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Stimme delegieren an…',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const HelpIcon(
                    contextId: 'proposal_voting_delegation', size: 18),
              ],
            ),
          ),
          const Divider(
              color: AppColors.surfaceVariant, height: 1),
          // List or empty state
          Expanded(
            child: candidates.isEmpty
                ? _DelegateEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: candidates.length,
                    itemBuilder: (ctx, i) => _CandidateTile(
                      member: candidates[i],
                      onTap: () =>
                          _confirmAndSelect(ctx, candidates[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSelect(
      BuildContext context, CellMember member) async {
    final name =
        ContactService.instance.getDisplayName(member.did);
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Stimme delegieren?',
          style: TextStyle(color: AppColors.onDark),
        ),
        content: Text(
          'Stimme an $name delegieren?',
          style: TextStyle(
              color: AppColors.onDark.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Abbrechen',
              style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delegieren',
              style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    Navigator.pop(context, member.did);
  }
}

// ── Candidate tile ─────────────────────────────────────────────────────────────

class _CandidateTile extends StatelessWidget {
  final CellMember member;
  final VoidCallback onTap;

  const _CandidateTile({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name =
        ContactService.instance.getDisplayName(member.did);
    // Short DID: last 8 characters for a compact subtitle.
    final shortDid = member.did.length > 8
        ? '…${member.did.substring(member.did.length - 8)}'
        : member.did;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.surfaceVariant,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: AppColors.onDark,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
            color: AppColors.onDark, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        shortDid,
        style: TextStyle(
            color: AppColors.onDark.withValues(alpha: 0.45),
            fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.surfaceVariant),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _DelegateEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off_outlined,
                size: 48,
                color: AppColors.onDark.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'Keine Cell-Mitglieder verfügbar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.onDark,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Du brauchst mindestens ein weiteres Cell-Mitglied, '
              'um delegieren zu können.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.55),
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
