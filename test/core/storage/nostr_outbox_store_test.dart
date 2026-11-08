import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexus_oneapp/core/storage/pod_database.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_outbox.dart';

/// TD-74: queued chat events are stored encrypted and survive restarts.
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      singleInstance: false,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE nostr_outbox (
          event_id   TEXT PRIMARY KEY,
          kind       INTEGER NOT NULL,
          enc        TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      '''),
    );
    PodDatabase.instance
        .injectDatabase(db, Uint8List(32)..fillRange(0, 32, 0x42));
  });

  tearDown(() => db.close());

  final event = NostrEvent(
    id: 'd' * 64,
    pubkey: 'e' * 64,
    createdAt: 1794120000,
    kind: NostrKind.channelMessage,
    tags: const [
      ['t', 'nexus-channel-kanal'],
    ],
    content: 'geheimer Kanalbeitrag',
    sig: 'f' * 128,
  );

  test('stores an event and reads it back unchanged', () async {
    final store = PodNostrOutboxStore();

    await store.put(event);
    final pending = await store.pending();

    expect(pending.single.toJson(), event.toJson());
  });

  test('keeps the event content encrypted at rest', () async {
    await PodNostrOutboxStore().put(event);

    final rows = await db.query('nostr_outbox');
    expect(rows.single['enc'], isNot(contains('geheimer Kanalbeitrag')));
  });

  test('removes a delivered event', () async {
    final store = PodNostrOutboxStore();
    await store.put(event);

    await store.remove(event.id);

    expect(await store.pending(), isEmpty);
  });

  test('stores the same event only once', () async {
    final store = PodNostrOutboxStore();

    await store.put(event);
    await store.put(event);

    expect(await store.pending(), hasLength(1));
  });
}
