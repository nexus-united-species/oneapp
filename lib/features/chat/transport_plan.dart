import '../../core/transport/message_transport.dart';

/// Which transports the chat starts (audit Z-7).
///
/// Bluetooth needs a permission on mobile; without it the chat still runs
/// over LAN and Nostr instead of stopping completely. Desktop never uses
/// Bluetooth.
Set<TransportType> plannedTransports({
  required bool isMobile,
  required bool bluetoothGranted,
}) =>
    {
      if (isMobile && bluetoothGranted) TransportType.ble,
      TransportType.lan,
      TransportType.nostr,
    };
