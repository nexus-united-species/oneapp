import 'dart:async';
import 'dart:convert';

import '../../storage/pod_database.dart';
import 'nostr_event.dart';
import 'publish_result.dart';

/// Persistence for [NostrOutbox]: signed events waiting for a relay.
abstract interface class NostrOutboxStore {
  Future<void> put(NostrEvent event);
  Future<List<NostrEvent>> pending();
  Future<void> remove(String eventId);
}

/// Non-persistent store, used where no database is available (tests).
class MemoryNostrOutboxStore implements NostrOutboxStore {
  final Map<String, NostrEvent> _events = {};

  @override
  Future<void> put(NostrEvent event) async => _events[event.id] = event;

  @override
  Future<List<NostrEvent>> pending() async => List.of(_events.values);

  @override
  Future<void> remove(String eventId) async => _events.remove(eventId);
}

/// Encrypted store in the local POD database (survives app restarts).
class PodNostrOutboxStore implements NostrOutboxStore {
  @override
  Future<void> put(NostrEvent event) => PodDatabase.instance.putOutboxEvent(
        eventId: event.id,
        kind: event.kind,
        json: jsonEncode(event.toJson()),
      );

  @override
  Future<List<NostrEvent>> pending() async {
    final events = <NostrEvent>[];
    for (final json in await PodDatabase.instance.listOutboxEvents()) {
      try {
        events.add(
          NostrEvent.fromJson(jsonDecode(json) as Map<String, dynamic>),
        );
      } on FormatException catch (e) {
        print('[OUTBOX] Unreadable stored event skipped: $e');
      } on TypeError catch (e) {
        print('[OUTBOX] Unreadable stored event skipped: $e');
      }
    }
    return events;
  }

  @override
  Future<void> remove(String eventId) =>
      PodDatabase.instance.deleteOutboxEvent(eventId);
}

/// Publishes a signed event to the relay pool.
typedef NostrEventPublisher = Future<RelayPublishOutcome> Function(
  NostrEvent event,
);

/// What one publish attempt means for a queued event (device test
/// 16.11.2026).
enum PublishVerdict {
  /// A relay accepted it, or already had it (`duplicate:`).
  accepted,

  /// No relay will ever take it in this form: `replaced:` (a newer version
  /// of a replaceable event exists), `invalid:` (e.g. too large),
  /// `blocked:`, `restricted:`, `pow:` or `deleted:`. Kept, it would be
  /// resent on every reconnect forever and get the client rate-limited.
  final_,

  /// Nobody answered, or only temporary refusals (`rate-limited:`,
  /// `banned:` … `try again later`, `error:`): keep and retry.
  retry,
}

/// Prefixes NIP-01 relays use for refusals that a resend cannot change.
const List<String> _finalRejectionPrefixes = [
  'replaced:',
  'invalid:',
  'blocked:',
  'restricted:',
  'pow:',
  'deleted:',
];

/// Classifies a relay [outcome] (device test 16.11.2026).
PublishVerdict verdictFor(RelayPublishOutcome outcome) {
  if (outcome.acceptedCount > 0) return PublishVerdict.accepted;
  final reasons =
      outcome.rejections.values.map((r) => r.trim().toLowerCase()).toList();
  if (reasons.any((r) => r.startsWith('duplicate:'))) {
    return PublishVerdict.accepted;
  }
  if (reasons.any((r) => _finalRejectionPrefixes.any(r.startsWith))) {
    return PublishVerdict.final_;
  }
  return PublishVerdict.retry;
}

/// Keeps chat events that no relay accepted and publishes them again once a
/// relay is reachable (TD-74: offline-first; before, such a DM was lost).
///
/// Events are stored signed and resent unchanged, so their event ID stays
/// the same; relays and receivers deduplicate repeated deliveries.
class NostrOutbox {
  NostrOutbox(this._store, this._publish);

  final NostrOutboxStore _store;
  final NostrEventPublisher _publish;
  bool _flushing = false;
  final _accepted = StreamController<String>.broadcast();
  final _rejected =
      StreamController<({String eventId, String reason})>.broadcast();

  /// IDs of events a relay accepted, right away or later from the queue
  /// (audit Z-4: the chat shows „gesendet“ only then).
  Stream<String> get onAccepted => _accepted.stream;

  /// Events no relay will take (e.g. `invalid: event too large`), so the
  /// chat can show them as not sent instead of „wartet“ forever. A
  /// `replaced:` refusal is not reported: a newer version exists.
  Stream<({String eventId, String reason})> get onRejected =>
      _rejected.stream;

  /// How many queued events are resent at the same time; a relay that never
  /// answers would otherwise hold up the queue for its timeout per event.
  static const int flushConcurrency = 8;

  /// Largest event sent at all, in bytes of its JSON. Our relay accepts
  /// 512 KB per event and 640 KB per WebSocket frame; anything larger made
  /// every relay drop the connection without an answer, so the event was
  /// queued and broke the connections again on each reconnect (device test
  /// 16.11.2026: a 45-second voice message from Windows).
  static const int maxEventBytes = 500 * 1024;

  /// Size of [event] as sent to a relay.
  static int sizeOf(NostrEvent event) =>
      utf8.encode(jsonEncode(event.toJson())).length;

  /// Everything that must not get lost while offline (audit Z-5): chat,
  /// Dorfplatz, profile, channels, cells and founding permits. Replaceable
  /// events are harmless to resend: relays keep the newest. Excluded:
  /// presence (sent again every few minutes anyway) and governance events
  /// (31010–31013, retried through their own publish results).
  static const Set<int> queuedKinds = {
    NostrKind.metadata,
    NostrKind.textNote,
    NostrKind.encryptedDm,
    NostrKind.deletion,
    NostrKind.repost,
    NostrKind.reaction,
    NostrKind.channelCreate,
    NostrKind.channelMetadata,
    NostrKind.channelMessage,
    NostrKind.cellAnnounce,
    NostrKind.cellJoinRequest,
    NostrKind.cellMembershipConfirmed,
    NostrKind.cellMemberUpdate,
    NostrKind.cellFoundingPermit,
    NostrKind.cellRoster,
  };

  /// Events older than this are dropped instead of resent.
  static const Duration maxAge = Duration(days: 7);

  /// Publishes [event]; keeps it for [flush] if no relay accepted it and a
  /// later attempt may still succeed.
  Future<void> publish(NostrEvent event) async {
    final verdict = await _tryPublish(event);
    if (verdict != PublishVerdict.retry) return;
    if (!queuedKinds.contains(event.kind)) return;
    try {
      await _store.put(event);
      print('[OUTBOX] Queued kind=${event.kind} '
          'id=${event.id.substring(0, 8)}… (no relay accepted it)');
    } on Exception catch (e) {
      print('[OUTBOX] Could not queue ${event.id.substring(0, 8)}…: $e');
    } on StateError catch (e) {
      print('[OUTBOX] Could not queue ${event.id.substring(0, 8)}…: $e');
    }
  }

  /// Resends all queued events; returns how many a relay accepted. Events
  /// refused for good are removed. Up to [flushConcurrency] events go out at
  /// once. Concurrent calls (several relays connecting) run only once.
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    try {
      final pending = await _store.pending();
      if (pending.isEmpty) return 0;
      final cutoff =
          DateTime.now().subtract(maxAge).toUtc().millisecondsSinceEpoch ~/
              1000;
      var delivered = 0;
      var dropped = 0;
      final due = <NostrEvent>[];
      for (final event in pending) {
        if (event.createdAt < cutoff) {
          await _store.remove(event.id);
          print('[OUTBOX] Dropped expired id=${event.id.substring(0, 8)}…');
        } else {
          due.add(event);
        }
      }
      for (var i = 0; i < due.length; i += flushConcurrency) {
        final batch = due.skip(i).take(flushConcurrency).toList();
        final verdicts = await Future.wait(batch.map(_tryPublish));
        for (var j = 0; j < batch.length; j++) {
          if (verdicts[j] == PublishVerdict.retry) continue;
          await _store.remove(batch[j].id);
          if (verdicts[j] == PublishVerdict.accepted) {
            delivered++;
          } else {
            dropped++;
          }
        }
      }
      print('[OUTBOX] Flush: $delivered/${pending.length} delivered'
          '${dropped > 0 ? ', $dropped refused for good and removed' : ''}');
      return delivered;
    } finally {
      _flushing = false;
    }
  }

  /// One attempt; reports acceptance and final refusals on the streams.
  Future<PublishVerdict> _tryPublish(NostrEvent event) async {
    final size = sizeOf(event);
    if (size > maxEventBytes) {
      final reason = 'too large: $size bytes (limit $maxEventBytes)';
      print('[OUTBOX] Not sent kind=${event.kind} '
          'id=${event.id.substring(0, 8)}…: $reason');
      _rejected.add((eventId: event.id, reason: reason));
      return PublishVerdict.final_;
    }
    final RelayPublishOutcome outcome;
    try {
      outcome = await _publish(event);
    } on Exception catch (e) {
      print('[OUTBOX] Publish failed for ${event.id.substring(0, 8)}…: $e');
      return PublishVerdict.retry;
    } on StateError catch (e) {
      print('[OUTBOX] Publish failed for ${event.id.substring(0, 8)}…: $e');
      return PublishVerdict.retry;
    }
    final verdict = verdictFor(outcome);
    switch (verdict) {
      case PublishVerdict.accepted:
        _accepted.add(event.id);
      case PublishVerdict.final_:
        final reason = outcome.rejections.values.join('; ');
        print('[OUTBOX] Refused for good kind=${event.kind} '
            'id=${event.id.substring(0, 8)}…: $reason');
        if (!reason.toLowerCase().contains('replaced:')) {
          _rejected.add((eventId: event.id, reason: reason));
        }
      case PublishVerdict.retry:
        break;
    }
    return verdict;
  }
}
