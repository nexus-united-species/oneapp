import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/contacts/contact.dart';
import 'package:nexus_oneapp/core/contacts/contact_service.dart';
import 'package:nexus_oneapp/core/contacts/contact_sync.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/storage/pod_encryption.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/core/transport/nostr/publish_result.dart';
import 'package:nexus_oneapp/features/contacts/contact_sync_service.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon about';

class _FakeRelayManager extends NostrRelayManager {
  _FakeRelayManager() : super(relayUrls: const []);

  final _events = StreamController<NostrEvent>.broadcast(sync: true);
  final _eose = StreamController<String>.broadcast(sync: true);
  final List<NostrEvent> published = [];
  final Map<String, Map<String, dynamic>> subscriptions = {};

  @override
  Stream<NostrEvent> get onEvent => _events.stream;
  @override
  Stream<String> get onEose => _eose.stream;
  @override
  bool get hasConnectedRelay => true;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  void publishFireAndForget(NostrEvent event) => published.add(event);
  @override
  Future<RelayPublishOutcome> publish(
    NostrEvent event, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    published.add(event);
    return RelayPublishOutcome(
      eventId: event.id,
      sentToRelays: const ['wss://fake.relay'],
      acceptedRelays: const ['wss://fake.relay'],
      rejections: const {},
      timedOut: false,
    );
  }

  @override
  String subscribe(Map<String, dynamic> filter) {
    final id = generateSubId();
    subscriptions[id] = filter;
    return id;
  }

  @override
  void closeSubscription(String subId) => subscriptions.remove(subId);

  void deliver(NostrEvent e) => _events.add(e);

  void eoseForContactList() => _eose.add(subscriptions.entries
      .singleWhere(
          (e) => (e.value['#d'] as List?)?.contains(contactSyncDTag) == true)
      .key);

  List<NostrEvent> get contactLists => published
      .where((e) =>
          e.kind == NostrKind.presence && e.tagValue('d') == contactSyncDTag)
      .toList();
}

final _contact = Contact(
  did: 'did:key:freund',
  pseudonym: 'Freund',
  trustLevel: TrustLevel.contact,
  addedAt: DateTime.utc(2026, 10, 1),
  lastSeen: DateTime.utc(2026, 11, 1),
  changedAt: DateTime.utc(2026, 11, 1),
);

void main() {
  final keys =
      NostrKeys.fromBip39Seed(Uint8List.fromList(Bip39.mnemonicToSeed(_mnemonic)));
  final service = ContactSyncService.instance;

  late _FakeRelayManager relay;
  late NostrTransport transport;

  Future<String?> seed() async => _mnemonic;

  void startAll(FakeAsync async) {
    relay = _FakeRelayManager();
    transport = NostrTransport(
      localDid: 'did:key:ich',
      localPseudonym: 'Ich',
      relayManager: relay,
    );
    // Not awaited on purpose, as in ChatProvider (audit C-3).
    unawaited(service.attach(transport, loadSeedPhrase: seed));
    transport.start(keysOverride: keys);
    async.flushMicrotasks();
    relay.published.clear();
  }

  tearDown(() async {
    await service.detach();
    ContactService.instance.clearForTest();
  });

  test('without a list on the relays, the first EOSE leads to one publish',
      () {
    fakeAsync((async) {
      ContactService.instance.addForTest(_contact);
      startAll(async);

      relay.eoseForContactList();
      async.elapse(ContactSyncService.afterEoseDelay);
      async.flushMicrotasks();
      expect(relay.contactLists, hasLength(1));

      relay.eoseForContactList(); // e.g. after a reconnect
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      expect(relay.contactLists, hasLength(1));
    });
  });

  test('nothing is published while no relay has answered (no fixed timer)',
      () {
    fakeAsync((async) {
      ContactService.instance.addForTest(_contact);
      startAll(async);

      async.elapse(const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(relay.contactLists, isEmpty);
    });
  });

  test('a list delivered right after attach is seen and suppresses the '
      'initial publish', () {
    fakeAsync((async) {
      ContactService.instance.addForTest(_contact);
      startAll(async);

      final key = deriveContactSyncKey(_mnemonic);
      String? encrypted;
      PodEncryption.encrypt(
              jsonEncode(buildContactSyncPayload([_contact], {})), key)
          .then((v) => encrypted = v);
      async.flushMicrotasks();
      relay.deliver(NostrEvent.create(
        keys: keys,
        kind: NostrKind.presence,
        content: encrypted!,
        tags: [
          ['d', contactSyncDTag],
        ],
      ));
      relay.eoseForContactList();
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();

      expect(relay.contactLists, isEmpty,
          reason: 'the identical list needs no republish');
    });
  });

  test('a device without contacts publishes nothing', () {
    fakeAsync((async) {
      startAll(async);

      relay.eoseForContactList();
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      expect(relay.contactLists, isEmpty);
    });
  });
}
