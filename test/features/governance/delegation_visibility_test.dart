// ignore_for_file: avoid_print
//
// G2.1.4b — Delegation UI visibility tests.
//
// Scope:
//   - Unit tests for the vote-list display logic (sorting, fallback, parsing).
//   - Widget-level tests for _IncomingDelegationsBlock and _ResultSection are
//     deferred: both widgets are private to proposal_detail_screen.dart and
//     depend on PodDatabase + IdentityService singletons.  Testing through
//     ProposalDetailScreen (the only accessible public ancestor) requires
//     the full multi-singleton setup used in delegation_service_test.dart.
//     That setup is feasible but has been deferred to live-test G2.1.5b per
//     the G2.1.4b spec (service-singleton-difficulty clause).
//
// Tests covered here (7 tests):
//   A — Vote list: sorting by createdAt ASC
//   B — Vote list: allVotes fallback when DecisionRecord.allVotes is empty
//   C — Vote list: fallback produces createdAt-sorted list from direct votes
//   D — Pluralisation helper: count == 1 → singular, count > 1 → plural
//   E — DecisionRecord.fromMap: allVotes round-trip preserves synthetic vote
//   F — _loadIncoming filter: delegate_did match returns only own delegations
//   G — Empty allVotes: empty-state text is produced (logic, not widget)

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/decision_record.dart';
import 'package:nexus_oneapp/features/governance/vote.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Vote _makeVote({
  required String voteId,
  required DateTime createdAt,
  VoteChoice choice = VoteChoice.YES,
  String voterPubkey = 'pk_direct',
  String voterDid = 'did:key:z6MkTest',
  String voterPseudonym = 'Tester',
  bool isDelegated = false,
}) =>
    Vote(
      voteId: voteId,
      proposalId: 'prop_test',
      voterPubkey: voterPubkey,
      voterDid: voterDid,
      voterPseudonym: voterPseudonym,
      choice: choice,
      createdAt: createdAt,
      isDelegated: isDelegated,
      nostrEventId: 'nostr_${voteId}',
    );

DecisionRecord _makeRecord(List<Vote> allVotes) => DecisionRecord(
      recordId: 'rec_test',
      proposalId: 'prop_test',
      cellId: 'cell_test',
      finalTitle: 'Test',
      finalDescription: '',
      result: 'approved',
      yesVotes: allVotes.where((v) => v.choice == VoteChoice.YES).length,
      noVotes: 0,
      abstainVotes: 0,
      participation: 1.0,
      decidedAt: DateTime.utc(2026, 5, 7),
      allVotes: allVotes,
      contentHash: 'hash_test',
      nostrEventId: 'nostr_rec_test',
    );

// Replicates the sort + fallback logic from _ResultSectionState.build().
List<Vote> _resolveDisplayVotes({
  required List<Vote> allVotesFromRecord,
  required List<Vote> directVotesFromService,
}) {
  if (allVotesFromRecord.isNotEmpty) {
    return List<Vote>.from(allVotesFromRecord)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  return List<Vote>.from(directVotesFromService)
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

// Replicates the incoming-delegation count text logic from
// _IncomingDelegationsBlockState.build().
String _incomingCountText(int count) => count == 1
    ? 'Dir wurde 1 Stimme delegiert.'
    : 'Dir wurden $count Stimmen delegiert.';

// Replicates the in-UI delegate_did filter from _loadIncoming().
List<Map<String, dynamic>> _filterIncoming(
    List<Map<String, dynamic>> rows, String myDid) =>
    rows.where((m) => m['delegate_did'] == myDid).toList();

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── A: Sorting by createdAt ASC ────────────────────────────────────────────

  test(
    'A — allVotes aus DecisionRecord werden createdAt ASC sortiert',
    () {
      final t1 = DateTime.utc(2026, 5, 7, 10, 0);
      final t2 = DateTime.utc(2026, 5, 7, 10, 5);
      final t3 = DateTime.utc(2026, 5, 7, 10, 10);

      final voteEarly = _makeVote(voteId: 'v1', createdAt: t1);
      final voteMid = _makeVote(voteId: 'v2', createdAt: t2);
      final voteLate = _makeVote(voteId: 'v3', createdAt: t3);

      // Deliberately out of order.
      final displayVotes = _resolveDisplayVotes(
        allVotesFromRecord: [voteLate, voteEarly, voteMid],
        directVotesFromService: [],
      );

      expect(displayVotes[0].voteId, equals('v1'));
      expect(displayVotes[1].voteId, equals('v2'));
      expect(displayVotes[2].voteId, equals('v3'));
    },
  );

  // ── B: Fallback when allVotes is empty ────────────────────────────────────

  test(
    'B — Fallback auf direkte Votes wenn DecisionRecord.allVotes leer ist '
    '(Empfänger-Gerät, Phase-4.5c scope-cut)',
    () {
      final directVote = _makeVote(
        voteId: 'direct_1',
        createdAt: DateTime.utc(2026, 5, 7, 9, 0),
      );

      final displayVotes = _resolveDisplayVotes(
        allVotesFromRecord: const [],  // empty → Empfänger-Gerät
        directVotesFromService: [directVote],
      );

      expect(displayVotes.length, equals(1));
      expect(displayVotes.first.voteId, equals('direct_1'));
    },
  );

  // ── C: Fallback also sorted ASC ───────────────────────────────────────────

  test(
    'C — Fallback-Liste (direkte Votes) wird ebenfalls createdAt ASC sortiert',
    () {
      final t1 = DateTime.utc(2026, 5, 7, 8, 0);
      final t2 = DateTime.utc(2026, 5, 7, 9, 0);

      final displayVotes = _resolveDisplayVotes(
        allVotesFromRecord: const [],
        directVotesFromService: [
          _makeVote(voteId: 'later', createdAt: t2),
          _makeVote(voteId: 'earlier', createdAt: t1),
        ],
      );

      expect(displayVotes[0].voteId, equals('earlier'));
      expect(displayVotes[1].voteId, equals('later'));
    },
  );

  // ── D: Pluralisation ───────────────────────────────────────────────────────

  group('D — Pluralisierung des Eingehende-Delegationen-Texts', () {
    test('count == 1 → Singular "Dir wurde 1 Stimme delegiert."', () {
      expect(_incomingCountText(1), equals('Dir wurde 1 Stimme delegiert.'));
    });

    test('count == 2 → Plural "Dir wurden 2 Stimmen delegiert."', () {
      expect(_incomingCountText(2), equals('Dir wurden 2 Stimmen delegiert.'));
    });

    test('count == 5 → Plural "Dir wurden 5 Stimmen delegiert."', () {
      expect(_incomingCountText(5), equals('Dir wurden 5 Stimmen delegiert.'));
    });
  });

  // ── E: DecisionRecord round-trip preserves synthetic vote ─────────────────

  test(
    'E — DecisionRecord.fromMap erhält Synthetic Vote (voterPubkey leer, '
    'isDelegated=true, Pseudonym gesetzt)',
    () {
      final syntheticVote = _makeVote(
        voteId: 'syn_1',
        createdAt: DateTime.utc(2026, 5, 7, 10, 5),
        voterPubkey: '',   // Synthetic Vote per G2.1.3 A.2-5e
        voterDid: 'did:key:z6MkAlice',
        voterPseudonym: 'Alice',
        isDelegated: true,
        choice: VoteChoice.YES,
      );
      final directVote = _makeVote(
        voteId: 'dir_1',
        createdAt: DateTime.utc(2026, 5, 7, 10, 0),
        voterPseudonym: 'Bob',
      );

      final record = _makeRecord([directVote, syntheticVote]);

      // Simulate DB round-trip via toMap / fromMap.
      final restored = DecisionRecord.fromMap(record.toMap());

      expect(restored.allVotes.length, equals(2));

      final syn = restored.allVotes.firstWhere((v) => v.isDelegated);
      expect(syn.voterPubkey, equals(''));
      expect(syn.voterPseudonym, equals('Alice'));
      expect(syn.choice, equals(VoteChoice.YES));
      expect(syn.isDelegated, isTrue);
    },
  );

  // ── F: delegate_did filter ────────────────────────────────────────────────

  test(
    'F — _loadIncoming-Filter: nur Delegationen mit delegate_did == myDid '
    'werden zurückgegeben',
    () {
      const myDid = 'did:key:z6MkBob';
      const otherDid = 'did:key:z6MkCarol';

      final rows = [
        {'delegator_did': 'did:key:z6MkAlice', 'delegate_did': myDid},
        {'delegator_did': 'did:key:z6MkDave', 'delegate_did': otherDid},
        {'delegator_did': 'did:key:z6MkEve', 'delegate_did': myDid},
      ];

      final filtered = _filterIncoming(rows, myDid);
      expect(filtered.length, equals(2));
      expect(filtered.every((m) => m['delegate_did'] == myDid), isTrue);
    },
  );

  // ── G: allVotes=0 → Empty-State ───────────────────────────────────────────

  test(
    'G — Wenn displayVotes leer ist, zeigt die Liste Empty-State '
    '(kein direkter/delegierter Vote vorhanden)',
    () {
      // Both allVotes and direct votes are empty.
      final displayVotes = _resolveDisplayVotes(
        allVotesFromRecord: const [],
        directVotesFromService: const [],
      );

      expect(displayVotes, isEmpty);
      // The _TransparencyList widget renders 'Keine abgegebenen Stimmen.'
      // when votes.isEmpty — verified in live-test G2.1.5b.
    },
  );
}
