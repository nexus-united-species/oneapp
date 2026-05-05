import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'proposal_option.dart';
import 'vote.dart';

// ── ResultReason ─────────────────────────────────────────────────────────────

/// Reasons why a [DecisionRecord] may have result = INVALID.
/// Per G2 spec v1.3 §20.8.
///
/// Stored as raw String values. A typed enum may be introduced in a
/// later phase if validation at multiple call-sites warrants it.
class ResultReason {
  ResultReason._(); // prevent instantiation

  static const String quorumNotMet = 'QUORUM_NOT_MET';
  static const String noValidVotes = 'NO_VALID_VOTES';
  static const String allAbstain = 'ALL_ABSTAIN';
  static const String tieRequiresRunoff = 'TIE_REQUIRES_RUNOFF';
  static const String winnerWithdrawn = 'WINNER_WITHDRAWN';
  static const String allCandidatesWithdrawn = 'ALL_CANDIDATES_WITHDRAWN';
  static const String withdrawnDuringVoting = 'WITHDRAWN_DURING_VOTING';
  static const String withdrawnByModeration = 'WITHDRAWN_BY_MODERATION';

  /// All valid resultReason values for runtime validation.
  static const Set<String> all = {
    quorumNotMet,
    noValidVotes,
    allAbstain,
    tieRequiresRunoff,
    winnerWithdrawn,
    allCandidatesWithdrawn,
    withdrawnDuringVoting,
    withdrawnByModeration,
  };
}

// ── Deterministic sort helpers ────────────────────────────────────────────────

/// Sorts votes deterministically: [Vote.createdAt] ASC, then [Vote.voteId]
/// ASC as tiebreaker.
///
/// Used for tally inputs to ensure reproducible content hashes per G2
/// spec v1.1 (deterministic tally inputs). Does not mutate [votes].
List<Vote> sortVotesDeterministic(List<Vote> votes) {
  final sorted = [...votes];
  sorted.sort((a, b) {
    final cmp = a.createdAt.compareTo(b.createdAt);
    if (cmp != 0) return cmp;
    return a.voteId.compareTo(b.voteId);
  });
  return sorted;
}

/// Sorts proposal options deterministically: [ProposalOption.position] ASC,
/// then [ProposalOption.optionId] ASC as tiebreaker.
///
/// Used for tally inputs to ensure reproducible content hashes per G2
/// spec v1.1. Does not mutate [options].
List<ProposalOption> sortOptionsDeterministic(List<ProposalOption> options) {
  final sorted = [...options];
  sorted.sort((a, b) {
    final cmp = a.position.compareTo(b.position);
    if (cmp != 0) return cmp;
    return a.optionId.compareTo(b.optionId);
  });
  return sorted;
}

// ── Canonical JSON encoding ───────────────────────────────────────────────────

/// Encodes a Dart value to canonical JSON for hashing purposes.
///
/// Determinism rules:
/// - Map keys **must** be Strings — a non-String key throws [ArgumentError].
///   Silent `toString()` conversion is forbidden: it could produce incorrect
///   lookups and falsify audit hashes.
/// - Map keys are sorted alphabetically (case-sensitive ASCII, recursive).
/// - List order is preserved (caller must pre-sort lists when order must
///   not matter).
/// - Strings: standard JSON escaping via [jsonEncode] from dart:convert
///   (handles `"`, `\`, control chars, Unicode correctly and stably).
/// - Integers: no decimal point (e.g. `7`).
/// - Doubles: Dart's default representation. For fractional fields where
///   floating-point drift matters (e.g. `participation`), callers must
///   pre-format as a fixed-precision String before encoding.
/// - bool / null: `true`, `false`, `null`.
/// - No whitespace, no trailing newline.
///
/// Throws [ArgumentError] on unsupported types (e.g. [DateTime], custom
/// classes) — caller must convert to String / num / bool / null / List /
/// Map<String, ...> first.
String canonicalJsonEncode(dynamic value) {
  final buffer = StringBuffer();
  _writeCanonical(buffer, value);
  return buffer.toString();
}

void _writeCanonical(StringBuffer buf, dynamic value) {
  if (value == null) {
    buf.write('null');
  } else if (value is bool) {
    buf.write(value ? 'true' : 'false');
  } else if (value is num) {
    buf.write(value.toString());
  } else if (value is String) {
    // dart:convert's jsonEncode provides correct, stable escaping for
    // control characters, quotes, backslashes, Unicode surrogates, etc.
    buf.write(jsonEncode(value));
  } else if (value is List) {
    buf.write('[');
    for (var i = 0; i < value.length; i++) {
      if (i > 0) buf.write(',');
      _writeCanonical(buf, value[i]);
    }
    buf.write(']');
  } else if (value is Map) {
    // Collect entries, enforcing String-only keys.
    // We iterate via entries and use entry.value directly — never via
    // key.toString() — to avoid incorrect null-lookups on non-String keys.
    final sortedEntries = <MapEntry<String, dynamic>>[];
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError(
          'canonicalJsonEncode requires String keys in Maps. '
          'Found key of type ${entry.key.runtimeType}: ${entry.key}',
        );
      }
      sortedEntries.add(MapEntry(entry.key as String, entry.value));
    }
    // Case-sensitive ASCII sort (stable ordering per canonical JSON spec).
    sortedEntries.sort((a, b) => a.key.compareTo(b.key));
    buf.write('{');
    for (var i = 0; i < sortedEntries.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(jsonEncode(sortedEntries[i].key));
      buf.write(':');
      _writeCanonical(buf, sortedEntries[i].value);
    }
    buf.write('}');
  } else {
    throw ArgumentError(
      'canonicalJsonEncode does not support ${value.runtimeType}. '
      'Convert to String, num, bool, null, List, or Map<String, ...> first.',
    );
  }
}

// ── Content hash ─────────────────────────────────────────────────────────────

/// Computes a SHA-256 content hash over the canonical JSON representation
/// of [data]. Returns a lowercase 64-character hex string.
///
/// CONTRACT — fields included in the contentHash for [DecisionRecord]
/// (per Phase 4.1b spec):
///
///   proposalId, cellId, votingMode, result, resultReason,
///   resultRelation, yesVotes, noVotes, abstainVotes,
///   participation, eligibleVotersCount, decidedAt (ISO-8601),
///   previousProposalId, previousDecisionHash, finalTitle,
///   finalDescription, optionResultsJson, tieOptionIdsJson
///
/// NOT included in [data] (caller must omit):
///   - recordId      (random UUID — not part of content integrity)
///   - nostrEventId  (assigned by relay in Phase 4.5, after hashing)
///   - allVotes      (individual vote IDs are random; vote content is
///                    represented through the aggregated yesVotes /
///                    noVotes / abstainVotes counts)
///
/// Determinism notes for callers:
/// - [DateTime] fields must be passed as ISO-8601 strings, e.g.
///   `decidedAt.toUtc().toIso8601String()`.
/// - `participation` (double) must be pre-formatted to a fixed decimal
///   precision (recommended: 4 digits, e.g. `"0.6500"`) to avoid
///   floating-point representation differences across platforms.
/// - null fields must be explicitly present in [data] as `null` values
///   (do not omit them — a missing key and a null value hash differently).
/// - JSON string fields like `optionResultsJson` / `tieOptionIdsJson`
///   should be passed as their raw String value (or null), not re-parsed.
///
/// Phase 4.5 may add a complementary `structuralHash` that excludes
/// content fields (finalTitle, finalDescription) for public verifiability
/// without cell-key access.
String computeContentHash(Map<String, dynamic> data) {
  final canonical = canonicalJsonEncode(data);
  final bytes = utf8.encode(canonical);
  return sha256.convert(bytes).toString();
}
