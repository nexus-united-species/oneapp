import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/pod_database.dart';
import 'publish_result.dart';

/// Data Access Object for the publish_results table.
///
/// Provides typed access to publish lifecycle records.
/// All methods are async and use try/catch with [PUBLISH-RESULT]
/// logging tag.
///
/// DB access goes through [PodDatabase.instance.testDb], which is
/// the public getter for the underlying sqflite [Database] instance.
// Strip 'publish_' prefix, then return first 8 chars of the remaining hash.
// Falls back to the full stripped string if shorter than 8 chars.
String _shortIdForLog(String publishResultId) {
  final stripped = publishResultId.startsWith('publish_')
      ? publishResultId.substring(8)
      : publishResultId;
  return stripped.length >= 8 ? stripped.substring(0, 8) : stripped;
}

class PublishResultDao {
  PublishResultDao._();
  static final PublishResultDao instance = PublishResultDao._();

  Database get _db => PodDatabase.instance.testDb;

  /// Inserts a new [PublishResult] into publish_results.
  ///
  /// On PRIMARY KEY conflict: logs the error, does not throw.
  Future<void> insert(PublishResult result) async {
    try {
      final id = _shortIdForLog(result.publishResultId);
      await _db.insert(
        'publish_results',
        result.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      debugPrint('[PUBLISH-RESULT] insert id=$id status=${result.status}');
    } catch (e) {
      debugPrint('[PUBLISH-RESULT] insert error: $e');
    }
  }

  /// Updates an existing [PublishResult] by publish_result_id.
  ///
  /// Automatically sets updated_at to the current timestamp before writing.
  Future<void> update(PublishResult result) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = result.copyWith(updatedAt: now);
      final id = _shortIdForLog(result.publishResultId);
      await _db.update(
        'publish_results',
        updated.toMap(),
        where: 'publish_result_id = ?',
        whereArgs: [result.publishResultId],
      );
      debugPrint('[PUBLISH-RESULT] update id=$id status=${result.status}');
    } catch (e) {
      debugPrint('[PUBLISH-RESULT] update error: $e');
    }
  }

  /// Returns the first record matching [localEventId], or null if not found.
  Future<PublishResult?> findByLocalEventId(String localEventId) async {
    try {
      final rows = await _db.query(
        'publish_results',
        where: 'local_event_id = ?',
        whereArgs: [localEventId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return PublishResult.fromMap(rows.first);
    } catch (e) {
      debugPrint('[PUBLISH-RESULT] findByLocalEventId error: $e');
      return null;
    }
  }

  /// Returns all records with status RETRYING whose next_retry_at is due.
  ///
  /// [now] — current time in milliseconds since epoch.
  Future<List<PublishResult>> findRetryDue(int now) async {
    try {
      final rows = await _db.query(
        'publish_results',
        where: "status = 'RETRYING' AND next_retry_at <= ?",
        whereArgs: [now],
        orderBy: 'next_retry_at ASC',
      );
      return rows.map(PublishResult.fromMap).toList();
    } catch (e) {
      debugPrint('[PUBLISH-RESULT] findRetryDue error: $e');
      return [];
    }
  }

  /// Returns all in-flight records for a given [proposalId].
  ///
  /// Statuses included: PENDING, PARTIAL, RETRYING.
  Future<List<PublishResult>> findPendingByProposal(String proposalId) async {
    try {
      final rows = await _db.query(
        'publish_results',
        where: "proposal_id = ? AND status IN ('PENDING', 'PARTIAL', 'RETRYING')",
        whereArgs: [proposalId],
        orderBy: 'created_at DESC',
      );
      return rows.map(PublishResult.fromMap).toList();
    } catch (e) {
      debugPrint('[PUBLISH-RESULT] findPendingByProposal error: $e');
      return [];
    }
  }
}
