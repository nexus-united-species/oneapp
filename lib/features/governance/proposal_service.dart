import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/identity/identity_service.dart';
import '../../core/storage/pod_database.dart';
import '../../core/transport/nostr/nostr_event.dart';
import '../../core/transport/nostr/publish_result.dart';
import '../../core/transport/nostr/publish_result_dao.dart';
import '../../core/transport/nostr/publish_result_status.dart';
import '../../core/contacts/contact_service.dart';
import '../../services/notification_service.dart';
import 'audit_log_entry.dart';
import 'cell_member.dart';
import 'delegation.dart';
import 'cell_service.dart';
import 'retry_backoff.dart';
import 'decision_record.dart';
import 'proposal.dart';
import 'proposal_edit.dart';
import 'proposal_option.dart';
import 'tally_helpers.dart';
import 'vote.dart';
import 'voting_mode.dart';

/// A single discussion message attached to a proposal.
class ProposalDiscussionMessage {
  final String id;
  final String proposalId;
  final String authorDid;
  final String authorPseudonym;
  final String content;
  final DateTime createdAt;

  const ProposalDiscussionMessage({
    required this.id,
    required this.proposalId,
    required this.authorDid,
    required this.authorPseudonym,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'proposal_id': proposalId,
        'author_did': authorDid,
        'author_pseudo': authorPseudonym,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static ProposalDiscussionMessage fromMap(Map<String, dynamic> m) =>
      ProposalDiscussionMessage(
        id: m['id'] as String,
        proposalId: m['proposal_id'] as String,
        authorDid: m['author_did'] as String,
        authorPseudonym: m['author_pseudo'] as String? ?? '',
        content: m['content'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            m['created_at'] as int,
            isUtc: true),
      );
}

/// Manages governance proposals and votes within cells.
///
/// G2 additions over G1:
/// - ProposalType (SACHFRAGE / VERFASSUNGSFRAGE)
/// - ProposalStatus VOTING_ENDED + WITHDRAWN
/// - Vote casting (Prompt 1B)
/// - Edit history (Prompt 1B)
/// - Audit log (Prompt 1B)
/// - Decision records with hash-chain (Prompt 1B)
/// - Nostr sync for votes + decisions (Prompt 1B)
class ProposalService {
  ProposalService._();
  static ProposalService? _instance;
  static ProposalService get instance => _instance ??= ProposalService._();

  // In-memory caches
  final Map<String, Proposal> _proposals = {};
  final Map<String, List<Vote>> _votes = {}; // keyed by proposal_id
  final Map<String, List<ProposalDiscussionMessage>> _discussions = {};

  /// Persistent tombstone list: proposal IDs that were deleted/withdrawn locally.
  /// Once tombstoned, a proposal can never be re-imported via Nostr replay.
  /// Tombstones are never cleared (except on full app data wipe).
  final Set<String> _proposalTombstones = {};

  /// AETHER synchronous seen-set for incoming Kind-31010 proposal events.
  /// Prevents duplicate audit log entries (PROPOSAL_EDITED, PROPOSAL_STATUS_
  /// CHANGED) when two relays deliver the same event in parallel. Set is
  /// cleared on app restart; cross-session dedup is provided by the
  /// version-gating logic (version > existing.version) inside the handler.
  final Set<String> _seenProposalEventIds = <String>{};

  /// AETHER synchronous seen-set for incoming Kind-31011 vote events.
  /// Prevents duplicate audit log entries (VOTE_CAST, VOTE_CHANGED) when
  /// two relays deliver the same event in parallel. Set is cleared on
  /// app restart; cross-session dedup is provided by the async
  /// hasAuditEntryForNostrEvent DB check inside the handler.
  final Set<String> _seenVoteEventIds = <String>{};

  /// AETHER synchronous seen-set for incoming Kind-31013 decision records.
  /// Prevents duplicate audit log entries (RESULT_CALCULATED) when two
  /// relays deliver the same event in parallel. Set is cleared on app
  /// restart; cross-session dedup is provided by the decision_records
  /// proposal_id UNIQUE constraint at the DB level.
  final Set<String> _seenDecisionEventIds = <String>{};

  /// AETHER synchronous seen-set for incoming Kind-31012 delegation events.
  /// Prevents duplicate audit log entries when two relays deliver the same
  /// event in parallel. Cross-session dedup is provided by the
  /// delegationId primary key + updatedAt comparison in the handler.
  /// Phase G2.1.2.
  final Set<String> _seenDelegationEventIds = <String>{};

  static const _tombstonesKey = 'proposal_tombstones';
  static const _tombstoneMigrationKey = 'proposal_tombstones_migrated_to_sqlite';

  /// Phase 4.8: Pseudonym used for auto-created runoff proposals.
  /// Constant across devices to prevent inadvertent disclosure of which
  /// device performed the tally, and to make runoff proposals visually
  /// distinguishable as system-generated.
  static const String _kRunoffSystemPseudonym = 'Stichwahl-System';

  /// Phase 4.8: SharedPreferences key for the set of original proposal IDs
  /// for which this device has already created a runoff proposal.
  static const String _kRunoffCreatedKey = 'runoff_created_for_original_ids';

  final _streamCtrl = StreamController<void>.broadcast();
  final _auditCtrl = StreamController<AuditLogEntry>.broadcast();

  Stream<void> get stream => _streamCtrl.stream;
  Stream<AuditLogEntry> get auditLogStream => _auditCtrl.stream;

  List<Proposal> get allProposals => List.unmodifiable(_proposals.values);

  // ── Nostr publish callbacks (set by ChatProvider) ─────────────────────────

  /// Called to publish a Kind-31010 proposal event.
  /// Returns a [PublishResult] tracking relay ACKs.
  Future<PublishResult> Function(Map<String, dynamic>)? onPublishProposalToNostr;

  /// Called to publish a Kind-31011 vote event.
  /// Returns a [PublishResult] tracking relay ACKs.
  Future<PublishResult> Function(Map<String, dynamic>)? onPublishVoteToNostr;

  /// Called to publish a Kind-31013 decision record.
  /// Returns a [PublishResult] tracking relay ACKs.
  Future<PublishResult> Function(Map<String, dynamic>)? onPublishDecisionToNostr;

  /// Called to publish a Kind-31012 delegation event. Phase G2.1.2.
  /// Returns a [PublishResult] tracking relay ACKs.
  Future<PublishResult> Function(Delegation)? onPublishDelegationToNostr;

  /// Called to send a proposal discussion message via the transport layer.
  Future<void> Function(Map<String, dynamic>)? onSendDiscussionMessage;

  /// Returns the local user's Nostr public key hex (from NostrTransport).
  /// Set by ChatProvider after transport is initialised.
  String? Function()? getMyNostrPubkeyHex;

  // ── Retry timer for DB-based Nostr publish retry ─────────────────────────

  Timer? _retryTimer;

  // ── Scheduler accessor ────────────────────────────────────────────────────

  /// Returns all proposals that need scheduler attention (active or recently
  /// decided). Used by [ProposalScheduler] to drive automatic status advances.
  List<Proposal> getAllProposalsForScheduler() {
    return _proposals.values.where((p) {
      switch (p.status) {
        case ProposalStatus.VOTING:
        case ProposalStatus.VOTING_ENDED:
          return true;
        case ProposalStatus.DECIDED:
          // Keep for 30-day auto-archive window.
          return p.decidedAt != null &&
              DateTime.now().toUtc().difference(p.decidedAt!).inDays < 31;
        default:
          return false;
      }
    }).toList();
  }

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    debugPrint('[PROPOSAL] Service initializing');
    try {
      // Load tombstones FIRST so they are active before any DB or Nostr data arrives.
      // Step 1: One-time migration from SharedPreferences to SQLite (idempotent).
      final prefs = await SharedPreferences.getInstance();
      await _migrateSharedPrefsTombstonesToSqlite(prefs);
      // Step 2: Load from SQLite (primary) into in-memory set.
      await _loadTombstonesFromSqlite();
      // Step 3: Also load from SharedPreferences as a fallback merge.
      // This catches any race conditions where SharedPrefs has more recent
      // data than SQLite (rare, but defensive).
      await _loadTombstones();
      await _migrateLegacyProposals();
      await _loadFromDatabase();
      await _cleanupZombiesOnStart();
      _advanceStatuses();
      debugPrint('[PROPOSAL] Loaded ${_proposals.length} proposals from DB');
      _notify();
      // Load any pending retries from the previous session.
      unawaited(_processRetryQueue());
      _startRetryTimer();
    } catch (e) {
      debugPrint('[PROPOSAL] load error: $e');
    }
  }

  /// Loads the persistent tombstone list from SharedPreferences.
  Future<void> _loadTombstones() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_tombstonesKey) ?? [];
    _proposalTombstones.addAll(list);
    print('[PROPOSAL] Loaded ${_proposalTombstones.length} tombstones');
  }

  /// One-time migration: copies SharedPreferences proposal-tombstone list
  /// into the SQLite tombstones table (type='proposal').
  /// Idempotent — runs once per install via the _tombstoneMigrationKey flag.
  Future<void> _migrateSharedPrefsTombstonesToSqlite(SharedPreferences prefs) async {
    if (prefs.getBool(_tombstoneMigrationKey) == true) {
      print('[PROPOSAL-TOMBSTONE-MIGRATION] Already done, skipping');
      return;
    }

    print('[PROPOSAL-TOMBSTONE-MIGRATION] === Starting one-time migration ===');
    int migrated = 0;

    final list = prefs.getStringList(_tombstonesKey) ?? [];
    print('[PROPOSAL-TOMBSTONE-MIGRATION] Found ${list.length} proposal tombstones in SharedPrefs');

    for (final id in list) {
      await PodDatabase.instance.addTombstone(
        id: id,
        type: 'proposal',
        reason: 'migrated from SharedPreferences',
      );
      migrated++;
    }

    await prefs.setBool(_tombstoneMigrationKey, true);
    print('[PROPOSAL-TOMBSTONE-MIGRATION] === Done: $migrated tombstones migrated ===');
  }

  /// Loads proposal tombstones from SQLite into the in-memory set.
  /// Called on every app start after migration.
  Future<void> _loadTombstonesFromSqlite() async {
    final fromSqlite = await PodDatabase.instance.listTombstones('proposal');
    _proposalTombstones.addAll(fromSqlite);
    print('[PROPOSAL-TOMBSTONE] Loaded ${fromSqlite.length} from SQLite');
  }

  /// Adds [proposalId] to the in-memory tombstone set and writes to both
  /// SQLite (primary) and SharedPreferences (fallback). The optional
  /// [reason] enables semantic auditability — defaults to 'tombstoned'
  /// for backwards compatibility with existing callers.
  Future<void> _addTombstone(
    String proposalId, {
    String reason = 'tombstoned',
  }) async {
    // In-memory first (synchronous), so callers can check immediately.
    _proposalTombstones.add(proposalId);

    // SQLite (primary persistent storage).
    await PodDatabase.instance.addTombstone(
      id: proposalId,
      type: 'proposal',
      reason: reason,
    );

    // SharedPreferences (fallback / backwards compat). Kept in sync so a
    // failed SQLite read on app start can still recover from prefs.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_tombstonesKey, _proposalTombstones.toList());

    print('[PROPOSAL] Tombstone added: $proposalId (reason=$reason)');
  }

  /// Removes any proposals from the DB/cache that are already tombstoned.
  ///
  /// Handles the race-window where a Nostr event landed between the last
  /// tombstone write and the current app start.
  Future<void> _cleanupZombiesOnStart() async {
    // WITHDRAWN proposals are tombstoned by design (to prevent re-import
    // of the original pre-withdraw event), but they are legitimately
    // visible per G2 spec §8.2. Skip them in zombie cleanup.
    final zombies = _proposals.entries
        .where((entry) =>
            _proposalTombstones.contains(entry.key) &&
            entry.value.status != ProposalStatus.WITHDRAWN)
        .map((entry) => entry.key)
        .toList();

    final skippedWithdrawn = _proposals.entries
        .where((entry) =>
            _proposalTombstones.contains(entry.key) &&
            entry.value.status == ProposalStatus.WITHDRAWN)
        .length;
    if (skippedWithdrawn > 0) {
      print('[PROPOSAL] Skipping $skippedWithdrawn tombstoned WITHDRAWN '
          'proposals during zombie cleanup');
    }

    if (zombies.isEmpty) return;
    print('[PROPOSAL] Cleanup zombies on start: ${zombies.length} removed');
    for (final id in zombies) {
      _proposals.remove(id);
      _votes.remove(id);
      await _deleteProposalKeepingAudit(id);
    }
  }

  /// One-time migration: reads enc-blob rows from proposals_legacy and
  /// writes them to the new flat-column proposals table.
  Future<void> _migrateLegacyProposals() async {
    // Check if migration has already run.
    final db = PodDatabase.instance;
    final alreadyMigrated = await db.getIdentityValue('proposals_g2_migrated');
    if (alreadyMigrated != null) return;

    debugPrint('[PROPOSAL] Migrating legacy proposals…');
    int count = 0;
    try {
      final legacyRows = await db.listLegacyProposals();
      for (final json in legacyRows) {
        try {
          final proposal = Proposal.fromLegacyJson(json);
          await _saveProposalToDb(proposal);
          count++;
        } catch (e) {
          debugPrint('[PROPOSAL] Migration skip: $e');
        }
      }
    } catch (e) {
      debugPrint('[PROPOSAL] Legacy migration error: $e');
    }
    // Mark migration complete even if partial (avoids re-running on every start).
    await db.setIdentityValue('proposals_g2_migrated', {'done': true, 'count': count});
    debugPrint('[PROPOSAL] Migrated $count legacy proposals');
  }

  Future<void> _loadFromDatabase() async {
    _proposals.clear();
    _votes.clear();

    final rows = await PodDatabase.instance.listProposals();
    for (final row in rows) {
      try {
        final p = Proposal.fromMap(row);
        _proposals[p.id] = p;
      } catch (e) {
        debugPrint('[PROPOSAL] Parse error: $e');
      }
    }

    // Load votes for all cached proposals.
    for (final proposalId in _proposals.keys) {
      try {
        final voteRows = await PodDatabase.instance.listVotes(proposalId);
        _votes[proposalId] = voteRows.map(Vote.fromMap).toList();
      } catch (e) {
        debugPrint('[PROPOSAL] Vote load error for $proposalId: $e');
      }
    }

    // Load discussion messages for all cached proposals.
    for (final proposalId in _proposals.keys) {
      try {
        final rows =
            await PodDatabase.instance.listProposalDiscussions(proposalId);
        _discussions[proposalId] =
            rows.map(ProposalDiscussionMessage.fromMap).toList();
      } catch (e) {
        debugPrint('[PROPOSAL] Discussion load error for $proposalId: $e');
      }
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Creates a new proposal in DRAFT state.
  ///
  /// Throws if the caller is not a confirmed cell member or hasn't waited
  /// [Cell.proposalWaitDays] since joining.
  Future<Proposal> createProposal(Proposal proposal) async {
    final myDid = IdentityService.instance.currentIdentity!.did;
    _checkCanCreateProposal(proposal.cellId, myDid);

    // AETHER state-locking: write in-memory first (synchronous, same microtask)
    // so concurrent relay echoes cannot insert a phantom duplicate during the
    // DB await window.
    _proposals[proposal.id] = proposal;

    await _saveProposalToDb(proposal);
    _notify();
    debugPrint('[PROPOSAL] Draft created: ${proposal.id}');
    return proposal;
  }

  /// Creates a draft using named parameters (convenience wrapper).
  ///
  /// Phase 4.7c3: accepts optional votingMode and initialOptionLabels.
  /// Labels are normalized (trim + drop empty) before validation.
  Future<Proposal> createDraft({
    required String cellId,
    required String creatorDid,
    required String creatorPseudonym,
    required String title,
    required String description,
    String? category,
    ProposalType type = ProposalType.SACHFRAGE,
    VotingMode votingMode = VotingMode.YES_NO_ABSTAIN,
    List<String> initialOptionLabels = const <String>[],
  }) async {
    debugPrint('[PROPOSAL] Creating draft: $title '
        'mode=${votingMode.name} options=${initialOptionLabels.length}');

    // Normalize: trim whitespace and drop empty entries BEFORE validation.
    final normalizedOptions = initialOptionLabels
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    // Mode-aware validation on the normalized list.
    if (votingMode == VotingMode.YES_NO_ABSTAIN &&
        normalizedOptions.isNotEmpty) {
      throw StateError(
          'YES_NO_ABSTAIN proposal must not have options '
          '(got ${normalizedOptions.length})');
    }
    if (votingMode == VotingMode.SINGLE_CHOICE &&
        normalizedOptions.length < 2) {
      throw StateError(
          'SINGLE_CHOICE proposal requires at least 2 options '
          '(got ${normalizedOptions.length})');
    }

    final proposal = Proposal.create(
      cellId: cellId,
      creatorDid: creatorDid,
      creatorPseudonym: creatorPseudonym,
      title: title,
      description: description,
      category: category,
      proposalType: type,
      votingMode: votingMode,
    );
    final created = await createProposal(proposal);

    // Persist normalized options only for non-empty labels.
    if (normalizedOptions.isNotEmpty) {
      for (var i = 0; i < normalizedOptions.length; i++) {
        final opt = ProposalOption.create(
          proposalId: created.id,
          position: i,
          label: normalizedOptions[i],
        );
        await PodDatabase.instance.upsertProposalOption(opt.toMap());
      }
      debugPrint('[PROPOSAL] Persisted ${normalizedOptions.length} '
          'options for ${created.id}');
    }

    return created;
  }

  /// Updates a DRAFT proposal (title/description/category changes before publishing).
  Future<void> updateDraft(Proposal proposal) async {
    if (proposal.status != ProposalStatus.DRAFT) {
      throw StateError('Can only update DRAFT proposals');
    }
    await _saveProposalToDb(proposal);
    _proposals[proposal.id] = proposal;
    _notify();
    debugPrint('[PROPOSAL] Draft updated: ${proposal.id}');
  }

  /// Permanently deletes a DRAFT (only creator, only while DRAFT).
  Future<void> deleteDraft(String proposalId) async {
    final proposal = _proposals[proposalId];
    if (proposal == null || proposal.status != ProposalStatus.DRAFT) {
      throw StateError('Can only delete DRAFT proposals');
    }
    // Tombstone synchronously BEFORE the async DB delete (race-condition guard).
    await _addTombstone(proposalId);
    _proposals.remove(proposalId);
    _votes.remove(proposalId);
    _notify(); // live UI update immediately
    await _deleteProposalKeepingAudit(proposalId);
    debugPrint('[PROPOSAL] Draft deleted: $proposalId');
  }

  // ── Status transitions (stubs – implemented in Prompt 1B) ─────────────────

  /// Publishes a DRAFT → DISCUSSION.
  ///
  /// This is the canonical entry point for both G1 compat and G2.
  Future<void> publishProposal(String proposalId) async {
    await publishToDiscussion(proposalId);
  }

  /// DRAFT → DISCUSSION: publishes to Nostr, creates discussion thread,
  /// sends push notification to cell members.
  Future<void> publishToDiscussion(String proposalId) async {
    print('[PROPOSAL] publishToDiscussion: $proposalId');
    final p = _proposals[proposalId];
    if (p == null) throw StateError('Proposal not found: $proposalId');
    if (p.status != ProposalStatus.DRAFT) {
      throw StateError('Only DRAFT can be published (current: ${p.status})');
    }

    p.status = ProposalStatus.DISCUSSION;
    p.discussionStartedAt = DateTime.now().toUtc();
    await _saveProposalToDb(p);

    final publishResult = await _publishProposalToNostr(p);
    final published = publishResult.status == PublishResultStatus.accepted ||
        publishResult.status == PublishResultStatus.partial;
    if (!published) {
      print('[PUBLISH-RESULT] Proposal queued for retry: ${publishResult.status}');
    }

    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.PROPOSAL_CREATED,
      actorDid: p.creatorDid,
      actorPseudonym: p.creatorPseudonym,
      timestamp: DateTime.now().toUtc(),
      payload: {'title': p.title, 'category': p.category},
    ));

    await _createDiscussionThread(p);

    await _notifyAllMembers(
      p.cellId,
      title: 'Neuer Antrag',
      body: '${p.creatorPseudonym}: ${p.title}',
      payload: 'proposal:${p.id}',
      excludeDid: p.creatorDid,
    );

    _notify();
    print('[PROPOSAL] Published ${p.id} → DISCUSSION');
  }

  /// DISCUSSION → edit title/description while in discussion phase.
  Future<void> editInDiscussion(String proposalId, String newTitle,
      String newDescription, String? reason) async {
    print('[PROPOSAL] editInDiscussion: $proposalId');
    final p = _proposals[proposalId];
    if (p == null) throw StateError('Proposal not found: $proposalId');
    if (p.status != ProposalStatus.DISCUSSION) {
      throw StateError('Only DISCUSSION proposals can be edited');
    }

    final edit = ProposalEdit(
      editId: ProposalEdit.generateId(),
      proposalId: p.id,
      editorDid: p.creatorDid,
      editorPseudonym: p.creatorPseudonym,
      oldTitle: p.title,
      newTitle: newTitle,
      oldDescription: p.description,
      newDescription: newDescription,
      editedAt: DateTime.now().toUtc(),
      editReason: reason,
      versionBefore: p.version,
      versionAfter: p.version + 1,
    );
    await _saveEditToDb(edit);

    print('[PROPOSAL] Edit detected: v${p.version} → v${p.version + 1}');
    p.title = newTitle;
    p.description = newDescription;
    p.version++;
    await _saveProposalToDb(p);

    final editResult = await _publishProposalToNostr(p, editReason: reason);
    final published = editResult.status == PublishResultStatus.accepted ||
        editResult.status == PublishResultStatus.partial;
    if (!published) {
      print('[PUBLISH-RESULT] Proposal edit queued for retry: ${editResult.status}');
    }

    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.PROPOSAL_EDITED,
      actorDid: p.creatorDid,
      actorPseudonym: p.creatorPseudonym,
      timestamp: DateTime.now().toUtc(),
      payload: {
        'oldTitle': edit.oldTitle,
        'newTitle': newTitle,
        'versionBefore': edit.versionBefore,
        'versionAfter': edit.versionAfter,
        'reason': reason,
      },
    ));

    await _notifyAllMembers(
      p.cellId,
      title: 'Antrag bearbeitet',
      body: '${p.creatorPseudonym} hat "${p.title}" bearbeitet',
      payload: 'proposal:${p.id}',
      excludeDid: p.creatorDid,
    );

    _notify();
  }

  /// Withdraws a proposal (DRAFT or DISCUSSION only, by creator).
  Future<void> withdrawProposal(String proposalId) async {
    print('[PROPOSAL] withdrawProposal: $proposalId');
    final p = _proposals[proposalId];
    if (p == null) throw StateError('Proposal not found: $proposalId');
    if (p.status != ProposalStatus.DRAFT &&
        p.status != ProposalStatus.DISCUSSION) {
      throw StateError(
          'Cannot withdraw at status ${p.status}');
    }

    final wasInDiscussion = p.discussionStartedAt != null;
    // Tombstone synchronously BEFORE DB write (race-condition guard).
    await _addTombstone(proposalId, reason: 'withdrawn');
    p.status = ProposalStatus.WITHDRAWN;
    p.withdrawnAt = DateTime.now().toUtc();
    await _saveProposalToDb(p);

    if (wasInDiscussion) {
      // Inform other devices via Nostr.
      await _publishProposalToNostr(p);
    }

    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.PROPOSAL_WITHDRAWN,
      actorDid: p.creatorDid,
      actorPseudonym: p.creatorPseudonym,
      timestamp: DateTime.now().toUtc(),
      payload: {'reason': 'creator_withdrawal'},
    ));

    _notify();
  }

  /// Publishes a Kind-31010 withdrawal event for [proposalId] without any
  /// status-transition checks. Used by the debug cleanup button to notify
  /// peer devices regardless of the current proposal status.
  Future<void> publishProposalWithdrawal(String proposalId) async {
    final p = _proposals[proposalId];
    if (p == null) return;
    await _addTombstone(proposalId);
    await _publishProposalToNostr(p);
  }

  /// Tombstones [proposalId] and deletes all its local data.
  ///
  /// Used by the debug cleanup button so that tombstones are set before the
  /// DB delete, preventing Nostr relay replays from re-inserting the proposal.
  Future<void> tombstoneAndDelete(String proposalId) async {
    // Synchronous in-memory tombstone FIRST.
    await _addTombstone(proposalId);
    // Remove from cache immediately → live UI update.
    _proposals.remove(proposalId);
    _votes.remove(proposalId);
    _notify();
    // Async DB cleanup (safe even if already deleted).
    await _deleteProposalKeepingAudit(proposalId);
    print('[PROPOSAL] tombstoneAndDelete: $proposalId');
  }

  /// DISCUSSION → VOTING. Checks proposalWaitDays constraint.
  Future<void> startVoting(String proposalId) async {
    print('[PROPOSAL] startVoting: $proposalId');
    final p = _proposals[proposalId];
    if (p == null) throw StateError('Proposal not found: $proposalId');
    if (p.status != ProposalStatus.DISCUSSION) {
      throw StateError('Only DISCUSSION can start voting');
    }

    // Check proposalWaitDays.
    final cell = CellService.instance.myCells
        .where((c) => c.id == p.cellId)
        .firstOrNull;
    if (cell != null && cell.proposalWaitDays > 0) {
      final discussionStart =
          p.discussionStartedAt ?? p.createdAt;
      final minStart =
          discussionStart.add(Duration(days: cell.proposalWaitDays));
      if (DateTime.now().toUtc().isBefore(minStart)) {
        throw StateError(
            'Discussion period not yet ended '
            '(${cell.proposalWaitDays} days required)');
      }
    }

    p.status = ProposalStatus.VOTING;
    p.votingStartedAt = DateTime.now().toUtc();
    p.votingEndsAt = DateTime.now().toUtc().add(const Duration(days: 7));
    await _saveProposalToDb(p);

    print('[PROPOSAL] startVoting: $proposalId, ends ${p.votingEndsAt}');

    final votingResult = await _publishProposalToNostr(p);
    final published = votingResult.status == PublishResultStatus.accepted ||
        votingResult.status == PublishResultStatus.partial;
    if (!published) {
      print('[PUBLISH-RESULT] Voting start queued for retry: ${votingResult.status}');
    }

    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.PROPOSAL_STATUS_CHANGED,
      actorDid: p.creatorDid,
      actorPseudonym: p.creatorPseudonym,
      timestamp: DateTime.now().toUtc(),
      payload: {
        'from': 'DISCUSSION',
        'to': 'VOTING',
        'votingEndsAt': p.votingEndsAt!.millisecondsSinceEpoch,
      },
    ));

    await _notifyAllMembers(
      p.cellId,
      title: '🗳️ Abstimmung gestartet',
      body: p.title,
      payload: 'proposal:${p.id}',
    );

    _notify();
  }

  /// VOTING → VOTING_ENDED (grace period start, called by scheduler).
  Future<void> processGracePeriodStart(String proposalId) async {
    print('[PROPOSAL] Grace period started: $proposalId');
    final p = _proposals[proposalId];
    if (p == null) return;
    if (p.status != ProposalStatus.VOTING) return;

    p.status = ProposalStatus.VOTING_ENDED;
    await _saveProposalToDb(p);

    print('[PROPOSAL] Status: VOTING → VOTING_ENDED for $proposalId');
    await _publishProposalToNostr(p);

    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.PROPOSAL_STATUS_CHANGED,
      actorDid: p.creatorDid,
      actorPseudonym: p.creatorPseudonym,
      timestamp: DateTime.now().toUtc(),
      payload: {'from': 'VOTING', 'to': 'VOTING_ENDED'},
    ));

    _notify();
  }

  /// VOTING_ENDED → DECIDED. Counts votes, checks quorum, creates DecisionRecord.
  Future<void> finalizeProposal(String proposalId) async {
    print('[PROPOSAL] Finalizing: $proposalId');
    final p = _proposals[proposalId];
    if (p == null) return;
    if (p.status != ProposalStatus.VOTING_ENDED) return;

    // ── Phase 4.6: Idempotenz-Guard ─────────────────────────────────────────
    // Schützt den Race-Fall: Status ist noch VOTING_ENDED, aber ein
    // DecisionRecord existiert bereits. Das passiert z.B.:
    //  - ein anderes Gerät hat finalisiert und wir haben den Record per Nostr
    //    empfangen, aber unser Status-Update hängt
    //  - Scheduler-5min-Tick und App-Resume feuern fast gleichzeitig
    //  - vorheriger Tally-Lauf hat den Record persistiert aber den lokalen
    //    Status nicht aktualisiert (Crash etc.)
    //
    // Wenn Status == DECIDED ist, fängt das schon der vorherige Status-Check
    // ab — dieser Guard greift nur bei VOTING_ENDED.
    final existing = await _getDecisionRecordByProposal(proposalId);
    if (existing != null) {
      print('[TALLY-SKIP] $proposalId reason=decision already exists');
      // Defensive Status-Heilung. Bestehender DecisionRecord wird NICHT
      // verändert. Status war garantiert VOTING_ENDED (sonst wäre Code hier
      // nicht angekommen), also kein if-Wrap nötig.
      print('[TALLY-SKIP] $proposalId healing local status '
          'VOTING_ENDED → DECIDED');
      p.status = ProposalStatus.DECIDED;
      p.decidedAt = existing.decidedAt;
      p.resultSummary = existing.result;
      p.resultParticipation = existing.participation;
      // yes/no nur bei YES_NO_ABSTAIN aus DecisionRecord spiegeln
      // (analog Phase-4.5c-Empfangs-Logik).
      if (p.votingMode == VotingMode.YES_NO_ABSTAIN) {
        p.resultYes = existing.yesVotes;
        p.resultNo = existing.noVotes;
      }
      p.resultAbstain = existing.abstainVotes;
      await _saveProposalToDb(p);
      return;
    }
    // ── Ende Idempotenz-Guard ────────────────────────────────────────────────

    // ── Phase 4.3: Modus-Verzweigung ──────────────────────────
    if (p.votingMode == VotingMode.SINGLE_CHOICE) {
      await _finalizeSingleChoice(p);
      return;
    }
    if (p.votingMode == VotingMode.CANDIDATE_CHOICE) {
      await _finalizeCandidateChoice(p);
      return;
    }
    // YES_NO_ABSTAIN fällt durch zur bestehenden Logik unten.
    // ── Ende Modus-Verzweigung ────────────────────────────────

    // Load votes directly from DB – the in-memory cache may be incomplete if
    // votes arrived on other devices while this device was offline.
    final voteRows = await PodDatabase.instance.listVotes(proposalId);
    List<Vote> votes = voteRows.map(Vote.fromMap).toList();
    print('[PROPOSAL] finalizeProposal: ${votes.length} votes loaded from DB');
    // Sync the cache with direct votes (synthetic delegated votes are RAM-only).
    _votes[proposalId] = votes;

    // ── Phase 4.2b: eligibleVoters-Snapshot ───────────────────
    final Set<String> eligibleVoterSet;
    final int eligibleCount;
    if (p.eligibleVoters != null) {
      eligibleVoterSet = p.eligibleVoters!.toSet();
      eligibleCount = p.eligibleVoters!.length;
    } else {
      // Fallback: no snapshot present (legacy data before v22).
      eligibleVoterSet = await _loadEligibleVoterSet(p.cellId);
      eligibleCount = eligibleVoterSet.length;
      print('[TALLY-FALLBACK] Proposal $proposalId has no '
          'eligibleVoters snapshot, using current cell_members count: '
          '$eligibleCount');
    }
    // ──────────────────────────────────────────────────────────

    // ── Phase G2.1.3: Delegation-Aggregation ─────────────────
    votes = await _aggregateVotesWithDelegations(
      directVotes: votes,
      proposalId: proposalId,
      cellId: p.cellId,
      eligibleVoters: eligibleVoterSet,
    );
    // ── Ende Phase G2.1.3 ────────────────────────────────────

    final yes = votes.where((v) => v.choice == VoteChoice.YES).length;
    final no = votes.where((v) => v.choice == VoteChoice.NO).length;
    final abstain = votes.where((v) => v.choice == VoteChoice.ABSTAIN).length;
    print('[PROPOSAL] Counted: Y=$yes N=$no A=$abstain');

    final participation = eligibleCount > 0
        ? (yes + no + abstain) / eligibleCount
        : 0.0;
    print('[PROPOSAL] Participation: ${(participation * 100).toStringAsFixed(1)}% '
        '(${yes + no + abstain} of $eligibleCount eligible)');

    String result;
    String? resultReason;
    final participationCount = yes + no + abstain;

    if (participationCount == 0) {
      result = 'invalid';
      resultReason = ResultReason.noValidVotes;
    } else if (participation < p.quorumRequired) {
      result = 'invalid';
      resultReason = ResultReason.quorumNotMet;
    } else if (yes + no == 0) {
      // Quorum reached, but all votes are ABSTAIN
      result = 'invalid';
      resultReason = ResultReason.allAbstain;
    } else if (yes > no) {
      result = 'approved';
      resultReason = null;
    } else {
      // yes <= no → REJECTED (tie counts as status quo)
      result = 'rejected';
      resultReason = null;
    }

    print('[TALLY-RESULT] $proposalId result=$result '
        'reason=${resultReason ?? "-"}');
    print('[PROPOSAL] Quorum: $yes+$no+$abstain/$eligibleCount = '
        '${(participation * 100).toStringAsFixed(1)}%');
    print('[PROPOSAL] Result: $result (J:$yes N:$no E:$abstain)');

    p.status = ProposalStatus.DECIDED;
    p.decidedAt = DateTime.now().toUtc();
    p.resultSummary = result;
    p.resultYes = yes;
    p.resultNo = no;
    p.resultAbstain = abstain;
    p.resultParticipation = participation;
    await _saveProposalToDb(p);

    print('[PROPOSAL] Status: VOTING_ENDED → DECIDED for $proposalId');
    await _publishProposalToNostr(p);

    // 4.5a: Bau und Persistierung über zentralen Helper.
    // Der lokale DecisionRecord ist semantisch identisch zum
    // alten Pfad (gleiche hashInput-Felder).
    final record = await _buildAndPersistDecisionRecord(
      proposal: p,
      result: result,
      resultReason: resultReason,
      yesVotes: yes,
      noVotes: no,
      abstainVotes: abstain,
      participation: participation,
      eligibleVotersCount: eligibleCount,
      sortedVotes: votes,
      optionResultsJson: null,
      tieOptionIdsJson: null,
    );

    final recordContent = _buildRecordContent(
      proposal: p,
      record: record,
      sortedVotes: votes,
    );
    await _publishAndQueueRetry(
      proposal: p,
      record: record,
      recordContent: recordContent,
    );

    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.RESULT_CALCULATED,
      actorDid: p.creatorDid,
      actorPseudonym: p.creatorPseudonym,
      timestamp: DateTime.now().toUtc(),
      payload: {
        'result': result,
        'yes': yes,
        'no': no,
        'abstain': abstain,
        'participation': participation,
        'eligibleCount': eligibleCount,
      },
    ));

    final resultLabel = result == 'approved'
        ? 'Angenommen'
        : result == 'rejected'
            ? 'Abgelehnt'
            : 'Ungültig (Quorum)';
    await _notifyAllMembers(
      p.cellId,
      title: 'Abstimmung beendet',
      body: '${p.title}: $resultLabel',
      payload: 'proposal:${p.id}',
    );

    _notify();
  }

  /// SINGLE_CHOICE tally: loads options, aggregates per-option votes,
  /// determines result, persists DecisionRecord locally. No Nostr publish
  /// in Phase 4.3 — deferred to Phase 4.5.
  Future<void> _finalizeSingleChoice(Proposal p) async {
    print('[TALLY-START] ${p.id} mode=SINGLE_CHOICE');

    // 1) Votes + Options laden
    final voteRows = await PodDatabase.instance.listVotes(p.id);
    List<Vote> votes = voteRows.map(Vote.fromMap).toList();
    final optionRows =
        await PodDatabase.instance.listProposalOptions(p.id);
    final options = optionRows.map(ProposalOption.fromMap).toList();
    print('[TALLY-INPUT] ${p.id} votes=${votes.length} '
        'options=${options.length}');

    // Cache sync — analog YES_NO_ABSTAIN-Pfad (direct votes only)
    _votes[p.id] = votes;

    // 2a) eligibleVoters-Snapshot — needed before delegation aggregation
    final Set<String> eligibleVoterSet;
    final int eligibleCount;
    if (p.eligibleVoters != null) {
      eligibleVoterSet = p.eligibleVoters!.toSet();
      eligibleCount = p.eligibleVoters!.length;
    } else {
      eligibleVoterSet = await _loadEligibleVoterSet(p.cellId);
      eligibleCount = eligibleVoterSet.length;
      print('[TALLY-FALLBACK] ${p.id} eligibleVoters snapshot '
          'missing, using current cell_members: $eligibleCount');
    }

    // ── Phase G2.1.3: Delegation-Aggregation ─────────────────
    votes = await _aggregateVotesWithDelegations(
      directVotes: votes,
      proposalId: p.id,
      cellId: p.cellId,
      eligibleVoters: eligibleVoterSet,
    );
    // ── Ende Phase G2.1.3 ────────────────────────────────────

    // 2b) Deterministisch sortieren (über augmented votes)
    final sortedVotes = sortVotesDeterministic(votes);
    final sortedOptions = sortOptionsDeterministic(options);

    // 4) Aggregation
    final optionCounts = <String, int>{};
    for (final opt in sortedOptions) {
      optionCounts[opt.optionId] = 0;
    }
    int abstainCount = 0;
    int invalidVoteCount = 0;

    for (final v in sortedVotes) {
      if (v.selectedOptionId != null) {
        if (optionCounts.containsKey(v.selectedOptionId)) {
          optionCounts[v.selectedOptionId!] =
              optionCounts[v.selectedOptionId!]! + 1;
        } else {
          invalidVoteCount++;
          print('[TALLY-WARN] ${p.id} vote ${v.voteId} references '
              'unknown optionId=${v.selectedOptionId}');
        }
      } else if (v.choice == VoteChoice.ABSTAIN) {
        abstainCount++;
      } else {
        invalidVoteCount++;
        print('[TALLY-WARN] ${p.id} vote ${v.voteId} has no '
            'selectedOptionId in SINGLE_CHOICE mode (choice='
            '${v.choice.name}), ignoring');
      }
    }

    final optionVoteSum =
        optionCounts.values.fold<int>(0, (a, b) => a + b);
    final participationCount = optionVoteSum + abstainCount;
    final participation = eligibleCount > 0
        ? participationCount / eligibleCount
        : 0.0;

    print('[TALLY-AGGREGATE] ${p.id} optionVotes=$optionVoteSum '
        'abstain=$abstainCount invalid=$invalidVoteCount '
        'eligible=$eligibleCount');
    print('[TALLY-QUORUM] ${p.id} participation='
        '${(participation * 100).toStringAsFixed(1)}% '
        'required=${(p.quorumRequired * 100).toStringAsFixed(1)}%');

    // 5) Result-Bestimmung
    String result;
    String? resultReason;
    String? tieOptionIdsJson;

    if (participationCount == 0) {
      result = 'invalid';
      resultReason = ResultReason.noValidVotes;
    } else if (participation < p.quorumRequired) {
      result = 'invalid';
      resultReason = ResultReason.quorumNotMet;
    } else if (optionVoteSum == 0) {
      result = 'invalid';
      resultReason = ResultReason.allAbstain;
    } else {
      final maxCount = optionCounts.values
          .fold<int>(0, (a, b) => b > a ? b : a);
      final winners = sortedOptions
          .where((o) => optionCounts[o.optionId] == maxCount)
          .map((o) => o.optionId)
          .toList();

      if (winners.length == 1) {
        result = 'approved';
        resultReason = null;
      } else {
        result = 'invalid';
        resultReason = ResultReason.tieRequiresRunoff;
        tieOptionIdsJson = canonicalJsonEncode(winners);
      }
    }

    // 6) optionResultsJson — IMMER bei vorhandenen Optionen
    String? optionResultsJson;
    if (sortedOptions.isNotEmpty) {
      final canonicalCounts = <String, dynamic>{};
      for (final opt in sortedOptions) {
        canonicalCounts[opt.optionId] = optionCounts[opt.optionId] ?? 0;
      }
      optionResultsJson = canonicalJsonEncode(canonicalCounts);
    }

    print('[TALLY-RESULT] ${p.id} result=$result '
        'reason=${resultReason ?? "-"}');

    // 7) Proposal-Status-Update + DB
    p.status = ProposalStatus.DECIDED;
    p.decidedAt = DateTime.now().toUtc();
    p.resultSummary = result;
    p.resultYes = 0;
    p.resultNo = 0;
    p.resultAbstain = abstainCount;
    p.resultParticipation = participation;
    await _saveProposalToDb(p);
    await _publishProposalToNostr(p);

    // 8) DecisionRecord lokal bauen
    // 4.5a: Bau und Persistierung über zentralen Helper.
    final record = await _buildAndPersistDecisionRecord(
      proposal: p,
      result: result,
      resultReason: resultReason,
      yesVotes: 0,
      noVotes: 0,
      abstainVotes: abstainCount,
      participation: participation,
      eligibleVotersCount: eligibleCount,
      sortedVotes: sortedVotes,
      optionResultsJson: optionResultsJson,
      tieOptionIdsJson: tieOptionIdsJson,
    );

    // Phase 4.8: auto-create runoff proposal on TIE_REQUIRES_RUNOFF.
    // Sender-only: only the device that ran _finalizeSingleChoice reaches
    // this code path. Other devices receive the runoff via Nostr pipeline.
    if (record.resultReason == ResultReason.tieRequiresRunoff) {
      await _createRunoffProposal(
        originalProposal: p,
        decisionRecord: record,
      );
    }

    // 9) Audit-Eintrag
    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.RESULT_CALCULATED,
      actorDid: p.creatorDid,
      actorPseudonym: p.creatorPseudonym,
      timestamp: DateTime.now().toUtc(),
      payload: {
        'result': result,
        'resultReason': resultReason,
        'votingMode': 'SINGLE_CHOICE',
        'optionVotesSum': optionVoteSum,
        'abstain': abstainCount,
        'invalid': invalidVoteCount,
        'eligibleCount': eligibleCount,
        'participation': participation,
      },
    ));

    // 10) Notification
    final resultLabel = result == 'approved'
        ? 'Option gewählt'
        : result == 'invalid'
            ? 'Ungültig'
            : 'Abgelehnt';
    await _notifyAllMembers(
      p.cellId,
      title: 'Abstimmung beendet',
      body: '${p.title}: $resultLabel',
      payload: 'proposal:${p.id}',
    );

    // 11) Publish + Retry (aktiviert in Phase 4.5b)
    final recordContent = _buildRecordContent(
      proposal: p,
      record: record,
      sortedVotes: sortedVotes,
    );
    await _publishAndQueueRetry(
      proposal: p,
      record: record,
      recordContent: recordContent,
    );

    _notify();
  }

  /// CANDIDATE_CHOICE tally: loads options with ACTIVE/WITHDRAWN status,
  /// aggregates per-option votes, determines result with candidate-specific
  /// result reasons, persists DecisionRecord locally. No Nostr publish of the
  /// DecisionRecord in Phase 4.4 — deferred to Phase 4.5.
  Future<void> _finalizeCandidateChoice(Proposal p) async {
    print('[TALLY-START] ${p.id} mode=CANDIDATE_CHOICE');

    // 1) Votes + Options laden
    final voteRows = await PodDatabase.instance.listVotes(p.id);
    final votes = voteRows.map(Vote.fromMap).toList();
    final optionRows =
        await PodDatabase.instance.listProposalOptions(p.id);
    final options = optionRows.map(ProposalOption.fromMap).toList();
    print('[TALLY-INPUT] ${p.id} votes=${votes.length} '
        'options=${options.length}');

    _votes[p.id] = votes;

    // 2) Sortieren
    final sortedVotes = sortVotesDeterministic(votes);
    final sortedOptions = sortOptionsDeterministic(options);

    // 3) eligibleVoters-Snapshot
    final int eligibleCount;
    if (p.eligibleVoters != null) {
      eligibleCount = p.eligibleVoters!.length;
    } else {
      eligibleCount =
          await CellService.instance.getMemberCount(p.cellId);
      print('[TALLY-FALLBACK] ${p.id} eligibleVoters snapshot '
          'missing, using current cell_members: $eligibleCount');
    }

    // 4) Aggregation — analog SINGLE_CHOICE
    final optionCounts = <String, int>{};
    for (final opt in sortedOptions) {
      optionCounts[opt.optionId] = 0;
    }
    int abstainCount = 0;
    int invalidVoteCount = 0;

    for (final v in sortedVotes) {
      if (v.selectedOptionId != null) {
        if (optionCounts.containsKey(v.selectedOptionId)) {
          optionCounts[v.selectedOptionId!] =
              optionCounts[v.selectedOptionId!]! + 1;
        } else {
          invalidVoteCount++;
          print('[TALLY-WARN] ${p.id} vote ${v.voteId} unknown '
              'optionId=${v.selectedOptionId}');
        }
      } else if (v.choice == VoteChoice.ABSTAIN) {
        abstainCount++;
      } else {
        invalidVoteCount++;
        print('[TALLY-WARN] ${p.id} vote ${v.voteId} no '
            'selectedOptionId in CANDIDATE_CHOICE (choice='
            '${v.choice.name})');
      }
    }

    final optionVoteSum =
        optionCounts.values.fold<int>(0, (a, b) => a + b);
    final participationCount = optionVoteSum + abstainCount;
    final participation = eligibleCount > 0
        ? participationCount / eligibleCount
        : 0.0;

    print('[TALLY-AGGREGATE] ${p.id} optionVotes=$optionVoteSum '
        'abstain=$abstainCount invalid=$invalidVoteCount '
        'eligible=$eligibleCount');
    print('[TALLY-QUORUM] ${p.id} participation='
        '${(participation * 100).toStringAsFixed(1)}% '
        'required=${(p.quorumRequired * 100).toStringAsFixed(1)}%');

    // 5) Result-Bestimmung — Reihenfolge VERBINDLICH:
    //    NO_VALID_VOTES → QUORUM_NOT_MET → ALL_ABSTAIN →
    //    ALL_CANDIDATES_WITHDRAWN → WINNER_WITHDRAWN →
    //    TIE_REQUIRES_RUNOFF → approved
    String result;
    String? resultReason;
    String? tieOptionIdsJson;

    if (participationCount == 0) {
      result = 'invalid';
      resultReason = ResultReason.noValidVotes;
    } else if (participation < p.quorumRequired) {
      result = 'invalid';
      resultReason = ResultReason.quorumNotMet;
    } else if (optionVoteSum == 0) {
      result = 'invalid';
      resultReason = ResultReason.allAbstain;
    } else {
      // Aktive vs. WITHDRAWN-Kandidaten unterscheiden
      final activeOptions = sortedOptions
          .where((o) => o.status == OptionStatus.ACTIVE)
          .toList();

      if (activeOptions.isEmpty) {
        // Schritt 4: ALL_CANDIDATES_WITHDRAWN
        result = 'invalid';
        resultReason = ResultReason.allCandidatesWithdrawn;
      } else {
        // Schritt 5: WINNER_WITHDRAWN-Check über ALLE Optionen
        final maxAllCount = optionCounts.values
            .fold<int>(0, (a, b) => b > a ? b : a);
        final allWinners = sortedOptions
            .where((o) => optionCounts[o.optionId] == maxAllCount)
            .map((o) => o.optionId)
            .toList();

        final activeIds =
            activeOptions.map((o) => o.optionId).toSet();
        final hasWithdrawnWinner =
            allWinners.any((id) => !activeIds.contains(id));

        if (hasWithdrawnWinner) {
          result = 'invalid';
          resultReason = ResultReason.winnerWithdrawn;
          tieOptionIdsJson = canonicalJsonEncode(allWinners);
          print('[TALLY-RESULT] ${p.id} WINNER_WITHDRAWN: '
              'allWinners=$allWinners');
        } else {
          // Schritt 6 + 7: TIE_REQUIRES_RUNOFF unter ACTIVE oder approved
          final activeCounts = <String, int>{};
          for (final opt in activeOptions) {
            activeCounts[opt.optionId] =
                optionCounts[opt.optionId] ?? 0;
          }
          final maxActiveCount = activeCounts.values
              .fold<int>(0, (a, b) => b > a ? b : a);
          final activeWinners = activeOptions
              .where(
                  (o) => activeCounts[o.optionId] == maxActiveCount)
              .map((o) => o.optionId)
              .toList();

          if (activeWinners.length == 1) {
            result = 'approved';
            resultReason = null;
          } else {
            result = 'invalid';
            resultReason = ResultReason.tieRequiresRunoff;
            tieOptionIdsJson = canonicalJsonEncode(activeWinners);
          }
        }
      }
    }

    // 6) optionResultsJson — IMMER bei vorhandenen Optionen (inkl. WITHDRAWN)
    String? optionResultsJson;
    if (sortedOptions.isNotEmpty) {
      final canonicalCounts = <String, dynamic>{};
      for (final opt in sortedOptions) {
        canonicalCounts[opt.optionId] =
            optionCounts[opt.optionId] ?? 0;
      }
      optionResultsJson = canonicalJsonEncode(canonicalCounts);
    }

    print('[TALLY-RESULT] ${p.id} result=$result '
        'reason=${resultReason ?? "-"}');

    // 7) Proposal-Status + DB + Proposal-Publish
    //    (analog 4.3 — _publishProposalToNostr ist erlaubt und gewollt)
    p.status = ProposalStatus.DECIDED;
    p.decidedAt = DateTime.now().toUtc();
    p.resultSummary = result;
    p.resultYes = 0;
    p.resultNo = 0;
    p.resultAbstain = abstainCount;
    p.resultParticipation = participation;
    await _saveProposalToDb(p);
    await _publishProposalToNostr(p);

    // 8) DecisionRecord lokal
    // 4.5a: Bau und Persistierung über zentralen Helper.
    final record = await _buildAndPersistDecisionRecord(
      proposal: p,
      result: result,
      resultReason: resultReason,
      yesVotes: 0,
      noVotes: 0,
      abstainVotes: abstainCount,
      participation: participation,
      eligibleVotersCount: eligibleCount,
      sortedVotes: sortedVotes,
      optionResultsJson: optionResultsJson,
      tieOptionIdsJson: tieOptionIdsJson,
    );

    // Phase 4.8: auto-create runoff proposal on TIE_REQUIRES_RUNOFF.
    // Sender-only: only the device that ran _finalizeCandidateChoice reaches
    // this code path. Other devices receive the runoff via Nostr pipeline.
    if (record.resultReason == ResultReason.tieRequiresRunoff) {
      await _createRunoffProposal(
        originalProposal: p,
        decisionRecord: record,
      );
    }

    // 9) Audit
    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.RESULT_CALCULATED,
      actorDid: p.creatorDid,
      actorPseudonym: p.creatorPseudonym,
      timestamp: DateTime.now().toUtc(),
      payload: {
        'result': result,
        'resultReason': resultReason,
        'votingMode': 'CANDIDATE_CHOICE',
        'optionVotesSum': optionVoteSum,
        'abstain': abstainCount,
        'invalid': invalidVoteCount,
        'eligibleCount': eligibleCount,
        'participation': participation,
        'activeCandidatesCount': sortedOptions
            .where((o) => o.status == OptionStatus.ACTIVE)
            .length,
        'withdrawnCandidatesCount': sortedOptions
            .where((o) => o.status == OptionStatus.WITHDRAWN)
            .length,
      },
    ));

    // 10) Notification
    final resultLabel = result == 'approved'
        ? 'Kandidat:in gewählt'
        : result == 'invalid'
            ? 'Ungültig'
            : 'Abgelehnt';
    await _notifyAllMembers(
      p.cellId,
      title: 'Wahl beendet',
      body: '${p.title}: $resultLabel',
      payload: 'proposal:${p.id}',
    );

    // 11) Publish + Retry (aktiviert in Phase 4.5b)
    final recordContent = _buildRecordContent(
      proposal: p,
      record: record,
      sortedVotes: sortedVotes,
    );
    await _publishAndQueueRetry(
      proposal: p,
      record: record,
      recordContent: recordContent,
    );

    _notify();
  }

  /// Builds the DecisionRecord canonical hash input, computes
  /// contentHash via tally_helpers, constructs the DecisionRecord,
  /// and persists it locally via _saveDecisionRecordToDb.
  ///
  /// Returns the persisted record. Callers may use it for logging
  /// or pass it to publish helpers.
  ///
  /// Phase 4.5a: extracted from the three _finalize* methods.
  /// No behavioral change — produces field-identical
  /// DecisionRecord objects to the prior inline code.
  Future<DecisionRecord> _buildAndPersistDecisionRecord({
    required Proposal proposal,
    required String result,
    required String? resultReason,
    required int yesVotes,
    required int noVotes,
    required int abstainVotes,
    required double participation,
    required int eligibleVotersCount,
    required List<Vote> sortedVotes,
    required String? optionResultsJson,
    required String? tieOptionIdsJson,
  }) async {
    final previousHash =
        await _getLastDecisionHashForCell(proposal.cellId);

    final hashInput = <String, dynamic>{
      'proposalId': proposal.id,
      'cellId': proposal.cellId,
      'votingMode': proposal.votingMode.name,
      'result': result,
      'resultReason': resultReason,
      'resultRelation': null,
      'yesVotes': yesVotes,
      'noVotes': noVotes,
      'abstainVotes': abstainVotes,
      'participation': participation.toStringAsFixed(4),
      'eligibleVotersCount': eligibleVotersCount,
      'decidedAt': proposal.decidedAt!.toIso8601String(),
      'previousProposalId': null,
      'previousDecisionHash': previousHash,
      'finalTitle': proposal.title,
      'finalDescription': proposal.description,
      'optionResultsJson': optionResultsJson,
      'tieOptionIdsJson': tieOptionIdsJson,
    };
    final contentHash = computeContentHash(hashInput);
    print('[TALLY-PERSIST] ${proposal.id} contentHash=$contentHash '
        'previousHash=$previousHash');

    final record = DecisionRecord(
      recordId: DecisionRecord.generateId(),
      proposalId: proposal.id,
      cellId: proposal.cellId,
      finalTitle: proposal.title,
      finalDescription: proposal.description,
      result: result,
      yesVotes: yesVotes,
      noVotes: noVotes,
      abstainVotes: abstainVotes,
      participation: participation,
      decidedAt: proposal.decidedAt!,
      allVotes: sortedVotes,
      contentHash: contentHash,
      previousDecisionHash: previousHash,
      nostrEventId: '',
      resultReason: resultReason,
      resultRelation: null,
      previousProposalId: null,
      optionResultsJson: optionResultsJson,
      tieOptionIdsJson: tieOptionIdsJson,
    );
    await _saveDecisionRecordToDb(record);
    print('[PROPOSAL] DecisionRecord saved locally: '
        '${record.recordId}');

    return record;
  }

  /// Builds the canonical recordContent payload for Nostr Kind-31013
  /// publish. Used by all three tally modes since Phase 4.5b.
  ///
  /// Keys are alphabetically sorted via SplayTreeMap to ensure
  /// deterministic JSON output. New v1.3 fields (votingMode,
  /// resultReason, resultRelation, previousProposalId,
  /// optionResultsJson, tieOptionIdsJson) are always present —
  /// null for fields that don't apply to a given mode.
  ///
  /// Backwards compatible with pre-4.5b receivers: old fields
  /// (yesVotes/noVotes/abstainVotes/participation/finalTitle/
  /// finalDescription/decidedAt/allVotes/proposalId/result) keep
  /// identical names, types, and meanings. The v1.3 additions
  /// are extra keys older receivers will harmlessly ignore.
  Map<String, dynamic> _buildRecordContent({
    required Proposal proposal,
    required DecisionRecord record,
    required List<Vote> sortedVotes,
  }) {
    return SplayTreeMap<String, dynamic>.from({
      'proposalId': proposal.id,
      'cellId': proposal.cellId,
      'votingMode': proposal.votingMode.name,
      'finalTitle': proposal.title,
      'finalDescription': proposal.description,
      'result': record.result,
      'resultReason': record.resultReason,
      'resultRelation': record.resultRelation,
      'previousProposalId': record.previousProposalId,
      'yesVotes': record.yesVotes,
      'noVotes': record.noVotes,
      'abstainVotes': record.abstainVotes,
      'participation': record.participation,
      'decidedAt': record.decidedAt.millisecondsSinceEpoch,
      'optionResultsJson': record.optionResultsJson,
      'tieOptionIdsJson': record.tieOptionIdsJson,
      'allVotes': sortedVotes
          .map((v) => {
                'voterPseudonym': v.voterPseudonym,
                'choice': v.choice.name,
                'selectedOptionId': v.selectedOptionId,
                'reasoning': v.reasoning,
                'createdAt': v.createdAt.millisecondsSinceEpoch,
              })
          .toList(),
    });
  }

  /// Publishes a DecisionRecord via the Nostr transport and logs the outcome.
  /// The PublishResult is already tracked by the transport layer for automatic
  /// retry via PublishResultDao / _processRetryQueue.
  /// Used by all three tally modes since Phase 4.5b.
  Future<void> _publishAndQueueRetry({
    required Proposal proposal,
    required DecisionRecord record,
    required Map<String, dynamic> recordContent,
  }) async {
    final result = await _publishDecisionRecord(
      proposalId: proposal.id,
      cellId: proposal.cellId,
      recordContent: recordContent,
      result: record.result,
      contentHash: record.contentHash,
      previousDecisionHash: record.previousDecisionHash,
    );
    // Phase 4.7d: acceptedRelayCount > 0 means the event is in the network.
    // PARTIAL (some relays accepted) is success — no retry needed.
    final totalRelays =
        result.acceptedRelayCount + result.failedRelayCount;
    if (result.acceptedRelayCount == 0) {
      final desc = totalRelays > 0 ? '0/$totalRelays accepted' : 'no relays';
      print('[PROPOSAL] Decision record publish FAILED: $desc, queuing retry');
    } else if (result.acceptedRelayCount < totalRelays) {
      print('[PROPOSAL] Decision record publish PARTIAL: '
          '${result.acceptedRelayCount}/$totalRelays relays accepted');
    } else {
      print('[PROPOSAL] Decision record publish FULL: '
          '${result.acceptedRelayCount}/$totalRelays relays accepted');
    }
  }

  /// DECIDED → ARCHIVED (manual or auto after 30 days).
  Future<void> archiveProposal(String proposalId) async {
    final p = _proposals[proposalId];
    if (p == null) return;
    if (p.status != ProposalStatus.DECIDED) return;

    p.status = ProposalStatus.ARCHIVED;
    p.archivedAt = DateTime.now().toUtc();
    await _saveProposalToDb(p);

    await _publishProposalToNostr(p);

    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.PROPOSAL_ARCHIVED,
      actorDid: p.creatorDid,
      actorPseudonym: p.creatorPseudonym,
      timestamp: DateTime.now().toUtc(),
      payload: {},
    ));

    _notify();
  }

  // ── Voting ─────────────────────────────────────────────────────────────────

  /// Cast or change a vote on a VOTING proposal.
  ///
  /// If the caller already voted, the old vote is replaced.
  Future<void> castVote(String proposalId, VoteChoice choice,
      {String? reasoning, String? selectedOptionId}) async {
    print('[VOTE] castVote: $choice for $proposalId '
        'optionId=${selectedOptionId ?? "-"}');
    final p = _proposals[proposalId];
    if (p == null) throw StateError('Proposal not found');
    if (p.status != ProposalStatus.VOTING) {
      throw StateError('Voting not active (status: ${p.status})');
    }

    final myDid = IdentityService.instance.currentIdentity?.did;
    if (myDid == null) throw StateError('No identity');

    final isMember = CellService.instance.isMember(p.cellId);
    if (!isMember) throw StateError('Not a member of this cell');

    // ── Phase 4.7b: Modus-Validierung ───────────────────────────────────────
    // Stellt sicher dass die (choice, selectedOptionId)-Kombination zur
    // votingMode des Proposals passt. Verstöße werden als StateError geworfen
    // bevor ein DB-Write oder Publish stattfindet.
    switch (p.votingMode) {
      case VotingMode.YES_NO_ABSTAIN:
        if (selectedOptionId != null) {
          throw StateError(
              'YES_NO_ABSTAIN proposal does not accept '
              'selectedOptionId (got: $selectedOptionId)');
        }
        // choice YES/NO/ABSTAIN: alle erlaubt
        break;

      case VotingMode.SINGLE_CHOICE:
        if (choice != VoteChoice.ABSTAIN) {
          throw StateError(
              'SINGLE_CHOICE proposal requires choice=ABSTAIN '
              '(got: ${choice.name}). Use selectedOptionId to '
              'pick an option, or selectedOptionId=null for abstention.');
        }
        if (selectedOptionId != null) {
          final options =
              await PodDatabase.instance.listProposalOptions(proposalId);
          final found = options.any((m) => m['option_id'] == selectedOptionId);
          if (!found) {
            throw StateError(
                'SINGLE_CHOICE selectedOptionId not found: $selectedOptionId');
          }
        }
        break;

      case VotingMode.CANDIDATE_CHOICE:
        if (choice != VoteChoice.ABSTAIN) {
          throw StateError(
              'CANDIDATE_CHOICE proposal requires '
              'choice=ABSTAIN (got: ${choice.name}). Use '
              'selectedOptionId to pick a candidate, or '
              'selectedOptionId=null for abstention.');
        }
        if (selectedOptionId != null) {
          final options =
              await PodDatabase.instance.listProposalOptions(proposalId);
          final candidate = options.firstWhere(
            (m) => m['option_id'] == selectedOptionId,
            orElse: () => <String, dynamic>{},
          );
          if (candidate.isEmpty) {
            throw StateError(
                'CANDIDATE_CHOICE selectedOptionId not found: $selectedOptionId');
          }
          final statusStr = candidate['status'] as String?;
          if (statusStr != 'ACTIVE') {
            throw StateError(
                'CANDIDATE_CHOICE candidate is not ACTIVE '
                '(status=$statusStr): $selectedOptionId');
          }
        }
        break;
    }
    // ── Ende Phase 4.7b castVote-Validierung ────────────────────────────────

    // ── Phase G2.1.1b: Auto-revoke active delegation when the delegator
    //    casts a direct vote (E5 first direction + D7 Status REVOKED). ────────
    final activeDelegationsForVoter = await PodDatabase.instance
        .listActiveDelegationsForProposal(proposalId);
    final ownActiveDelegation = activeDelegationsForVoter
        .where((m) => m['delegator_did'] == myDid)
        .toList();
    if (ownActiveDelegation.isNotEmpty) {
      final old = Delegation.fromMap(ownActiveDelegation.first);
      final autoRevoked = old.copyWith(
        status: DelegationStatus.REVOKED,
        updatedAt: DateTime.now().toUtc(),
      );
      await PodDatabase.instance.upsertDelegation(autoRevoked.toMap());
      await addAuditEntry(AuditLogEntry(
        entryId: AuditLogEntry.generateId(),
        proposalId: proposalId,
        cellId: old.cellId,
        eventType: AuditEventType.DELEGATION_REVOKED_BY_DIRECT_VOTE,
        actorDid: myDid,
        actorPseudonym: '',
        timestamp: DateTime.now().toUtc(),
        payload: {
          'delegationId': old.delegationId,
          'previousDelegateDid': old.delegateDid,
          'reason': 'DIRECT_VOTE_CAST',
        },
      ));
      // G2.1.2: wire publish so other devices see the REVOKED status during
      // tally aggregation (G2.1.3).
      final autoRevokeResult = await _publishDelegationToNostr(autoRevoked);
      if (autoRevokeResult.acceptedRelayCount == 0) {
        final totalAR =
            autoRevokeResult.acceptedRelayCount + autoRevokeResult.failedRelayCount;
        print('[DELEGATION] publish FAILED (auto-revoke): '
            '${totalAR > 0 ? "0/$totalAR accepted" : "no relays"}, queuing retry');
      }
      print('[DELEGATION] auto-revoked due to direct vote: '
          'delegationId=${old.delegationId} voter=$myDid');
    }
    // ── Ende Phase G2.1.1b ────────────────────────────────────────────────────

    final existingVotes = _votes[proposalId] ?? [];
    final myExisting = existingVotes
        .where((v) => v.voterDid == myDid)
        .firstOrNull;
    final isChange = myExisting != null;

    final myPubkey = getMyNostrPubkeyHex?.call() ?? '';
    final vote = Vote(
      voteId: Vote.generateId(),
      proposalId: proposalId,
      voterPubkey: myPubkey,
      voterDid: myDid,
      voterPseudonym: IdentityService.instance.currentIdentity!.pseudonym,
      choice: choice,
      reasoning: reasoning,
      selectedOptionId: selectedOptionId,
      createdAt: DateTime.now().toUtc(),
      nostrEventId: '',
    );

    // DB: upsert (UNIQUE(proposal_id, voter_pubkey) → REPLACE).
    await _saveVoteToDb(vote);

    // Memory: replace existing or add new.
    final updated = List<Vote>.from(existingVotes)
      ..removeWhere((v) => v.voterDid == myDid);
    updated.add(vote);
    _votes[proposalId] = updated;

    final voteResult = await _publishVoteToNostr(
      proposalId: proposalId,
      cellId: p.cellId,
      vote: vote,
    );
    final published = voteResult.status == PublishResultStatus.accepted ||
        voteResult.status == PublishResultStatus.partial;
    // Phase 4.7d: differentiated vote publish log.
    final voteTotalRelays =
        voteResult.acceptedRelayCount + voteResult.failedRelayCount;
    if (!published) {
      final desc = voteTotalRelays > 0
          ? '0/$voteTotalRelays accepted'
          : 'no relays';
      print('[VOTE] publish FAILED: $desc, queuing retry');
    } else if (voteResult.acceptedRelayCount < voteTotalRelays) {
      print('[VOTE] publish PARTIAL: '
          '${voteResult.acceptedRelayCount}/$voteTotalRelays relays accepted');
    } else {
      print('[VOTE] publish FULL: '
          '${voteResult.acceptedRelayCount}/$voteTotalRelays relays accepted');
    }

    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: proposalId,
      cellId: p.cellId,
      eventType: isChange ? AuditEventType.VOTE_CHANGED : AuditEventType.VOTE_CAST,
      actorDid: myDid,
      actorPseudonym: vote.voterPseudonym,
      timestamp: DateTime.now().toUtc(),
      payload: {
        'choice': choice.name,
        if (selectedOptionId != null) 'selectedOptionId': selectedOptionId,
        if (reasoning != null) 'reasoning': reasoning,
        if (isChange) 'previousChoice': myExisting.choice.name,
        if (isChange && myExisting.selectedOptionId != null)
          'previousSelectedOptionId': myExisting.selectedOptionId,
      },
    ));

    _notify();
  }

  /// Alias – changeVote delegates to castVote (same semantics).
  Future<void> changeVote(String proposalId, VoteChoice newChoice,
      {String? newReasoning, String? newSelectedOptionId}) async {
    await castVote(proposalId, newChoice,
        reasoning: newReasoning,
        selectedOptionId: newSelectedOptionId);
  }

  // ── Delegation (Phase G2.1.1b) ─────────────────────────────────────────────

  /// Phase G2.1.1b: Create a per-proposal delegation.
  ///
  /// Local-only — no wire publish in this phase. Returns the newly-created
  /// (or, for re-delegation, the new ACTIVE) Delegation.
  ///
  /// Throws [StateError] when:
  ///   - Proposal does not exist
  ///   - Proposal.votingMode == CANDIDATE_CHOICE
  ///   - Proposal.status != VOTING
  ///   - Proposal.votingEndsAt is set and now > votingEndsAt
  ///   - delegatorDid == delegateDid (self-delegation)
  ///   - delegatorDid is not a member of proposal.cellId
  ///   - delegateDid is not a member of proposal.cellId
  ///   - delegator has already cast a direct vote on this proposal
  Future<Delegation> createDelegation({
    required String delegatorDid,
    required String delegateDid,
    required String proposalId,
  }) async {
    // 1. Proposal-Lookup.
    final p = _proposals[proposalId];
    if (p == null) throw StateError('Antrag nicht gefunden: $proposalId');

    // 2. Modus-Check: CC-Ausschluss.
    if (p.votingMode == VotingMode.CANDIDATE_CHOICE) {
      print('[DELEGATION-REJECT] mode=CANDIDATE_CHOICE proposal=$proposalId');
      throw StateError('Delegation in Kandidatenwahlen nicht möglich');
    }

    // 3. Status-Check: nur VOTING erlaubt.
    if (p.status != ProposalStatus.VOTING) {
      print('[DELEGATION-REJECT] status=${p.status.name} proposal=$proposalId');
      throw StateError('Delegation nur während laufender Abstimmung möglich');
    }

    // 4. votingEndsAt-Check.
    if (p.votingEndsAt != null &&
        DateTime.now().toUtc().isAfter(p.votingEndsAt!)) {
      print('[DELEGATION-REJECT] reason=voting-ended proposal=$proposalId');
      throw StateError(
          'Delegation nicht mehr möglich — Abstimmungsfrist ist abgelaufen');
    }

    // 5. Self-Check.
    if (delegatorDid == delegateDid) {
      throw StateError('Du kannst nicht an dich selbst delegieren');
    }

    // 6. Cell-Membership-Check (DB-direkt, L5 Entscheidung).
    final memberRows =
        await PodDatabase.instance.listCellMembers(p.cellId);
    final memberDids = <String>{};
    for (final row in memberRows) {
      final m = CellMember.fromJson(row);
      if (m.isConfirmed) memberDids.add(m.did);
    }
    if (!memberDids.contains(delegatorDid)) {
      throw StateError(
          'Du bist kein stimmberechtigtes Mitglied dieser Zelle');
    }
    if (!memberDids.contains(delegateDid)) {
      throw StateError('Delegierter ist kein Mitglied dieser Zelle');
    }

    // 7. Direct-Vote-Check: delegator hat schon direkt abgestimmt?
    final voteRows = await PodDatabase.instance.listVotes(proposalId);
    final hasDirectVote =
        voteRows.any((v) => (v['voter_did'] as String?) == delegatorDid);
    if (hasDirectVote) {
      throw StateError(
          'Du hast bereits direkt abgestimmt — Delegation nicht mehr möglich');
    }

    // 8. Re-Delegation-Check (defense-in-depth neben Partial Unique Index).
    final activeDelegations =
        await PodDatabase.instance.listActiveDelegationsForProposal(proposalId);
    final existingActive = activeDelegations
        .where((m) => (m['delegator_did'] as String?) == delegatorDid)
        .toList();

    if (existingActive.isNotEmpty) {
      final existing = Delegation.fromMap(existingActive.first);
      if (existing.delegateDid == delegateDid) {
        // Idempotent: gleicher Delegat — keine Änderung.
        print('[DELEGATION] createDelegation: delegator=$delegatorDid '
            'delegate=$delegateDid proposal=$proposalId result=idempotent');
        return existing;
      }
      // Re-Delegation: alte Delegation auf SUPERSEDED setzen.
      final superseded = existing.copyWith(
        status: DelegationStatus.SUPERSEDED,
        updatedAt: DateTime.now().toUtc(),
      );
      await PodDatabase.instance.upsertDelegation(superseded.toMap());
      await addAuditEntry(AuditLogEntry(
        entryId: AuditLogEntry.generateId(),
        proposalId: p.id,
        cellId: p.cellId,
        eventType: AuditEventType.DELEGATION_SUPERSEDED,
        actorDid: delegatorDid,
        actorPseudonym: '',
        timestamp: DateTime.now().toUtc(),
        payload: {
          'oldDelegationId': existing.delegationId,
          'newDelegationId': '', // filled below after creation
          'oldDelegateDid': existing.delegateDid,
          'newDelegateDid': delegateDid,
          'proposalId': p.id,
        },
      ));
      // G2.1.2: publish SUPERSEDED delegation wire event first (re-delegation
      // requires two events: old SUPERSEDED, then new ACTIVE).
      final supersededResult = await _publishDelegationToNostr(superseded);
      if (supersededResult.acceptedRelayCount == 0) {
        final totalS =
            supersededResult.acceptedRelayCount + supersededResult.failedRelayCount;
        print('[DELEGATION] publish FAILED (SUPERSEDED): '
            '${totalS > 0 ? "0/$totalS accepted" : "no relays"}, queuing retry');
      }
    }

    // 9. Neue Delegation anlegen.
    final created = Delegation.create(
      delegatorDid: delegatorDid,
      delegateDid: delegateDid,
      proposalId: proposalId,
      cellId: p.cellId,
    );
    await PodDatabase.instance.upsertDelegation(created.toMap());
    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.DELEGATION_CREATED,
      actorDid: delegatorDid,
      actorPseudonym: '',
      timestamp: DateTime.now().toUtc(),
      payload: {
        'delegationId': created.delegationId,
        'delegateDid': delegateDid,
        'proposalId': p.id,
        'cellId': p.cellId,
      },
    ));

    // G2.1.2: publish new ACTIVE delegation.
    final createdResult = await _publishDelegationToNostr(created);
    if (createdResult.acceptedRelayCount == 0) {
      final totalC =
          createdResult.acceptedRelayCount + createdResult.failedRelayCount;
      print('[DELEGATION] publish FAILED (ACTIVE): '
          '${totalC > 0 ? "0/$totalC accepted" : "no relays"}, queuing retry');
    }

    final result = existingActive.isNotEmpty ? 're-delegated' : 'created';
    print('[DELEGATION] createDelegation: delegator=$delegatorDid '
        'delegate=$delegateDid proposal=$proposalId result=$result');
    return created;
  }

  /// Phase G2.1.1b: Revoke an existing delegation.
  ///
  /// Local-only — no wire publish in this phase.
  ///
  /// Throws [StateError] when:
  ///   - Delegation does not exist
  ///   - Delegation.status != ACTIVE
  ///   - Underlying proposal not found
  ///   - proposal.status != VOTING
  ///   - proposal.votingEndsAt is set and now > votingEndsAt
  Future<Delegation> revokeDelegation(String delegationId) async {
    // 1. Delegation-Lookup.
    final row = await PodDatabase.instance.getDelegation(delegationId);
    if (row == null) {
      throw StateError('Delegation nicht gefunden: $delegationId');
    }

    // 2. Status-Check: nur ACTIVE kann widerrufen werden.
    final delegation = Delegation.fromMap(row);
    if (delegation.status != DelegationStatus.ACTIVE) {
      throw StateError(
          'Nur aktive Delegationen können widerrufen werden, '
          'aktueller Status: ${delegation.status.name}');
    }

    // 3. Proposal-Lookup.
    final p = _proposals[delegation.proposalId];
    if (p == null) {
      throw StateError(
          'Zu dieser Delegation gehört kein auffindbarer Antrag mehr');
    }

    // 4. Status-Check (verschärft per Joachim G2.1.1b): nur VOTING erlaubt.
    if (p.status != ProposalStatus.VOTING) {
      throw StateError(
          'Delegation kann nur während laufender Abstimmung widerrufen werden, '
          'aktueller Antragsstatus: ${p.status.name}');
    }

    // 5. votingEndsAt-Check.
    if (p.votingEndsAt != null &&
        DateTime.now().toUtc().isAfter(p.votingEndsAt!)) {
      throw StateError(
          'Delegation kann nach Ablauf der Abstimmungsfrist '
          'nicht mehr widerrufen werden');
    }

    // 6. Update: ACTIVE → REVOKED.
    final revoked = delegation.copyWith(
      status: DelegationStatus.REVOKED,
      updatedAt: DateTime.now().toUtc(),
    );
    await PodDatabase.instance.upsertDelegation(revoked.toMap());

    // 7. Audit.
    await addAuditEntry(AuditLogEntry(
      entryId: AuditLogEntry.generateId(),
      proposalId: p.id,
      cellId: p.cellId,
      eventType: AuditEventType.DELEGATION_REVOKED,
      actorDid: delegation.delegatorDid,
      actorPseudonym: '',
      timestamp: DateTime.now().toUtc(),
      payload: {
        'delegationId': delegationId,
        'delegateDid': delegation.delegateDid,
        'proposalId': p.id,
        'reason': 'USER_REVOKED',
      },
    ));

    // 8. G2.1.2: wire publish (DB + Audit already done above).
    final revokeResult = await _publishDelegationToNostr(revoked);
    if (revokeResult.acceptedRelayCount == 0) {
      final totalR = revokeResult.acceptedRelayCount + revokeResult.failedRelayCount;
      print('[DELEGATION] publish FAILED (REVOKED): '
          '${totalR > 0 ? "0/$totalR accepted" : "no relays"}, queuing retry');
    }

    // 9. Logging.
    print('[DELEGATION] revokeDelegation: delegationId=$delegationId '
        'delegator=${delegation.delegatorDid} previous=ACTIVE → REVOKED');

    return revoked;
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  List<Proposal> proposalsForCell(String cellId, {ProposalStatus? status}) {
    var list = _proposals.values.where((p) => p.cellId == cellId).toList();
    if (status != null) list = list.where((p) => p.status == status).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Proposal> activeProposalsForCell(String cellId) =>
      proposalsForCell(cellId).where((p) => p.isActive).toList();

  List<Proposal> getActiveProposals(String cellId) => activeProposalsForCell(cellId);

  List<Proposal> myProposals() {
    final myDid = IdentityService.instance.currentIdentity?.did;
    if (myDid == null) return [];
    print('[G2-UI] My proposals filter: $myDid found ${_proposals.values.where((p) => p.creatorDid == myDid || (_votes[p.id]?.any((v) => v.voterDid == myDid) ?? false)).length}');
    return _proposals.values
        .where((p) =>
            p.creatorDid == myDid ||
            (_votes[p.id]?.any((v) => v.voterDid == myDid) ?? false))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Proposal> getMyProposals(String cellId, String myDid) {
    return _proposals.values
        .where((p) =>
            p.cellId == cellId &&
            (p.creatorDid == myDid ||
                (_votes[p.id]?.any((v) => v.voterDid == myDid) ?? false)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Proposal> getCompletedProposals(String cellId) => proposalsForCell(
        cellId,
        status: ProposalStatus.DECIDED,
      );

  List<Proposal> getArchivedProposals(
    String cellId, {
    String? searchQuery,
    String? category,
    DateTimeRange? range,
    String? resultFilter,
  }) {
    var list = _proposals.values.where((p) =>
        p.cellId == cellId &&
        (p.status == ProposalStatus.ARCHIVED ||
            p.status == ProposalStatus.WITHDRAWN));

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((p) =>
          p.title.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q));
    }
    if (category != null) {
      list = list.where((p) => p.category == category);
    }
    if (range != null) {
      list = list.where((p) =>
          p.createdAt.isAfter(range.start) && p.createdAt.isBefore(range.end));
    }
    if (resultFilter != null) {
      list = list.where((p) => p.resultSummary == resultFilter);
    }
    return list.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Proposal? getProposal(String proposalId) => _proposals[proposalId];

  List<Vote> getVotes(String proposalId) => _votes[proposalId] ?? [];

  Future<List<ProposalEdit>> getEditHistory(String proposalId) async {
    final rows = await PodDatabase.instance.listProposalEdits(proposalId);
    return rows.map(ProposalEdit.fromMap).toList();
  }

  Future<List<AuditLogEntry>> getAuditLog(String proposalId) async {
    final rows = await PodDatabase.instance.listAuditLog(proposalId);
    return rows.map(AuditLogEntry.fromMap).toList();
  }

  Future<DecisionRecord?> getDecisionRecord(String proposalId) async {
    final row = await PodDatabase.instance.getDecisionRecord(proposalId);
    if (row == null) return null;
    return DecisionRecord.fromMap(row);
  }

  // ── Proposal discussions ──────────────────────────────────────────────────

  List<ProposalDiscussionMessage> getDiscussionMessages(String proposalId) {
    final msgs = _discussions[proposalId] ?? [];
    print('[G2-UI] Audit log filter for proposal $proposalId: ${msgs.length} entries');
    return List.unmodifiable(msgs);
  }

  Future<void> postDiscussionMessage(String proposalId, String content) async {
    final myDid = IdentityService.instance.currentIdentity?.did ?? '';
    final myPseudo = IdentityService.instance.currentIdentity?.pseudonym ?? '';
    final id = 'disc_${DateTime.now().millisecondsSinceEpoch}_${proposalId.substring(0, 8)}';

    final disc = ProposalDiscussionMessage(
      id: id,
      proposalId: proposalId,
      authorDid: myDid,
      authorPseudonym: myPseudo,
      content: content,
      createdAt: DateTime.now().toUtc(),
    );

    print('[G2-UI] Posting discussion message');
    await _saveDiscussion(disc);
    _notify();

    final fn = onSendDiscussionMessage;
    if (fn != null) {
      await fn({
        'id': id,
        'proposalId': proposalId,
        'content': content,
        'authorPseudonym': myPseudo,
      });
    }
  }

  Future<void> handleDiscussionMessage(Map<String, dynamic> params) async {
    final proposalId = params['proposalId'] as String? ?? '';
    if (proposalId.isEmpty) return;
    // Only store if we know this proposal
    if (!_proposals.containsKey(proposalId)) return;

    final disc = ProposalDiscussionMessage(
      id: params['id'] as String? ?? '',
      proposalId: proposalId,
      authorDid: params['authorDid'] as String? ?? '',
      authorPseudonym: params['authorPseudonym'] as String? ?? '',
      content: params['content'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          params['createdAt'] as int? ?? 0,
          isUtc: true),
    );
    if (disc.id.isEmpty || disc.content.isEmpty) return;

    await _saveDiscussion(disc);
    _notify();
  }

  Future<void> _saveDiscussion(ProposalDiscussionMessage disc) async {
    _discussions.putIfAbsent(disc.proposalId, () => []);
    final list = _discussions[disc.proposalId]!;
    if (!list.any((d) => d.id == disc.id)) {
      list.add(disc);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    try {
      await PodDatabase.instance.insertProposalDiscussion(disc.toMap());
    } catch (_) {}
  }

  // ── Incoming Nostr event handlers ─────────────────────────────────────────

  /// Processes a received Kind-31010 proposal event from Nostr.
  ///
  /// Creates or updates the local proposal. Edit and status-change audit
  /// entries are generated so both devices build an identical audit log.
  Future<void> handleIncomingProposal(NostrEvent event) async {
    print('[PROPOSAL] handleIncomingProposal: ${event.id}');

    // AETHER state-locking: synchronous seen-set check by Nostr event ID.
    // Two relays delivering the same Kind-31010 in parallel would otherwise
    // both enter the existing-vs-new branching, both call _saveEditToDb +
    // addAuditEntry (with freshly generated editIds/entryIds — no UNIQUE
    // constraint to deduplicate them), and both mutate `existing` fields
    // after multiple awaits. The version-gating (version > existing.version)
    // remains the authoritative guard for legitimate edit ordering across
    // sessions; this set only suppresses duplicate event-id deliveries
    // within a session.
    if (!_seenProposalEventIds.add(event.id)) {
      print('[PROPOSAL] Proposal event already processed: ${event.id}');
      return;
    }

    try {
      final proposalId = event.tagValue('d');
      final cellId = event.tagValues('t')
          .where((v) => v.startsWith('nexus-cell-'))
          .map((v) => v.substring('nexus-cell-'.length))
          .firstOrNull;
      final type = event.tagValue('type');
      final statusStr = event.tagValue('status');
      final versionStr = event.tagValue('version');
      final category = event.tagValue('category');
      final votingEndsAtStr = event.tagValue('voting_ends_at');

      if (proposalId == null || cellId == null) {
        print('[PROPOSAL] handleIncomingProposal: missing d/nexus-cell tag, skipping');
        return;
      }

      // TOMBSTONE CHECK: never re-import a deleted/withdrawn proposal.
      if (_proposalTombstones.contains(proposalId)) {
        print('[PROPOSAL] Ignoring tombstoned proposal: $proposalId');
        return;
      }

      // Only process events for cells we are a member of.
      if (!CellService.instance.isMember(cellId)) {
        print('[PROPOSAL] Ignoring – not a member of cell $cellId');
        return;
      }

      final content = jsonDecode(event.content) as Map<String, dynamic>;
      final version = int.tryParse(versionStr ?? '1') ?? 1;
      final newStatus = ProposalStatus.values.firstWhere(
        (e) => e.name == (statusStr ?? 'DRAFT').toUpperCase(),
        orElse: () => ProposalStatus.DRAFT,
      );

      // WITHDRAWN from another device: status-update, keep proposal visible
      // (symmetric to local withdrawProposal at L470-504). Tombstone still
      // set first to prevent re-import via late relay replay of the original
      // pre-withdraw event.
      if (newStatus == ProposalStatus.WITHDRAWN) {
        print('[PROPOSAL] Withdraw received, applying status update: $proposalId');
        await _addTombstone(proposalId, reason: 'remote_withdrawn');

        final existingWithdrawn = _proposals[proposalId];
        if (existingWithdrawn == null) {
          // Proposal was never seen on this device. Skip — nothing to update.
          // The tombstone above prevents future re-import.
          print('[PROPOSAL] Withdraw for unknown proposal, tombstone only: $proposalId');
          _notify();
          return;
        }

        // Skip if already WITHDRAWN locally (idempotency).
        if (existingWithdrawn.status == ProposalStatus.WITHDRAWN) {
          print('[PROPOSAL] Withdraw already applied locally: $proposalId');
          return;
        }

        // Apply status transition.
        existingWithdrawn.status = ProposalStatus.WITHDRAWN;
        existingWithdrawn.withdrawnAt = DateTime.now().toUtc();
        await _saveProposalToDb(existingWithdrawn);

        // Mirror the audit entry from the local withdrawProposal path
        // for a complete audit trail on this device.
        // NOTE: actorDid uses existingWithdrawn.creatorDid as a stand-in.
        // Deriving the actor from the Nostr event signer is tech-debt for
        // a later refinement.
        await addAuditEntry(AuditLogEntry(
          entryId: AuditLogEntry.generateId(),
          proposalId: existingWithdrawn.id,
          cellId: existingWithdrawn.cellId,
          eventType: AuditEventType.PROPOSAL_WITHDRAWN,
          actorDid: existingWithdrawn.creatorDid,
          actorPseudonym: existingWithdrawn.creatorPseudonym,
          timestamp: DateTime.now().toUtc(),
          payload: {'reason': 'remote_withdrawal_received'},
        ));

        _notify();
        return;
      }

      final existing = _proposals[proposalId];

      if (existing != null) {
        final newTitle = content['title'] as String? ?? existing.title;
        final newDesc = content['description'] as String? ?? existing.description;

        // An edit requires both a content change AND a higher version number.
        final isContentEdit =
            (existing.title != newTitle || existing.description != newDesc) &&
                version > existing.version;
        final isStatusChange = existing.status != newStatus;

        // Nothing relevant changed – skip silently.
        if (!isContentEdit && !isStatusChange) {
          print(
              '[PROPOSAL] Ignoring – no content or status change (v$version, ${newStatus.name})');
          return;
        }

        if (isContentEdit) {
          print('[PROPOSAL] Edit detected: v${existing.version} → v$version');
          final edit = ProposalEdit(
            editId: ProposalEdit.generateId(),
            proposalId: proposalId,
            editorDid: existing.creatorDid,
            editorPseudonym: existing.creatorPseudonym,
            oldTitle: existing.title,
            newTitle: newTitle,
            oldDescription: existing.description,
            newDescription: newDesc,
            editedAt: DateTime.fromMillisecondsSinceEpoch(
                event.createdAt * 1000,
                isUtc: true),
            editReason: content['editReason'] as String?,
            versionBefore: existing.version,
            versionAfter: version,
          );
          await _saveEditToDb(edit);

          await addAuditEntry(AuditLogEntry(
            entryId: AuditLogEntry.generateId(),
            proposalId: proposalId,
            cellId: cellId,
            eventType: AuditEventType.PROPOSAL_EDITED,
            actorDid: existing.creatorDid,
            actorPseudonym: existing.creatorPseudonym,
            timestamp: edit.editedAt,
            payload: {
              'oldTitle': existing.title,
              'newTitle': newTitle,
              'versionBefore': existing.version,
              'versionAfter': version,
              'reason': content['editReason'],
            },
          ));
        }

        // Status change – always process regardless of version.
        if (isStatusChange) {
          print(
              '[PROPOSAL] Status: ${existing.status.name} → ${newStatus.name}');
          await addAuditEntry(AuditLogEntry(
            entryId: AuditLogEntry.generateId(),
            proposalId: proposalId,
            cellId: cellId,
            eventType: AuditEventType.PROPOSAL_STATUS_CHANGED,
            actorDid: existing.creatorDid,
            actorPseudonym: existing.creatorPseudonym,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
                event.createdAt * 1000,
                isUtc: true),
            payload: {
              'from': existing.status.name,
              'to': newStatus.name,
            },
          ));
        }

        // Apply updates.
        if (isContentEdit) {
          existing.title = newTitle;
          existing.description = newDesc;
          existing.version = version;
        }
        existing.status = newStatus;
        if (category != null) existing.category = category;
        if (votingEndsAtStr != null) {
          final ts = int.tryParse(votingEndsAtStr);
          if (ts != null) {
            existing.votingEndsAt =
                DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
          }
        }
        await _saveProposalToDb(existing);
        await _persistIncomingOptions(proposalId, content); // Phase 4.7c2
      } else {
        // New proposal – create from event.
        final createdAtTs = content['createdAt'] as int? ?? event.createdAt;
        // Phase 4.7c1: read votingMode from content with parseVotingMode.
        // Legacy events (pre-4.7c1) lack the key → parseVotingMode(null)
        // returns YES_NO_ABSTAIN, which matches the historical default
        // behavior.
        final votingModeStr = content['votingMode'] as String?;
        final proposal = Proposal(
          id: proposalId,
          cellId: cellId,
          creatorDid: content['creatorDid'] as String? ?? '',
          creatorPseudonym: content['creatorPseudonym'] as String? ?? '',
          title: content['title'] as String? ?? '',
          description: content['description'] as String? ?? '',
          proposalType: ProposalType.values.firstWhere(
            (e) => e.name == (type ?? 'SACHFRAGE').toUpperCase(),
            orElse: () => ProposalType.SACHFRAGE,
          ),
          category: category,
          status: newStatus,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
              createdAtTs * 1000,
              isUtc: true),
          version: version,
          votingMode: parseVotingMode(votingModeStr),
          votingEndsAt: votingEndsAtStr != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  int.parse(votingEndsAtStr) * 1000,
                  isUtc: true)
              : null,
        );

        // AETHER state-locking: write in-memory first (synchronous, same microtask).
        // Two relays can deliver the same Kind-31010 within milliseconds; both
        // fall into this else-branch because _proposals[proposalId] is still null.
        // Locking the map BEFORE the DB await prevents UNIQUE-constraint failures
        // and phantom duplicates.
        _proposals[proposalId] = proposal;

        await _saveProposalToDb(proposal);
        await _persistIncomingOptions(proposalId, content); // Phase 4.7c2

        await addAuditEntry(AuditLogEntry(
          entryId: AuditLogEntry.generateId(),
          proposalId: proposalId,
          cellId: cellId,
          eventType: AuditEventType.PROPOSAL_CREATED,
          actorDid: proposal.creatorDid,
          actorPseudonym: proposal.creatorPseudonym,
          timestamp: proposal.createdAt,
          payload: {'title': proposal.title, 'category': proposal.category},
          nostrEventId: event.id,
        ));

        // Notify only if not own event.
        final myDid = IdentityService.instance.currentIdentity?.did;
        if (proposal.creatorDid != myDid &&
            newStatus == ProposalStatus.DISCUSSION) {
          await _notifyAllMembers(
            cellId,
            title: 'Neuer Antrag',
            body: '${proposal.creatorPseudonym}: ${proposal.title}',
            payload: 'proposal:$proposalId',
            excludeDid: proposal.creatorDid,
          );
        }
      }

      _notify();
    } catch (e) {
      print('[PROPOSAL] handleIncomingProposal error: $e');
    }
  }

  /// Processes a received Kind-31011 vote event from Nostr.
  Future<void> handleIncomingVote(NostrEvent event) async {
    print('[VOTE] handleIncomingVote: ${event.id}');

    // AETHER state-locking: synchronous seen-set check by Nostr event ID.
    // Same rationale as handleIncomingProposal — protects the audit log
    // against duplicate VOTE_CAST/VOTE_CHANGED entries from parallel relay
    // delivery while keeping the async hasAuditEntryForNostrEvent DB check
    // (further down in the method) as cross-session dedup guard.
    if (!_seenVoteEventIds.add(event.id)) {
      print('[VOTE] Vote event already processed: ${event.id}');
      return;
    }

    try {
      // Skip echo of own votes – castVote() already wrote the audit entry locally.
      final myPubkey = getMyNostrPubkeyHex?.call();
      if (myPubkey != null && myPubkey.isNotEmpty && event.pubkey == myPubkey) {
        print('[VOTE] Echo of own vote ignored: ${event.id}');
        return;
      }

      // Dedup: the same event can arrive from multiple relays.
      if (await PodDatabase.instance.hasAuditEntryForNostrEvent(event.id)) {
        print('[VOTE] Already processed: ${event.id}');
        return;
      }

      final proposalId = event.tagValue('proposal_id');
      final cellId = event.tagValues('t')
          .where((v) => v.startsWith('nexus-cell-'))
          .map((v) => v.substring('nexus-cell-'.length))
          .firstOrNull;
      final choiceStr = event.tagValue('choice');

      if (proposalId == null || cellId == null || choiceStr == null) {
        print('[VOTE] handleIncomingVote: missing tags, skipping');
        return;
      }

      // TOMBSTONE CHECK: ignore votes for deleted proposals.
      if (_proposalTombstones.contains(proposalId)) {
        print('[VOTE] Ignoring vote for tombstoned proposal: $proposalId');
        return;
      }

      if (!CellService.instance.isMember(cellId)) return;

      final p = _proposals[proposalId];
      if (p == null) {
        print('[VOTE] handleIncomingVote: unknown proposal $proposalId, skipping');
        return;
      }

      // Grace period: accept votes created before the deadline, reject after.
      AuditEventType? lateType;
      if (p.status == ProposalStatus.VOTING_ENDED) {
        final voteCreatedAt = DateTime.fromMillisecondsSinceEpoch(
            event.createdAt * 1000,
            isUtc: true);
        if (p.votingEndsAt != null &&
            voteCreatedAt.isAfter(p.votingEndsAt!)) {
          print('[VOTE] Late REJECTED - created after deadline');
          await addAuditEntry(AuditLogEntry(
            entryId: AuditLogEntry.generateId(),
            proposalId: proposalId,
            cellId: cellId,
            eventType: AuditEventType.VOTE_LATE_REJECTED,
            actorDid: '',
            actorPseudonym: '',
            timestamp: voteCreatedAt,
            payload: {
              'voterPubkey': event.pubkey,
              'createdAt': voteCreatedAt.millisecondsSinceEpoch,
              'deadline': p.votingEndsAt!.millisecondsSinceEpoch,
            },
          ));
          return;
        }
        print('[VOTE] Late accepted (created before deadline)');
        lateType = AuditEventType.VOTE_LATE_ACCEPTED;
      } else if (p.status != ProposalStatus.VOTING) {
        return; // Voting not open
      }

      final content = jsonDecode(event.content) as Map<String, dynamic>;
      final choice = VoteChoice.values.firstWhere(
        (c) => c.name == choiceStr.toUpperCase(),
        orElse: () => VoteChoice.ABSTAIN,
      );

      final vote = Vote(
        voteId: content['voteId'] as String? ?? Vote.generateId(),
        proposalId: proposalId,
        voterPubkey: event.pubkey,
        voterDid: content['voterDid'] as String? ?? '',
        voterPseudonym: content['voterPseudonym'] as String? ?? '',
        choice: choice,
        reasoning: content['reasoning'] as String?,
        // Phase 4.7a2: read selectedOptionId from content with
        // defensive null default. Legacy events (pre-4.7a2) won't
        // have this key — null is the correct fallback (=
        // abstention for SC/CC, harmless for YES_NO_ABSTAIN).
        selectedOptionId: content['selectedOptionId'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (content['createdAt'] as int? ?? event.createdAt) * 1000,
            isUtc: true),
        nostrEventId: event.id,
      );

      // ── Phase 4.7b: Modus-Validierung (defensive) ───────────────────────
      // Invalide Wire-Votes werden ignoriert. Kein DB-Insert, kein Audit,
      // kein _notify. Der seen-set-Eintrag bleibt — kein Re-Verarbeiten.
      // Bösartige oder fehlerhafte Sender werden so neutralisiert.
      String? rejectReason;
      switch (p.votingMode) {
        case VotingMode.YES_NO_ABSTAIN:
          if (vote.selectedOptionId != null) {
            rejectReason =
                'YES_NO_ABSTAIN with selectedOptionId=${vote.selectedOptionId}';
          }
          break;

        case VotingMode.SINGLE_CHOICE:
          if (vote.choice != VoteChoice.ABSTAIN) {
            rejectReason =
                'SINGLE_CHOICE with choice=${vote.choice.name}';
          } else if (vote.selectedOptionId != null) {
            final options =
                await PodDatabase.instance.listProposalOptions(proposalId);
            final found =
                options.any((m) => m['option_id'] == vote.selectedOptionId);
            if (!found) {
              rejectReason =
                  'SINGLE_CHOICE unknown selectedOptionId=${vote.selectedOptionId}';
            }
          }
          break;

        case VotingMode.CANDIDATE_CHOICE:
          if (vote.choice != VoteChoice.ABSTAIN) {
            rejectReason =
                'CANDIDATE_CHOICE with choice=${vote.choice.name}';
          } else if (vote.selectedOptionId != null) {
            final options =
                await PodDatabase.instance.listProposalOptions(proposalId);
            final candidate = options.firstWhere(
              (m) => m['option_id'] == vote.selectedOptionId,
              orElse: () => <String, dynamic>{},
            );
            if (candidate.isEmpty) {
              rejectReason =
                  'CANDIDATE_CHOICE unknown selectedOptionId=${vote.selectedOptionId}';
            } else if ((candidate['status'] as String?) != 'ACTIVE') {
              rejectReason =
                  'CANDIDATE_CHOICE candidate not ACTIVE '
                  '(status=${candidate['status']}) ${vote.selectedOptionId}';
            }
          }
          break;
      }

      if (rejectReason != null) {
        print('[VOTE-REJECT] $proposalId reason=$rejectReason '
            'voterPubkey=${event.pubkey.substring(0, 12)}…');
        return;
      }
      // ── Ende Phase 4.7b handleIncomingVote-Validierung ──────────────────

      final existingVotes = _votes[proposalId] ?? [];
      final existing = existingVotes
          .where((v) => v.voterPubkey == event.pubkey)
          .firstOrNull;
      final isChange = existing != null;

      // AETHER state-locking: build the new list and replace _votes[proposalId]
      // synchronously BEFORE the DB await. A parallel relay echoing the same
      // vote would otherwise see the still-old list, build its own "updated"
      // copy, and overwrite ours after both DB upserts complete — losing one
      // of the two memory replacements depending on scheduling order.
      // List.from is a shallow copy; we never mutate the previous list.
      final updated = List<Vote>.from(existingVotes)
        ..removeWhere((v) => v.voterPubkey == event.pubkey);
      updated.add(vote);
      _votes[proposalId] = updated;

      // DB: upsert handles UNIQUE(proposal_id, voter_pubkey) replacement.
      await _saveVoteToDb(vote);

      if (isChange) {
        print('[VOTE] Updated (replaced existing)');
      }

      final eventType = lateType ??
          (isChange ? AuditEventType.VOTE_CHANGED : AuditEventType.VOTE_CAST);

      if (isChange) {
        print('[VOTE] Previous choice: ${existing?.choice.name}');
      }

      await addAuditEntry(AuditLogEntry(
        entryId: AuditLogEntry.generateId(),
        proposalId: proposalId,
        cellId: cellId,
        eventType: eventType,
        actorDid: vote.voterDid,
        actorPseudonym: vote.voterPseudonym,
        timestamp: vote.createdAt,
        payload: {
          'choice': vote.choice.name,
          if (vote.reasoning != null) 'reasoning': vote.reasoning,
          if (isChange && existing != null) 'previousChoice': existing.choice.name,
          if (vote.selectedOptionId != null) 'selectedOptionId': vote.selectedOptionId,
          if (isChange && existing != null && existing.selectedOptionId != null)
            'previousSelectedOptionId': existing.selectedOptionId,
        },
        nostrEventId: event.id,
      ));

      _notify();
    } catch (e) {
      print('[VOTE] handleIncomingVote error: $e');
    }
  }

  /// Processes a received Kind-31013 decision record from Nostr.
  Future<void> handleIncomingDecisionRecord(NostrEvent event) async {
    print('[PROPOSAL] handleIncomingDecisionRecord: ${event.id}');

    // AETHER state-locking: synchronous seen-set check by Nostr event ID.
    // Two relays delivering the same Kind-31013 in parallel would otherwise
    // both pass the async _getDecisionRecordByProposal dedup check (since
    // neither call has yet written to DB), both insert RESULT_CALCULATED
    // audit entries (with freshly generated entryIds — no UNIQUE constraint),
    // and both fire _notify(). The decision_records.proposal_id UNIQUE
    // constraint protects the DB itself across sessions; this set adds
    // protection for the audit trail and UI refresh within a session.
    if (!_seenDecisionEventIds.add(event.id)) {
      print('[PROPOSAL] Decision record event already processed: ${event.id}');
      return;
    }

    try {
      final cellId = event.tagValues('t')
          .where((v) => v.startsWith('nexus-cell-'))
          .map((v) => v.substring('nexus-cell-'.length))
          .firstOrNull;
      if (cellId == null || !CellService.instance.isMember(cellId)) return;

      final content = jsonDecode(event.content) as Map<String, dynamic>;
      final proposalId = content['proposalId'] as String?;
      if (proposalId == null) return;

      // TOMBSTONE CHECK: ignore decision records for deleted proposals.
      if (_proposalTombstones.contains(proposalId)) {
        print('[PROPOSAL] Ignoring decision record for tombstoned proposal: $proposalId');
        return;
      }

      // Skip if we already have this record (e.g. we created it).
      final existing = await _getDecisionRecordByProposal(proposalId);
      if (existing != null) {
        print('[PROPOSAL] Decision record already exists for $proposalId, skipping');
        return;
      }

      // Phase 4.5c: read v1.3 fields with defensive null defaults.
      // Legacy records (pre-4.5b senders) won't have these keys;
      // null is the correct fallback.
      // allVotes is intentionally NOT reconstructed in 4.5c —
      // votes are tracked separately via Kind-31011.
      final record = DecisionRecord(
        recordId: DecisionRecord.generateId(),
        proposalId: proposalId,
        cellId: cellId,
        finalTitle: content['finalTitle'] as String? ?? '',
        finalDescription: content['finalDescription'] as String? ?? '',
        result: content['result'] as String? ?? 'invalid',
        yesVotes: content['yesVotes'] as int? ?? 0,
        noVotes: content['noVotes'] as int? ?? 0,
        abstainVotes: content['abstainVotes'] as int? ?? 0,
        participation: (content['participation'] as num?)?.toDouble() ?? 0.0,
        decidedAt: DateTime.fromMillisecondsSinceEpoch(
            content['decidedAt'] as int? ?? 0,
            isUtc: true),
        allVotes: const [],
        contentHash: event.tagValue('content_hash') ?? '',
        previousDecisionHash: event.tagValue('prev_hash'),
        nostrEventId: event.id,
        // ── Phase 4.5c: v1.3 fields ─────────────────────────────
        resultReason: content['resultReason'] as String?,
        resultRelation: content['resultRelation'] as String?,
        previousProposalId: content['previousProposalId'] as String?,
        optionResultsJson: content['optionResultsJson'] as String?,
        tieOptionIdsJson: content['tieOptionIdsJson'] as String?,
      );

      await _saveDecisionRecordToDb(record);
      print('[PROPOSAL] Decision record saved from Nostr for $proposalId');

      // votingMode-Fallback: read from content; fallback used inside
      // localProposal block only (localProposal.votingMode is safe there).
      final receivedModeStr = content['votingMode'] as String?;

      // Bug B fix: update the local proposal with the authoritative result
      // values from the received decision record so that all devices show the
      // same outcome regardless of which device ran finalizeProposal().
      final localProposal = _proposals[proposalId];
      if (localProposal != null) {
        // With localProposal: use its votingMode as fallback when content
        // doesn't include votingMode (legacy pre-4.5b senders).
        final mode = receivedModeStr != null
            ? parseVotingMode(receivedModeStr)
            : localProposal.votingMode;

        print('[PROPOSAL] Updating local proposal from decision record '
            '(mode=${mode.name})');
        print('[PROPOSAL]   Y=${record.yesVotes} N=${record.noVotes} '
            'A=${record.abstainVotes} Participation=${record.participation} '
            'Result=${record.result}');

        localProposal.status = ProposalStatus.DECIDED;
        localProposal.decidedAt = record.decidedAt;
        localProposal.resultSummary = record.result;
        localProposal.resultParticipation = record.participation;
        localProposal.resultAbstain = record.abstainVotes;

        // Only YES_NO_ABSTAIN has meaningful yes/no semantics on the
        // legacy result_yes/result_no columns. For SC/CC the truth
        // lives in optionResultsJson on the persisted DecisionRecord;
        // resultYes/resultNo stay at whatever value they had locally
        // (typically 0).
        if (mode == VotingMode.YES_NO_ABSTAIN) {
          localProposal.resultYes = record.yesVotes;
          localProposal.resultNo = record.noVotes;
        }

        await _saveProposalToDb(localProposal);

        final myIdentity = IdentityService.instance.currentIdentity;
        await addAuditEntry(AuditLogEntry(
          entryId: AuditLogEntry.generateId(),
          proposalId: proposalId,
          cellId: record.cellId,
          eventType: AuditEventType.RESULT_CALCULATED,
          actorDid: myIdentity?.did ?? '',
          actorPseudonym: myIdentity?.pseudonym ?? '',
          timestamp: DateTime.now().toUtc(),
          payload: {
            'result': record.result,
            'resultReason': record.resultReason,
            'votingMode': receivedModeStr,
            'yes': record.yesVotes,
            'no': record.noVotes,
            'abstain': record.abstainVotes,
            'participation': record.participation,
            'optionResultsJson': record.optionResultsJson,
            'tieOptionIdsJson': record.tieOptionIdsJson,
            'source': 'decision_record_received',
          },
          nostrEventId: event.id,
        ));

        _notify();
      }
    } catch (e) {
      print('[PROPOSAL] handleIncomingDecisionRecord error: $e');
    }
  }

  /// Phase G2.1.2: Handle an incoming Kind-31012 delegation event from Nostr.
  ///
  /// Sender-only pattern §31.3: NO auto-actions are triggered on the receiver
  /// side. The event is persisted (idempotent via delegationId as primary key)
  /// and an audit entry is written iff the delegation is new locally.
  Future<void> handleIncomingDelegationEvent(NostrEvent event) async {
    // Synchronous seen-set check (same AETHER pattern as vote/decision).
    if (!_seenDelegationEventIds.add(event.id)) {
      print('[DELEGATION] Event already processed: ${event.id}');
      return;
    }

    try {
      // 1. Identity / Echo — skip echo of own events.
      final myPubkey = getMyNostrPubkeyHex?.call();
      if (myPubkey == null || myPubkey.isEmpty) {
        print('[DELEGATION-REJECT] reason=no-identity event=${event.id}');
        return;
      }
      if (event.pubkey == myPubkey) {
        print('[DELEGATION] Echo of own delegation ignored: ${event.id}');
        return;
      }

      // 2. Content parse.
      Map<String, dynamic> content;
      try {
        content = jsonDecode(event.content) as Map<String, dynamic>;
      } catch (_) {
        print('[DELEGATION-REJECT] reason=malformed-content event=${event.id}');
        return;
      }

      final delegationId = content['delegationId'] as String?;
      final delegatorDid = content['delegatorDid'] as String?;
      final delegateDid = content['delegateDid'] as String?;
      final proposalId = content['proposalId'] as String?;
      final cellId = content['cellId'] as String?;
      final statusStr = content['status'] as String?;

      if (delegationId == null || delegatorDid == null ||
          delegateDid == null || proposalId == null || cellId == null) {
        print('[DELEGATION-REJECT] reason=malformed-content '
            '(missing required field) event=${event.id}');
        return;
      }

      // 3. Status parse — EXPIRED/INVALID → REJECT (D9 Variante A: these
      //    states exist only as tally-time evaluation results, never as
      //    legitimate wire status values).
      final parsedStatus = parseDelegationStatus(statusStr);
      if (parsedStatus == DelegationStatus.EXPIRED ||
          parsedStatus == DelegationStatus.INVALID) {
        print('[DELEGATION-REJECT] reason=non-persistent-status '
            'status=$statusStr event=${event.id}');
        return;
      }

      final createdAtMs = (content['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;
      final updatedAtMs = (content['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;

      // 4. Proposal lookup — cannot validate mode or provide tally context
      //    without the proposal.
      final proposal = _proposals[proposalId];
      if (proposal == null) {
        print('[DELEGATION-REJECT] reason=unknown-proposal '
            'proposalId=$proposalId event=${event.id}');
        return;
      }

      // 5. Mode validation (defense-in-depth, mirrors sender-side check).
      if (proposal.votingMode == VotingMode.CANDIDATE_CHOICE) {
        print('[DELEGATION-REJECT] reason=candidate-choice '
            'proposalId=$proposalId event=${event.id}');
        return;
      }

      // 6. Cell-membership validation (defense-in-depth).
      final memberRows = await PodDatabase.instance.listCellMembers(cellId);
      final memberDids = <String>{};
      for (final row in memberRows) {
        final m = CellMember.fromJson(row);
        if (m.isConfirmed) memberDids.add(m.did);
      }
      if (!memberDids.contains(delegatorDid)) {
        print('[DELEGATION-REJECT] reason=not-cell-member '
            'delegatorDid=$delegatorDid event=${event.id}');
        return;
      }
      if (!memberDids.contains(delegateDid)) {
        print('[DELEGATION-REJECT] reason=not-cell-member '
            'delegateDid=$delegateDid event=${event.id}');
        return;
      }

      // 7. Idempotency check — updatedAt-based stale detection.
      final existingRow =
          await PodDatabase.instance.getDelegation(delegationId);

      if (existingRow != null) {
        final existing = Delegation.fromMap(existingRow);
        if (updatedAtMs <= existing.updatedAt.millisecondsSinceEpoch) {
          print('[DELEGATION] Stale incoming, ignored: $delegationId');
          return;
        }
        // Newer wire version: update local row, NO audit (delegation was
        // already known locally — either from sender or earlier receive).
        final updated = existing.copyWith(
          status: parsedStatus,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs,
              isUtc: true),
          nostrEventId: event.id,
        );
        await PodDatabase.instance.upsertDelegation(updated.toMap());
        print('[DELEGATION] Status update from wire: $delegationId '
            '${existing.status.name} → ${parsedStatus.name}');
        return;
      }

      // 8. New delegation: persist + audit.
      final incoming = Delegation(
        delegationId: delegationId,
        delegatorDid: delegatorDid,
        delegateDid: delegateDid,
        proposalId: proposalId,
        cellId: cellId,
        status: parsedStatus,
        nostrEventId: event.id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs,
            isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs,
            isUtc: true),
      );
      await PodDatabase.instance.upsertDelegation(incoming.toMap());

      AuditEventType auditType;
      switch (parsedStatus) {
        case DelegationStatus.ACTIVE:
          auditType = AuditEventType.DELEGATION_CREATED;
        case DelegationStatus.REVOKED:
          auditType = AuditEventType.DELEGATION_REVOKED;
        case DelegationStatus.SUPERSEDED:
          auditType = AuditEventType.DELEGATION_SUPERSEDED;
        default:
          auditType = AuditEventType.DELEGATION_CREATED;
      }

      await addAuditEntry(AuditLogEntry(
        entryId: AuditLogEntry.generateId(),
        proposalId: proposalId,
        cellId: cellId,
        eventType: auditType,
        actorDid: delegatorDid,
        actorPseudonym: '',
        timestamp: DateTime.now().toUtc(),
        payload: {
          'delegationId': delegationId,
          'delegateDid': delegateDid,
          'proposalId': proposalId,
          'source': 'wire_received',
        },
        nostrEventId: event.id,
      ));

      print('[DELEGATION] handleIncoming: persisted new $delegationId '
          'status=${parsedStatus.name}');
    } catch (e) {
      print('[DELEGATION] handleIncomingDelegationEvent error: $e');
    }
  }

  // ── Retry queue (DB-based) ─────────────────────────────────────────────────

  void _startRetryTimer() {
    if (_retryTimer != null && _retryTimer!.isActive) return;
    _retryTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _processRetryQueue();
    });
  }

  Future<void> _processRetryQueue() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dueRetries = await PublishResultDao.instance.findRetryDue(now);

    if (dueRetries.isEmpty) return;

    print('[RETRY] Processing ${dueRetries.length} due retries');

    for (final pendingResult in dueRetries) {
      PublishResult? newResult;

      try {
        if (pendingResult.eventKind == NostrKind.delegationEvent) {
          // Delegation retry — delegationId stored in voteId field at publish
          // time to avoid a DB migration (no delegationId column in
          // publish_results). Phase G2.1.2.
          final delegationId = pendingResult.voteId;
          if (delegationId != null) {
            final row =
                await PodDatabase.instance.getDelegation(delegationId);
            if (row != null) {
              final delegation = Delegation.fromMap(row);
              newResult = await _publishDelegationToNostr(delegation);
            }
          }
        } else if (pendingResult.voteId != null) {
          // Vote retry
          final votes = _votes[pendingResult.proposalId] ?? [];
          final vote = votes
              .where((v) => v.voteId == pendingResult.voteId)
              .firstOrNull;
          if (vote != null) {
            newResult = await _publishVoteToNostr(
              proposalId: pendingResult.proposalId!,
              cellId: pendingResult.cellId!,
              vote: vote,
            );
          }
        } else if (pendingResult.eventKind == 31013) {
          // Decision Record retry — reload from DB
          final record =
              await _getDecisionRecordByProposal(pendingResult.proposalId!);
          if (record != null) {
            final retryContent = SplayTreeMap<String, dynamic>.from({
              'proposalId': record.proposalId,
              'finalTitle': record.finalTitle,
              'finalDescription': record.finalDescription,
              'result': record.result,
              'yesVotes': record.yesVotes,
              'noVotes': record.noVotes,
              'abstainVotes': record.abstainVotes,
              'participation': record.participation,
              'decidedAt': record.decidedAt.millisecondsSinceEpoch,
              'allVotes': record.allVotes
                  .map((v) => {
                        'voterPseudonym': v.voterPseudonym,
                        'choice': v.choice.name,
                        'reasoning': v.reasoning,
                        'createdAt': v.createdAt.millisecondsSinceEpoch,
                      })
                  .toList(),
            });
            newResult = await _publishDecisionRecord(
              proposalId: record.proposalId,
              cellId: record.cellId,
              recordContent: Map<String, dynamic>.from(retryContent),
              result: record.result,
              contentHash: record.contentHash,
              previousDecisionHash: record.previousDecisionHash,
            );
          }
        } else {
          // Proposal retry
          final p = _proposals[pendingResult.proposalId];
          if (p != null) {
            newResult = await _publishProposalToNostr(p);
          }
        }
      } catch (e) {
        print('[RETRY] Error during retry: $e');
      }

      final retryCount = pendingResult.retryCount + 1;
      final shortId = pendingResult.localEventId.length >= 8
          ? pendingResult.localEventId.substring(0, 8)
          : pendingResult.localEventId;

      String nextStatus;
      int? nextRetryAt;
      String? finalStatus;

      // Phase 4.7d: PARTIAL (acceptedRelayCount > 0) is also success —
      // the event reached the network and no further retry is needed.
      if (newResult != null && newResult.acceptedRelayCount > 0) {
        nextStatus = PublishResultStatus.accepted;
        finalStatus = PublishResultStatus.accepted;
        print('[RETRY] SUCCESS after $retryCount attempts: eventId=$shortId');
      } else if (retryCount >= 6) {
        nextStatus = PublishResultStatus.failed;
        finalStatus = PublishResultStatus.failed;
        print('[RETRY] FAILED after $retryCount attempts: eventId=$shortId');
      } else {
        nextStatus = PublishResultStatus.retrying;
        nextRetryAt = now + backoffMs(retryCount);
        print('[RETRY] Scheduled attempt ${retryCount + 1} in '
            '${backoffMs(retryCount) / 1000}s for eventId=$shortId');
      }

      final updated = pendingResult.copyWith(
        status: nextStatus,
        finalStatus: finalStatus,
        retryCount: retryCount,
        nextRetryAt: nextRetryAt,
        updatedAt: now,
      );
      await PublishResultDao.instance.update(updated);
    }
  }

  // ── Private Nostr publish wrappers ─────────────────────────────────────────

  Future<PublishResult> _publishProposalToNostr(Proposal p,
      {String? editReason}) async {
    final fn = onPublishProposalToNostr;
    if (fn == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return PublishResult(
        publishResultId: 'publish_no_callback_$now',
        localEventId: '',
        eventKind: 0,
        status: PublishResultStatus.failed,
        finalStatus: PublishResultStatus.failed,
        attemptedAt: now,
        retryCount: 0,
        requiredAckCount: 2,
        acceptedRelayCount: 0,
        failedRelayCount: 0,
        errorMessage: 'No transport callback registered',
        createdAt: now,
        updatedAt: now,
      );
    }
    // Phase 4.7c2: embed ProposalOptions for non-YES_NO_ABSTAIN proposals
    // so receivers get the options atomically with the proposal event.
    List<Map<String, dynamic>>? optionsForWire;
    if (p.votingMode != VotingMode.YES_NO_ABSTAIN) {
      final rows = await PodDatabase.instance.listProposalOptions(p.id);
      if (rows.isNotEmpty) {
        final options = rows.map(ProposalOption.fromMap).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        optionsForWire = options
            .map(_optionToWireMap)
            .toList(growable: false);
      }
    }

    return fn({
      'proposalId': p.id,
      'cellId': p.cellId,
      'type': p.proposalType.name,
      'status': p.status.name,
      'title': p.title,
      'description': p.description,
      'creatorDid': p.creatorDid,
      'creatorPseudonym': p.creatorPseudonym,
      'createdAt': p.createdAt.millisecondsSinceEpoch ~/ 1000,
      'version': p.version,
      if (p.category != null) 'category': p.category,
      if (p.votingEndsAt != null)
        'votingEndsAt': p.votingEndsAt!.millisecondsSinceEpoch ~/ 1000,
      if (editReason != null) 'editReason': editReason,
      'votingMode': p.votingMode.name,
      if (optionsForWire != null) 'proposalOptions': optionsForWire,
    });
  }

  /// Phase 4.7c2: serialize a ProposalOption to the wire-format
  /// Map embedded in the Proposal Kind-31010 event content.
  /// Keys are camelCase to match the rest of the content payload.
  Map<String, dynamic> _optionToWireMap(ProposalOption opt) {
    return <String, dynamic>{
      'optionId': opt.optionId,
      'position': opt.position,
      'label': opt.label,
      if (opt.description != null && opt.description!.isNotEmpty)
        'description': opt.description,
      if (opt.candidateDid != null) 'candidateDid': opt.candidateDid,
      if (opt.candidatePseudonym != null)
        'candidatePseudonym': opt.candidatePseudonym,
      'status': opt.status.name,
      if (opt.candidateAcceptedAt != null)
        'candidateAcceptedAt':
            opt.candidateAcceptedAt!.millisecondsSinceEpoch,
      if (opt.candidateWithdrawnAt != null)
        'candidateWithdrawnAt':
            opt.candidateWithdrawnAt!.millisecondsSinceEpoch,
    };
  }

  /// Phase 4.7c2: parse the proposalOptions list embedded in
  /// the Proposal content (if present) and upsert each into
  /// the local proposal_options table. Idempotent — receiving
  /// the same proposal multiple times produces no duplicates
  /// (upsert via UNIQUE(option_id)).
  ///
  /// Legacy events without the key produce a no-op.
  /// Malformed individual entries are skipped without aborting
  /// the rest of the list.
  Future<void> _persistIncomingOptions(
      String proposalId, Map<String, dynamic> content) async {
    final raw = content['proposalOptions'];
    if (raw == null) return;
    if (raw is! List) {
      print('[PROPOSAL] proposalOptions is not a list, ignoring');
      return;
    }
    print('[PROPOSAL] persisting ${raw.length} embedded options '
        'for $proposalId');
    int persistedCount = 0;
    int skippedCount = 0;
    for (final entry in raw) {
      if (entry is! Map) {
        skippedCount++;
        continue;
      }
      final m = entry.cast<String, dynamic>();
      try {
        final positionRaw = m['position'];
        final acceptedRaw = m['candidateAcceptedAt'];
        final withdrawnRaw = m['candidateWithdrawnAt'];
        final now = DateTime.now().toUtc();

        final opt = ProposalOption(
          optionId: m['optionId'] as String,
          proposalId: proposalId,
          position: (positionRaw as num).toInt(),
          label: m['label'] as String,
          description: m['description'] as String?,
          candidateDid: m['candidateDid'] as String?,
          candidatePseudonym: m['candidatePseudonym'] as String?,
          status: OptionStatus.values.firstWhere(
            (e) => e.name == (m['status'] as String? ?? ''),
            orElse: () => OptionStatus.ACTIVE,
          ),
          candidateAcceptedAt: acceptedRaw is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  acceptedRaw.toInt(),
                  isUtc: true,
                )
              : null,
          candidateWithdrawnAt: withdrawnRaw is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  withdrawnRaw.toInt(),
                  isUtc: true,
                )
              : null,
          createdAt: now,
          updatedAt: now,
        );
        await PodDatabase.instance.upsertProposalOption(opt.toMap());
        persistedCount++;
      } catch (e) {
        skippedCount++;
        print('[PROPOSAL] skipping malformed option entry: $e');
      }
    }
    print('[PROPOSAL] options persist done for $proposalId: '
        '$persistedCount persisted, $skippedCount skipped');
  }

  Future<PublishResult> _publishVoteToNostr({
    required String proposalId,
    required String cellId,
    required Vote vote,
  }) async {
    final fn = onPublishVoteToNostr;
    if (fn == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return PublishResult(
        publishResultId: 'publish_no_callback_$now',
        localEventId: '',
        eventKind: 0,
        status: PublishResultStatus.failed,
        finalStatus: PublishResultStatus.failed,
        attemptedAt: now,
        retryCount: 0,
        requiredAckCount: 2,
        acceptedRelayCount: 0,
        failedRelayCount: 0,
        errorMessage: 'No transport callback registered',
        createdAt: now,
        updatedAt: now,
      );
    }
    return fn({
      'proposalId': proposalId,
      'cellId': cellId,
      'voteId': vote.voteId,
      'choiceName': vote.choice.name,
      'voterDid': vote.voterDid,
      'voterPseudonym': vote.voterPseudonym,
      'createdAt': vote.createdAt.millisecondsSinceEpoch ~/ 1000,
      if (vote.reasoning != null) 'reasoning': vote.reasoning,
      if (vote.selectedOptionId != null) 'selectedOptionId': vote.selectedOptionId,
    });
  }

  Future<PublishResult> _publishDecisionRecord({
    required String proposalId,
    required String cellId,
    required Map<String, dynamic> recordContent,
    required String result,
    required String contentHash,
    String? previousDecisionHash,
  }) async {
    final fn = onPublishDecisionToNostr;
    if (fn == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return PublishResult(
        publishResultId: 'publish_no_callback_$now',
        localEventId: '',
        eventKind: 0,
        status: PublishResultStatus.failed,
        finalStatus: PublishResultStatus.failed,
        attemptedAt: now,
        retryCount: 0,
        requiredAckCount: 2,
        acceptedRelayCount: 0,
        failedRelayCount: 0,
        errorMessage: 'No transport callback registered',
        createdAt: now,
        updatedAt: now,
      );
    }
    return fn({
      'proposalId': proposalId,
      'cellId': cellId,
      'recordContent': recordContent,
      'result': result,
      'contentHash': contentHash,
      'previousDecisionHash': previousDecisionHash,
    });
  }

  /// Phase G2.1.2: thin wrapper calling [onPublishDelegationToNostr].
  /// Returns a failed [PublishResult] when no callback is registered.
  Future<PublishResult> _publishDelegationToNostr(Delegation d) async {
    final fn = onPublishDelegationToNostr;
    if (fn == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return PublishResult(
        publishResultId: 'publish_no_callback_$now',
        localEventId: '',
        eventKind: 0,
        status: PublishResultStatus.failed,
        finalStatus: PublishResultStatus.failed,
        attemptedAt: now,
        retryCount: 0,
        requiredAckCount: 2,
        acceptedRelayCount: 0,
        failedRelayCount: 0,
        errorMessage: 'No transport callback registered',
        createdAt: now,
        updatedAt: now,
      );
    }
    return fn(d);
  }

  /// Returns the `content_hash` of the most recent DecisionRecord for a cell,
  /// or null if none exists yet. Used for the hash-chain in DecisionRecords.
  Future<String?> _getLastDecisionHashForCell(String cellId) async {
    final rows =
        await PodDatabase.instance.listDecisionRecords(cellId: cellId);
    if (rows.isEmpty) return null;
    // listDecisionRecords returns rows ordered DESC by decided_at.
    return rows.first['content_hash'] as String?;
  }

  Future<DecisionRecord?> _getDecisionRecordByProposal(
      String proposalId) async {
    final row = await PodDatabase.instance.getDecisionRecord(proposalId);
    if (row == null) return null;
    return DecisionRecord.fromMap(row);
  }

  // ── Discussion thread helper ───────────────────────────────────────────────

  Future<void> _createDiscussionThread(Proposal p) async {
    // Placeholder: in a future iteration this will post a message to the
    // cell's discussion Group Channel.
    print('[PROPOSAL] Discussion thread created in cell ${p.cellId}: "${p.title}"');
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  bool canVote(String proposalId, String userDid) {
    final proposal = _proposals[proposalId];
    if (proposal == null) return false;
    if (proposal.status != ProposalStatus.VOTING) return false;
    // TODO (Prompt 1B): verify userDid is a confirmed member of proposal.cellId
    return true;
  }

  bool canEdit(String proposalId, String userDid) {
    final proposal = _proposals[proposalId];
    if (proposal == null) return false;
    if (proposal.creatorDid != userDid) return false;
    return proposal.status == ProposalStatus.DRAFT ||
        proposal.status == ProposalStatus.DISCUSSION;
  }

  bool canStartVoting(String proposalId, String userDid) {
    final proposal = _proposals[proposalId];
    if (proposal == null) return false;
    if (proposal.status != ProposalStatus.DISCUSSION) return false;
    // TODO (Prompt 1B): check proposalWaitDays + role (creator or mod/founder)
    return true;
  }

  bool canArchive(String proposalId, String userDid) {
    final proposal = _proposals[proposalId];
    if (proposal == null) return false;
    if (proposal.status != ProposalStatus.DECIDED) return false;
    // TODO (Prompt 1B): check userDid is mod/founder
    return true;
  }

  bool canWithdraw(String proposalId, String userDid) {
    final proposal = _proposals[proposalId];
    if (proposal == null) return false;
    if (proposal.creatorDid != userDid) return false;
    return proposal.status == ProposalStatus.DRAFT ||
        proposal.status == ProposalStatus.DISCUSSION;
  }

  // ── Audit log ──────────────────────────────────────────────────────────────

  Future<void> addAuditEntry(AuditLogEntry entry) async {
    await _saveAuditEntryToDb(entry);
    _auditCtrl.add(entry);
    debugPrint('[AUDIT] Saving entry: ${entry.eventType}');
  }

  // ── Phase G2.1.3: Liquid Democracy tally aggregation ──────────────────────

  /// Loads eligible voter DIDs for a cell directly from the DB.
  /// Used as fallback when [Proposal.eligibleVoters] snapshot is null
  /// (legacy data pre-v22).
  Future<Set<String>> _loadEligibleVoterSet(String cellId) async {
    final rows = await PodDatabase.instance.listCellMembers(cellId);
    final members = rows.map(CellMember.fromJson).toList();
    return members.map((m) => m.did).toSet();
  }

  /// Phase G2.1.3: Augments [directVotes] with the effect of ACTIVE
  /// delegations for this proposal.
  ///
  /// Per §31.3 (Sender-only) this runs only on the tally-owner device.
  /// EXPIRED and INVALID classifications are RAM-only (D9 Variante A):
  /// the underlying delegation row is NEVER mutated. Audit entries
  /// DELEGATION_EXPIRED and DELEGATION_INVALIDATED are written for
  /// affected delegations.
  ///
  /// Returns a new list containing:
  ///   - all original direct votes (unchanged)
  ///   - plus synthetic [Vote] objects for each successfully aggregated
  ///     delegation, with [Vote.isDelegated]=true and
  ///     [Vote.delegatedFrom]=<delegateDid> (the delegate who voted directly).
  ///
  /// E4 (non-transitive): A's delegation to B counts only when B votes
  /// directly. B's own delegation to C does NOT propagate A's vote to C.
  Future<List<Vote>> _aggregateVotesWithDelegations({
    required List<Vote> directVotes,
    required String proposalId,
    required String cellId,
    required Set<String> eligibleVoters,
  }) async {
    // Step 1: Load ACTIVE delegations for this proposal.
    // listActiveDelegationsForProposal already orders by
    // (created_at ASC, delegation_id ASC) — deterministic per A.5.
    final delegationRows = await PodDatabase.instance
        .listActiveDelegationsForProposal(proposalId);

    // Step 2: Fast path — no delegations.
    if (delegationRows.isEmpty) {
      print('[TALLY-DELEGATION] proposalId=$proposalId '
          'activeDelegationsCount=0 aggregatedCount=0 '
          'expiredCount=0 invalidCount=0 ignoredByDirectVoteCount=0');
      return directVotes;
    }

    final activeDelegations =
        delegationRows.map(Delegation.fromMap).toList();

    // Step 3: Build direct voter DID set for O(1) lookup.
    final directVoterDids = directVotes.map((v) => v.voterDid).toSet();

    // Step 4: Iterate deterministically (already sorted by DB query).
    final syntheticVotes = <Vote>[];
    int expiredCount = 0;
    int invalidCount = 0;
    int ignoredByDirectVoteCount = 0;

    for (final d in activeDelegations) {
      // Step 5a: INVALID — delegator not in eligibleVoters.
      if (!eligibleVoters.contains(d.delegatorDid)) {
        await addAuditEntry(AuditLogEntry(
          entryId: AuditLogEntry.generateId(),
          proposalId: proposalId,
          cellId: cellId,
          eventType: AuditEventType.DELEGATION_INVALIDATED,
          actorDid: 'SYSTEM',
          actorPseudonym: '',
          timestamp: DateTime.now().toUtc(),
          payload: {
            'delegationId': d.delegationId,
            'reason': 'DELEGATOR_NOT_ELIGIBLE',
            'delegatorDid': d.delegatorDid,
          },
        ));
        print('[TALLY-DELEGATION-INVALID] delegationId=${d.delegationId} '
            'reason=delegator-not-eligible');
        invalidCount++;
        continue;
      }

      // Step 5b: INVALID — delegate not in eligibleVoters.
      if (!eligibleVoters.contains(d.delegateDid)) {
        await addAuditEntry(AuditLogEntry(
          entryId: AuditLogEntry.generateId(),
          proposalId: proposalId,
          cellId: cellId,
          eventType: AuditEventType.DELEGATION_INVALIDATED,
          actorDid: 'SYSTEM',
          actorPseudonym: '',
          timestamp: DateTime.now().toUtc(),
          payload: {
            'delegationId': d.delegationId,
            'reason': 'DELEGATE_NOT_ELIGIBLE',
            'delegateDid': d.delegateDid,
          },
        ));
        print('[TALLY-DELEGATION-INVALID] delegationId=${d.delegationId} '
            'reason=delegate-not-eligible');
        invalidCount++;
        continue;
      }

      // Step 5c: Direct-vote-overrides-delegation consistency.
      // Delegator has already cast a direct vote (e.g. multi-device race
      // or auto-revoke not yet propagated). The direct vote wins.
      // No audit entry — this is a normal consistency path.
      if (directVoterDids.contains(d.delegatorDid)) {
        print('[TALLY-DELEGATION-IGNORED] delegationId=${d.delegationId} '
            'reason=direct-vote-by-delegator');
        ignoredByDirectVoteCount++;
        continue;
      }

      // Step 5d: EXPIRED — delegate did not cast a direct vote.
      if (!directVoterDids.contains(d.delegateDid)) {
        await addAuditEntry(AuditLogEntry(
          entryId: AuditLogEntry.generateId(),
          proposalId: proposalId,
          cellId: cellId,
          eventType: AuditEventType.DELEGATION_EXPIRED,
          actorDid: 'SYSTEM',
          actorPseudonym: '',
          timestamp: DateTime.now().toUtc(),
          payload: {
            'delegationId': d.delegationId,
            'reason': 'DELEGATE_DID_NOT_VOTE',
            'delegateDid': d.delegateDid,
          },
        ));
        print('[TALLY-DELEGATION-EXPIRED] delegationId=${d.delegationId}');
        expiredCount++;
        continue;
      }

      // Step 5e: Success — synthesise a vote for the delegator using
      // the delegate's choice/selectedOptionId.
      // G2.1.4a: voterPseudonym resolved via ContactService; weight and
      // voiceCredits are always 1 (Liquid Democracy: one vote per delegator,
      // no weight amplification regardless of the delegate's own weight).
      final delegateVote =
          directVotes.firstWhere((v) => v.voterDid == d.delegateDid);
      final delegatorPseudonym =
          _resolveDelegatorPseudonym(d.delegatorDid);
      final syntheticVote = Vote(
        voteId: 'delegated-${d.delegationId}',
        proposalId: proposalId,
        voterPubkey: '',
        voterDid: d.delegatorDid,
        voterPseudonym: delegatorPseudonym,
        choice: delegateVote.choice,
        weight: 1,
        voiceCredits: 1,
        reasoning: null,
        createdAt: delegateVote.createdAt,
        isDelegated: true,
        delegatedFrom: d.delegateDid,
        nostrEventId: '',
        selectedOptionId: delegateVote.selectedOptionId,
      );
      print('[TALLY-DELEGATION-AGGREGATED] delegationId=${d.delegationId} '
          'from=${d.delegatorDid}:$delegatorPseudonym via=${d.delegateDid} '
          'choice=${delegateVote.choice.name}');
      syntheticVotes.add(syntheticVote);
    }

    // Step 6: Summary log.
    print('[TALLY-DELEGATION] proposalId=$proposalId '
        'activeDelegationsCount=${activeDelegations.length} '
        'aggregatedCount=${syntheticVotes.length} '
        'expiredCount=$expiredCount '
        'invalidCount=$invalidCount '
        'ignoredByDirectVoteCount=$ignoredByDirectVoteCount');

    // Return directVotes + synthetic votes.
    // No re-sort here — callers apply sortVotesDeterministic when needed.
    return [...directVotes, ...syntheticVotes];
  }

  /// Phase G2.1.4a: Resolve the display name of a delegator for the
  /// synthetic vote's voterPseudonym field.
  ///
  /// ContactService.getDisplayName returns the stored pseudonym for known
  /// contacts, or a 12-character DID fragment as a fallback for unknown
  /// ones. Both are acceptable per Joachim's Variante-A decision (recon R2).
  /// The cell_members fallback was dropped after recon R3 — CellMember has
  /// no pseudonym field.
  ///
  /// voterPseudonym is NOT part of the contentHash input (recon R4), so
  /// different values across devices cause no hash divergence.
  static String _resolveDelegatorPseudonym(String delegatorDid) {
    try {
      return ContactService.instance.getDisplayName(delegatorDid);
    } catch (_) {
      return '';
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  Future<void> deleteAllProposalsForCell(String cellId) async {
    debugPrint('[PROPOSAL] Deleting all data for cell: $cellId');
    // Tombstone all proposals for this cell BEFORE DB delete.
    final toTombstone =
        _proposals.values.where((p) => p.cellId == cellId).map((p) => p.id).toList();
    for (final id in toTombstone) {
      await _addTombstone(id);
    }
    debugPrint('[PROPOSAL] Tombstoned ${toTombstone.length} proposals for cell $cellId');
    await PodDatabase.instance.deleteAllProposalDataForCell(cellId);
    _proposals.removeWhere((_, p) => p.cellId == cellId);
    _votes.removeWhere((id, _) => !_proposals.containsKey(id));
    _notify();
  }

  // ── Status advancement (G1 compat, replaces _advanceStatuses) ─────────────

  void _advanceStatuses() {
    final now = DateTime.now().toUtc();
    for (final p in _proposals.values) {
      switch (p.status) {
        case ProposalStatus.DISCUSSION:
          // Auto-advance if votingEndsAt was set via legacy discussionDeadline.
          // G2 advancement is driven by explicit startVoting() calls (Prompt 1B).
          break;
        case ProposalStatus.VOTING:
          if (p.votingEndsAt != null && now.isAfter(p.votingEndsAt!)) {
            p.status = ProposalStatus.VOTING_ENDED;
            _saveProposalToDb(p);
            _notifyAllMembers(
              p.cellId,
              title: 'Abstimmung beendet',
              body: p.title,
              payload: 'proposal:${p.id}',
            );
          }
        case ProposalStatus.DECIDED:
          if (p.decidedAt != null &&
              now.difference(p.decidedAt!).inDays >= 30) {
            p.status = ProposalStatus.ARCHIVED;
            p.archivedAt = now;
            _saveProposalToDb(p);
          }
        default:
          break;
      }
    }
  }

  // ── DB helpers ─────────────────────────────────────────────────────────────

  Future<void> _saveProposalToDb(Proposal proposal) async {
    debugPrint('[PROPOSAL] Saving to DB: ${proposal.id}');
    await PodDatabase.instance.upsertProposal(
      proposal.id,
      proposal.cellId,
      proposal.toMap(),
    );
  }

  /// Deletes a proposal AND its audit log from the local DB.
  ///
  /// This is destructive for the audit trail. Per G2 spec §18,
  /// audit logs are append-only and must not be deleted.
  ///
  /// USE ONLY in the local cell-teardown path: when the entire
  /// enclosing cell is being removed from THIS device (cell
  /// dissolution applied locally, user leaves the cell completely).
  /// In all other cases — including withdraw, decision finalization,
  /// receive-WITHDRAWN, debug cleanup, and per-proposal removal —
  /// use _deleteProposalKeepingAudit.
  Future<void> _deleteProposalIncludingAudit(String proposalId) async {
    debugPrint('[PROPOSAL] LOCAL TEARDOWN delete (audit cascaded): $proposalId');
    await PodDatabase.instance.deleteProposal(proposalId);
    await PodDatabase.instance.deleteVotesForProposal(proposalId);
    await PodDatabase.instance.deleteEditsForProposal(proposalId);
    await PodDatabase.instance.deleteAuditLogForProposal(proposalId);
    await PodDatabase.instance.deleteDecisionRecord(proposalId);
  }

  Future<void> _deleteProposalKeepingAudit(String proposalId) async {
    debugPrint('[PROPOSAL] Deleting from DB (keeping audit log): $proposalId');
    await PodDatabase.instance.deleteProposal(proposalId);
    await PodDatabase.instance.deleteVotesForProposal(proposalId);
    await PodDatabase.instance.deleteEditsForProposal(proposalId);
    // NOTE: deleteAuditLogForProposal nicht aufrufen — append-only per G2 §18.
    await PodDatabase.instance.deleteDecisionRecord(proposalId);
  }

  Future<void> _saveAuditEntryToDb(AuditLogEntry entry) async {
    await PodDatabase.instance.insertAuditEntry(entry.toMap());
  }

  Future<void> _saveEditToDb(ProposalEdit edit) async {
    await PodDatabase.instance.insertProposalEdit(edit.toMap());
  }

  Future<void> _saveVoteToDb(Vote vote) async {
    // upsertVote uses REPLACE conflict algorithm on UNIQUE(proposal_id,
    // voter_pubkey), so this handles both insert and change-vote.
    await PodDatabase.instance.upsertVote(vote.toMap());
  }

  Future<void> _saveDecisionRecordToDb(DecisionRecord record) async {
    await PodDatabase.instance.insertDecisionRecord(record.toMap());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _checkCanCreateProposal(String cellId, String myDid) {
    final membership = CellService.instance.myMembershipIn(cellId);
    if (membership == null || !membership.isConfirmed) {
      throw StateError(
          'Must be a confirmed cell member to create proposals.');
    }
    if (membership.role == MemberRole.pending) {
      throw StateError('Pending members cannot create proposals.');
    }

    final cell = CellService.instance.myCells
        .where((c) => c.id == cellId)
        .firstOrNull;
    if (cell == null) return;

    if (cell.proposalWaitDays > 0) {
      final waitedDays =
          DateTime.now().toUtc().difference(membership.joinedAt).inDays;
      if (waitedDays < cell.proposalWaitDays) {
        throw StateError(
            'Must wait ${cell.proposalWaitDays - waitedDays} more day(s) before creating proposals.');
      }
    }
  }

  Future<void> _notifyAllMembers(
    String cellId, {
    required String title,
    required String body,
    String? payload,
    String? excludeDid,
  }) async {
    // excludeDid is reserved for future per-member push; currently we show one
    // local notification and skip it if the actor is the current user.
    final myDid = IdentityService.instance.currentIdentity?.did;
    if (excludeDid != null && excludeDid == myDid) return;
    try {
      await NotificationService.instance.showGenericNotification(
        title: title,
        body: body,
        payload: payload,
      );
    } catch (_) {}
  }

  void _notify() => _streamCtrl.add(null);

  // ── Phase 4.8: Runoff auto-creation ──────────────────────────────────────

  /// Phase 4.8: auto-creates a SINGLE_CHOICE runoff proposal for a tied tally.
  ///
  /// Sender-only: only the device that performed the tally (and thus reached
  /// this code path) creates the runoff. Other devices receive the runoff via
  /// the standard proposal Nostr pipeline (Phase 4.7c2 with proposalOptions).
  ///
  /// The runoff is published in DISCUSSION status so it is visible to all
  /// members but not yet in VOTING. A Founder/Admin starts the runoff vote
  /// through the normal startVoting flow.
  Future<void> _createRunoffProposal({
    required Proposal originalProposal,
    required DecisionRecord decisionRecord,
  }) async {
    final originalId = originalProposal.id;

    // 1) Idempotency: has this device already created a runoff for this
    //    original? Backed by SharedPreferences (Phase 4.8 Variante 2-Light;
    //    no DB migration required). Cross-session persistent on this device.
    if (await _runoffExistsFor(originalId)) {
      print('[RUNOFF] runoff already exists for $originalId, skipping');
      return;
    }

    // 2) Resolve tie option IDs from the DecisionRecord JSON.
    final tieOptionIds = _parseTieOptionIds(decisionRecord.tieOptionIdsJson);
    if (tieOptionIds.length < 2) {
      print('[RUNOFF] WARN unexpected tie size '
          '(${tieOptionIds.length}) for $originalId — '
          'aborting runoff creation');
      return;
    }

    // 3) Look up the original option labels for the tied IDs.
    final originalOptionRows =
        await PodDatabase.instance.listProposalOptions(originalId);
    final originalOptions =
        originalOptionRows.map(ProposalOption.fromMap).toList();
    final tieLabels = <String>[];
    for (final id in tieOptionIds) {
      ProposalOption? matched;
      for (final opt in originalOptions) {
        if (opt.optionId == id) {
          matched = opt;
          break;
        }
      }
      if (matched != null) tieLabels.add(matched.label);
    }
    if (tieLabels.length < 2) {
      print('[RUNOFF] WARN could not resolve tie labels '
          'for $originalId, aborting');
      return;
    }

    // 4) Build title + description.
    final runoffTitle = 'Stichwahl: ${originalProposal.title}';
    final runoffDescription = _buildRunoffDescription(
      original: originalProposal,
      tieLabels: tieLabels,
    );

    // 5) Creator identity: must use the local device DID for Nostr signing.
    //    Pseudonym is the system constant to avoid tally-owner disclosure.
    final localIdentity = IdentityService.instance.currentIdentity;
    if (localIdentity == null) {
      print('[RUNOFF] no local identity — cannot publish, aborting');
      return;
    }

    // 6) createDraft → publishToDiscussion.
    //    SINGLE_CHOICE with exactly the tied option labels preserved.
    final draft = await createDraft(
      cellId: originalProposal.cellId,
      creatorDid: localIdentity.did,
      creatorPseudonym: _kRunoffSystemPseudonym,
      title: runoffTitle,
      description: runoffDescription,
      category: originalProposal.category,
      type: originalProposal.proposalType,
      votingMode: VotingMode.SINGLE_CHOICE,
      initialOptionLabels: tieLabels,
    );

    print('[RUNOFF] draft ${draft.id} created for original '
        '$originalId, advancing to DISCUSSION');

    await publishToDiscussion(draft.id);
    await _markRunoffCreated(originalId);

    print('[RUNOFF] runoff ${draft.id} published to DISCUSSION '
        'for original $originalId');
  }

  /// Phase 4.8: returns true if this device has already created a runoff
  /// proposal for [originalProposalId].
  ///
  /// Backed by SharedPreferences (Variante 2-Light — no DB migration needed).
  Future<bool> _runoffExistsFor(String originalProposalId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kRunoffCreatedKey) ?? [];
    return ids.contains(originalProposalId);
  }

  /// Phase 4.8: records [originalProposalId] in SharedPreferences so that
  /// a future call to [_runoffExistsFor] returns true for this ID.
  Future<void> _markRunoffCreated(String originalProposalId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kRunoffCreatedKey) ?? [];
    if (!ids.contains(originalProposalId)) {
      ids.add(originalProposalId);
      await prefs.setStringList(_kRunoffCreatedKey, ids);
    }
  }

  /// Phase 4.8: parses [tieOptionIdsJson] into a list of option ID strings.
  /// Returns an empty list on null, empty string, or malformed JSON.
  List<String> _parseTieOptionIds(String? tieOptionIdsJson) {
    if (tieOptionIdsJson == null || tieOptionIdsJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(tieOptionIdsJson);
      if (decoded is List) return List<String>.from(decoded);
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Phase 4.8: builds the human-readable description for a runoff proposal.
  /// Embeds the original proposal ID as a plain-text reference for traceability
  /// (no model field required; UI linkage can be added in a later phase).
  String _buildRunoffDescription({
    required Proposal original,
    required List<String> tieLabels,
  }) {
    final buf = StringBuffer();
    buf.writeln('Diese Stichwahl folgt aus einer unentschiedenen '
        'Abstimmung im Original-Antrag.');
    buf.writeln();
    buf.writeln('Original-Antrag: "${original.title}"');
    buf.writeln('Original-ID: ${original.id}');
    buf.writeln();
    buf.writeln('Zur Auswahl stehen die unentschiedenen '
        'Kandidaten/Optionen:');
    for (final label in tieLabels) {
      buf.writeln('  • $label');
    }
    return buf.toString();
  }

  // ── Test hooks (visibleForTesting only) ───────────────────────────────────

  @visibleForTesting
  void injectProposalForTest(Proposal p) => _proposals[p.id] = p;

  @visibleForTesting
  void resetForTest() {
    _proposals.clear();
    _votes.clear();
  }
}

/// DateTimeRange helper (used in getArchivedProposals filter).
/// Avoids a Flutter material dependency here — UI code passes this in.
class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
}
