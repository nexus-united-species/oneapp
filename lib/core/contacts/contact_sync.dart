import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as pkg_crypto;

import '../identity/bip39.dart';
import 'contact.dart';

/// Contact list sync between the user's own devices (TD-60).
///
/// The list travels as one encrypted, replaceable Nostr event (kind 30078,
/// `d` = [contactSyncDTag]); only devices holding the seed phrase can read
/// it. This file holds the pure parts: payload format, merge rules and key
/// derivation.

/// `d` tag of the contact list event.
const contactSyncDTag = 'nexus-contacts';

/// Payload format version.
const contactSyncVersion = 1;

/// Derives the 32-byte AES-256-GCM key for the contact list from the seed.
/// Separate from the backup and pod keys.
Uint8List deriveContactSyncKey(String mnemonic) {
  final seed64 = Bip39.mnemonicToSeed(mnemonic);
  final digest = pkg_crypto.sha256.convert([
    ...seed64,
    ...utf8.encode('nexus-contact-sync-v1'),
  ]);
  return Uint8List.fromList(digest.bytes);
}

/// Fields of a contact that are synced. Notes and local file paths stay on
/// the device; profile details come from each contact's Kind-0.
Map<String, dynamic> _syncEntry(Contact c) => {
      'did': c.did,
      'pseudonym': c.pseudonym,
      'trustLevel': c.trustLevel.name,
      'addedAt': c.addedAt.toUtc().toIso8601String(),
      'changedAt': c.changedAt.toUtc().toIso8601String(),
      'blocked': c.blocked,
      if (c.mutedUntil != null)
        'mutedUntil': c.mutedUntil!.toUtc().toIso8601String(),
      if (c.encryptionPublicKey != null)
        'encryptionPublicKey': c.encryptionPublicKey,
      if (c.nostrPubkey != null) 'nostrPubkey': c.nostrPubkey,
    };

/// Builds the payload of the contact list event.
Map<String, dynamic> buildContactSyncPayload(
  Iterable<Contact> contacts,
  Map<String, DateTime> tombstones,
) {
  final sorted = contacts.toList()..sort((a, b) => a.did.compareTo(b.did));
  final removed = tombstones.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return {
    'v': contactSyncVersion,
    'contacts': sorted.map(_syncEntry).toList(),
    'removed': [
      for (final e in removed)
        {'did': e.key, 'deletedAt': e.value.toUtc().toIso8601String()},
    ],
  };
}

/// What applying a received contact list changes locally.
class ContactSyncMerge {
  ContactSyncMerge({
    required this.added,
    required this.updated,
    required this.removed,
    required this.tombstones,
    required this.needsRepublish,
  });

  /// Contacts unknown on this device.
  final List<Contact> added;

  /// Copies of known contacts with newer synced fields.
  final List<Contact> updated;

  /// DIDs deleted on the other device after their last change here.
  final List<String> removed;

  /// Deletion marks to store (from the other device), DID → deletedAt.
  final Map<String, DateTime> tombstones;

  /// Whether this device knows something the received list lacks, so the
  /// merged list should be published again.
  final bool needsRepublish;

  bool get changesLocalState =>
      added.isNotEmpty ||
      updated.isNotEmpty ||
      removed.isNotEmpty ||
      tombstones.isNotEmpty;
}

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toUtc() : null;

bool _isHex64(Object? v) =>
    v is String && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(v);

/// Merges a received contact list into the local state.
///
/// Per contact the newer `changedAt` wins for trust level, block and mute
/// state. Keys are only filled in where this device has none. A deletion
/// wins over a contact whose last change is older; a contact changed after
/// the deletion stays. Malformed entries are skipped.
ContactSyncMerge mergeContactSync({
  required List<Contact> local,
  required Map<String, DateTime> localTombstones,
  required Map<String, dynamic> remote,
}) {
  final localByDid = {for (final c in local) c.did: c};
  final added = <Contact>[];
  final updated = <Contact>[];
  final removed = <String>[];
  final tombstones = <String, DateTime>{};
  var needsRepublish = false;

  // ── Deletions from the other device ───────────────────────────────────────
  final remoteTombstones = <String, DateTime>{};
  for (final raw in (remote['removed'] as List?) ?? const []) {
    if (raw is! Map) continue;
    final did = raw['did'];
    final at = _date(raw['deletedAt']);
    if (did is! String || did.isEmpty || at == null) continue;
    remoteTombstones[did] = at;

    // A contact changed here after the deletion stays, and so does its row:
    // storing the mark would overwrite the contact in the database (audit
    // C-1). The other device learns about the newer state via republish.
    final contact = localByDid[did];
    if (contact != null && contact.changedAt.toUtc().isAfter(at)) continue;

    final known = localTombstones[did];
    if (known == null || at.isAfter(known)) tombstones[did] = at;
    if (contact != null) removed.add(did);
  }

  // ── Contacts from the other device ────────────────────────────────────────
  final remoteDids = <String>{};
  for (final raw in (remote['contacts'] as List?) ?? const []) {
    if (raw is! Map) continue;
    final did = raw['did'];
    final changedAt = _date(raw['changedAt']);
    if (did is! String || did.isEmpty || changedAt == null) continue;
    remoteDids.add(did);

    final deletedAt = remoteTombstones[did] ?? localTombstones[did];
    if (deletedAt != null && !changedAt.isAfter(deletedAt)) continue;

    final trust = TrustLevel.values
        .where((t) => t.name == raw['trustLevel'])
        .firstOrNull;
    if (trust == null) continue;
    final encKey =
        _isHex64(raw['encryptionPublicKey']) ? raw['encryptionPublicKey'] as String : null;
    final nostrKey =
        _isHex64(raw['nostrPubkey']) ? raw['nostrPubkey'] as String : null;
    final mutedUntil = _date(raw['mutedUntil']);
    final blocked = raw['blocked'] == true;

    final existing = localByDid[did];
    if (existing == null || removed.contains(did)) {
      if (existing != null) continue; // deleted here by the merge above
      final pseudonym = raw['pseudonym'];
      added.add(Contact(
        did: did,
        pseudonym: pseudonym is String && pseudonym.isNotEmpty
            ? pseudonym
            : (did.length > 12 ? did.substring(did.length - 12) : did),
        trustLevel: trust,
        addedAt: _date(raw['addedAt']) ?? changedAt,
        lastSeen: DateTime.now(),
        blocked: blocked,
        mutedUntil: mutedUntil,
        encryptionPublicKey: encKey,
        nostrPubkey: nostrKey,
        changedAt: changedAt,
      ));
      continue;
    }

    final copy = Contact.fromJson(existing.toJson());
    var changed = false;
    final localChangedAt = existing.changedAt.toUtc();
    if (changedAt.isAfter(localChangedAt)) {
      copy
        ..trustLevel = trust
        ..blocked = blocked
        ..mutedUntil = mutedUntil
        ..changedAt = changedAt;
      changed = true;
    } else if (localChangedAt.isAfter(changedAt)) {
      needsRepublish = true;
    }
    if (copy.encryptionPublicKey == null && encKey != null) {
      copy.encryptionPublicKey = encKey;
      changed = true;
    }
    if (copy.nostrPubkey == null && nostrKey != null) {
      copy.nostrPubkey = nostrKey;
      changed = true;
    }
    if (changed) updated.add(copy);
  }

  // ── What the other device does not know yet ───────────────────────────────
  for (final c in local) {
    if (removed.contains(c.did)) continue;
    if (!remoteDids.contains(c.did)) {
      final deletedAt = remoteTombstones[c.did];
      if (deletedAt == null || c.changedAt.toUtc().isAfter(deletedAt)) {
        needsRepublish = true;
      }
    }
  }
  for (final e in localTombstones.entries) {
    final theirs = remoteTombstones[e.key];
    if (theirs == null || e.value.isAfter(theirs)) needsRepublish = true;
  }

  return ContactSyncMerge(
    added: added,
    updated: updated,
    removed: removed,
    tombstones: tombstones,
    needsRepublish: needsRepublish,
  );
}
