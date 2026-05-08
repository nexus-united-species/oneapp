import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/contacts/contact_service.dart';
import '../../core/identity/identity_service.dart';
import '../../core/storage/pod_database.dart';
import '../../services/role_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/help_icon.dart';
import 'audit_log_entry.dart';
import 'cell_service.dart';
import 'decision_record.dart';
import 'delegate_select_sheet.dart';
import 'delegation.dart';
import 'edit_history_screen.dart';
import 'proposal.dart';
import 'proposal_edit_screen.dart';
import 'proposal_option.dart';
import 'proposal_service.dart';
import 'vote.dart';
import 'voting_mode.dart';

/// Full detail view of a proposal — Tabs: Details / Historie.
class ProposalDetailScreen extends StatefulWidget {
  final Proposal proposal;
  const ProposalDetailScreen({super.key, required this.proposal});

  @override
  State<ProposalDetailScreen> createState() => _ProposalDetailScreenState();
}

class _ProposalDetailScreenState extends State<ProposalDetailScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;
  StreamSubscription<void>? _sub;
  late Proposal _proposal;

  // Voting state
  VoteChoice? _selectedChoice;
  String? _selectedOptionId; // Phase 4.7c3: for SC/CC option selection
  List<ProposalOption> _options = []; // Phase 4.7c3: loaded for SC/CC
  final _reasoningCtrl = TextEditingController();
  Vote? _myExistingVote;
  bool _isVoting = false;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _proposal = widget.proposal;
    _sub = ProposalService.instance.stream.listen((_) {
      if (mounted) setState(() => _refreshProposal());
    });
    _refreshProposal();
    _loadOptions();
    print('[G2-UI] Opening detail screen for: ${_proposal.id}');
  }

  /// Phase 4.7c3: Load proposal options for SC/CC proposals.
  Future<void> _loadOptions() async {
    if (_proposal.votingMode == VotingMode.YES_NO_ABSTAIN) return;
    final rows =
        await PodDatabase.instance.listProposalOptions(_proposal.id);
    if (!mounted) return;
    setState(() {
      _options = rows.map(ProposalOption.fromMap).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    });
  }

  void _refreshProposal() {
    _proposal = ProposalService.instance.allProposals
        .firstWhere((p) => p.id == _proposal.id, orElse: () => _proposal);
    _myExistingVote = _getMyVote();
    // Pre-fill voting state from existing vote
    if (_selectedChoice == null && _myExistingVote != null) {
      _selectedChoice = _myExistingVote!.choice;
      _selectedOptionId = _myExistingVote!.selectedOptionId;
      _reasoningCtrl.text = _myExistingVote!.reasoning ?? '';
    }
  }

  Vote? _getMyVote() {
    final myDid = IdentityService.instance.currentIdentity?.did;
    if (myDid == null) return null;
    return ProposalService.instance
        .getVotes(_proposal.id)
        .where((v) => v.voterDid == myDid)
        .firstOrNull;
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    _reasoningCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  // ── Permissions ──────────────────────────────────────────────────────────────

  String get _myDid => IdentityService.instance.currentIdentity?.did ?? '';

  bool get _isCreator => _proposal.creatorDid == _myDid;

  bool get _canManage {
    final m = CellService.instance.myMembershipIn(_proposal.cellId);
    return m?.canManageRequests ?? false;
  }

  bool get _isSuperadmin =>
      RoleService.instance.isSuperadmin(_myDid);

  bool get _canEditProposal =>
      _isCreator &&
      (_proposal.status == ProposalStatus.DRAFT ||
          _proposal.status == ProposalStatus.DISCUSSION);

  bool get _canStartVoting =>
      _proposal.status == ProposalStatus.DISCUSSION &&
      (_isCreator || _canManage);

  // ── Action handlers ───────────────────────────────────────────────────────

  Future<void> _runAction(String name, Future<void> Function() fn) async {
    print('[G2-UI] Action triggered: $name');
    setState(() => _isActionLoading = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _confirmAndRun(
      String title, String body, String confirmLabel, Future<void> Function() fn,
      {Color confirmColor = AppColors.gold}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title,
            style: const TextStyle(color: AppColors.onDark)),
        content: Text(body,
            style: TextStyle(
                color: AppColors.onDark.withValues(alpha: 0.8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abbrechen',
                style: TextStyle(
                    color: AppColors.onDark.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: confirmColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _runAction(title, fn);
  }

  void _openEdit() {
    print('[G2-UI] Edit screen opened: ${_proposal.id}');
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
          builder: (_) => ProposalEditScreen(proposal: _proposal)),
    );
  }

  Future<void> _publishToDiscussion() => _confirmAndRun(
        'Zur Diskussion stellen',
        'Der Antrag wird für alle Gemeinschaftsmitglieder sichtbar.',
        'Veröffentlichen',
        () async {
          await ProposalService.instance.publishToDiscussion(_proposal.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Antrag ist jetzt in der Diskussion.'),
                  backgroundColor: Colors.green),
            );
          }
        },
      );

  Future<void> _deleteDraft() => _confirmAndRun(
        'Entwurf verwerfen',
        'Der Entwurf wird dauerhaft gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.',
        'Verwerfen',
        () async {
          await ProposalService.instance.deleteDraft(_proposal.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Entwurf gelöscht.')),
            );
            Navigator.of(context).pop();
          }
        },
        confirmColor: Colors.red,
      );

  Future<void> _withdraw() => _confirmAndRun(
        'Antrag zurückziehen',
        'Dein Antrag wird zurückgezogen. Er bleibt sichtbar, '
            'aber als "Zurückgezogen" markiert.',
        'Zurückziehen',
        () async {
          await ProposalService.instance.withdrawProposal(_proposal.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Antrag zurückgezogen.')),
            );
          }
        },
        confirmColor: Colors.orange,
      );

  Future<void> _startVoting() => _confirmAndRun(
        'Abstimmung starten',
        'Nach dem Start kann der Antragstext nicht mehr geändert werden. '
            'Bist du sicher?',
        'Abstimmung starten',
        () async {
          await ProposalService.instance.startVoting(_proposal.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Abstimmung gestartet!'),
                  backgroundColor: Colors.orange),
            );
          }
        },
        confirmColor: Colors.orange,
      );

  Future<void> _archive() => _confirmAndRun(
        'Antrag archivieren',
        'Der Antrag wird ins Archiv verschoben.',
        'Archivieren',
        () async {
          await ProposalService.instance.archiveProposal(_proposal.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Antrag archiviert.')),
            );
          }
        },
      );

  Future<void> _forceFinalize() async {
    print('[G2-UI] Detail-screen force button clicked');
    await _runAction('Force beenden', () async {
      final p = _proposal;
      p.votingEndsAt = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
      p.gracePeriodHours = 0;
      await PodDatabase.instance.upsertProposal(p.id, p.cellId, p.toMap());
      await ProposalService.instance.processGracePeriodStart(p.id);
      await ProposalService.instance.finalizeProposal(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Voting force-beendet'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> _castVote() async {
    if (_selectedChoice == null) return;
    setState(() => _isVoting = true);
    print('[G2-UI] Cast vote: $_selectedChoice for ${_proposal.id} '
        'optionId=${_selectedOptionId ?? "-"}');
    try {
      await ProposalService.instance.castVote(
        _proposal.id,
        _selectedChoice!,
        reasoning: _reasoningCtrl.text.trim().isEmpty
            ? null
            : _reasoningCtrl.text.trim(),
        selectedOptionId: _selectedOptionId,
      );
      if (mounted) {
        final isChange = _myExistingVote != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isChange ? 'Stimme aktualisiert.' : 'Stimme abgegeben.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedChoice = null;
          _selectedOptionId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrag'),
        backgroundColor: AppColors.deepBlue,
        actions: [
          if (_isActionLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.gold)),
            ),
          if (_canEditProposal)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.gold),
              onPressed: _openEdit,
              tooltip: 'Bearbeiten',
            ),
          _AppBarMenu(
            proposal: _proposal,
            isCreator: _isCreator,
            canManage: _canManage,
            canStartVoting: _canStartVoting,
            onPublishToDiscussion: _publishToDiscussion,
            onDeleteDraft: _deleteDraft,
            onWithdraw: _withdraw,
            onStartVoting: _startVoting,
            onArchive: _archive,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.onDark,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Diskussion'),
            Tab(text: 'Historie'),
          ],
        ),
      ),
      backgroundColor: AppColors.deepBlue,
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _DetailsTab(
            proposal: _proposal,
            myExistingVote: _myExistingVote,
            selectedChoice: _selectedChoice,
            selectedOptionId: _selectedOptionId,
            options: _options,
            reasoningCtrl: _reasoningCtrl,
            isVoting: _isVoting,
            isSuperadmin: _isSuperadmin,
            onSelectChoice: (c) {
              print('[G2-UI] Vote button clicked: $c');
              if (_myExistingVote != null) {
                print('[G2-UI] Vote update from ${_myExistingVote!.choice} to $c');
              }
              setState(() {
                _selectedChoice = c;
                _selectedOptionId = null; // clear option when choosing YNA
              });
            },
            onSelectOption: (optionId) {
              setState(() {
                _selectedChoice = VoteChoice.ABSTAIN;
                _selectedOptionId = optionId;
              });
            },
            onSelectAbstention: () {
              setState(() {
                _selectedChoice = VoteChoice.ABSTAIN;
                _selectedOptionId = null;
              });
            },
            onCastVote: _castVote,
            onForceFinalize: _forceFinalize,
          ),
          _DiskussionTab(proposal: _proposal),
          _HistorieTab(proposalId: _proposal.id),
        ],
      ),
    );
  }
}

// ── AppBar popup menu ─────────────────────────────────────────────────────────

class _AppBarMenu extends StatelessWidget {
  final Proposal proposal;
  final bool isCreator;
  final bool canManage;
  final bool canStartVoting;
  final VoidCallback onPublishToDiscussion;
  final VoidCallback onDeleteDraft;
  final VoidCallback onWithdraw;
  final VoidCallback onStartVoting;
  final VoidCallback onArchive;

  const _AppBarMenu({
    required this.proposal,
    required this.isCreator,
    required this.canManage,
    required this.canStartVoting,
    required this.onPublishToDiscussion,
    required this.onDeleteDraft,
    required this.onWithdraw,
    required this.onStartVoting,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final items = <PopupMenuItem<_MenuAction>>[];

    switch (proposal.status) {
      case ProposalStatus.DRAFT:
        if (isCreator) {
          items.add(PopupMenuItem(
            value: _MenuAction.publish,
            child: const Text('Zur Diskussion stellen'),
          ));
          items.add(PopupMenuItem(
            value: _MenuAction.delete,
            child: const Text('Verwerfen',
                style: TextStyle(color: Colors.red)),
          ));
        }
        break;

      case ProposalStatus.DISCUSSION:
        if (isCreator || canManage) {
          items.add(PopupMenuItem(
            value: _MenuAction.startVoting,
            child: const Text('Abstimmung starten'),
          ));
        }
        if (isCreator) {
          items.add(PopupMenuItem(
            value: _MenuAction.withdraw,
            child: const Text('Zurückziehen',
                style: TextStyle(color: Colors.orange)),
          ));
        }
        break;

      case ProposalStatus.DECIDED:
        if (canManage) {
          items.add(PopupMenuItem(
            value: _MenuAction.archive,
            child: const Text('Archivieren'),
          ));
        }
        break;

      default:
        break;
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<_MenuAction>(
      icon: const Icon(Icons.more_vert, color: AppColors.onDark),
      color: AppColors.surface,
      onSelected: (action) {
        switch (action) {
          case _MenuAction.publish:
            onPublishToDiscussion();
            break;
          case _MenuAction.delete:
            onDeleteDraft();
            break;
          case _MenuAction.withdraw:
            onWithdraw();
            break;
          case _MenuAction.startVoting:
            onStartVoting();
            break;
          case _MenuAction.archive:
            onArchive();
            break;
        }
      },
      itemBuilder: (_) => items,
    );
  }
}

enum _MenuAction { publish, delete, withdraw, startVoting, archive }

// ── Details Tab ───────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final Proposal proposal;
  final Vote? myExistingVote;
  final VoteChoice? selectedChoice;
  final String? selectedOptionId;
  final List<ProposalOption> options;
  final TextEditingController reasoningCtrl;
  final bool isVoting;
  final bool isSuperadmin;
  final ValueChanged<VoteChoice> onSelectChoice;
  final ValueChanged<String> onSelectOption;
  final VoidCallback onSelectAbstention;
  final VoidCallback onCastVote;
  final VoidCallback onForceFinalize;

  const _DetailsTab({
    required this.proposal,
    required this.myExistingVote,
    required this.selectedChoice,
    required this.selectedOptionId,
    required this.options,
    required this.reasoningCtrl,
    required this.isVoting,
    required this.isSuperadmin,
    required this.onSelectChoice,
    required this.onSelectOption,
    required this.onSelectAbstention,
    required this.onCastVote,
    required this.onForceFinalize,
  });

  @override
  Widget build(BuildContext context) {
    final p = proposal;
    final votes = ProposalService.instance.getVotes(p.id);
    final members = CellService.instance.membersOf(p.cellId);
    final confirmedMembers = members.where((m) => m.isConfirmed).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header: badges + meta ─────────────────────────────────────────
        _HeaderSection(proposal: p),
        const SizedBox(height: 16),

        // ── Content: title + description ─────────────────────────────────
        _ContentSection(proposal: p),
        const SizedBox(height: 16),

        // ── Timeline ─────────────────────────────────────────────────────
        _Timeline(proposal: p),
        const SizedBox(height: 16),

        // ── Voting section (status-dependent) ────────────────────────────
        if (p.status == ProposalStatus.VOTING)
          _VotingCard(
            proposal: p,
            myExistingVote: myExistingVote,
            selectedChoice: selectedChoice,
            selectedOptionId: selectedOptionId,
            options: options,
            reasoningCtrl: reasoningCtrl,
            isVoting: isVoting,
            onSelectChoice: onSelectChoice,
            onSelectOption: onSelectOption,
            onSelectAbstention: onSelectAbstention,
            onCastVote: onCastVote,
            votes: votes,
            confirmedMemberCount: confirmedMembers,
          )
        else if (p.status == ProposalStatus.VOTING_ENDED)
          _GracePeriodBanner()
        else if (p.status == ProposalStatus.DECIDED ||
            p.status == ProposalStatus.ARCHIVED)
          _ResultSection(proposal: p, votes: votes, options: options),

        // ── Delegations-Block (VOTING + YNA/SC, kein CC) ─────────────────
        if (p.status == ProposalStatus.VOTING &&
            p.votingMode != VotingMode.CANDIDATE_CHOICE) ...[
          const SizedBox(height: 12),
          _DelegationBlock(
            proposal: p,
            myExistingVote: myExistingVote,
          ),
        ],

        // ── Eingehende Delegationen (G2.1.4b: Delegate-Sicht) ────────────
        if (p.status == ProposalStatus.VOTING &&
            p.votingMode != VotingMode.CANDIDATE_CHOICE) ...[
          const SizedBox(height: 8),
          _IncomingDelegationsBlock(proposal: p),
        ],

        // ── Superadmin Force-Button (nur Voting + Superadmin) ─────────────
        if (p.status == ProposalStatus.VOTING && isSuperadmin) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: onForceFinalize,
                  icon: const Text('🧪', style: TextStyle(fontSize: 14)),
                  label: const Text('Force beenden (Debug)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nur für Tests — wird in Produktion entfernt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.orange.withValues(alpha: 0.6),
                      fontSize: 11),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }
}

// ── Header section ────────────────────────────────────────────────────────────

class _HeaderSection extends StatelessWidget {
  final Proposal proposal;
  const _HeaderSection({required this.proposal});

  @override
  Widget build(BuildContext context) {
    final p = proposal;
    final (statusLabel, statusColor) = _statusInfo(p.status, p.resultSummary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Status badge (large)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Category chip
            if (p.category != null && p.category!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _categoryLabel(p.category!),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                  ),
                ),
              ),
            const Spacer(),
            // Version badge
            if (p.version > 1)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'v${p.version}',
                  style: TextStyle(
                    color: AppColors.onDark.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // Creator + date
        Text(
          '${p.creatorPseudonym} · ${_fmtDate(p.createdAt)}',
          style: TextStyle(
            color: AppColors.onDark.withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _categoryLabel(String key) {
    return switch (key) {
      'umwelt' => '🌱 Umwelt',
      'finanzen' => '💰 Finanzen',
      'it' => '💻 IT',
      'soziales' => '🤝 Soziales',
      'gesundheit' => '❤️ Gesundheit',
      'bildung' => '📚 Bildung',
      _ => '📋 Sonstiges',
    };
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

(String, Color) _statusInfo(ProposalStatus status, String? resultSummary) {
  return switch (status) {
    ProposalStatus.DRAFT => ('Entwurf', AppColors.onDark),
    ProposalStatus.DISCUSSION => ('Diskussion', Colors.blue),
    ProposalStatus.VOTING => ('Abstimmung läuft', Colors.orange),
    ProposalStatus.VOTING_ENDED => ('Grace Period', Colors.deepOrange),
    ProposalStatus.DECIDED => _decidedInfo(resultSummary),
    ProposalStatus.ARCHIVED => ('Archiviert', AppColors.surfaceVariant),
    ProposalStatus.WITHDRAWN => ('Zurückgezogen', AppColors.surfaceVariant),
  };
}

(String, Color) _decidedInfo(String? resultSummary) {
  return switch (resultSummary) {
    'approved' => ('Angenommen', Colors.green),
    'rejected' => ('Abgelehnt', Colors.red),
    _ => ('Ungültig', AppColors.surfaceVariant),
  };
}

// ── Content section ───────────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  final Proposal proposal;
  const _ContentSection({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          proposal.title,
          style: const TextStyle(
            color: AppColors.onDark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        // Description
        if (proposal.description.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              proposal.description,
              style: TextStyle(
                color: AppColors.onDark.withValues(alpha: 0.85),
                height: 1.6,
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Edit history link (if version > 1)
        if (proposal.version > 1)
          TextButton.icon(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      EditHistoryScreen(proposalId: proposal.id),
                ),
              );
            },
            icon: const Text('📝'),
            label: Text(
              'Edit-Historie anzeigen (${proposal.version - 1} '
              '${proposal.version - 1 == 1 ? 'Änderung' : 'Änderungen'})',
              style: const TextStyle(color: AppColors.gold, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  final Proposal proposal;
  const _Timeline({required this.proposal});

  @override
  Widget build(BuildContext context) {
    final p = proposal;
    final now = DateTime.now().toUtc();
    final events = <_TimelineEvent>[];

    // Always: created
    events.add(_TimelineEvent(label: 'Erstellt', date: p.createdAt, done: true));

    switch (p.status) {
      case ProposalStatus.DRAFT:
        // Nothing further
        break;

      case ProposalStatus.DISCUSSION:
        final canStart = p.discussionStartedAt != null;
        events.add(_TimelineEvent(
          label: 'Diskussion läuft',
          date: p.discussionStartedAt ?? p.createdAt,
          done: false,
          hint: canStart
              ? 'Abstimmung kann jetzt gestartet werden'
              : null,
        ));
        break;

      case ProposalStatus.VOTING:
        if (p.votingStartedAt != null) {
          events.add(_TimelineEvent(
              label: 'Abstimmung gestartet',
              date: p.votingStartedAt!,
              done: true));
        }
        if (p.votingEndsAt != null) {
          final diff = p.votingEndsAt!.difference(now);
          final label = diff.isNegative
              ? 'Abstimmung läuft noch'
              : 'Abstimmung endet in ${diff.inDays}d ${diff.inHours % 24}h';
          events.add(_TimelineEvent(
              label: label, date: p.votingEndsAt!, done: false));
        }
        break;

      case ProposalStatus.VOTING_ENDED:
        if (p.votingEndsAt != null) {
          events.add(_TimelineEvent(
              label: 'Abstimmung beendet',
              date: p.votingEndsAt!,
              done: true));
        }
        events.add(_TimelineEvent(
          label: 'Grace Period läuft',
          date: p.votingEndsAt ?? p.createdAt,
          done: false,
        ));
        break;

      case ProposalStatus.DECIDED:
        if (p.votingEndsAt != null) {
          events.add(_TimelineEvent(
              label: 'Abstimmung beendet',
              date: p.votingEndsAt!,
              done: true));
        }
        if (p.decidedAt != null) {
          events.add(_TimelineEvent(
              label: 'Entschieden', date: p.decidedAt!, done: true));
        }
        break;

      case ProposalStatus.ARCHIVED:
        if (p.decidedAt != null) {
          events.add(_TimelineEvent(
              label: 'Entschieden', date: p.decidedAt!, done: true));
        }
        if (p.archivedAt != null) {
          events.add(_TimelineEvent(
              label: 'Archiviert', date: p.archivedAt!, done: true));
        }
        break;

      case ProposalStatus.WITHDRAWN:
        if (p.withdrawnAt != null) {
          events.add(_TimelineEvent(
              label: 'Zurückgezogen', date: p.withdrawnAt!, done: true));
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zeitplan',
            style: TextStyle(
              color: AppColors.onDark.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          ...events.map((e) => _TimelineRow(event: e)),
        ],
      ),
    );
  }
}

class _TimelineEvent {
  final String label;
  final DateTime date;
  final bool done;
  final String? hint;
  const _TimelineEvent(
      {required this.label,
      required this.date,
      required this.done,
      this.hint});
}

class _TimelineRow extends StatelessWidget {
  final _TimelineEvent event;
  const _TimelineRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                event.done
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 16,
                color: event.done
                    ? Colors.green
                    : AppColors.surfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  event.label,
                  style: TextStyle(
                    color: event.done
                        ? AppColors.onDark
                        : AppColors.onDark.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                _fmtDate(event.date),
                style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (event.hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 3),
              child: Text(
                event.hint!,
                style: TextStyle(
                  color: Colors.blue.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ── Voting card (VOTING status) ───────────────────────────────────────────────

class _VotingCard extends StatelessWidget {
  final Proposal proposal;
  final Vote? myExistingVote;
  final VoteChoice? selectedChoice;
  final String? selectedOptionId;
  final List<ProposalOption> options;
  final TextEditingController reasoningCtrl;
  final bool isVoting;
  final ValueChanged<VoteChoice> onSelectChoice;
  final ValueChanged<String> onSelectOption;
  final VoidCallback onSelectAbstention;
  final VoidCallback onCastVote;
  final List<Vote> votes;
  final int confirmedMemberCount;

  const _VotingCard({
    required this.proposal,
    required this.myExistingVote,
    required this.selectedChoice,
    required this.selectedOptionId,
    required this.options,
    required this.reasoningCtrl,
    required this.isVoting,
    required this.onSelectChoice,
    required this.onSelectOption,
    required this.onSelectAbstention,
    required this.onCastVote,
    required this.votes,
    required this.confirmedMemberCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasVoted = myExistingVote != null;
    final total = confirmedMemberCount > 0 ? confirmedMemberCount : 1;
    final participation = votes.length / total;
    final quorumPct = (proposal.quorumRequired * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Text('🗳️',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text(
                'Deine Stimme',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 4),
              const HelpIcon(
                  contextId: 'proposal_voting_transparency', size: 15),
            ],
          ),
          const SizedBox(height: 12),

          // Already voted notice
          if (hasVoted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Du hast bereits abgestimmt — du kannst deine Wahl noch ändern.',
                      style: TextStyle(
                          color: Colors.green.shade300, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Vote buttons — mode-aware (Phase 4.7c3)
          if (proposal.votingMode == VotingMode.YES_NO_ABSTAIN)
            LayoutBuilder(
              builder: (context, constraints) {
                final buttons = [
                  _VoteButton(
                      label: 'Ja',
                      choice: VoteChoice.YES,
                      color: Colors.green,
                      selected: selectedChoice == VoteChoice.YES,
                      onTap: () => onSelectChoice(VoteChoice.YES)),
                  _VoteButton(
                      label: 'Enthaltung',
                      choice: VoteChoice.ABSTAIN,
                      color: Colors.blueGrey.shade300,
                      selected: selectedChoice == VoteChoice.ABSTAIN &&
                          selectedOptionId == null,
                      onTap: () => onSelectChoice(VoteChoice.ABSTAIN)),
                  _VoteButton(
                      label: 'Nein',
                      choice: VoteChoice.NO,
                      color: Colors.red,
                      selected: selectedChoice == VoteChoice.NO,
                      onTap: () => onSelectChoice(VoteChoice.NO)),
                ];
                if (constraints.maxWidth >= 400) {
                  return Row(
                    children: [
                      Expanded(child: buttons[0]),
                      const SizedBox(width: 8),
                      Expanded(child: buttons[1]),
                      const SizedBox(width: 8),
                      Expanded(child: buttons[2]),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buttons[0],
                      const SizedBox(height: 8),
                      buttons[1],
                      const SizedBox(height: 8),
                      buttons[2],
                    ],
                  );
                }
              },
            )
          else
            // SINGLE_CHOICE and CANDIDATE_CHOICE: option list + Enthaltung
            _buildOptionsButtons(options, selectedChoice, selectedOptionId,
                onSelectOption, onSelectAbstention),
          const SizedBox(height: 14),

          // Reasoning
          Row(
            children: [
              Text(
                'Begründung (optional)',
                style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              const HelpIcon(contextId: 'proposal_reasoning', size: 14),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: reasoningCtrl,
            decoration: InputDecoration(
              hintText: 'Warum stimmst du so?',
              hintStyle: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.35),
                  fontSize: 13),
              filled: true,
              fillColor: AppColors.deepBlue,
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.surfaceVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.surfaceVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
            ),
            style: const TextStyle(color: AppColors.onDark, fontSize: 13),
            maxLines: 3,
            maxLength: 500,
            buildCounter: (context,
                    {required currentLength,
                    required isFocused,
                    maxLength}) =>
                Text(
              '$currentLength / ${maxLength ?? 500}',
              style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.4),
                  fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),

          // Submit button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed:
                  (selectedChoice == null || isVoting) ? null : onCastVote,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                disabledBackgroundColor:
                    AppColors.gold.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              child: isVoting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text(
                      hasVoted ? 'Stimme aktualisieren' : 'Stimme abgeben',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar
          Row(
            children: [
              const HelpIcon(contextId: 'proposal_quorum', size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${votes.length} von $total Mitgliedern haben abgestimmt'
                      ' (Quorum: $quorumPct%)',
                      style: TextStyle(
                        color: AppColors.onDark.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: participation.clamp(0.0, 1.0),
                      backgroundColor:
                          AppColors.surfaceVariant.withValues(alpha: 0.3),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.gold),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Phase 4.7c3: Builds the voting UI for SINGLE_CHOICE and CANDIDATE_CHOICE.
  Widget _buildOptionsButtons(
    List<ProposalOption> opts,
    VoteChoice? selectedChoice,
    String? selectedOptionId,
    ValueChanged<String> onSelectOption,
    VoidCallback onSelectAbstention,
  ) {
    final activeOpts =
        opts.where((o) => o.status == OptionStatus.ACTIVE).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final opt in activeOpts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionVoteButton(
              label: opt.label,
              selected: selectedOptionId == opt.optionId,
              onTap: () => onSelectOption(opt.optionId),
            ),
          ),
        const SizedBox(height: 8),
        _VoteButton(
          label: 'Enthaltung',
          choice: VoteChoice.ABSTAIN,
          color: Colors.blueGrey.shade300,
          selected: selectedChoice == VoteChoice.ABSTAIN &&
              selectedOptionId == null,
          onTap: onSelectAbstention,
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final VoteChoice choice;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _VoteButton({
    required this.label,
    required this.choice,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : color.withValues(alpha: 0.7),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Option vote button (Phase 4.7c3) ─────────────────────────────────────────

class _OptionVoteButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionVoteButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.surfaceVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.deepBlue : AppColors.onDark,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.deepBlue : AppColors.onDark,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grace period banner ───────────────────────────────────────────────────────

class _GracePeriodBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.deepOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('⏳', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Abstimmung beendet — letzte verspätete Stimmen werden noch akzeptiert.',
              style: TextStyle(color: Colors.deepOrange.shade200),
            ),
          ),
          const HelpIcon(contextId: 'proposal_grace_period', size: 16),
        ],
      ),
    );
  }
}

// ── Result section (DECIDED / ARCHIVED) ──────────────────────────────────────
//
// G2.1.4b: Reads from DecisionRecord.allVotes when available so that synthetic
// votes (liquid-democracy delegations) are visible in the result list.
// Falls back to ProposalService.getVotes() when allVotes is empty — this is
// the case on recipient devices because handleIncomingDecisionRecord sets
// allVotes: const [] (Phase 4.5c scope-cut).
//
// Tally-Owner  → allVotes has direct + synthetic votes   → full list shown
// Recipient    → allVotes empty → fallback to getVotes() → direct votes only
//   (phase-consistent; synthetic visibility on recipients deferred to a later
//    phase that would transmit allVotes over the wire)

/// Builds the participation line from a [DecisionRecord].
///
/// Source of Truth: yesVotes + noVotes + abstainVotes aus dem DecisionRecord.
/// Denominator wird aus [DecisionRecord.participation] rückgerechnet, da
/// eligibleVotersCount kein Modell-Feld ist und nicht im Wire transportiert wird.
@visibleForTesting
String buildParticipationText(DecisionRecord dr) {
  final num = dr.yesVotes + dr.noVotes + dr.abstainVotes;
  if (num == 0) return 'Keine Stimmen abgegeben';

  final participation = dr.participation;
  final pct = (participation * 100).round();

  if (participation <= 0) return 'Beteiligung: $pct%';

  final den = (num / participation).round();
  if (den == 0) return 'Beteiligung: $pct%';

  final stimmenLabel = num == 1 ? 'Stimme' : 'Stimmen';
  if (den == 1) {
    return 'Beteiligung: $pct% ($num $stimmenLabel von 1 stimmberechtigten Person)';
  }
  return 'Beteiligung: $pct% ($num $stimmenLabel von $den Stimmberechtigten)';
}

class _ResultSection extends StatefulWidget {
  final Proposal proposal;
  final List<Vote> votes;
  final List<ProposalOption> options;

  const _ResultSection({
    required this.proposal,
    required this.votes,
    this.options = const [],
  });

  @override
  State<_ResultSection> createState() => _ResultSectionState();
}

class _ResultSectionState extends State<_ResultSection> {
  // null  = still loading
  // non-null = loaded; may be empty if record not found or allVotes empty
  List<Vote>? _decisionVotes;
  DecisionRecord? _decisionRecord;

  @override
  void initState() {
    super.initState();
    _loadDecisionVotes();
  }

  Future<void> _loadDecisionVotes() async {
    final row =
        await PodDatabase.instance.getDecisionRecord(widget.proposal.id);
    if (!mounted) return;
    if (row != null) {
      final record = DecisionRecord.fromMap(row);
      // Sort deterministically by createdAt ASC (matches tally order).
      final sorted = List<Vote>.from(record.allVotes)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      setState(() {
        _decisionVotes = sorted;
        _decisionRecord = record;
      });
    } else {
      setState(() => _decisionVotes = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    final result = p.resultSummary ?? 'invalid';

    final (bannerText, bannerColor, _) = switch (result) {
      'approved' => ('✅ ANGENOMMEN', Colors.green, Icons.check_circle),
      'rejected' => ('❌ ABGELEHNT', Colors.red, Icons.cancel),
      _ => ('⚠️ UNGÜLTIG — Quorum nicht erreicht',
          AppColors.surfaceVariant,
          Icons.warning_amber_outlined),
    };

    final yes = p.resultYes ?? 0;
    final no = p.resultNo ?? 0;
    final abstain = p.resultAbstain ?? 0;

    // Variante A: use allVotes from DecisionRecord when non-empty,
    // otherwise fall back to direct votes from ProposalService cache.
    final displayVotes = (_decisionVotes != null && _decisionVotes!.isNotEmpty)
        ? _decisionVotes!
        : () {
            final fallback = List<Vote>.from(widget.votes)
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return fallback;
          }();

    return Column(
      children: [
        // Result banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: bannerColor.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              bannerText,
              style: TextStyle(
                color: bannerColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Stats card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _StatColumn('Ja', '$yes', Colors.green),
                  _StatColumn('Nein', '$no', Colors.red),
                  _StatColumn(
                      'Enthaltung', '$abstain', AppColors.surfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _decisionRecord != null
                    ? buildParticipationText(_decisionRecord!)
                    : _decisionVotes == null
                        ? 'Beteiligung wird geladen …'
                        : 'Beteiligung nicht verfügbar',
                style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Transparency list: always rendered (shows empty-state if no votes)
        _TransparencyList(votes: displayVotes, options: widget.options),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatColumn(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.onDark.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransparencyList extends StatelessWidget {
  final List<Vote> votes;
  final List<ProposalOption> options;
  const _TransparencyList({
    required this.votes,
    this.options = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wer hat wie abgestimmt',
            style: TextStyle(
              color: AppColors.onDark,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          if (votes.isEmpty)
            Text(
              'Keine abgegebenen Stimmen.',
              style: TextStyle(
                color: AppColors.onDark.withValues(alpha: 0.45),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...votes.map((v) => _VoteRow(vote: v, options: options)),
        ],
      ),
    );
  }
}

class _VoteRow extends StatelessWidget {
  final Vote vote;
  final List<ProposalOption> options;
  const _VoteRow({required this.vote, this.options = const []});

  @override
  Widget build(BuildContext context) {
    // Phase 4.7c3: show option label when selectedOptionId is set.
    String choiceLabel;
    Color choiceColor;
    if (vote.selectedOptionId != null) {
      ProposalOption? matched;
      for (final option in options) {
        if (option.optionId == vote.selectedOptionId) {
          matched = option;
          break;
        }
      }
      choiceLabel = matched != null ? matched.label : 'Unbekannte Option';
      choiceColor = AppColors.gold;
    } else {
      switch (vote.choice) {
        case VoteChoice.YES:
          choiceLabel = 'Ja';
          choiceColor = Colors.green;
          break;
        case VoteChoice.NO:
          choiceLabel = 'Nein';
          choiceColor = Colors.red;
          break;
        case VoteChoice.ABSTAIN:
          choiceLabel = 'Enthaltung';
          choiceColor = AppColors.surfaceVariant;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vote.voterPseudonym,
                  style: const TextStyle(
                    color: AppColors.onDark,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: choiceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  choiceLabel,
                  style: TextStyle(
                    color: choiceColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmtDate(vote.createdAt),
                style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (vote.reasoning != null && vote.reasoning!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '"${vote.reasoning}"',
                style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ── Diskussion Tab ────────────────────────────────────────────────────────────

class _DiskussionTab extends StatefulWidget {
  final Proposal proposal;
  const _DiskussionTab({required this.proposal});

  @override
  State<_DiskussionTab> createState() => _DiskussionTabState();
}

class _DiskussionTabState extends State<_DiskussionTab>
    with AutomaticKeepAliveClientMixin {
  List<ProposalDiscussionMessage> _messages = [];
  final _ctrl = TextEditingController();
  bool _isSending = false;
  StreamSubscription<void>? _sub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print('[G2-UI] Discussion tab opened for ${widget.proposal.id}');
    _load();
    _sub = ProposalService.instance.stream.listen((_) {
      if (mounted) _load();
    });
  }

  void _load() {
    setState(() {
      _messages = List.from(
          ProposalService.instance.getDiscussionMessages(widget.proposal.id));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    print('[G2-UI] Posting discussion message');
    try {
      await ProposalService.instance
          .postDiscussionMessage(widget.proposal.id, text);
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = widget.proposal;

    // DRAFT/WITHDRAWN: Diskussion noch nicht gestartet
    if (p.status == ProposalStatus.DRAFT ||
        p.status == ProposalStatus.WITHDRAWN) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined,
                  size: 48,
                  color: AppColors.onDark.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                p.status == ProposalStatus.DRAFT
                    ? 'Diskussion beginnt sobald der Antrag veröffentlicht wird.'
                    : 'Dieser Antrag wurde zurückgezogen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.onDark.withValues(alpha: 0.5),
                    height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Message list
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Noch keine Beiträge.\nSei der Erste!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.onDark.withValues(alpha: 0.45),
                          height: 1.5),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) =>
                      _DiscussionMessageTile(msg: _messages[i]),
                ),
        ),
        // Input row
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          color: AppColors.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(color: AppColors.onDark, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Dein Beitrag zur Diskussion…',
                    hintStyle: TextStyle(
                        color: AppColors.onDark.withValues(alpha: 0.35),
                        fontSize: 13),
                    filled: true,
                    fillColor: AppColors.deepBlue,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide:
                          const BorderSide(color: AppColors.surfaceVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide:
                          const BorderSide(color: AppColors.surfaceVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.gold)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: AppColors.gold),
                      onPressed: _send,
                      tooltip: 'Senden',
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscussionMessageTile extends StatelessWidget {
  final ProposalDiscussionMessage msg;
  const _DiscussionMessageTile({required this.msg});

  @override
  Widget build(BuildContext context) {
    final myDid = IdentityService.instance.currentIdentity?.did ?? '';
    final isMe = msg.authorDid == myDid;
    final dt = msg.createdAt.toLocal();
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceVariant,
              child: Text(
                (msg.authorPseudonym.isNotEmpty
                    ? msg.authorPseudonym[0]
                    : '?'),
                style: const TextStyle(fontSize: 12, color: AppColors.onDark),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    msg.authorPseudonym.isNotEmpty
                        ? msg.authorPseudonym
                        : msg.authorDid.substring(0, 12),
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.gold.withValues(alpha: 0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 12 : 2),
                      topRight: Radius.circular(isMe ? 2 : 12),
                      bottomLeft: const Radius.circular(12),
                      bottomRight: const Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: const TextStyle(
                        color: AppColors.onDark, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: TextStyle(
                      color: AppColors.onDark.withValues(alpha: 0.4),
                      fontSize: 10),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Historie Tab ──────────────────────────────────────────────────────────────

class _HistorieTab extends StatefulWidget {
  final String proposalId;
  const _HistorieTab({required this.proposalId});

  @override
  State<_HistorieTab> createState() => _HistorieTabState();
}

class _HistorieTabState extends State<_HistorieTab>
    with AutomaticKeepAliveClientMixin {
  List<AuditLogEntry>? _entries;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries =
        await ProposalService.instance.getAuditLog(widget.proposalId);
    if (mounted) setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_entries == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const HelpIcon(contextId: 'proposal_history', size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diese Historie ist unveränderlich — sie ist das Gedächtnis unserer Demokratie.',
                  style: TextStyle(
                    color: AppColors.onDark.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_entries!.isEmpty)
          Center(
            child: Text(
              'Noch keine Einträge.',
              style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.4)),
            ),
          )
        else
          ..._entries!.map((e) => _AuditTile(entry: e)),
      ],
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditLogEntry entry;
  const _AuditTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (icon, title) = _entryInfo(entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.surfaceVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.onDark,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                // Vote reasoning
                if (entry.eventType == AuditEventType.VOTE_CAST ||
                    entry.eventType == AuditEventType.VOTE_CHANGED) ...[
                  if (entry.payload['reasoning'] != null &&
                      (entry.payload['reasoning'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '"${entry.payload['reasoning']}"',
                        style: TextStyle(
                          color: AppColors.onDark.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
                // Edit reason
                if (entry.eventType == AuditEventType.PROPOSAL_EDITED &&
                    entry.payload['reason'] != null &&
                    (entry.payload['reason'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Grund: ${entry.payload['reason']}',
                      style: TextStyle(
                        color: AppColors.onDark.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtTimestamp(entry.timestamp),
            style: TextStyle(
              color: AppColors.onDark.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  (String, String) _entryInfo(AuditLogEntry e) {
    final actor = e.actorPseudonym;
    final p = e.payload;

    return switch (e.eventType) {
      AuditEventType.PROPOSAL_CREATED =>
        ('📋', '$actor hat den Antrag erstellt'),
      AuditEventType.PROPOSAL_EDITED => () {
          final from = p['versionBefore'] ?? '?';
          final to = p['versionAfter'] ?? '?';
          return ('✏️', '$actor hat den Antragstext bearbeitet  v$from → v$to');
        }(),
      AuditEventType.PROPOSAL_STATUS_CHANGED => () {
          final from = _statusLabel(p['from']?.toString() ?? '');
          final to = _statusLabel(p['to']?.toString() ?? '');
          return ('🔄', 'Status: $from → $to');
        }(),
      AuditEventType.PROPOSAL_WITHDRAWN =>
        ('↩️', '$actor hat den Antrag zurückgezogen'),
      AuditEventType.VOTE_CAST => () {
          final choice = _choiceLabel(p['choice']?.toString() ?? '');
          return ('✅', '$actor hat mit $choice gestimmt');
        }(),
      AuditEventType.VOTE_CHANGED => () {
          final prev = p['previousChoice']?.toString();
          final to = _choiceLabel(p['choice']?.toString() ?? '');
          if (prev != null && prev.isNotEmpty) {
            return ('🔁', '$actor hat die Stimme von ${_choiceLabel(prev)} zu $to geändert');
          }
          return ('🔁', '$actor hat die Stimme zu $to geändert');
        }(),
      AuditEventType.VOTE_LATE_ACCEPTED => () {
          final choice = _choiceLabel(p['choice']?.toString() ?? '');
          return ('⏰',
              'Verspätete Stimme von $actor akzeptiert ($choice, vor Ende abgegeben)');
        }(),
      AuditEventType.VOTE_LATE_REJECTED =>
        ('⏰', 'Verspätete Stimme abgelehnt (nach Ende abgegeben)'),
      AuditEventType.RESULT_CALCULATED => () {
          final result = _resultLabel(p['result']?.toString() ?? '');
          final yes = p['yes'] ?? 0;
          final no = p['no'] ?? 0;
          final abstain = p['abstain'] ?? 0;
          final pct = p['participationPct'] != null
              ? '${(p['participationPct'] as num).round()}%'
              : '?%';
          return ('🏁',
              'Ergebnis: $result  (Ja: $yes, Nein: $no, Enthaltung: $abstain, Beteiligung: $pct)');
        }(),
      AuditEventType.PROPOSAL_ARCHIVED => ('📦', 'Antrag archiviert'),
      // Phase G2.1.1a — delegation audit types (displayed starting in G2.1.4).
      AuditEventType.DELEGATION_CREATED =>
        ('🔗', '$actor hat eine Delegation erstellt'),
      AuditEventType.DELEGATION_REVOKED =>
        ('🔗', '$actor hat eine Delegation widerrufen'),
      AuditEventType.DELEGATION_REVOKED_BY_DIRECT_VOTE =>
        ('🔗', '$actor hat eine Delegation durch Direktvote aufgehoben'),
      AuditEventType.DELEGATION_SUPERSEDED =>
        ('🔗', '$actor hat eine Delegation durch eine neue ersetzt'),
      AuditEventType.DELEGATION_EXPIRED =>
        ('🔗', 'Delegation abgelaufen (Abstimmung nicht mehr aktiv)'),
      AuditEventType.DELEGATION_INVALIDATED =>
        ('🔗', 'Delegation ungültig (Delegator kein gültiges Mitglied)'),
    };
  }

  String _statusLabel(String s) => switch (s) {
        'DISCUSSION' => 'Diskussion',
        'VOTING' => 'Abstimmung gestartet',
        'VOTING_ENDED' => 'Abstimmung beendet (Grace Period)',
        'DECIDED' => 'Entschieden',
        'ARCHIVED' => 'Archiviert',
        'WITHDRAWN' => 'Zurückgezogen',
        _ => s,
      };

  String _choiceLabel(String s) => switch (s) {
        'YES' => 'JA',
        'NO' => 'NEIN',
        'ABSTAIN' => 'ENTHALTUNG',
        _ => s,
      };

  String _resultLabel(String s) => switch (s) {
        'approved' => 'ANGENOMMEN',
        'rejected' => 'ABGELEHNT',
        _ => 'UNGÜLTIG',
      };

  String _fmtTimestamp(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.\n'
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Delegations-Block (Phase G2.1.4) ─────────────────────────────────────────
//
// Shown only when:
//   - proposal.status == VOTING
//   - proposal.votingMode != CANDIDATE_CHOICE  (enforced by caller + guard here)
//   - user has NOT cast a direct vote yet
//
// Three states:
//   1. No active delegation → "Stimme delegieren" button
//   2. Active delegation exists → status text + "Widerrufen" button
//   3. User has voted directly → SizedBox.shrink() (no block)

class _DelegationBlock extends StatefulWidget {
  final Proposal proposal;
  final Vote? myExistingVote;

  const _DelegationBlock({
    required this.proposal,
    required this.myExistingVote,
  });

  @override
  State<_DelegationBlock> createState() => _DelegationBlockState();
}

class _DelegationBlockState extends State<_DelegationBlock> {
  late Future<Delegation?> _future;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _future = _loadOwnDelegation();
  }

  String get _myDid =>
      IdentityService.instance.currentIdentity?.did ?? '';

  Future<Delegation?> _loadOwnDelegation() async {
    if (_myDid.isEmpty) return null;
    final rows = await PodDatabase.instance
        .listActiveDelegationsForProposal(widget.proposal.id);
    final own =
        rows.where((m) => m['delegator_did'] == _myDid).toList();
    if (own.isEmpty) return null;
    return Delegation.fromMap(own.first);
  }

  void _reload() =>
      setState(() => _future = _loadOwnDelegation());

  @override
  Widget build(BuildContext context) {
    // CC-Ausschluss (defense-in-depth — Caller-Guard ist primär).
    if (widget.proposal.votingMode == VotingMode.CANDIDATE_CHOICE) {
      return const SizedBox.shrink();
    }
    // Direktvote-Ausschluss: wer bereits abgestimmt hat, sieht keinen Block.
    if (widget.myExistingVote != null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Delegation?>(
      future: _future,
      builder: (context, snapshot) {
        // Still loading: render nothing to avoid flicker.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final delegation = snapshot.data;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.surfaceVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with help icon
              Row(
                children: [
                  const Text('🤝', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  const Text(
                    'Liquid Democracy',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const HelpIcon(
                      contextId: 'proposal_voting_delegation',
                      size: 15),
                ],
              ),
              const SizedBox(height: 10),
              if (delegation != null)
                _buildActiveDelegation(context, delegation)
              else
                _buildDelegateButton(context),
            ],
          ),
        );
      },
    );
  }

  // ── Active delegation: status text + revoke button ────────────────────────

  Widget _buildActiveDelegation(
      BuildContext context, Delegation delegation) {
    final name =
        ContactService.instance.getDisplayName(delegation.delegateDid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.link, color: Colors.blue.shade300, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Du hast deine Stimme an $name delegiert.',
                style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isActing
              ? null
              : () => _confirmRevoke(context, delegation, name),
          icon: const Icon(Icons.link_off, size: 16),
          label: const Text('Widerrufen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: const BorderSide(color: Colors.orange),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ],
    );
  }

  // ── No delegation: delegate button ────────────────────────────────────────

  Widget _buildDelegateButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isActing ? null : () => _openDelegateSheet(context),
      icon: const Icon(Icons.person_add_outlined, size: 16),
      label: const Text('Stimme delegieren'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }

  // ── Revoke flow ──────────────────────────────────────────────────────────

  Future<void> _confirmRevoke(
    BuildContext context,
    Delegation delegation,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delegation widerrufen?',
            style: TextStyle(color: AppColors.onDark)),
        content: Text(
          'Delegation an $name widerrufen?',
          style: TextStyle(
              color: AppColors.onDark.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abbrechen',
                style: TextStyle(
                    color: AppColors.onDark.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Widerrufen',
                style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isActing = true);
    try {
      await ProposalService.instance
          .revokeDelegation(delegation.delegationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delegation widerrufen.'),
            backgroundColor: Colors.green,
          ),
        );
        _reload();
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  // ── Delegate-Sheet flow ───────────────────────────────────────────────────

  Future<void> _openDelegateSheet(BuildContext context) async {
    final selectedDid = await DelegateSelectSheet.show(
      context,
      cellId: widget.proposal.cellId,
      myDid: _myDid,
    );
    if (selectedDid == null || !mounted) return;
    setState(() => _isActing = true);
    try {
      await ProposalService.instance.createDelegation(
        delegatorDid: _myDid,
        delegateDid: selectedDid,
        proposalId: widget.proposal.id,
      );
      if (mounted) {
        final name =
            ContactService.instance.getDisplayName(selectedDid);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stimme an $name delegiert.'),
            backgroundColor: Colors.green,
          ),
        );
        _reload();
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }
}

// ── Eingehende Delegationen (Phase G2.1.4b) ───────────────────────────────────
//
// Shown during VOTING when other cell members have delegated to the current
// user.  Only visible in YNA and SC modes (CC excluded, same guard as
// _DelegationBlock).
//
// Data source: PodDatabase.listActiveDelegationsForProposal, filtered
// client-side to delegate_did == myDid.  No new DB API needed.

class _IncomingDelegationsBlock extends StatefulWidget {
  final Proposal proposal;

  const _IncomingDelegationsBlock({required this.proposal});

  @override
  State<_IncomingDelegationsBlock> createState() =>
      _IncomingDelegationsBlockState();
}

class _IncomingDelegationsBlockState
    extends State<_IncomingDelegationsBlock> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadIncoming();
  }

  String get _myDid =>
      IdentityService.instance.currentIdentity?.did ?? '';

  Future<List<Map<String, dynamic>>> _loadIncoming() async {
    if (_myDid.isEmpty) return const [];
    final all = await PodDatabase.instance
        .listActiveDelegationsForProposal(widget.proposal.id);
    return all.where((m) => m['delegate_did'] == _myDid).toList();
  }

  @override
  Widget build(BuildContext context) {
    // CC-Ausschluss (defense-in-depth — Caller-Guard ist primär).
    if (widget.proposal.votingMode == VotingMode.CANDIDATE_CHOICE) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        // Still loading: render nothing to avoid flicker.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final incoming = snapshot.data ?? const [];
        if (incoming.isEmpty) return const SizedBox.shrink();

        final count = incoming.length;
        final countText = count == 1
            ? 'Dir wurde 1 Stimme delegiert.'
            : 'Dir wurden $count Stimmen delegiert.';

        // Optional: Delegatoren-Pseudonyme (A.5).
        final names = incoming
            .map((m) => ContactService.instance
                .getDisplayName(m['delegator_did'] as String))
            .join(', ');

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.how_to_vote,
                      color: Colors.blue.shade300, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      countText,
                      style: const TextStyle(
                        color: AppColors.onDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const HelpIcon(
                      contextId: 'proposal_voting_incoming_delegation',
                      size: 15),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Wenn du in dieser Abstimmung selbst direkt abstimmst, '
                'zählt deine Stimme auch für die delegierten Personen.',
                style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.75),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (names.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Von: $names',
                  style: TextStyle(
                    color: AppColors.onDark.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
