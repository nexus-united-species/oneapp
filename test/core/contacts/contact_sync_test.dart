import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/contacts/contact.dart';
import 'package:nexus_oneapp/core/contacts/contact_sync.dart';
import 'package:nexus_oneapp/core/storage/pod_encryption.dart';
import 'package:nexus_oneapp/services/backup_service.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon about';
final _hexA = 'a' * 64;
final _hexB = 'b' * 64;

Contact _contact(
  String did, {
  TrustLevel trust = TrustLevel.contact,
  DateTime? changedAt,
  bool blocked = false,
  String? encKey,
  String? nostrKey,
}) {
  final at = changedAt ?? DateTime.utc(2026, 11, 1);
  return Contact(
    did: did,
    pseudonym: 'Name $did',
    trustLevel: trust,
    addedAt: DateTime.utc(2026, 10, 1),
    lastSeen: DateTime.utc(2026, 11, 1),
    blocked: blocked,
    encryptionPublicKey: encKey,
    nostrPubkey: nostrKey,
    changedAt: at,
  );
}

Map<String, dynamic> _remote(List<Contact> contacts,
        [Map<String, DateTime> tombstones = const {}]) =>
    jsonDecode(jsonEncode(buildContactSyncPayload(contacts, tombstones)))
        as Map<String, dynamic>;

void main() {
  group('Contact.changedAt', () {
    test('defaults to addedAt and survives JSON', () {
      final plain = Contact(
        did: 'did:key:x',
        pseudonym: 'X',
        trustLevel: TrustLevel.contact,
        addedAt: DateTime.utc(2026, 10, 1),
        lastSeen: DateTime.utc(2026, 11, 1),
      );
      expect(plain.changedAt, DateTime.utc(2026, 10, 1));

      final changed = _contact('did:key:y', changedAt: DateTime.utc(2026, 11, 5));
      expect(Contact.fromJson(changed.toJson()).changedAt,
          DateTime.utc(2026, 11, 5));
    });

    test('older stored contacts without the field fall back to addedAt', () {
      final json = _contact('did:key:z').toJson()..remove('changedAt');
      expect(Contact.fromJson(json).changedAt, DateTime.utc(2026, 10, 1));
    });
  });

  group('buildContactSyncPayload', () {
    test('contains synced fields but no notes or local image paths', () {
      final c = _contact('did:key:a', encKey: _hexA)
        ..notes = 'privat'
        ..profileImage = '/data/bild.jpg';
      final payload = buildContactSyncPayload([c], {});
      final entry = (payload['contacts'] as List).single as Map;

      expect(payload['v'], contactSyncVersion);
      expect(entry['did'], 'did:key:a');
      expect(entry['encryptionPublicKey'], _hexA);
      expect(entry.containsKey('notes'), isFalse);
      expect(entry.containsKey('profileImage'), isFalse);
    });

    test('is stable regardless of contact order', () {
      final a = _contact('did:key:a');
      final b = _contact('did:key:b');
      expect(jsonEncode(buildContactSyncPayload([a, b], {})),
          jsonEncode(buildContactSyncPayload([b, a], {})));
    });
  });

  group('mergeContactSync', () {
    test('adds contacts unknown on this device', () {
      final merge = mergeContactSync(
        local: [],
        localTombstones: {},
        remote: _remote([_contact('did:key:a', nostrKey: _hexB)]),
      );

      expect(merge.added.single.did, 'did:key:a');
      expect(merge.added.single.nostrPubkey, _hexB);
      expect(merge.needsRepublish, isFalse);
    });

    test('a newer change on the other device wins', () {
      final local = _contact('did:key:a', changedAt: DateTime.utc(2026, 11, 1));
      final remote = _contact('did:key:a',
          trust: TrustLevel.trusted,
          blocked: true,
          changedAt: DateTime.utc(2026, 11, 2));

      final merge = mergeContactSync(
          local: [local], localTombstones: {}, remote: _remote([remote]));

      expect(merge.updated.single.trustLevel, TrustLevel.trusted);
      expect(merge.updated.single.blocked, isTrue);
      expect(local.trustLevel, TrustLevel.contact,
          reason: 'the local object itself is not changed');
    });

    test('an older remote change loses and asks for a republish', () {
      final local = _contact('did:key:a',
          trust: TrustLevel.guardian, changedAt: DateTime.utc(2026, 11, 3));
      final remote = _contact('did:key:a', changedAt: DateTime.utc(2026, 11, 1));

      final merge = mergeContactSync(
          local: [local], localTombstones: {}, remote: _remote([remote]));

      expect(merge.updated, isEmpty);
      expect(merge.needsRepublish, isTrue);
    });

    test('missing keys are filled in, existing keys stay', () {
      final local = _contact('did:key:a', encKey: _hexA);
      final remote = _contact('did:key:a', encKey: _hexB, nostrKey: _hexB);

      final merge = mergeContactSync(
          local: [local], localTombstones: {}, remote: _remote([remote]));

      expect(merge.updated.single.encryptionPublicKey, _hexA);
      expect(merge.updated.single.nostrPubkey, _hexB);
    });

    test('absence in the received list never deletes', () {
      final merge = mergeContactSync(
        local: [_contact('did:key:a')],
        localTombstones: {},
        remote: _remote([]),
      );

      expect(merge.removed, isEmpty);
      expect(merge.needsRepublish, isTrue);
    });

    test('a deletion removes a contact last changed before it', () {
      final merge = mergeContactSync(
        local: [_contact('did:key:a', changedAt: DateTime.utc(2026, 11, 1))],
        localTombstones: {},
        remote: _remote([], {'did:key:a': DateTime.utc(2026, 11, 2)}),
      );

      expect(merge.removed, ['did:key:a']);
      expect(merge.tombstones['did:key:a'], DateTime.utc(2026, 11, 2));
    });

    test('a contact changed after the deletion stays', () {
      final merge = mergeContactSync(
        local: [_contact('did:key:a', changedAt: DateTime.utc(2026, 11, 3))],
        localTombstones: {},
        remote: _remote([], {'did:key:a': DateTime.utc(2026, 11, 2)}),
      );

      expect(merge.removed, isEmpty);
      expect(merge.needsRepublish, isTrue);
    });

    test('a contact deleted here does not come back with an older entry', () {
      final merge = mergeContactSync(
        local: [],
        localTombstones: {'did:key:a': DateTime.utc(2026, 11, 2)},
        remote: _remote(
            [_contact('did:key:a', changedAt: DateTime.utc(2026, 11, 1))]),
      );

      expect(merge.added, isEmpty);
      expect(merge.needsRepublish, isTrue,
          reason: 'the other device must learn about the deletion');
    });

    test('identical lists change nothing and need no republish', () {
      final contacts = [_contact('did:key:a'), _contact('did:key:b')];
      final merge = mergeContactSync(
        local: contacts,
        localTombstones: {'did:key:c': DateTime.utc(2026, 10, 5)},
        remote: _remote(contacts, {'did:key:c': DateTime.utc(2026, 10, 5)}),
      );

      expect(merge.changesLocalState, isFalse);
      expect(merge.needsRepublish, isFalse);
    });

    test('malformed entries are skipped', () {
      final merge = mergeContactSync(
        local: [],
        localTombstones: {},
        remote: {
          'v': 1,
          'contacts': [
            'kaputt',
            {'did': 'did:key:a'},
            {
              'did': 'did:key:b',
              'changedAt': '2026-11-01T00:00:00Z',
              'trustLevel': 'gibtsnicht',
            },
            {
              'did': 'did:key:c',
              'changedAt': '2026-11-01T00:00:00Z',
              'trustLevel': 'contact',
              'encryptionPublicKey': 'zu-kurz',
            },
          ],
          'removed': [
            {'did': 'did:key:d'},
          ],
        },
      );

      expect(merge.added.map((c) => c.did), ['did:key:c']);
      expect(merge.added.single.encryptionPublicKey, isNull);
      expect(merge.tombstones, isEmpty);
    });
  });

  group('deriveContactSyncKey', () {
    test('is deterministic and differs from the backup key', () {
      final key = deriveContactSyncKey(_mnemonic);
      expect(key, hasLength(32));
      expect(deriveContactSyncKey(_mnemonic), key);
      expect(key, isNot(deriveBackupKeySync(_mnemonic)));
    });

    test('encrypted payload round-trips with the derived key', () async {
      final key = deriveContactSyncKey(_mnemonic);
      final payload = jsonEncode(buildContactSyncPayload([_contact('did:key:a')], {}));

      final encrypted = await PodEncryption.encrypt(payload, key);
      expect(encrypted, isNot(contains('did:key:a')));
      expect(await PodEncryption.decrypt(encrypted, key), payload);
    });
  });
}
