import '../../core/transport/message_transport.dart';
import '../../core/transport/nexus_message.dart';

/// Delivery state of an own chat message (audit Z-3/Z-4).
///
/// Stored in the `status` column of `pod_messages` and mirrored into the
/// local-only metadata key [localDeliveryMetaKey] for the UI. Older rows
/// carry `pending` (the column default) and show no state.
enum DeliveryState {
  /// Saved, not yet confirmed: no relay has accepted it so far (it waits in
  /// the outbox while offline).
  sending('sending'),

  /// Delivered directly (LAN/BLE) or accepted by at least one relay.
  sent('sent'),

  /// No transport could take it; the user can send it again.
  failed('failed');

  const DeliveryState(this.value);

  final String value;

  /// The state stored as [value], or null for legacy and unknown values.
  static DeliveryState? fromValue(String? value) {
    for (final state in values) {
      if (state.value == value) return state;
    }
    return null;
  }
}

/// Local-only metadata key; never part of a message on the wire.
const String localDeliveryMetaKey = 'local_delivery';

/// The state right after handing a message to the transports: a direct
/// delivery counts as sent; a relay hand-off waits for the relay's answer.
DeliveryState deliveryAfterHandOff(
  TransportType? deliveredVia, {
  required bool relayAlreadyAccepted,
}) {
  if (deliveredVia == TransportType.nostr && !relayAlreadyAccepted) {
    return DeliveryState.sending;
  }
  return DeliveryState.sent;
}

/// Whether a chat screen showing [shown] must take over [fresh]: new or
/// removed messages, or a changed delivery state (audit Z-4). Comparing the
/// length alone left „wartet“ on screen after the message was sent.
bool messageListChanged(List<NexusMessage> shown, List<NexusMessage> fresh) {
  if (shown.length != fresh.length) return true;
  for (var i = 0; i < shown.length; i++) {
    if (shown[i].id != fresh[i].id) return true;
    if (shown[i].metadata?[localDeliveryMetaKey] !=
        fresh[i].metadata?[localDeliveryMetaKey]) {
      return true;
    }
  }
  return false;
}
