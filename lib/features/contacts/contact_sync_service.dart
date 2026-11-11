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

  /// After the first relay reported the end of its stored events (EOSE):
  /// time for a list that is still being verified or decrypted to arrive
  /// before this device publishes its own (audit C-2).
  static const afterEoseDelay = Duration(seconds: 3);

  NostrTransport? _transport;
  Uint8List? _key;
  Future<Uint8List?> _keyReady = Future.value(null);
  StreamSubscription<void>? _changeSub;
  StreamSubscription<void>? _eoseSub;
  StreamSubscription<({String content, int createdAt})>? _incomingSub;
  Timer? _publishTimer;
  Timer? _initialTimer;
  int _newestAppliedAt = 0;
  bool _sawList = false;
  bool _initialDecided = false;
  void Function(List<Contact> added)? _onContactsAdded;

  /// Connects to [transport]. [onContactsAdded] is called for contacts that
  /// arrived from another device (e.g. to fetch their Kind-0 profiles).
  ///
  /// The listeners are registered synchronously, before the first `await`,
  /// so a caller that starts the transport right after `attach` (even
  /// without awaiting it) cannot miss the first list (audit C-3, sync law 2).
  Future<void> attach(
    NostrTransport transport, {
    void Function(List<Contact> added)? onContactsAdded,
    @visibleForTesting Future<String?> Function()? loadSeedPhrase,
  }) async {
    _stopListening();
    _transport = transport;
    _onContactsAdded = onContactsAdded;
    _newestAppliedAt = 0;
    _sawList = false;
    _initialDecided = false;
    _key = null;
    final keyReady = Completer<Uint8List?>();
    _keyReady = keyReady.future;
    _incomingSub = transport.onContactSync.listen(_onIncoming);
    _eoseSub = transport.onContactSyncEose.listen((_) => _onEose());
    _changeSub = ContactService.instance.syncRelevantChanges
        .listen((_) => schedulePublish());

    final mnemonic = await (loadSeedPhrase ??
        IdentityService.instance.loadSeedPhrase)();
    final key = mnemonic == null ? null : deriveContactSyncKey(mnemonic);
    if (key == null) {
      debugPrint('[CONTACT-SYNC] No seed phrase – contact sync disabled');
    }
    _key = key;
    keyReady.complete(key);
  }

  Future<void> detach() async {
    _stopListening();
    _transport = null;
    _key = null;
  }

  void _stopListening() {
    _publishTimer?.cancel();
    _initialTimer?.cancel();
    unawaited(_changeSub?.cancel());
    unawaited(_eoseSub?.cancel());
    unawaited(_incomingSub?.cancel());
    _changeSub = null;
    _eoseSub = null;
    _incomingSub = null;
  }

  /// First EOSE: the relay has no list newer than what it already sent.
  /// Publish our own only if no list arrived meanwhile; otherwise the merge
  /// decides whether a republish is needed.
  void _onEose() {
    if (_initialDecided) return;
    _initialDecided = true;
    _initialTimer = Timer(afterEoseDelay, () {
      if (!_sawList) {
        debugPrint('[CONTACT-SYNC] No contact list on the relays – '
            'publishing ours');
        unawaited(_publish());
      }
    });
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
    // Synchronously, before any await: the EOSE timer must see it.
    _sawList = true;
    final key = await _keyReady;
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
