import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/nostr/seen_event_ids.dart';

void main() {
  test('an event delivered by several relays counts once', () {
    final seen = SeenEventIds();

    expect(seen.add('a'), isTrue);
    expect(seen.add('a'), isFalse);
    expect(seen.add('b'), isTrue);
    expect(seen.length, 2);
  });

  test('forgets the oldest ID once the capacity is reached', () {
    final seen = SeenEventIds(capacity: 2);

    seen.add('a');
    seen.add('b');
    seen.add('c');

    expect(seen.length, 2);
    expect(seen.add('a'), isTrue, reason: 'a was evicted');
    expect(seen.add('c'), isFalse, reason: 'c is still remembered');
  });
}
