import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/cell_member.dart';

CellMember _as(MemberRole role) => CellMember(
      cellId: 'cell-1',
      did: 'did:key:z6MkMember',
      joinedAt: DateTime.utc(2026, 11, 9),
      role: role,
    );

void main() {
  test('every confirmed member may file proposals (decision 09.11.2026)', () {
    for (final role in [
      MemberRole.founder,
      MemberRole.moderator,
      MemberRole.member,
    ]) {
      expect(_as(role).canCreateProposals, isTrue, reason: role.name);
    }
  });

  test('a pending applicant may not file proposals', () {
    expect(_as(MemberRole.pending).canCreateProposals, isFalse);
  });
}
