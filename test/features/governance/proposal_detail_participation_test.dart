// Tests für buildParticipationText (G2.1.4c).
//
// Die Funktion ist @visibleForTesting und top-level in proposal_detail_screen.dart.
// Kein Widget-Setup nötig — reine Berechnungslogik.

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/decision_record.dart';
import 'package:nexus_oneapp/features/governance/proposal_detail_screen.dart';

DecisionRecord _dr({
  int yes = 0,
  int no = 0,
  int abstain = 0,
  double participation = 0.0,
}) =>
    DecisionRecord(
      recordId: 'r1',
      proposalId: 'p1',
      cellId: 'c1',
      finalTitle: 'T',
      finalDescription: 'D',
      result: 'approved',
      yesVotes: yes,
      noVotes: no,
      abstainVotes: abstain,
      participation: participation,
      decidedAt: DateTime.utc(2026, 1, 1),
      allVotes: const [],
      contentHash: 'h',
      nostrEventId: 'e1',
    );

void main() {
  group('buildParticipationText', () {
    test('0 Stimmen → Keine Stimmen abgegeben', () {
      final dr = _dr(yes: 0, no: 0, abstain: 0, participation: 0.0);
      expect(buildParticipationText(dr), 'Keine Stimmen abgegeben');
    });

    test('2 Stimmen von 4 Stimmberechtigten → 50%', () {
      // participation = 2/4 = 0.5 → den rückrechnung: 2/0.5 = 4
      final dr = _dr(yes: 2, no: 0, abstain: 0, participation: 0.5);
      expect(
        buildParticipationText(dr),
        'Beteiligung: 50% (2 Stimmen von 4 Stimmberechtigten)',
      );
    });

    test('1 Stimme von 1 stimmberechtigten Person — Singular beider Werte', () {
      // participation = 1/1 = 1.0 → den = 1/1.0 = 1
      final dr = _dr(yes: 1, no: 0, abstain: 0, participation: 1.0);
      expect(
        buildParticipationText(dr),
        'Beteiligung: 100% (1 Stimme von 1 stimmberechtigten Person)',
      );
    });

    test('1 Stimme von 4 Stimmberechtigten — Stimme singular, Stimmberechtigte plural', () {
      // participation = 1/4 = 0.25 → den = 1/0.25 = 4
      final dr = _dr(yes: 1, no: 0, abstain: 0, participation: 0.25);
      expect(
        buildParticipationText(dr),
        'Beteiligung: 25% (1 Stimme von 4 Stimmberechtigten)',
      );
    });

    test('Rundung korrekt: 3 von 7 → 43%', () {
      // participation = 3/7 ≈ 0.42857 → pct = 43%, den ≈ 7
      final dr = _dr(yes: 3, no: 0, abstain: 0, participation: 3 / 7);
      expect(
        buildParticipationText(dr),
        'Beteiligung: 43% (3 Stimmen von 7 Stimmberechtigten)',
      );
    });

    test('participation-Feld direkt für Prozent genutzt, nicht neu berechnet', () {
      // participation=0.6 → 60%; num=3, den=3/0.6=5
      final dr = _dr(yes: 2, no: 1, abstain: 0, participation: 0.6);
      expect(
        buildParticipationText(dr),
        'Beteiligung: 60% (3 Stimmen von 5 Stimmberechtigten)',
      );
    });

    test('gemischte Stimmen (ja+nein+enthaltung) werden korrekt summiert', () {
      // num = 1+1+1 = 3; participation = 3/6 = 0.5 → den = 6
      final dr = _dr(yes: 1, no: 1, abstain: 1, participation: 0.5);
      expect(
        buildParticipationText(dr),
        'Beteiligung: 50% (3 Stimmen von 6 Stimmberechtigten)',
      );
    });

    test('participation == 0 aber num > 0 → kein Absturz, nur Prozentwert', () {
      // Pathologischer Edge-Case: Rückrechnung wäre Division durch 0
      final dr = _dr(yes: 2, no: 0, abstain: 0, participation: 0.0);
      expect(buildParticipationText(dr), 'Beteiligung: 0%');
    });
  });
}
