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

  /// IDs of events a relay accepted, right away or later from the queue
  /// (audit Z-4: the chat shows „gesendet“ only then).
  Stream<String> get onAccepted => _accepted.stream;

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

  /// Publishes [event]; keeps it for [flush] if no relay accepted it.
  Future<void> publish(NostrEvent event) async {
    if (await _tryPublish(event)) {
      _accepted.add(event.id);
      return;
    }
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

  /// Resends all queued events; returns how many a relay accepted.
  /// Concurrent calls (several relays connecting at once) run only once.
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
      for (final event in pending) {
        if (event.createdAt < cutoff) {
          await _store.remove(event.id);
          print('[OUTBOX] Dropped expired id=${event.id.substring(0, 8)}…');
          continue;
        }
        if (await _tryPublish(event)) {
          await _store.remove(event.id);
          _accepted.add(event.id);
          delivered++;
        }
      }
      print('[OUTBOX] Flush: $delivered/${pending.length} delivered');
      return delivered;
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _tryPublish(NostrEvent event) async {
    try {
      return (await _publish(event)).acceptedCount > 0;
    } on Exception catch (e) {
      print('[OUTBOX] Publish failed for ${event.id.substring(0, 8)}…: $e');
      return false;
    } on StateError catch (e) {
      print('[OUTBOX] Publish failed for ${event.id.substring(0, 8)}…: $e');
      return false;
    }
  }
}
