import 'dart:math';

/// Waiting time before the next reconnect attempt to a relay (audit Z-6).
///
/// Grows with each failure in a row – 5 s, 10 s, 20 s … up to [maxDelay] –
/// so an unreachable relay is not hammered every few seconds, and a short
/// outage is still bridged quickly. [jitter] (0.8–1.2) spreads devices that
/// lost the connection at the same moment.
Duration reconnectDelay(int failuresInARow, {double jitter = 1.0}) {
  final failures = failuresInARow < 1 ? 1 : failuresInARow;
  final exponent = min(failures - 1, 10);
  final seconds =
      min(baseDelay.inSeconds * (1 << exponent), maxDelay.inSeconds);
  return Duration(milliseconds: (seconds * 1000 * jitter).round());
}

/// First waiting time after a lost connection.
const Duration baseDelay = Duration(seconds: 5);

/// Longest waiting time between two attempts.
const Duration maxDelay = Duration(minutes: 5);

/// A random factor between 0.8 and 1.2 for [reconnectDelay].
double randomJitter([Random? random]) =>
    0.8 + (random ?? Random()).nextDouble() * 0.4;
