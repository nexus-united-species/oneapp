import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/identity.dart';
import 'package:nexus_oneapp/core/identity/identity_service.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';
import 'package:nexus_oneapp/features/governance/cell_member.dart';
import 'package:nexus_oneapp/features/governance/cell_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _myDid = 'did:key:z6MkMember';
const _founderDid = 'did:key:z6MkFounder';

Future<Database> _openDb() => openDatabase(
      inMemoryDatabasePath,
      version: 1,
      singleInstance: false,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE tombstones (
            id TEXT NOT NULL, type TEXT NOT NULL, reason TEXT,
            created_at INTEGER NOT NULL, PRIMARY KEY (id, type))''');
        await db.execute('''
          CREATE TABLE cells (id TEXT PRIMARY KEY, enc TEXT NOT NULL,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''');
        await db.execute('''
          CREATE TABLE cell_members (cell_id TEXT NOT NULL, did TEXT NOT NULL,
            enc TEXT NOT NULL, PRIMARY KEY (cell_id, did))''');
        await db.execute('''
          CREATE TABLE cell_join_requests (id TEXT PRIMARY KEY,
            cell_id TEXT NOT NULL, is_sent INTEGER NOT NULL DEFAULT 0,
            enc TEXT NOT NULL)''');
        await db.execute('''
          CREATE TABLE cell_departures (cell_id TEXT NOT NULL,
            did TEXT NOT NULL, departed_at INTEGER NOT NULL,
            enc TEXT NOT NULL, PRIMARY KEY (cell_id, did))''');
      },
    );

Cell _cell() => Cell.create(
      name: 'Testzelle811',
      description: 'Test',
      createdBy: _founderDid,
      cellType: CellType.thematic,
    );

CellMember _membership(String cellId, DateTime joinedAt) => CellMember(
      cellId: cellId,
      did: _myDid,
      joinedAt: joinedAt,
      role: MemberRole.member,
      confirmedBy: _founderDid,
    );

void main() {
  late Database db;
  final service = CellService.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await _openDb();
    PodDatabase.instance
        .injectDatabase(db, Uint8List(32)..fillRange(0, 32, 0x42));
    IdentityService.instance.setForTest(
      NexusIdentity(publicKeyHex: 'aa' * 32, pseudonym: 'Ich', did: _myDid),
    );
  });

  tearDown(() async {
    service.clearForTest();
    IdentityService.instance.clearForTest();
    await db.close();
  });

  Future<Cell> joinedCell() async {
    final cell = _cell();
    final earlier = DateTime.now().toUtc().subtract(const Duration(days: 1));
    await service.handleMembershipConfirmed(cell, _membership(cell.id, earlier));
    expect(service.myCells.map((c) => c.id), contains(cell.id));
    return cell;
  }

  test('a left cell stays discoverable and is not tombstoned', () async {
    final cell = await joinedCell();

    await service.leaveCell(cell.id);

    expect(service.myCells.map((c) => c.id), isNot(contains(cell.id)));
    expect(service.discoveredCells.map((c) => c.id), contains(cell.id));
    expect(service.hasLeft(cell.id), isTrue);
    expect(service.isTombstoned(cell.id), isFalse);
    expect(
      await PodDatabase.instance.hasTombstone(id: cell.id, type: 'cell_left'),
      isTrue,
    );
  });

  test('an old confirmation does not pull me back in after leaving',
      () async {
    final cell = await joinedCell();
    await service.leaveCell(cell.id);

    final stale = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    await service.handleMembershipConfirmed(cell, _membership(cell.id, stale));

    expect(service.myCells.map((c) => c.id), isNot(contains(cell.id)));
    expect(service.hasLeft(cell.id), isTrue);
  });

  test('a confirmation without a new request of mine is ignored', () async {
    final cell = await joinedCell();
    await service.leaveCell(cell.id);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await service.handleMembershipConfirmed(
        cell, _membership(cell.id, DateTime.now().toUtc()));

    expect(service.myCells.map((c) => c.id), isNot(contains(cell.id)));
  });

  test('rejoining after a new request works and clears the left marker',
      () async {
    final cell = await joinedCell();
    await service.leaveCell(cell.id);
    await service.sendJoinRequest(cell);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await service.handleMembershipConfirmed(
        cell, _membership(cell.id, DateTime.now().toUtc()));

    expect(service.myCells.map((c) => c.id), contains(cell.id));
    expect(service.hasLeft(cell.id), isFalse);
    expect(
      await PodDatabase.instance.hasTombstone(id: cell.id, type: 'cell_left'),
      isFalse,
    );
  });
}
