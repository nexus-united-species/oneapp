import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexus_oneapp/core/identity/identity.dart';
import 'package:nexus_oneapp/core/identity/identity_service.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/features/dorfplatz/feed_post.dart';
import 'package:nexus_oneapp/features/dorfplatz/feed_service.dart';

/// TD-72: a Kind-5 on the Dorfplatz path may only remove posts signed by the
/// same key, and only reactions recorded for the signer.

const _postEventId =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
const _reactionEventId =
    'c1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
const _myDid = 'did:key:z6MkFeedDeleteTestFeedDeleteTest';
final _bobKey = '44' * 32;
final _malloryKey = '55' * 32;

Future<Database> _openTestDb() async {
  final db = await openDatabase(
    inMemoryDatabasePath,
    version: 1,
    singleInstance: false,
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE feed_posts (
          id             TEXT PRIMARY KEY,
          author_did     TEXT NOT NULL,
          visibility     TEXT NOT NULL DEFAULT 'contacts',
          created_at     INTEGER NOT NULL,
          nostr_event_id TEXT,
          enc            TEXT NOT NULL,
          is_deleted     INTEGER NOT NULL DEFAULT 0
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
  PodDatabase.instance.injectDatabase(db, Uint8List(32)..fillRange(0, 32, 9));
  return db;
}

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await _openTestDb();
    IdentityService.instance.setForTest(
      NexusIdentity(publicKeyHex: '11' * 32, pseudonym: 'Feed', did: _myDid),
    );
  });

  tearDown(() async {
    IdentityService.instance.clearForTest();
    await db.close();
  });

  /// Delivers a Dorfplatz post from Bob as the transport would.
  Future<String> receiveBobPost(String eventId) async {
    final id = generateFeedId();
    await FeedService.instance.handleIncomingPost({
      'id': id,
      'authorDid': 'did:key:z6MkBobBobBobBobBobBobBobBobBob',
      'authorPseudonym': 'Bob',
      'content': 'Hallo Dorfplatz',
      'visibility': 'public',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'nostrEventId': eventId,
      '_nostrPubkey': _bobKey,
    });
    return id;
  }

  Future<int> visiblePosts(String id) async => (await db.query(
        'feed_posts',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      ))
          .length;

  test('remembers the signing key of a received post', () async {
    final post = FeedPost.fromJson({
      'id': 'x',
      'authorDid': 'did:key:bob',
      'authorPseudonym': 'Bob',
      'visibility': 'public',
      'createdAt': 0,
      'authorPubkey': 'gefälscht',
      '_nostrPubkey': _bobKey,
    });

    expect(post.authorPubkey, _bobKey,
        reason: 'The transport-provided key wins over content claims');
    expect(FeedPost.fromJson(post.toJson()).authorPubkey, _bobKey);
  });

  test('the author can delete their post', () async {
    final id = await receiveBobPost(_postEventId);

    await FeedService.instance.handleIncomingDelete(
      MessageDeletionRequest(authorPubkey: _bobKey, eventIds: [_postEventId]),
    );

    expect(await visiblePosts(id), 0);
  });

  test('someone else cannot delete the post', () async {
    final eventId = 'b2' * 32;
    final id = await receiveBobPost(eventId);

    await FeedService.instance.handleIncomingDelete(
      MessageDeletionRequest(
        authorPubkey: _malloryKey,
        eventIds: [eventId],
      ),
    );

    expect(await visiblePosts(id), 1);
  });

  test('only the reactor can withdraw a reaction', () async {
    final postId = await receiveBobPost('b3' * 32);
    await PodDatabase.instance.upsertReaction(
      messageId: postId,
      emoji: '🔥',
      reactorDid: _bobKey,
      nostrEventId: _reactionEventId,
    );

    await FeedService.instance.handleIncomingDelete(
      MessageDeletionRequest(
        authorPubkey: _malloryKey,
        eventIds: [_reactionEventId],
      ),
    );
    expect(await PodDatabase.instance.getReactionsForMessage(postId), {
      '🔥': [_bobKey],
    });

    await FeedService.instance.handleIncomingDelete(
      MessageDeletionRequest(
        authorPubkey: _bobKey,
        eventIds: [_reactionEventId],
      ),
    );
    expect(await PodDatabase.instance.getReactionsForMessage(postId), isEmpty);
  });
}
