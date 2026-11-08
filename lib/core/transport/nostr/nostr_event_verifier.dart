import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'nostr_event.dart';

/// Verifies a batch of events; returns one result per event, in order.
typedef NostrBatchVerifier = Future<List<bool>> Function(
  List<NostrEvent> events,
);

/// Default [NostrBatchVerifier]: Schnorr verification costs ~25 ms per event
/// in pure Dart, so it runs in a background isolate to keep the UI smooth.
Future<List<bool>> verifyEventsInBackground(List<NostrEvent> events) =>
    Isolate.run(() => [for (final event in events) event.verify()]);

/// Passes incoming relay events on only if their ID and signature are valid
/// (TD-39 / V-002), deduplicated and in arrival order.
///
/// Deduplication happens only after verification: a forged event carrying a
/// genuine event's ID must not cause the genuine one to be dropped.
class NostrEventVerifier {
  NostrEventVerifier({
    required void Function(NostrEvent event) onValid,
    NostrBatchVerifier? verifyBatch,
  })  : _onValid = onValid,
        _verifyBatch = verifyBatch ?? verifyEventsInBackground;

  final void Function(NostrEvent event) _onValid;
  final NostrBatchVerifier _verifyBatch;

  static const int _maxBatch = 64;
  static const int _maxSeen = 5000;

  final LinkedHashSet<String> _seenIds = LinkedHashSet<String>();
  final Set<String> _inFlight = <String>{};
  final List<NostrEvent> _queue = <NostrEvent>[];
  Completer<void>? _idle;

  /// Completes once every event added so far has been processed.
  Future<void> get idle => _idle?.future ?? Future<void>.value();

  /// Queues [event] for verification unless it was already passed on.
  void add(NostrEvent event) {
    if (_seenIds.contains(event.id)) return;
    // Identical copies from several relays are verified once; a differing
    // event with the same ID (forgery) is verified separately.
    if (!_inFlight.add(_copyKey(event))) return;
    _queue.add(event);
    if (_idle == null) unawaited(_drain());
  }

  Future<void> _drain() async {
    _idle = Completer<void>();
    try {
      while (_queue.isNotEmpty) {
        final batch = _queue.take(_maxBatch).toList();
        _queue.removeRange(0, batch.length);
        final results = await _verify(batch);
        for (var i = 0; i < batch.length; i++) {
          _handleResult(batch[i], results[i]);
        }
      }
    } finally {
      final idle = _idle;
      _idle = null;
      idle?.complete();
    }
  }

  Future<List<bool>> _verify(List<NostrEvent> batch) async {
    try {
      final results = await _verifyBatch(batch);
      if (results.length == batch.length) return results;
      print('[NOSTR-VERIFY] Batch result size mismatch — verifying directly');
    } on Exception catch (e) {
      print('[NOSTR-VERIFY] Background verification failed ($e) — '
          'verifying directly');
    } on Error catch (e) {
      print('[NOSTR-VERIFY] Background verification failed ($e) — '
          'verifying directly');
    }
    return [for (final event in batch) event.verify()];
  }

  void _handleResult(NostrEvent event, bool isValid) {
    _inFlight.remove(_copyKey(event));
    if (!isValid) {
      final shortId = event.id.length >= 8 ? event.id.substring(0, 8) : event.id;
      final shortKey =
          event.pubkey.length >= 8 ? event.pubkey.substring(0, 8) : event.pubkey;
      print('[NOSTR-VERIFY] Rejected kind=${event.kind} id=$shortId… '
          'from=$shortKey…: invalid ID or signature');
      return;
    }
    if (!_seenIds.add(event.id)) return;
    if (_seenIds.length > _maxSeen) _seenIds.remove(_seenIds.first);
    _onValid(event);
  }

  static String _copyKey(NostrEvent event) =>
      '${event.id}|${event.sig}|${event.pubkey}|${event.createdAt}|'
      '${event.content.hashCode}|${event.tags.length}';
}
