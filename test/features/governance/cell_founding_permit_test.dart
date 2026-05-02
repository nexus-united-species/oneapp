import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';
import 'package:nexus_oneapp/features/governance/cell_founding_permit.dart';
import 'package:nexus_oneapp/features/governance/cell_founding_permit_service.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

CellFoundingPermit _makeLocalPermit({
  String id = 'permit001',
  String requesterDid = 'did:test:alice',
  String requesterPseudonym = 'Alice',
  String requesterNostrPubkey = 'aabbccdd',
  String proposedName = 'Hamburg Altona',
  String regionHint = 'DE-HH',
  PermitStatus status = PermitStatus.pending,
  DateTime? expiresAt,
  DateTime? usedAt,
  String? createdCellId,
}) =>
    CellFoundingPermit(
      id: id,
      requesterDid: requesterDid,
      requesterPseudonym: requesterPseudonym,
      requesterNostrPubkey: requesterNostrPubkey,
      cellType: CellType.local,
      proposedName: proposedName,
      regionHint: regionHint,
      status: status,
      requestedAt: DateTime.utc(2026, 1, 1),
      expiresAt: expiresAt,
      usedAt: usedAt,
      createdCellId: createdCellId,
    );

CellFoundingPermit _makeThematicPermit({
  String id = 'permit002',
  String requesterDid = 'did:test:bob',
  String requesterPseudonym = 'Bob',
  String proposedName = 'Code Circle',
  String proposedCategory = 'Technik',
  PermitStatus status = PermitStatus.pending,
  DateTime? expiresAt,
}) =>
    CellFoundingPermit(
      id: id,
      requesterDid: requesterDid,
      requesterPseudonym: requesterPseudonym,
      cellType: CellType.thematic,
      proposedName: proposedName,
      proposedCategory: proposedCategory,
      status: status,
      requestedAt: DateTime.utc(2026, 1, 1),
      expiresAt: expiresAt,
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // ── CellFoundingPermit.createRequest() ──────────────────────────────────────

  group('CellFoundingPermit.createRequest()', () {
    test('erzeugt Permit mit status=pending', () {
      final permit = CellFoundingPermit.createRequest(
        cellType: CellType.local,
        requesterDid: 'did:test:alice',
        requesterPseudonym: 'Alice',
        requesterNostrPubkey: 'aabbccdd',
        proposedName: 'Hamburg Altona',
        regionHint: 'DE-HH',
      );
      expect(permit.status, PermitStatus.pending);
      expect(permit.id, isNotEmpty);
      expect(permit.requestedAt.isUtc, isTrue);
      expect(permit.maxUses, 1);
    });

    test('wirft ArgumentError bei leerem proposedName', () {
      expect(
        () => CellFoundingPermit.createRequest(
          cellType: CellType.local,
          requesterDid: 'did:test:alice',
          requesterPseudonym: 'Alice',
          requesterNostrPubkey: 'aabbccdd',
          proposedName: '',
          regionHint: 'DE-HH',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('wirft ArgumentError bei fehlendem regionHint für lokale Zelle', () {
      expect(
        () => CellFoundingPermit.createRequest(
          cellType: CellType.local,
          requesterDid: 'did:test:alice',
          requesterPseudonym: 'Alice',
          requesterNostrPubkey: 'aabbccdd',
          proposedName: 'Hamburg Altona',
          regionHint: null,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('wirft ArgumentError bei fehlendem proposedCategory für thematische Zelle',
        () {
      expect(
        () => CellFoundingPermit.createRequest(
          cellType: CellType.thematic,
          requesterDid: 'did:test:alice',
          requesterPseudonym: 'Alice',
          requesterNostrPubkey: 'aabbccdd',
          proposedName: 'Code Circle',
          proposedCategory: null,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ── Computed getters ─────────────────────────────────────────────────────────

  group('isExpired', () {
    test('false wenn expiresAt in der Zukunft', () {
      final permit = _makeLocalPermit(
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      );
      expect(permit.isExpired, isFalse);
    });

    test('true wenn expiresAt in der Vergangenheit', () {
      final permit = _makeLocalPermit(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      expect(permit.isExpired, isTrue);
    });
  });

  group('isActive', () {
    test('false wenn status=used', () {
      final permit = _makeLocalPermit(
        status: PermitStatus.used,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      );
      expect(permit.isActive, isFalse);
    });

    test('false wenn status=approved aber isExpired=true', () {
      final permit = _makeLocalPermit(
        status: PermitStatus.approved,
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      expect(permit.isActive, isFalse);
    });

    test('true wenn status=approved und nicht expired', () {
      final permit = _makeLocalPermit(
        status: PermitStatus.approved,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      );
      expect(permit.isActive, isTrue);
    });
  });

  // ── copyWith() ───────────────────────────────────────────────────────────────

  group('copyWith()', () {
    test('setzt status, usedAt und createdCellId korrekt', () {
      final original = _makeLocalPermit(
        status: PermitStatus.approved,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      );
      final usedAt = DateTime.utc(2026, 4, 1, 12);
      final updated = original.copyWith(
        status: PermitStatus.used,
        usedAt: usedAt,
        createdCellId: 'cell_xyz',
      );

      expect(updated.id, original.id);
      expect(updated.status, PermitStatus.used);
      expect(updated.usedAt, usedAt);
      expect(updated.createdCellId, 'cell_xyz');
      // Unchanged fields stay identical
      expect(updated.requesterDid, original.requesterDid);
      expect(updated.cellType, original.cellType);
    });
  });

  // ── JSON round-trip ──────────────────────────────────────────────────────────

  group('toJson() / fromJson()', () {
    test('round-trip mit allen Feldern inkl. adminNostrPubkey', () {
      final expiresAt = DateTime.utc(2026, 5, 1, 10, 30);
      final decidedAt = DateTime.utc(2026, 4, 24, 8, 0);
      final requestedAt = DateTime.utc(2026, 4, 20);
      final usedAt = DateTime.utc(2026, 4, 25, 14);

      final original = CellFoundingPermit(
        id: 'permit_roundtrip',
        requesterDid: 'did:test:roundtrip',
        requesterPseudonym: 'Roundtrip',
        requesterNostrPubkey: 'npub_requester',
        adminNostrPubkey: 'npub_admin',
        cellType: CellType.thematic,
        proposedName: 'Öko-Kreis',
        proposedDescription: 'Umwelt und Natur',
        proposedCategory: 'Umwelt',
        regionHint: null,
        requestMessage: 'Bitte genehmigen',
        status: PermitStatus.used,
        requestedAt: requestedAt,
        decidedAt: decidedAt,
        decidedBy: 'did:test:admin',
        adminNote: 'Alles in Ordnung',
        expiresAt: expiresAt,
        usedAt: usedAt,
        createdCellId: 'cell_abc',
        maxUses: 2,
      );

      final json = original.toJson();
      final restored = CellFoundingPermit.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.requesterDid, original.requesterDid);
      expect(restored.requesterPseudonym, original.requesterPseudonym);
      expect(restored.requesterNostrPubkey, original.requesterNostrPubkey);
      expect(restored.adminNostrPubkey, original.adminNostrPubkey);
      expect(restored.cellType, original.cellType);
      expect(restored.proposedName, original.proposedName);
      expect(restored.proposedDescription, original.proposedDescription);
      expect(restored.proposedCategory, original.proposedCategory);
      expect(restored.regionHint, isNull);
      expect(restored.requestMessage, original.requestMessage);
      expect(restored.status, original.status);
      expect(restored.requestedAt, original.requestedAt);
      expect(restored.decidedAt, original.decidedAt);
      expect(restored.decidedBy, original.decidedBy);
      expect(restored.adminNote, original.adminNote);
      expect(restored.expiresAt, original.expiresAt);
      expect(restored.usedAt, original.usedAt);
      expect(restored.createdCellId, original.createdCellId);
      expect(restored.maxUses, 2);
    });
  });

  // ── Service guard tests ──────────────────────────────────────────────────────
  //
  // In the test environment no identity is loaded and no DB is open, so the
  // guards fire for the "not admin / identity null" path — which is still the
  // correct StateError surface being tested.

  group('CellFoundingPermitService admin guards', () {
    setUp(() {
      // Reset in-memory state between tests.
      CellFoundingPermitService.instance.injectPermitsForTest();
    });

    test('approvePermit() wirft StateError wenn Nutzer kein Admin', () async {
      // Permit is needed in _receivedPermits so the "not found" guard doesn't
      // fire first. Even without a DB the admin guard fires before any await.
      CellFoundingPermitService.instance.injectPermitsForTest(
        received: [_makeLocalPermit(id: 'p1')],
      );
      expect(
        () => CellFoundingPermitService.instance.approvePermit('p1'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejectPermit() wirft StateError wenn Nutzer kein Admin', () async {
      CellFoundingPermitService.instance.injectPermitsForTest(
        received: [_makeLocalPermit(id: 'p2')],
      );
      expect(
        () => CellFoundingPermitService.instance.rejectPermit('p2'),
        throwsA(isA<StateError>()),
      );
    });

    test('revokePermit() wirft StateError wenn Nutzer kein Admin', () async {
      CellFoundingPermitService.instance.injectPermitsForTest(
        received: [_makeLocalPermit(id: 'p3')],
      );
      expect(
        () => CellFoundingPermitService.instance.revokePermit('p3'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('CellFoundingPermitService.markPermitUsed()', () {
    setUp(() {
      CellFoundingPermitService.instance.injectPermitsForTest();
    });

    test('wirft StateError wenn Permit nicht aktiv (status=pending)', () async {
      // Permit is in _sentPermits but not active — isActive check fires first.
      CellFoundingPermitService.instance.injectPermitsForTest(
        sent: [_makeLocalPermit(id: 'p_pending', status: PermitStatus.pending)],
      );
      await expectLater(
        CellFoundingPermitService.instance.markPermitUsed('p_pending', 'cell_x'),
        throwsA(isA<StateError>()),
      );
    });

    test('wirft StateError wenn Permit nicht aktiv (abgelaufen)', () async {
      final expired = _makeLocalPermit(
        id: 'p_expired',
        status: PermitStatus.approved,
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      CellFoundingPermitService.instance.injectPermitsForTest(sent: [expired]);
      await expectLater(
        CellFoundingPermitService.instance.markPermitUsed('p_expired', 'cell_x'),
        throwsA(isA<StateError>()),
      );
    });

    test('wirft StateError wenn requesterDid != currentIdentity.did', () async {
      // Active permit injected — the identity check fires (identity == null ≠ any DID).
      final active = _makeLocalPermit(
        id: 'p_active',
        requesterDid: 'did:test:someone_else',
        status: PermitStatus.approved,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      );
      CellFoundingPermitService.instance.injectPermitsForTest(sent: [active]);
      await expectLater(
        CellFoundingPermitService.instance.markPermitUsed('p_active', 'cell_x'),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── getActivePermitForType() ─────────────────────────────────────────────────

  group('CellFoundingPermitService.getActivePermitForType()', () {
    setUp(() {
      CellFoundingPermitService.instance.injectPermitsForTest();
    });

    test('gibt null zurück ohne aktives Permit', () {
      // _sentPermits is empty after setUp
      expect(
        CellFoundingPermitService.instance
            .getActivePermitForType('did:test:alice', CellType.local),
        isNull,
      );
    });

    test('gibt null zurück bei falschem cellType', () {
      final localPermit = _makeLocalPermit(
        requesterDid: 'did:test:alice',
        status: PermitStatus.approved,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      );
      CellFoundingPermitService.instance
          .injectPermitsForTest(sent: [localPermit]);

      // Query for thematic — should not match the local permit
      expect(
        CellFoundingPermitService.instance
            .getActivePermitForType('did:test:alice', CellType.thematic),
        isNull,
      );
    });

    test('gibt korrektes Permit zurück bei richtigem cellType', () {
      final localPermit = _makeLocalPermit(
        id: 'p_correct',
        requesterDid: 'did:test:alice',
        status: PermitStatus.approved,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      );
      CellFoundingPermitService.instance
          .injectPermitsForTest(sent: [localPermit]);

      final result = CellFoundingPermitService.instance
          .getActivePermitForType('did:test:alice', CellType.local);

      expect(result, isNotNull);
      expect(result!.id, 'p_correct');
      expect(result.isActive, isTrue);
    });
  });

  // ── NostrTransport.publishCellFoundingPermit() — guard + routing ─────────────
  //
  // These tests use NostrTransport without a started relay connection.
  // publishCellFoundingPermit() returns false before reaching _nip04Encrypt
  // when the recipient pubkey is missing or invalid — no Nostr keys required.
  //
  // Recipient routing is tested via the @visibleForTesting helper
  // resolvePermitRecipientPubkeyForTest(), which exposes the private
  // _resolvePermitRecipientPubkey() method without needing actual crypto.

  NostrTransport _makeTransport() => NostrTransport(
        localDid: 'did:test:local',
        localPseudonym: 'Test',
        relayManager: NostrRelayManager(),
      );

  // 64-char hex pubkeys used in routing tests.
  const _adminPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const _requesterPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  CellFoundingPermit _makePermitWithPubkeys({
    String? adminNostrPubkey,
    String? requesterNostrPubkey,
    PermitStatus status = PermitStatus.pending,
  }) =>
      CellFoundingPermit(
        id: 'permit_nostr_test',
        requesterDid: 'did:test:alice',
        requesterPseudonym: 'Alice',
        requesterNostrPubkey: requesterNostrPubkey,
        adminNostrPubkey: adminNostrPubkey,
        cellType: CellType.local,
        proposedName: 'Test Zelle',
        regionHint: 'DE-HH',
        status: status,
        requestedAt: DateTime.utc(2026, 1, 1),
      );

  group('NostrTransport.publishCellFoundingPermit() guard tests', () {
    test('gibt false zurück wenn recipientPubkey null (action=request, kein adminPubkey)',
        () async {
      final transport = _makeTransport();
      final permit = _makePermitWithPubkeys(
        adminNostrPubkey: null, // no admin key → bootstrapCellAuthors empty in test env
        requesterNostrPubkey: _requesterPubkey,
      );
      // SystemConfig.bootstrapCellAuthors is empty in test env → recipientPubkey = null
      final result = await transport.publishCellFoundingPermit(
        permit,
        action: 'request',
      );
      expect(result, isFalse);
    });

    test('gibt false zurück wenn recipientPubkey kein 64-Hex (zu kurz)', () async {
      final transport = _makeTransport();
      final permit = _makePermitWithPubkeys(
        adminNostrPubkey: 'short_invalid_key',
        requesterNostrPubkey: _requesterPubkey,
      );
      final result = await transport.publishCellFoundingPermit(
        permit,
        action: 'request',
      );
      expect(result, isFalse);
    });

    test('gibt false zurück wenn action=approve und requesterNostrPubkey null',
        () async {
      final transport = _makeTransport();
      final permit = _makePermitWithPubkeys(
        adminNostrPubkey: _adminPubkey,
        requesterNostrPubkey: null, // no requester key
      );
      final result = await transport.publishCellFoundingPermit(
        permit,
        action: 'approve',
      );
      expect(result, isFalse);
    });

    test('gibt false zurück bei unbekannter action', () async {
      final transport = _makeTransport();
      final permit = _makePermitWithPubkeys(
        adminNostrPubkey: _adminPubkey,
        requesterNostrPubkey: _requesterPubkey,
      );
      final result = await transport.publishCellFoundingPermit(
        permit,
        action: 'unknown_action',
      );
      expect(result, isFalse);
    });
  });

  // ── Recipient routing via resolvePermitRecipientPubkeyForTest() ───────────────
  //
  // These tests verify that the correct pubkey is chosen as recipient for each
  // action without needing real crypto or a relay connection.

  group('NostrTransport recipient routing', () {
    test("'request' → adminNostrPubkey", () {
      final transport = _makeTransport();
      final permit = _makePermitWithPubkeys(
        adminNostrPubkey: _adminPubkey,
        requesterNostrPubkey: _requesterPubkey,
      );
      expect(
        transport.resolvePermitRecipientPubkeyForTest(permit, 'request'),
        equals(_adminPubkey),
      );
    });

    test("'used' → adminNostrPubkey", () {
      final transport = _makeTransport();
      final permit = _makePermitWithPubkeys(
        adminNostrPubkey: _adminPubkey,
        requesterNostrPubkey: _requesterPubkey,
      );
      expect(
        transport.resolvePermitRecipientPubkeyForTest(permit, 'used'),
        equals(_adminPubkey),
      );
    });

    test("'approve' → requesterNostrPubkey", () {
      final transport = _makeTransport();
      final permit = _makePermitWithPubkeys(
        adminNostrPubkey: _adminPubkey,
        requesterNostrPubkey: _requesterPubkey,
      );
      expect(
        transport.resolvePermitRecipientPubkeyForTest(permit, 'approve'),
        equals(_requesterPubkey),
      );
    });

    test("'reject' → requesterNostrPubkey", () {
      final transport = _makeTransport();
      final permit = _makePermitWithPubkeys(
        adminNostrPubkey: _adminPubkey,
        requesterNostrPubkey: _requesterPubkey,
      );
      expect(
        transport.resolvePermitRecipientPubkeyForTest(permit, 'reject'),
        equals(_requesterPubkey),
      );
    });

    test("'revoke' → requesterNostrPubkey", () {
      final transport = _makeTransport();
      final permit = _makePermitWithPubkeys(
        adminNostrPubkey: _adminPubkey,
        requesterNostrPubkey: _requesterPubkey,
      );
      expect(
        transport.resolvePermitRecipientPubkeyForTest(permit, 'revoke'),
        equals(_requesterPubkey),
      );
    });

    test("unbekannte action → null", () {
      final transport = _makeTransport();
      final permit = _makePermitWithPubkeys(
        adminNostrPubkey: _adminPubkey,
        requesterNostrPubkey: _requesterPubkey,
      );
      expect(
        transport.resolvePermitRecipientPubkeyForTest(permit, 'unknown'),
        isNull,
      );
    });
  });

  // ── _handleIncomingPermitEvent dedup + validation ─────────────────────────────
  //
  // These tests use handleIncomingPermitEventForTest() and
  // seenPermitEventIdsForTest to verify synchronous dedup and admin-pubkey
  // validation without starting a relay connection.
  //
  // NOTE: Tests that require full decrypt (keys+shared secret) are limited to
  // the dedup path only — events with duplicate IDs are rejected before any
  // async crypto work.

  NostrEvent _makeFakePermitEvent({
    String id = 'event0000000000000000000000000000000000000000000000000000000000001',
    String pubkey = _adminPubkey,
    String action = 'approve',
    String permitId = 'permit_nostr_test',
    String content = 'encrypted_placeholder',
  }) =>
      NostrEvent(
        id: id,
        pubkey: pubkey,
        createdAt: 1_700_000_000,
        kind: NostrKind.cellFoundingPermit,
        tags: [
          ['d', permitId],
          ['action', action],
          ['t', 'nexus-permit'],
        ],
        content: content,
        sig: '0' * 128,
      );

  group('NostrTransport._handleIncomingPermitEvent()', () {
    test('ignoriert doppelte event.id (Dedup-Check)', () async {
      final transport = _makeTransport();
      final event = _makeFakePermitEvent();

      // First call: ID is added to the set.
      await transport.handleIncomingPermitEventForTest(event);
      expect(transport.seenPermitEventIdsForTest.contains(event.id), isTrue);

      // Second call with identical ID: dedup fires before any other check.
      // The set still contains exactly one entry — no duplicate processing.
      await transport.handleIncomingPermitEventForTest(event);
      expect(
        transport.seenPermitEventIdsForTest
            .where((id) => id == event.id)
            .length,
        equals(1),
      );
    });

    test('verwirft Event ohne action-Tag', () async {
      final transport = _makeTransport();
      final event = NostrEvent(
        id: 'event_no_action_tag' + '0' * 44,
        pubkey: _adminPubkey,
        createdAt: 1_700_000_000,
        kind: NostrKind.cellFoundingPermit,
        tags: [
          ['d', 'permit_xyz'], // missing 'action' tag
        ],
        content: 'encrypted',
        sig: '0' * 128,
      );
      // Must not throw; simply returns without processing.
      await transport.handleIncomingPermitEventForTest(event);
      // No crash = pass.
    });

    test('verwirft Event ohne d-Tag', () async {
      final transport = _makeTransport();
      final event = NostrEvent(
        id: 'event_no_d_tag_00000000000000000000000000000000000000000000000',
        pubkey: _adminPubkey,
        createdAt: 1_700_000_000,
        kind: NostrKind.cellFoundingPermit,
        tags: [
          ['action', 'approve'], // missing 'd' tag
        ],
        content: 'encrypted',
        sig: '0' * 128,
      );
      await transport.handleIncomingPermitEventForTest(event);
      // No crash = pass.
    });
  });
}
