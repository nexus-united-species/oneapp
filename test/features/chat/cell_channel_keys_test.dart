import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/roles/role_enums.dart';
import 'package:nexus_oneapp/features/chat/cell_channel_keys.dart';
import 'package:nexus_oneapp/features/chat/group_channel.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';

const _founder = 'did:key:founder';
const _member = 'did:key:member';

Cell _cell() => Cell.create(
      name: 'Teneriffa Nord',
      description: '',
      createdBy: _founder,
      cellType: CellType.thematic,
    );

GroupChannel _channel(Cell cell, String suffix) => GroupChannel.create(
      name: '#cell-${cell.id}-$suffix',
      description: '',
      createdBy: _founder,
      isPublic: false,
      isDiscoverable: false,
      channelMode: suffix == 'bulletin'
          ? ChannelMode.announcement
          : ChannelMode.discussion,
      cellId: cell.id,
    );

void main() {
  group('cell channel keys (device test 14.11.2026)', () {
    test('payload round-trips both channels', () {
      final cell = _cell();
      final channels = [_channel(cell, 'bulletin'), _channel(cell, 'discussion')];

      final keys =
          parseCellChannelKeys(buildCellChannelKeysPayload(cell.id, channels));

      expect(keys, hasLength(2));
      expect(keys!.map((k) => k.id), channels.map((c) => c.id));
      expect(keys.map((k) => k.secret), channels.map((c) => c.channelSecret));
    });

    test('a channel name outside the cell is rejected', () {
      final cell = _cell();
      final payload = buildCellChannelKeysPayload(cell.id, [_channel(cell, 'discussion')]);
      (payload['channels'] as List).first['name'] = '#fremder-kanal';

      expect(parseCellChannelKeys(payload), isNull);
    });

    test('a malformed secret is rejected', () {
      final cell = _cell();
      final payload = buildCellChannelKeysPayload(cell.id, [_channel(cell, 'discussion')]);
      (payload['channels'] as List).first['secret'] = 'kurz';

      expect(parseCellChannelKeys(payload), isNull);
    });
  });

  group('cellChannelKeysDecision (receive is a trust boundary)', () {
    test('adopts keys from the confirmed founder', () {
      expect(
        cellChannelKeysDecision(
            cell: _cell(), myDid: _member, senderDid: _founder, senderVerified: true),
        isNull,
      );
    });

    test('rejects keys from a member who is not the founder', () {
      expect(
        cellChannelKeysDecision(
            cell: _cell(), myDid: _member, senderDid: 'did:key:other', senderVerified: true),
        isNotNull,
      );
    });

    test('rejects an unconfirmed sender claiming to be the founder', () {
      expect(
        cellChannelKeysDecision(
            cell: _cell(), myDid: _member, senderDid: _founder, senderVerified: false),
        isNotNull,
      );
    });

    test('follows a founder handover', () {
      final handedOver = _cell().withFounder('did:key:successor');
      expect(
        cellChannelKeysDecision(
            cell: handedOver, myDid: _member, senderDid: _founder, senderVerified: true),
        isNotNull,
        reason: 'the previous founder may no longer set keys',
      );
      expect(
        cellChannelKeysDecision(
            cell: handedOver,
            myDid: _member,
            senderDid: 'did:key:successor',
            senderVerified: true),
        isNull,
      );
    });

    test('rejects unknown cells and keys sent to the founder itself', () {
      expect(
        cellChannelKeysDecision(
            cell: null, myDid: _member, senderDid: _founder, senderVerified: true),
        isNotNull,
      );
      expect(
        cellChannelKeysDecision(
            cell: _cell(), myDid: _founder, senderDid: _founder, senderVerified: true),
        isNotNull,
      );
    });
  });

  group('delivery fingerprint and shared identity', () {
    test('changes when a key changes, stable otherwise', () {
      final cell = _cell();
      final channels = [_channel(cell, 'bulletin'), _channel(cell, 'discussion')];
      final a = cellKeysFingerprint(cell.id, _member, channels);

      expect(cellKeysFingerprint(cell.id, _member, channels), a);
      expect(
        cellKeysFingerprint(cell.id, _member,
            [channels.first.withRotatedSecret(GroupChannel.generateSecret()), channels.last]),
        isNot(a),
      );
      expect(cellKeysFingerprint(cell.id, 'did:key:other', channels), isNot(a));
    });

    test('withSharedIdentity adopts ID and secret, keeps the old secret', () {
      final cell = _cell();
      final local = _channel(cell, 'discussion');
      final shared = GroupChannel.generateSecret();

      final adopted = local.withSharedIdentity(id: 'founder-id', secret: shared);

      expect(adopted.id, 'founder-id');
      expect(adopted.channelSecret, shared);
      expect(adopted.previousSecrets, [local.channelSecret]);
      expect(adopted.name, local.name);
      expect(adopted.cellId, cell.id);
    });
  });
}
