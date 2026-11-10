import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/contacts/contact.dart';
import '../../core/contacts/contact_service.dart';
import '../../core/contacts/contact_sync.dart';
import '../../core/identity/identity_service.dart';
import '../../core/storage/pod_encryption.dart';
import '../../core/transport/nostr/nostr_transport.dart';

/// Keeps the contact list in step between the user's own devices (TD-60).
///
/// Publishes the encrypted list a few seconds after a relevant change and
/// merges lists published by the other devices. Absence of a contact in a
/// received list never deletes it; only explicit deletion marks do.
class ContactSyncService {
  ContactSyncService._();
  static final instance = ContactSyncService._();

  /// Bundles quick successive changes into one publish.
  static const publishDelay = Duration(seconds: 5);

  /// Time to wait for the other devices' list before publishing our own
  /// after start, so a merged list goes out instead of a partial one.
  static const initialPublishDelay = Duration(seconds: 20);

  NostrTransport? _transport;
  Uint8List? _key;
  StreamSubscription<void>? _changeSub;
  StreamSubscription<({String content, int createdAt})>? _incomingSub;
  Timer? _publishTimer;
  Timer? _initialTimer;
  int _newestAppliedAt = 0;
  void Function(List<Contact> added)? _onContactsAdded;

  /// Connects to [transport]. [onContactsAdded] is called for contacts that
  /// arrived from another device (e.g. to fetch their Kind-0 profiles).
  Future<void> attach(
    NostrTransport transport, {
    void Function(List<Contact> added)? onContactsAdded,
  }) async {
    await detach();
    final mnemonic = await IdentityService.instance.loadSeedPhrase();
    if (mnemonic == null) {
      debugPrint('[CONTACT-SYNC] No seed phrase – contact sync disabled');
      return;
    }
    _key = deriveContactSyncKey(mnemonic);
    _transport = transport;
    _onContactsAdded = onContactsAdded;
    _incomingSub = transport.onContactSync.listen(_onIncoming);
    _changeSub = ContactService.instance.syncRelevantChanges
        .listen((_) => schedulePublish());
    _initialTimer = Timer(initialPublishDelay, () {
      if (_newestAppliedAt == 0) unawaited(_publish());
    });
  }

  Future<void> detach() async {
    _publishTimer?.cancel();
    _initialTimer?.cancel();
    await _changeSub?.cancel();
    await _incomingSub?.cancel();
    _changeSub = null;
    _incomingSub = null;
    _transport = null;
    _key = null;
  }

  void schedulePublish() {
    _publishTimer?.cancel();
    _publishTimer = Timer(publishDelay, () => unawaited(_publish()));
  }

  Future<void> _publish() async {
    final transport = _transport;
    final key = _key;
    if (transport == null || key == null) return;
    final contacts = ContactService.instance.allContacts;
    final tombstones = ContactService.instance.tombstones;
    // A fresh device must not replace the list on the relays with nothing.
    if (contacts.isEmpty && tombstones.isEmpty) {
      debugPrint('[CONTACT-SYNC] Nothing to publish yet');
      return;
    }
    try {
      final payload = jsonEncode(buildContactSyncPayload(contacts, tombstones));
      final encrypted = await PodEncryption.encrypt(payload, key);
      await transport.publishContactSync(encrypted);
    } on Exception catch (e) {
      debugPrint('[CONTACT-SYNC] Publish failed: $e');
    }
  }

  Future<void> _onIncoming(({String content, int createdAt}) list) async {
    final key = _key;
    if (key == null) return;
    if (list.createdAt < _newestAppliedAt) {
      debugPrint('[CONTACT-SYNC] Older contact list ignored');
      return;
    }
    final Map<String, dynamic> remote;
    try {
      final plain = await PodEncryption.decrypt(list.content, key);
      final decoded = jsonDecode(plain);
      if (decoded is! Map<String, dynamic>) return;
      remote = decoded;
    } on Object catch (e) {
      debugPrint('[CONTACT-SYNC] Contact list not readable: $e');
      return;
    }
    _newestAppliedAt = list.createdAt;

    final merge = mergeContactSync(
      local: ContactService.instance.allContacts,
      localTombstones: ContactService.instance.tombstones,
      remote: remote,
    );
    await ContactService.instance.applySyncMerge(merge);
    print('[CONTACT-SYNC] Merged: +${merge.added.length} '
        '~${merge.updated.length} -${merge.removed.length}, '
        'republish=${merge.needsRepublish}');
    if (merge.added.isNotEmpty) _onContactsAdded?.call(merge.added);
    if (merge.needsRepublish) schedulePublish();
  }
}
