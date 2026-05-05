import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/retry_backoff.dart';

void main() {
  group('backoffMs schedule', () {
    test('attempt 1 returns 60 seconds', () {
      expect(backoffMs(1), equals(60 * 1000));
    });

    test('attempt 2 returns 5 minutes', () {
      expect(backoffMs(2), equals(5 * 60 * 1000));
    });

    test('attempt 3 returns 15 minutes', () {
      expect(backoffMs(3), equals(15 * 60 * 1000));
    });

    test('attempt 4 returns 1 hour', () {
      expect(backoffMs(4), equals(60 * 60 * 1000));
    });

    test('attempt 5 returns 6 hours', () {
      expect(backoffMs(5), equals(6 * 60 * 60 * 1000));
    });

    test('attempts beyond 5 return 6 hours (failsafe)', () {
      expect(backoffMs(6), equals(6 * 60 * 60 * 1000));
      expect(backoffMs(10), equals(6 * 60 * 60 * 1000));
      expect(backoffMs(100), equals(6 * 60 * 60 * 1000));
    });

    test('schedule is monotonically non-decreasing', () {
      // Each attempt's backoff should be >= previous attempt's backoff.
      // (The schedule grows then plateaus at 6h.)
      for (int i = 1; i < 10; i++) {
        expect(backoffMs(i + 1), greaterThanOrEqualTo(backoffMs(i)),
            reason: 'attempt ${i + 1} should not be shorter than attempt $i');
      }
    });

    test('total wait through full schedule equals expected sum', () {
      // 1min + 5min + 15min + 1h + 6h = 7h 21min = 26460 seconds
      final total = backoffMs(1) + backoffMs(2) + backoffMs(3) +
          backoffMs(4) + backoffMs(5);
      expect(total, equals((60 + 300 + 900 + 3600 + 21600) * 1000));
    });

    test('attempt 0 returns failsafe value (6 hours)', () {
      // retryCount=0 sollte nicht vorkommen (erste retry hat retryCount=1),
      // aber wenn doch: defensive default zum 6h-failsafe.
      expect(backoffMs(0), equals(6 * 60 * 60 * 1000));
    });
  });
}
