import 'group_channel.dart';

/// How often the creator's device announces each of its channels again.
const Duration channelReannounceInterval = Duration(days: 7);

/// Channels this device should announce again (device test 17.11.2026).
///
/// A Kind-40 announcement used to be published only once, at creation.
/// Public relays drop old events, so after a while nobody could find the
/// channel any more. The creator's device now repeats the announcement,
/// at most once per [interval] per channel. Only own channels qualify –
/// only the creator can sign it – and no community channels, which are
/// created together with their community on every member's device.
List<GroupChannel> channelsToReannounce({
  required Iterable<GroupChannel> channels,
  required String myDid,
  required Map<String, int> lastAnnouncedMs,
  required DateTime now,
  Duration interval = channelReannounceInterval,
}) {
  if (myDid.isEmpty) return const [];
  final nowMs = now.millisecondsSinceEpoch;
  return channels.where((c) {
    if (c.createdBy != myDid || c.cellId != null) return false;
    final last = lastAnnouncedMs[c.id];
    return last == null || nowMs - last >= interval.inMilliseconds;
  }).toList();
}
