import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/roles/permission_helper.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';
import 'package:nexus_oneapp/features/governance/cell_founding_permit.dart';
import 'package:nexus_oneapp/features/governance/cell_founding_permit_service.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

CellFoundingPermit _pending({
  String id = 'p_local',
  String did = 'did:test:normal',
}) =>
    CellFoundingPermit(
      id: id,
      requesterDid: did,
      requesterPseudonym: 'Alice',
      cellType: CellType.local,
      proposedName: 'Hamburg Altona',
      regionHint: 'DE-HH',
      status: PermitStatus.pending,
      requestedAt: DateTime.utc(2026, 1, 1),
    );

CellFoundingPermit _activeLocal({
  String id = 'p_active_local',
  String did = 'did:test:normal',
}) =>
    CellFoundingPermit(
      id: id,
      requesterDid: did,
      requesterPseudonym: 'Alice',
      cellType: CellType.local,
      proposedName: 'Hamburg Altona',
      regionHint: 'DE-HH',
      status: PermitStatus.approved,
      requestedAt: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
    );

CellFoundingPermit _activeThematic({
  String id = 'p_active_thematic',
  String did = 'did:test:normal',
}) =>
    CellFoundingPermit(
      id: id,
      requesterDid: did,
      requesterPseudonym: 'Alice',
      cellType: CellType.thematic,
      proposedName: 'Code Circle',
      proposedCategory: 'Technik',
      status: PermitStatus.approved,
      requestedAt: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
    );

CellFoundingPermit _expiredLocal({
  String id = 'p_expired_local',
  String did = 'did:test:normal',
}) =>
    CellFoundingPermit(
      id: id,
      requesterDid: did,
      requesterPseudonym: 'Alice',
      cellType: CellType.local,
      proposedName: 'Hamburg Altona',
      regionHint: 'DE-HH',
      status: PermitStatus.approved,
      requestedAt: DateTime.utc(2026, 1, 1),
      expiresAt:
          DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );

void main() {
  // Reset service state before each test.
  setUp(() {
    CellFoundingPermitService.instance.injectPermitsForTest();
  });

  // ── 1. requestPermit() — pending state ─────────────────────────────────────
  //
  // The actual requestPermit() requires an initialised identity + DB.
  // We verify the equivalent state via injectPermitsForTest() and assert
  // that myPendingRequests reflects a permit with status=pending.
  group('1. requestPermit() → status=pending', () {
    test('pending Permit taucht in myPendingRequests auf', () {
      CellFoundingPermitService.instance
          .injectPermitsForTest(sent: [_pending()]);

      final pending =
          CellFoundingPermitService.instance.myPendingRequests;
      expect(pending, hasLength(1));
      expect(pending.first.status, PermitStatus.pending);
    });
  });

  // ── 2. approvePermit() — model state after approval ────────────────────────
  //
  // approvePermit() in the service requires admin identity + DB.
  // We verify the model contract via copyWith (which is exactly what
  // approvePermit() calls internally before persisting).
  group('2. approvePermit() → status=approved + expiresAt', () {
    test('copyWith setzt status=approved und expiresAt korrekt', () {
      final permit = _pending();
      final now = DateTime.now().toUtc();
      final approved = permit.copyWith(
        status: PermitStatus.approved,
        decidedAt: now,
        decidedBy: 'did:test:admin',
        expiresAt: now.add(const Duration(days: 7)),
      );

      expect(approved.status, PermitStatus.approved);
      expect(approved.expiresAt, isNotNull);
      expect(approved.expiresAt!.isAfter(now), isTrue);
    });
  });

  // ── 3. findById() nach approve ─────────────────────────────────────────────
  group('3. findById() nach approvePermit → approved', () {
    test('findById liefert approved Permit nach injectPermitsForTest', () {
      final approved = _pending().copyWith(status: PermitStatus.approved);
      CellFoundingPermitService.instance
          .injectPermitsForTest(received: [approved]);

      final found =
          CellFoundingPermitService.instance.findById(approved.id);
      expect(found, isNotNull);
      expect(found!.status, PermitStatus.approved);
    });
  });

  // ── 4. rejectPermit() → status=rejected ────────────────────────────────────
  group('4. rejectPermit() → status=rejected', () {
    test('copyWith setzt status=rejected', () {
      final permit = _pending();
      final rejected = permit.copyWith(
        status: PermitStatus.rejected,
        decidedAt: DateTime.now().toUtc(),
        decidedBy: 'did:test:admin',
        adminNote: 'Nicht genug Begründung',
      );

      expect(rejected.status, PermitStatus.rejected);
      expect(rejected.decidedBy, 'did:test:admin');
      expect(rejected.adminNote, isNotNull);
    });
  });

  // ── 5. findById() nach reject ──────────────────────────────────────────────
  group('5. findById() nach rejectPermit → rejected', () {
    test('findById liefert rejected Permit', () {
      final rejected = _pending().copyWith(status: PermitStatus.rejected);
      CellFoundingPermitService.instance
          .injectPermitsForTest(received: [rejected]);

      final found =
          CellFoundingPermitService.instance.findById(rejected.id);
      expect(found, isNotNull);
      expect(found!.status, PermitStatus.rejected);
    });
  });

  // ── 6. revokePermit() → status=revoked ────────────────────────────────────
  group('6. revokePermit() → status=revoked', () {
    test('copyWith setzt status=revoked', () {
      final active = _activeLocal();
      final revoked = active.copyWith(
        status: PermitStatus.revoked,
        decidedAt: DateTime.now().toUtc(),
        decidedBy: 'did:test:admin',
      );

      expect(revoked.status, PermitStatus.revoked);
      expect(revoked.isActive, isFalse);
    });
  });

  // ── 7. findById() nach revoke ──────────────────────────────────────────────
  group('7. findById() nach revokePermit → revoked', () {
    test('findById liefert revoked Permit', () {
      final revoked = _activeLocal().copyWith(status: PermitStatus.revoked);
      CellFoundingPermitService.instance
          .injectPermitsForTest(received: [revoked]);

      final found =
          CellFoundingPermitService.instance.findById(revoked.id);
      expect(found, isNotNull);
      expect(found!.status, PermitStatus.revoked);
    });
  });

  // ── 8. markPermitUsed() — guard: identity=null ─────────────────────────────
  //
  // In the test environment no identity is loaded. markPermitUsed() first
  // checks isActive (passes for an active permit), then checks identity
  // (identity == null → requesterDid mismatch → StateError).
  // This guard must never silently pass.
  group('8. markPermitUsed() — wirft StateError ohne Identity', () {
    test('StateError wenn Identity null (active permit, kein CurrentUser)',
        () async {
      final active = _activeLocal(did: 'did:test:someone');
      CellFoundingPermitService.instance
          .injectPermitsForTest(sent: [active]);

      await expectLater(
        CellFoundingPermitService.instance
            .markPermitUsed(active.id, 'cell_x'),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── 9. canCreateCell — ohne Permit → false ─────────────────────────────────
  group('9. canCreateCell(normalDid, cellType: local) == false ohne Permit',
      () {
    test('false wenn kein Permit vorhanden', () {
      // _sentPermits is empty (no permit injected for this DID)
      expect(
        PermissionHelper.canCreateCell(
          'did:test:normal',
          cellType: CellType.local,
        ),
        isFalse,
      );
    });
  });

  // ── 10. canCreateCell — mit aktivem lokalem Permit → true ─────────────────
  group('10. canCreateCell(normalDid, cellType: local) == true mit aktivem Permit',
      () {
    test('true wenn aktives lokales Permit vorhanden', () {
      CellFoundingPermitService.instance
          .injectPermitsForTest(sent: [_activeLocal()]);

      expect(
        PermissionHelper.canCreateCell(
          'did:test:normal',
          cellType: CellType.local,
        ),
        isTrue,
      );
    });
  });

  // ── 11. canCreateCell — mit abgelaufenem Permit → false ───────────────────
  group('11. canCreateCell(normalDid, cellType: local) == false mit abgelaufenem Permit',
      () {
    test('false wenn Permit abgelaufen', () {
      CellFoundingPermitService.instance
          .injectPermitsForTest(sent: [_expiredLocal()]);

      expect(
        PermissionHelper.canCreateCell(
          'did:test:normal',
          cellType: CellType.local,
        ),
        isFalse,
      );
    });
  });

  // ── 12. canCreateCell — lokales Permit + thematic CellType → false ─────────
  group('12. canCreateCell(normalDid, cellType: thematic) == false mit lokalem Permit',
      () {
    test('false wenn cellType nicht übereinstimmt', () {
      // Inject a local permit — should NOT match a thematic query
      CellFoundingPermitService.instance
          .injectPermitsForTest(sent: [_activeLocal()]);

      expect(
        PermissionHelper.canCreateCell(
          'did:test:normal',
          cellType: CellType.thematic,
        ),
        isFalse,
      );
    });
  });

  // ── 13. canCreateCell(adminDid) — TODO: requires RoleService + DB ──────────
  //
  // TODO: This test requires RoleService to be fully initialized with a known
  // superadmin DID (e.g. via DB or SystemConfig injection). In the current test
  // environment RoleService.instance.isSystemAdmin() returns false for all DIDs
  // because no DB is available.
  //
  // Expected behavior: canCreateCell(superadminDid, cellType: CellType.local) == true
  //
  // Covered by: device integration test / flutter drive
  group('13. canCreateCell(adminDid) — TODO (RoleService braucht DB)', () {
    test('canCreateCell ohne cellType und ohne Admin → false (Guard)', () {
      // Verifies the cellType=null guard for non-admin DIDs.
      expect(
        PermissionHelper.canCreateCell('did:test:normal'),
        isFalse,
      );
    });
  });

  // ── 14. canCreateCell(normalDid) ohne cellType → false ────────────────────
  group('14. canCreateCell(normalDid) ohne cellType → false', () {
    test('false wenn cellType nicht angegeben und kein Admin', () {
      expect(
        PermissionHelper.canCreateCell('did:test:normal'),
        isFalse,
      );
    });
  });

  // ── 15. Volles Roundtrip: pending → approved → used ───────────────────────
  group('15. Roundtrip: pending → approved → used', () {
    test('isActive=true nach approve, isActive=false nach markUsed', () {
      final now = DateTime.now().toUtc();

      // Step 1: pending
      final permit = _pending(id: 'roundtrip_001');
      expect(permit.status, PermitStatus.pending);
      expect(permit.isActive, isFalse);

      // Step 2: approved
      final approved = permit.copyWith(
        status: PermitStatus.approved,
        decidedAt: now,
        decidedBy: 'did:test:admin',
        expiresAt: now.add(const Duration(days: 7)),
      );
      expect(approved.status, PermitStatus.approved);
      expect(approved.isActive, isTrue);

      // Inject as sent permit so getActivePermitForType can find it
      CellFoundingPermitService.instance
          .injectPermitsForTest(sent: [approved]);
      expect(
        CellFoundingPermitService.instance
            .getActivePermitForType('did:test:normal', CellType.local),
        isNotNull,
      );

      // Step 3: used
      final used = approved.copyWith(
        status: PermitStatus.used,
        usedAt: now,
        createdCellId: 'cell_roundtrip',
      );
      expect(used.status, PermitStatus.used);
      expect(used.isActive, isFalse);

      // After marking as used, getActivePermitForType should return null
      CellFoundingPermitService.instance
          .injectPermitsForTest(sent: [used]);
      expect(
        CellFoundingPermitService.instance
            .getActivePermitForType('did:test:normal', CellType.local),
        isNull,
      );
    });
  });
}
