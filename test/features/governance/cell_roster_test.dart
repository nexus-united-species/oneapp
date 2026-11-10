import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/identity.dart';
import 'package:nexus_oneapp/core/identity/identity_service.dart';
import 'package:nexus_oneapp/core/storage/pod_database.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';
import 'package:nexus_oneapp/features/governance/cell_member.dart';
import 'package:nexus_oneapp/features/governance/cell_roster.dart';
import 'package:nexus_oneapp/features/governance/cell_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _founder = 'did:key:z6MkFounder';
const _me = 'did:key:z6MkMe';
const _other = 'did:key:z6MkOther';
const _mod = 'did:key:z6MkModerator';

CellMember _m(String cellId, String did, MemberRole role) => CellMember(
      cellId: cellId,
      did: did,
      joinedAt: DateTime.utc(2026, 11, 1),
      role: role,
    );

Future<Database> _openDb() => openDatabase(
      inMemoryDatabasePath,
      version: 1,
      singleInstance: false,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE tombstones (id TEXT NOT NULL, type TEXT NOT NULL,
            reason TEXT, created_at INTEGER NOT NULL, PRIMARY KEY (id, type))''');
        await db.execute('''
          CREATE TABLE cells (id TEXT PRIMARY KEY, enc TEXT NOT NULL,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''');
        await db.execute('''
          CREATE TABLE cell_members (cell_id TEXT NOT NULL, did TEXT NOT NULL,
            enc TEXT NOT NULL, PRIMARY KEY (cell_id, did))''');
      },
    );

void main() {
  group('CellRoster model', () {
    test('lists confirmed members, always the founder, sorted by DID', () {
      final roster = CellRoster.fromMembers(
        cellId: 'c1',
        founderDid: _founder,
        members: [
          _m('c1', _other, MemberRole.member),
          _m('c1', 'did:key:z6MkPending', MemberRole.pending),
          _m('c1', _mod, MemberRole.moderator),
        ],
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAtMs: 1000,
      );

      expect(roster.members.map((e) => e.did), [_founder, _mod, _other]);
      expect(roster.founderDid, _founder);
      expect(
        roster.members.firstWhere((e) => e.did == _mod).role,
        MemberRole.moderator,
      );
    });

    test('survives the wire format', () {
      final roster = CellRoster.fromMembers(
        cellId: 'c1',
        founderDid: _founder,
        members: [_m('c1', _other, MemberRole.member)],
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAtMs: 1000,
      );

      final parsed = CellRoster.tryParse(roster.toJson())!;

      expect(parsed.cellId, 'c1');
      expect(parsed.updatedAtMs, 1000);
      expect(parsed.members.map((e) => e.toJson()),
          roster.members.map((e) => e.toJson()));
    });

    test('rejects malformed rosters', () {
      Map<String, dynamic> entry(String did, String role) =>
          {'did': did, 'role': role, 'joinedAt': 1};
      final cases = <Map<String, dynamic>>[
        {'cellId': 'c1', 'members': <Object>[]}, // no updatedAt
        {
          'cellId': 'c1',
          'updatedAt': 1,
          'members': [entry(_founder, 'founder'), entry(_founder, 'member')],
        },
        {
          'cellId': 'c1',
          'updatedAt': 1,
          'members': [entry(_founder, 'founder'), entry(_other, 'pending')],
        },
        {
          'cellId': 'c1',
          'updatedAt': 1,
          'members': [entry(_founder, 'founder'), entry(_other, 'founder')],
        },
        {
          'cellId': 'c1',
          'updatedAt': 1,
          'members': [entry(_other, 'member')], // no founder
        },
      ];
      for (final json in cases) {
        expect(CellRoster.tryParse(json), isNull, reason: '$json');
      }
    });
  });

  group('CellService roster', () {
    late Database db;
    final service = CellService.instance;
    late Cell cell;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = await _openDb();
      PodDatabase.instance
          .injectDatabase(db, Uint8List(32)..fillRange(0, 32, 0x42));
      cell = Cell.create(
        name: 'test911',
        description: 'Test',
        createdBy: _founder,
        cellType: CellType.thematic,
      );
      service.addCellForTest(cell);
      service.addMemberForTest(cell.id, _m(cell.id, _founder, MemberRole.founder));
      service.addMemberForTest(cell.id, _m(cell.id, _me, MemberRole.member));
    });

    tearDown(() async {
      service.clearForTest();
      service.onPublishRoster = null;
      IdentityService.instance.clearForTest();
      await db.close();
    });

    void actAs(String did) => IdentityService.instance.setForTest(
          NexusIdentity(publicKeyHex: 'aa' * 32, pseudonym: did, did: did),
        );

    CellRoster rosterWith(List<CellRosterEntry> entries, int updatedAtMs) =>
        CellRoster(cellId: cell.id, updatedAtMs: updatedAtMs, members: [
          const CellRosterEntry(
              did: _founder, role: MemberRole.founder, joinedAtMs: 1),
          ...entries,
        ]);

    test('a joiner learns existing members and roles from the roster',
        () async {
      actAs(_me);

      final applied = await service.applyRoster(rosterWith([
        const CellRosterEntry(did: _me, role: MemberRole.member, joinedAtMs: 3),
        const CellRosterEntry(
            did: _mod, role: MemberRole.moderator, joinedAtMs: 2),
      ], 1000));

      expect(applied, isTrue);
      final members = service.membersOf(cell.id);
      expect(members.map((m) => m.did).toSet(), {_founder, _me, _mod});
      expect(members.firstWhere((m) => m.did == _mod).canManageRequests,
          isTrue);
    });

    test('an older or replayed roster is ignored', () async {
      actAs(_me);
      await service.applyRoster(rosterWith([
        const CellRosterEntry(did: _me, role: MemberRole.member, joinedAtMs: 3),
        const CellRosterEntry(did: _other, role: MemberRole.member, joinedAtMs: 4),
      ], 2000));

      final applied = await service.applyRoster(rosterWith([
        const CellRosterEntry(did: _me, role: MemberRole.member, joinedAtMs: 3),
      ], 1000));

      expect(applied, isFalse);
      expect(service.membersOf(cell.id).map((m) => m.did), contains(_other));
    });

    test('my own membership stays even if the roster predates my joining',
        () async {
      actAs(_me);

      await service.applyRoster(rosterWith(const [], 1000));

      expect(service.membersOf(cell.id).map((m) => m.did).toSet(),
          {_founder, _me});
    });

    test('a stale roster keeps later joiners and does not re-add leavers',
        () async {
      actAs(_me);
      // Locally known after the roster was built (e.g. via 31005 while the
      // founder was offline).
      service.addMemberForTest(
        cell.id,
        CellMember(
          cellId: cell.id,
          did: 'did:key:z6MkLateJoiner',
          joinedAt: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
          role: MemberRole.member,
        ),
      );
      service.setDepartureForTest(cell.id, _other, 4000);

      await service.applyRoster(rosterWith([
        const CellRosterEntry(did: _me, role: MemberRole.member, joinedAtMs: 3),
        const CellRosterEntry(did: _other, role: MemberRole.member, joinedAtMs: 2),
      ], 3000));

      final dids = service.membersOf(cell.id).map((m) => m.did).toSet();
      expect(dids, contains('did:key:z6MkLateJoiner'));
      expect(dids, isNot(contains(_other)));
    });

    test('the founder never applies its own (possibly stale) roster',
        () async {
      actAs(_founder);

      expect(await service.applyRoster(rosterWith(const [], 1000)), isFalse);
      expect(service.membersOf(cell.id).map((m) => m.did), contains(_me));
    });

    test('a local founder transfer neither breaks nor reverts rosters',
        () async {
      final published = <Map<String, dynamic>>[];
      service.onPublishRoster = published.add;
      actAs(_founder);
      await service.transferFounderRole(cell.id, _me);

      service.publishRosterIfFounder(cell.id);
      expect(published, isEmpty,
          reason: 'after the transfer this device is no longer founder');

      final roster = CellRoster.fromMembers(
        cellId: cell.id,
        founderDid: _founder,
        members: service.membersOf(cell.id),
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAtMs: 1000,
      );
      expect(CellRoster.tryParse(roster.toJson()), isNotNull,
          reason: 'exactly one founder on the wire');
    });

    test('rosters of cells I am not a member of are ignored', () async {
      actAs(_me);
      final foreign = CellRoster(
        cellId: 'not-my-cell',
        updatedAtMs: 1000,
        members: const [
          CellRosterEntry(did: _founder, role: MemberRole.founder, joinedAtMs: 1),
        ],
      );

      expect(await service.applyRoster(foreign), isFalse);
    });

    test('only the founder publishes, e.g. after promoting a moderator',
        () async {
      final published = <Map<String, dynamic>>[];
      service.onPublishRoster = published.add;

      actAs(_me);
      service.publishRosterIfFounder(cell.id);
      expect(published, isEmpty);

      actAs(_founder);
      await service.promoteModerator(cell.id, _me);

      expect(published, hasLength(1));
      final roster = CellRoster.tryParse(published.single)!;
      expect(roster.founderDid, _founder);
      expect(roster.members.firstWhere((e) => e.did == _me).role,
          MemberRole.moderator);
    });
  });
}
