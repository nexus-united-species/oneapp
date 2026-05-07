import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/delegation.dart';

void main() {
  // ── DelegationStatus enum ─────────────────────────────────────────────────

  group('DelegationStatus enum (Phase G2.1.1a)', () {
    test('has exactly five values', () {
      expect(DelegationStatus.values.length, equals(5));
    });

    test('contains all expected values by name', () {
      final names = DelegationStatus.values.map((e) => e.name).toList();
      expect(names, containsAll([
        'ACTIVE',
        'REVOKED',
        'SUPERSEDED',
        'EXPIRED',
        'INVALID',
      ]));
    });
  });

  // ── parseDelegationStatus ─────────────────────────────────────────────────

  group('parseDelegationStatus (Phase G2.1.1a)', () {
    test('parses "ACTIVE" correctly', () {
      expect(parseDelegationStatus('ACTIVE'), equals(DelegationStatus.ACTIVE));
    });

    test('parses "REVOKED" correctly', () {
      expect(parseDelegationStatus('REVOKED'), equals(DelegationStatus.REVOKED));
    });

    test('parses "SUPERSEDED" correctly', () {
      expect(parseDelegationStatus('SUPERSEDED'),
          equals(DelegationStatus.SUPERSEDED));
    });

    test('parses "EXPIRED" correctly — reserved enum value, parseable but '
        'not persisted in G2.1 (D9 Variante A)', () {
      expect(parseDelegationStatus('EXPIRED'), equals(DelegationStatus.EXPIRED));
    });

    test('parses "INVALID" correctly — reserved enum value, parseable but '
        'not persisted in G2.1 (D9 Variante A)', () {
      expect(parseDelegationStatus('INVALID'), equals(DelegationStatus.INVALID));
    });

    test('returns ACTIVE for null (defensive fallback)', () {
      expect(parseDelegationStatus(null), equals(DelegationStatus.ACTIVE));
    });

    test('returns ACTIVE for unknown string (defensive fallback)', () {
      expect(parseDelegationStatus('TOTALLY_UNKNOWN'),
          equals(DelegationStatus.ACTIVE));
    });

    test('returns ACTIVE for empty string (defensive fallback)', () {
      expect(parseDelegationStatus(''), equals(DelegationStatus.ACTIVE));
    });
  });

  // ── Delegation.create ─────────────────────────────────────────────────────

  group('Delegation.create (Phase G2.1.1a)', () {
    test('generates a non-empty delegationId', () {
      final d = Delegation.create(
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_001',
        cellId: 'cell_001',
      );
      expect(d.delegationId, isNotEmpty);
    });

    test('generates unique IDs across two calls', () {
      final a = Delegation.create(
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_001',
        cellId: 'cell_001',
      );
      final b = Delegation.create(
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_001',
        cellId: 'cell_001',
      );
      expect(a.delegationId, isNot(equals(b.delegationId)));
    });

    test('sets status to ACTIVE by default', () {
      final d = Delegation.create(
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_001',
        cellId: 'cell_001',
      );
      expect(d.status, equals(DelegationStatus.ACTIVE));
    });

    test('nostrEventId defaults to empty string', () {
      final d = Delegation.create(
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_001',
        cellId: 'cell_001',
      );
      expect(d.nostrEventId, equals(''));
    });

    test('createdAt and updatedAt are UTC', () {
      final before = DateTime.now().toUtc();
      final d = Delegation.create(
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_001',
        cellId: 'cell_001',
      );
      final after = DateTime.now().toUtc();
      expect(d.createdAt.isUtc, isTrue);
      expect(d.updatedAt.isUtc, isTrue);
      expect(
          d.createdAt.isAfter(before) ||
              d.createdAt.isAtSameMomentAs(before),
          isTrue);
      expect(
          d.createdAt.isBefore(after) ||
              d.createdAt.isAtSameMomentAs(after),
          isTrue);
    });

    test('createdAt equals updatedAt on create', () {
      final d = Delegation.create(
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_001',
        cellId: 'cell_001',
      );
      expect(d.createdAt, equals(d.updatedAt));
    });

    test('accepts custom status (e.g. REVOKED for incoming wire events)', () {
      final d = Delegation.create(
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_001',
        cellId: 'cell_001',
        status: DelegationStatus.REVOKED,
      );
      expect(d.status, equals(DelegationStatus.REVOKED));
    });
  });

  // ── Delegation.toMap ──────────────────────────────────────────────────────

  group('Delegation.toMap (Phase G2.1.1a)', () {
    late Delegation d;

    setUp(() {
      d = Delegation.create(
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_abc',
        cellId: 'cell_xyz',
      );
    });

    test('produces exactly 9 keys', () {
      expect(d.toMap().length, equals(9));
    });

    test('uses snake_case keys', () {
      final m = d.toMap();
      expect(m.containsKey('delegation_id'), isTrue);
      expect(m.containsKey('delegator_did'), isTrue);
      expect(m.containsKey('delegate_did'), isTrue);
      expect(m.containsKey('proposal_id'), isTrue);
      expect(m.containsKey('cell_id'), isTrue);
      expect(m.containsKey('status'), isTrue);
      expect(m.containsKey('nostr_event_id'), isTrue);
      expect(m.containsKey('created_at'), isTrue);
      expect(m.containsKey('updated_at'), isTrue);
      // Verify no camelCase leaks
      expect(m.containsKey('delegationId'), isFalse);
      expect(m.containsKey('delegatorDid'), isFalse);
    });

    test('serialises status as name string', () {
      expect(d.toMap()['status'], equals('ACTIVE'));
    });

    test('timestamps are stored as int (millisecondsSinceEpoch)', () {
      final m = d.toMap();
      expect(m['created_at'], isA<int>());
      expect(m['updated_at'], isA<int>());
    });

    test('nostrEventId defaults to empty string in map', () {
      expect(d.toMap()['nostr_event_id'], equals(''));
    });
  });

  // ── Delegation.fromMap ────────────────────────────────────────────────────

  group('Delegation.fromMap (Phase G2.1.1a)', () {
    test('parses all required fields correctly', () {
      final now = DateTime.utc(2026, 5, 7, 12, 0, 0);
      final m = {
        'delegation_id': 'del_001',
        'delegator_did': 'did:key:z6MkAlice',
        'delegate_did': 'did:key:z6MkBob',
        'proposal_id': 'prop_abc',
        'cell_id': 'cell_xyz',
        'status': 'ACTIVE',
        'nostr_event_id': '',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      };
      final d = Delegation.fromMap(m);
      expect(d.delegationId, equals('del_001'));
      expect(d.delegatorDid, equals('did:key:z6MkAlice'));
      expect(d.delegateDid, equals('did:key:z6MkBob'));
      expect(d.proposalId, equals('prop_abc'));
      expect(d.cellId, equals('cell_xyz'));
      expect(d.status, equals(DelegationStatus.ACTIVE));
      expect(d.nostrEventId, equals(''));
      expect(d.createdAt.millisecondsSinceEpoch,
          equals(now.millisecondsSinceEpoch));
      expect(d.createdAt.isUtc, isTrue);
    });

    test('handles null nostrEventId (DB default) → empty string', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final m = {
        'delegation_id': 'del_002',
        'delegator_did': 'did:key:z6MkAlice',
        'delegate_did': 'did:key:z6MkBob',
        'proposal_id': 'prop_abc',
        'cell_id': 'cell_xyz',
        'status': 'REVOKED',
        'nostr_event_id': null,
        'created_at': now,
        'updated_at': now,
      };
      final d = Delegation.fromMap(m);
      expect(d.nostrEventId, equals(''));
    });

    test('numeric created_at/updated_at robust against num type', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final m = {
        'delegation_id': 'del_003',
        'delegator_did': 'did:key:z6MkAlice',
        'delegate_did': 'did:key:z6MkBob',
        'proposal_id': 'prop_abc',
        'cell_id': 'cell_xyz',
        'status': 'ACTIVE',
        'nostr_event_id': '',
        'created_at': now + 0.0, // num (double), not int
        'updated_at': now + 0.0,
      };
      // Should not throw — (m['created_at'] as num).toInt() handles this.
      expect(() => Delegation.fromMap(m), returnsNormally);
    });

    test('unknown status falls back to ACTIVE (defensive)', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final m = {
        'delegation_id': 'del_004',
        'delegator_did': 'did:key:z6MkAlice',
        'delegate_did': 'did:key:z6MkBob',
        'proposal_id': 'prop_abc',
        'cell_id': 'cell_xyz',
        'status': 'UNKNOWN_STATUS',
        'nostr_event_id': '',
        'created_at': now,
        'updated_at': now,
      };
      final d = Delegation.fromMap(m);
      expect(d.status, equals(DelegationStatus.ACTIVE));
    });
  });

  // ── Delegation.copyWith ───────────────────────────────────────────────────

  group('Delegation.copyWith (Phase G2.1.1a)', () {
    late Delegation original;

    setUp(() {
      original = Delegation(
        delegationId: 'del_copy_001',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_abc',
        cellId: 'cell_xyz',
        status: DelegationStatus.ACTIVE,
        createdAt: DateTime.utc(2026, 5, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
      );
    });

    test('updates only status, preserves all other fields', () {
      final updated = original.copyWith(status: DelegationStatus.REVOKED);
      expect(updated.status, equals(DelegationStatus.REVOKED));
      expect(updated.delegationId, equals(original.delegationId));
      expect(updated.delegatorDid, equals(original.delegatorDid));
      expect(updated.delegateDid, equals(original.delegateDid));
      expect(updated.proposalId, equals(original.proposalId));
      expect(updated.cellId, equals(original.cellId));
      expect(updated.createdAt, equals(original.createdAt));
      expect(updated.updatedAt, equals(original.updatedAt));
      expect(updated.nostrEventId, equals(original.nostrEventId));
    });

    test('updates only updatedAt, preserves status and createdAt', () {
      final newTime = DateTime.utc(2026, 5, 7);
      final updated = original.copyWith(updatedAt: newTime);
      expect(updated.updatedAt, equals(newTime));
      expect(updated.createdAt, equals(original.createdAt));
      expect(updated.status, equals(original.status));
    });

    test('updates nostrEventId, preserves all other fields', () {
      final eventId = 'abcd1234' * 8;
      final updated = original.copyWith(nostrEventId: eventId);
      expect(updated.nostrEventId, equals(eventId));
      expect(updated.status, equals(original.status));
      expect(updated.delegationId, equals(original.delegationId));
    });

    test('copyWith with no args returns equivalent object', () {
      final copy = original.copyWith();
      expect(copy.delegationId, equals(original.delegationId));
      expect(copy.status, equals(original.status));
      expect(copy.createdAt, equals(original.createdAt));
      expect(copy.updatedAt, equals(original.updatedAt));
    });
  });

  // ── Round-trip ────────────────────────────────────────────────────────────

  group('Delegation round-trip (Phase G2.1.1a)', () {
    test('create → toMap → fromMap preserves all fields', () {
      final original = Delegation(
        delegationId: 'del_rt_001',
        delegatorDid: 'did:key:z6MkAlice',
        delegateDid: 'did:key:z6MkBob',
        proposalId: 'prop_roundtrip',
        cellId: 'cell_roundtrip',
        status: DelegationStatus.SUPERSEDED,
        createdAt: DateTime.utc(2026, 5, 1, 10, 0),
        updatedAt: DateTime.utc(2026, 5, 7, 12, 30),
        nostrEventId: 'a1b2c3d4' * 8,
      );

      final restored = Delegation.fromMap(original.toMap());

      expect(restored.delegationId, equals(original.delegationId));
      expect(restored.delegatorDid, equals(original.delegatorDid));
      expect(restored.delegateDid, equals(original.delegateDid));
      expect(restored.proposalId, equals(original.proposalId));
      expect(restored.cellId, equals(original.cellId));
      expect(restored.status, equals(DelegationStatus.SUPERSEDED));
      expect(restored.nostrEventId, equals(original.nostrEventId));
      expect(restored.createdAt.millisecondsSinceEpoch,
          equals(original.createdAt.millisecondsSinceEpoch));
      expect(restored.updatedAt.millisecondsSinceEpoch,
          equals(original.updatedAt.millisecondsSinceEpoch));
      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.updatedAt.isUtc, isTrue);
    });
  });
}
