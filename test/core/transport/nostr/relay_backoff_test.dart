import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/nostr/relay_backoff.dart';

void main() {
  group('reconnectDelay (audit Z-6)', () {
    test('starts at 5 seconds and doubles with each failure', () {
      expect(
        [for (var i = 1; i <= 6; i++) reconnectDelay(i).inSeconds],
        [5, 10, 20, 40, 80, 160],
      );
    });

    test('never waits longer than five minutes', () {
      expect(reconnectDelay(7), maxDelay);
      expect(reconnectDelay(50), maxDelay);
    });

    test('treats zero or negative failures like the first one', () {
      expect(reconnectDelay(0), baseDelay);
      expect(reconnectDelay(-3), baseDelay);
    });

    test('jitter spreads the waiting time by up to 20 percent', () {
      expect(reconnectDelay(2, jitter: 0.8), const Duration(seconds: 8));
      expect(reconnectDelay(2, jitter: 1.2), const Duration(seconds: 12));
    });

    test('random jitter stays between 0.8 and 1.2', () {
      final random = Random(42);
      for (var i = 0; i < 1000; i++) {
        final j = randomJitter(random);
        expect(j, inInclusiveRange(0.8, 1.2));
      }
    });
  });
}
