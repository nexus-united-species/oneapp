/// Voting modes per G2 spec v1.3 §9.1.
///
/// YES_NO_ABSTAIN: classical yes/no/abstain on a substantive question
/// SINGLE_CHOICE: one of N options is selected (poll-like)
/// CANDIDATE_CHOICE: person/role election; no delegation, no QV,
///                   strictly 1-human-1-vote per spec §9.5
enum VotingMode {
  YES_NO_ABSTAIN,
  SINGLE_CHOICE,
  CANDIDATE_CHOICE,
}

/// Parses a voting-mode string into the enum.
/// Defaults to YES_NO_ABSTAIN for null, empty, unknown, or legacy values
/// per G2 spec v1.3 §29.13.5 (migration default for existing data).
VotingMode parseVotingMode(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return VotingMode.YES_NO_ABSTAIN;
  try {
    return VotingMode.values.byName(trimmed);
  } catch (_) {
    return VotingMode.YES_NO_ABSTAIN;
  }
}
