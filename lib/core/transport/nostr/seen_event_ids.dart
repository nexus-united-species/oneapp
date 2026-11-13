import 'dart:collection';

/// Remembers the most recent Nostr event IDs so that an event delivered by
/// several relays is handled only once (e.g. one notification per DM).
///
/// Bounded: once [capacity] IDs are stored, the oldest is forgotten.
class SeenEventIds {
  SeenEventIds({this.capacity = 500}) : assert(capacity > 0);

  final int capacity;
  final _order = Queue<String>();
  final _ids = <String>{};

  /// Records [id]. Returns `true` the first time an ID is seen and `false`
  /// for repeats that are still remembered.
  bool add(String id) {
    if (!_ids.add(id)) return false;
    _order.addLast(id);
    if (_order.length > capacity) {
      _ids.remove(_order.removeFirst());
    }
    return true;
  }

  int get length => _ids.length;
}
