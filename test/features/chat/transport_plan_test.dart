import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/message_transport.dart';
import 'package:nexus_oneapp/features/chat/transport_plan.dart';

void main() {
  group('plannedTransports (audit Z-7)', () {
    test('a phone without Bluetooth permission still chats over LAN and Nostr',
        () {
      expect(
        plannedTransports(isMobile: true, bluetoothGranted: false),
        {TransportType.lan, TransportType.nostr},
      );
    });

    test('a phone with permission also uses Bluetooth', () {
      expect(
        plannedTransports(isMobile: true, bluetoothGranted: true),
        {TransportType.ble, TransportType.lan, TransportType.nostr},
      );
    });

    test('desktop never uses Bluetooth', () {
      expect(
        plannedTransports(isMobile: false, bluetoothGranted: true),
        {TransportType.lan, TransportType.nostr},
      );
    });
  });
}
