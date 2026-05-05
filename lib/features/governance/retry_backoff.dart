/// Backoff schedule for governance event publish retries.
///
/// Per G2 spec §21.4:
///   attempt 1 -> 60s
///   attempt 2 -> 5min
///   attempt 3 -> 15min
///   attempt 4 -> 1h
///   attempt 5 -> 6h
///   attempt >= 6 -> 6h (caller treats as FAILED beyond retry limit)
///
/// Returns the delay in milliseconds before the next retry attempt.
///
/// This is a pure function — no side effects, deterministic output
/// for the same input. Extracted from ProposalService for testability.
int backoffMs(int retryCount) {
  switch (retryCount) {
    case 1:
      return 60 * 1000;
    case 2:
      return 5 * 60 * 1000;
    case 3:
      return 15 * 60 * 1000;
    case 4:
      return 60 * 60 * 1000;
    case 5:
      return 6 * 60 * 60 * 1000;
    default:
      return 6 * 60 * 60 * 1000;
  }
}
