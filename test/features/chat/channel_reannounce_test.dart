import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/chat/channel_reannounce.dart';
import 'package:nexus_oneapp/features/chat/group_channel.dart';

const _me = 'did:key:me';
final _now = DateTime.utc(2026, 11, 17, 12);

GroupChannel _channel(String id, {String createdBy = _me, String? cellId}) =>
    GroupChannel(
      id: id,
      name: '#$id',
      description: '',
      createdBy: createdBy,
      createdAt: DateTime.utc(2026, 10, 1),
      nostrTag: 'nexus-channel-$id',
      cellId: cellId,
    );

List<String> _due(List<GroupChannel> channels, Map<String, int> last) =>
    channelsToReannounce(
      channels: channels,
      myDid: _me,
      lastAnnouncedMs: last,
      now: _now,
    ).map((c) => c.id).toList();

void main() {
  group('channelsToReannounce (device test 17.11.2026)', () {
    test('announces own channels that were never announced again', () {
      expect(_due([_channel('vespla'), _channel('technik')], {}),
          ['vespla', 'technik']);
    });

    test('not again within a week', () {
      final yesterday =
          _now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      expect(_due([_channel('vespla')], {'vespla': yesterday}), isEmpty);
    });

    test('again after a week', () {
      final eightDays =
          _now.subtract(const Duration(days: 8)).millisecondsSinceEpoch;
      expect(_due([_channel('vespla')], {'vespla': eightDays}), ['vespla']);
    });

    test('never channels created by someone else', () {
      expect(_due([_channel('elsid', createdBy: 'did:key:other')], {}),
          isEmpty);
    });

    test('never community channels', () {
      expect(_due([_channel('cell-x-discussion', cellId: 'x')], {}), isEmpty);
    });

    test('nothing without an identity', () {
      expect(
          channelsToReannounce(
            channels: [_channel('vespla')],
            myDid: '',
            lastAnnouncedMs: const {},
            now: _now,
          ),
          isEmpty);
    });
  });
}
