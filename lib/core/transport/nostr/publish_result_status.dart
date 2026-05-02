/// Status values for publish_results.status column.
/// Used by Phase 1 PublishResult tracking (G2 prerequisite).
///
/// Lifecycle:
///   PENDING  → published to relays, awaiting OK responses
///   PARTIAL  → some relays accepted (< required_ack_count)
///   ACCEPTED → required_ack_count relays accepted
///   REJECTED → relays explicitly rejected with NOTICE
///   RETRYING → no acceptance yet, scheduled for retry
///   FAILED   → max retries exhausted, given up
class PublishResultStatus {
  static const String pending = 'PENDING';
  static const String partial = 'PARTIAL';
  static const String accepted = 'ACCEPTED';
  static const String rejected = 'REJECTED';
  static const String retrying = 'RETRYING';
  static const String failed = 'FAILED';

  /// All valid status values (for validation).
  static const Set<String> all = {
    pending, partial, accepted, rejected, retrying, failed,
  };

  /// Statuses that indicate the publish is still in flight.
  static const Set<String> inFlight = {
    pending, partial, retrying,
  };

  /// Statuses that indicate the publish reached a terminal state.
  static const Set<String> terminal = {
    accepted, rejected, failed,
  };
}
