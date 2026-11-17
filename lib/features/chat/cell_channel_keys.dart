import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../governance/cell.dart';
import 'group_channel.dart';

/// Shared keys for a cell's Pinnwand and Diskussion (device test 14.11.2026).
///
/// Every device used to create these two channels on its own, each with a
/// random ID and secret, so no device could read another's posts. The
/// cell's current founder is the key authority: it sends the ID and secret
/// of both channels to every member in an encrypted system DM, and members
/// adopt them only from that founder.

/// System message type; starts with `channel_` so the chat routes it to the
/// channel access handler and never stores it as a chat message.
const String cellChannelKeysType = 'channel_cell_keys';

/// One channel's shared identity as carried in the system DM.
typedef CellChannelKey = ({String name, String id, String secret});

final RegExp _hexSecret = RegExp(r'^[0-9a-f]{64}$');

/// The two channel names a cell may have.
Set<String> cellChannelNames(String cellId) =>
    {'#cell-$cellId-bulletin', '#cell-$cellId-discussion'};

/// Payload for the system DM carrying the keys of [channels] of [cellId].
Map<String, dynamic> buildCellChannelKeysPayload(
  String cellId,
  List<GroupChannel> channels,
) =>
    {
      'sys_type': cellChannelKeysType,
      'cellId': cellId,
      'channels': [
        for (final c in channels)
          if (c.channelSecret != null)
            {'name': c.name, 'id': c.id, 'secret': c.channelSecret},
      ],
    };

/// The channel keys in [data], or null when anything is malformed or names
/// a channel that does not belong to the cell.
List<CellChannelKey>? parseCellChannelKeys(Map<String, dynamic> data) {
  final cellId = data['cellId'];
  final raw = data['channels'];
  if (cellId is! String || cellId.isEmpty || raw is! List || raw.isEmpty) {
    return null;
  }
  final allowed = cellChannelNames(cellId);
  final keys = <CellChannelKey>[];
  for (final entry in raw) {
    if (entry is! Map) return null;
    final name = entry['name'];
    final id = entry['id'];
    final secret = entry['secret'];
    if (name is! String || !allowed.contains(name)) return null;
    if (id is! String || id.isEmpty) return null;
    if (secret is! String || !_hexSecret.hasMatch(secret)) return null;
    keys.add((name: name, id: id, secret: secret));
  }
  return keys;
}

/// Why received cell channel keys must be ignored, or null to adopt them.
/// Receive is a trust boundary: only the confirmed current founder of a
/// cell I belong to may set its keys, and never for my own cell.
String? cellChannelKeysDecision({
  required Cell? cell,
  required String myDid,
  required String senderDid,
  required bool senderVerified,
}) {
  if (cell == null) return 'unknown cell';
  if (!senderVerified) return 'sender not confirmed';
  if (senderDid != cell.currentFounder) return 'sender is not the founder';
  if (myDid == cell.currentFounder) return 'I am the founder';
  return null;
}

/// Identifies one delivery of [channels] to [memberDid], so the founder
/// sends the same keys only once (and again after they change).
String cellKeysFingerprint(
  String cellId,
  String memberDid,
  List<GroupChannel> channels,
) {
  final parts = [
    cellId,
    memberDid,
    for (final c in channels) '${c.name}|${c.id}|${c.channelSecret}',
  ]..sort();
  return sha256.convert(utf8.encode(parts.join('\n'))).toString();
}
