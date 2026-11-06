import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexus_oneapp/core/identity/identity.dart';
import 'package:nexus_oneapp/core/identity/identity_service.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';
import 'package:nexus_oneapp/core/transport/nexus_message.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/core/transport/transport_manager.dart';
import 'package:nexus_oneapp/features/chat/chat_provider.dart';

/// F-001: the Nostr wrapper event ID must stay associated with the internal
/// message UUID across serialization and across an app restart, so reactions
/// and deletions can reference a real event instead of a UUID.

const _validEventId =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

class _FakeNostrTransport extends NostrTransport {
  _FakeNostrTransport()
    : super(localDid: 'did:key:reaction-test', localPseudonym: 'Test');

  final reactionController = StreamController<Map<String, dynamic>>.broadcast();
  final publishedReactions = <({String targetEventId, String emoji})>[];
  final publishedDeletions = <String>[];
  final sentEventIds = <String, String>{};

  @override
  Future<void> sendMessage(
    NexusMessage message, {
    String? recipientDid,
  }) async {
    sentEventIds[message.id] = _validEventId;
  }

  @override
  String? consumeSentNostrEventId(String messageId) =>
      sentEventIds.remove(messageId);

  @override
  Stream<Map<String, dynamic>> get onFeedReaction => reactionController.stream;

  @override
  void publishReaction(String targetEventId, String emoji) {
    publishedReactions.add((targetEventId: targetEventId, emoji: emoji));
  }

  @override
  void publishDeletion(String targetEventId) {
    publishedDeletions.add(targetEventId);
  }

  Future<void> emitReaction(Map<String, dynamic> data) async {
    reactionController.add(data);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> close() => reactionController.close();
}

Future<PodDatabase> _openTestDb() async {
  final pod = PodDatabase.instance;
  final db = await openDatabase(
    inMemoryDatabasePath,
    version: 1,
    singleInstance: false,
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE pod_messages (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          conversation_id TEXT NOT NULL,
          sender_did      TEXT NOT NULL,
          enc             TEXT NOT NULL,
          ts              INTEGER NOT NULL,
          status          TEXT NOT NULL DEFAULT 'pending',
          encrypted       INTEGER NOT NULL DEFAULT 0,
          message_id      TEXT,
          is_favorite     INTEGER NOT NULL DEFAULT 0,
          is_deleted      INTEGER NOT NULL DEFAULT 0,
          edited_body     TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE message_reactions (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          message_id     TEXT NOT NULL,
          emoji          TEXT NOT NULL,
          reactor_did    TEXT NOT NULL,
          created_at     INTEGER NOT NULL,
          nostr_event_id TEXT,
          UNIQUE(message_id, emoji, reactor_did)
        )
      ''');
    },
  );
  final key = Uint8List(32)..fillRange(0, 32, 0x77);
  pod.injectDatabase(db, key);
  return pod;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('NexusMessage – Nostr event ID association', () {
    test('a fresh message carries no Nostr event ID', () {
      final msg = NexusMessage.create(fromDid: 'did:key:alice', body: 'hallo');
      expect(msg.nostrEventId, isNull);
      expect(NostrTransport.isValidNostrEventId(msg.id), isFalse);
    });

    test('withNostrEventId keeps the internal UUID and existing metadata', () {
      final msg = NexusMessage.create(
        fromDid: 'did:key:alice',
        body: 'hallo',
        metadata: {'duration_ms': 1500},
      );
      final enriched = msg.withNostrEventId(_validEventId);

      expect(enriched.id, equals(msg.id));
      expect(enriched.nostrEventId, equals(_validEventId));
      expect(enriched.metadata?['duration_ms'], equals(1500));
      // The original stays untouched (immutable update).
      expect(msg.nostrEventId, isNull);
    });

    test('the association survives a JSON round-trip', () {
      final msg = NexusMessage.create(
        fromDid: 'did:key:alice',
        body: 'hallo',
      ).withNostrEventId(_validEventId);
      final restored = NexusMessage.fromJson(msg.toJson());

      expect(restored.id, equals(msg.id));
      expect(restored.nostrEventId, equals(_validEventId));
    });

    test('the association survives the encrypted DB round-trip', () async {
      final pod = await _openTestDb();
      final msg = NexusMessage.create(
        fromDid: 'did:key:alice',
        toDid: NexusMessage.broadcastDid,
        channel: '#teneriffa',
        body: 'hallo',
      ).withNostrEventId(_validEventId);

      await pod.insertMessage(
        conversationId: '#teneriffa',
        senderDid: msg.fromDid,
        data: msg.toJson(),
      );

      final rows = await pod.listMessages('#teneriffa');
      expect(rows, hasLength(1));
      final restored = NexusMessage.fromJson(rows.single);
      expect(restored.id, equals(msg.id));
      expect(restored.nostrEventId, equals(_validEventId));
      expect(NostrTransport.isValidNostrEventId(restored.nostrEventId), isTrue);
    });

    test('a legacy row without the metadata key stays usable', () async {
      final pod = await _openTestDb();
      final legacy = NexusMessage.create(
        fromDid: 'did:key:alice',
        toDid: NexusMessage.broadcastDid,
        channel: '#legacy',
        body: 'alte Nachricht',
      );

      await pod.insertMessage(
        conversationId: '#legacy',
        senderDid: legacy.fromDid,
        data: legacy.toJson(),
      );

      final rows = await pod.listMessages('#legacy');
      final restored = NexusMessage.fromJson(rows.single);
      expect(restored.id, equals(legacy.id));
      expect(restored.body, equals('alte Nachricht'));
      // No substitute: the UUID must never stand in for a Nostr event ID.
      expect(restored.nostrEventId, isNull);
    });
  });

  group('ChatProvider – reaction reference behavior', () {
    const myDid = 'did:key:reaction-test';
    late PodDatabase pod;
    late _FakeNostrTransport nostrTransport;
    late ChatProvider provider;
    late List<({String title, String body, String? payload})> notifications;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'notif_channel_reactions': true});
      TransportManager.instance.clearTransports();
      pod = await _openTestDb();
      IdentityService.instance.setForTest(
        NexusIdentity(
          publicKeyHex: '11' * 32,
          pseudonym: 'Reaktionstest',
          did: myDid,
        ),
      );
      nostrTransport = _FakeNostrTransport();
      TransportManager.instance.registerTransport(nostrTransport);
      notifications = [];
      provider = ChatProvider(
        nostrTransport: nostrTransport,
        reactionNotification:
            ({required title, required body, String? payload}) async {
              notifications.add((title: title, body: body, payload: payload));
            },
      );
    });

    tearDown(() async {
      provider.dispose();
      TransportManager.instance.clearTransports();
      await nostrTransport.close();
      IdentityService.instance.clearForTest();
    });

    Future<NexusMessage> cacheMessage({required bool withNostrEventId}) async {
      final message = NexusMessage.create(
        fromDid: myDid,
        toDid: NexusMessage.broadcastDid,
        channel: '#reaktionen',
        body: 'hallo',
      );
      final stored = withNostrEventId
          ? message.withNostrEventId(_validEventId)
          : message;
      await pod.insertMessage(
        conversationId: '#reaktionen',
        senderDid: stored.fromDid,
        data: stored.toJson(),
      );
      await provider.getMessages('#reaktionen');
      return stored;
    }

    test(
      'persists the generated Nostr event ID for an outgoing direct message',
      () async {
        const recipientDid = 'did:key:direct-recipient';

        await provider.sendMessage(recipientDid, 'Direkte Nachricht');

        final convId = ([myDid, recipientDid]..sort()).join(':');
        final messages = await provider.getMessages(convId);
        expect(messages, hasLength(1));
        expect(messages.single.body, 'Direkte Nachricht');
        expect(messages.single.nostrEventId, _validEventId);
        expect(
          NostrTransport.isValidNostrEventId(messages.single.nostrEventId),
          isTrue,
        );

        final rows = await pod.listMessages(convId);
        final persisted = NexusMessage.fromJson(rows.single);
        expect(persisted.id, messages.single.id);
        expect(persisted.nostrEventId, _validEventId);
      },
    );

    test(
      'persists the generated Nostr event ID for an outgoing mesh broadcast',
      () async {
        await provider.sendBroadcast('Nachricht an #mesh');

        final messages =
            await provider.getMessages(NexusMessage.broadcastDid);
        expect(messages, hasLength(1));
        expect(messages.single.nostrEventId, _validEventId);

        final rows = await pod.listMessages(NexusMessage.broadcastDid);
        final persisted = NexusMessage.fromJson(rows.single);
        expect(persisted.id, messages.single.id);
        expect(persisted.nostrEventId, _validEventId);
      },
    );

    test(
      'publishes the stored Nostr event ID instead of the internal UUID',
      () async {
        final message = await cacheMessage(withNostrEventId: true);

        await provider.addChannelReaction(message.id, '👍');

        expect(nostrTransport.publishedReactions, [
          (targetEventId: _validEventId, emoji: '👍'),
        ]);
        expect(
          nostrTransport.publishedReactions.single.targetEventId,
          isNot(message.id),
        );
        expect(await provider.getMessageReactions(message.id), {
          '👍': [myDid],
        });
        expect(await provider.getMessageReactions(_validEventId), isEmpty);
      },
    );

    test(
      'keeps legacy-message reactions local without publishing the UUID',
      () async {
        final message = await cacheMessage(withNostrEventId: false);

        await provider.addChannelReaction(message.id, '👍');

        expect(message.nostrEventId, isNull);
        expect(nostrTransport.publishedReactions, isEmpty);
        expect(await provider.getMessageReactions(message.id), {
          '👍': [myDid],
        });
      },
    );

    test(
      'matches an incoming reaction through the cached Nostr event ID',
      () async {
        await cacheMessage(withNostrEventId: true);

        await nostrTransport.emitReaction({
          'referencedEventId': _validEventId,
          'senderPubkey': '22' * 32,
          'emoji': '🔥',
        });

        expect(notifications, hasLength(1));
        expect(notifications.single.body, '🔥');
        expect(notifications.single.payload, '#reaktionen');
      },
    );

    test(
      'rejects an incoming reaction that references only the internal UUID',
      () async {
        final message = await cacheMessage(withNostrEventId: true);

        await nostrTransport.emitReaction({
          'referencedEventId': message.id,
          'senderPubkey': '22' * 32,
          'emoji': '🔥',
        });

        expect(notifications, isEmpty);
      },
    );

    // ── F-001 REWORK: message deletion (Kind-5, NIP-09) ───────────────────

    test(
      'publishNostrDeletion publishes the real Nostr event ID for a self-sent message',
      () async {
        final message = await cacheMessage(withNostrEventId: true);

        provider.publishNostrDeletion(message);

        expect(nostrTransport.publishedDeletions, [_validEventId]);
        expect(nostrTransport.publishedDeletions.single, isNot(message.id));
      },
    );

    test(
      'publishNostrDeletion publishes the real Nostr event ID for a received message',
      () async {
        final received = NexusMessage.create(
          fromDid: 'did:key:someone-else',
          toDid: myDid,
          body: 'von jemand anderem',
        ).withNostrEventId(_validEventId);
        await pod.insertMessage(
          conversationId: 'did:key:someone-else',
          senderDid: received.fromDid,
          data: received.toJson(),
        );

        provider.publishNostrDeletion(received);

        expect(nostrTransport.publishedDeletions, [_validEventId]);
      },
    );

    test(
      'publishNostrDeletion keeps legacy/offline messages local-only — no UUID fallback',
      () async {
        final message = await cacheMessage(withNostrEventId: false);

        provider.publishNostrDeletion(message);

        expect(message.nostrEventId, isNull);
        expect(nostrTransport.publishedDeletions, isEmpty);
      },
    );
  });
}
