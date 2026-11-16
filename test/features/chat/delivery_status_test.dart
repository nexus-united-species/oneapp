import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/message_transport.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/core/transport/nexus_message.dart';
import 'package:nexus_oneapp/features/chat/delivery_status.dart';

void main() {
  group('DeliveryState (audit Z-3/Z-4)', () {
    test('reads stored values; legacy rows show no state', () {
      expect(DeliveryState.fromValue('sending'), DeliveryState.sending);
      expect(DeliveryState.fromValue('sent'), DeliveryState.sent);
      expect(DeliveryState.fromValue('failed'), DeliveryState.failed);
      expect(DeliveryState.fromValue('pending'), isNull);
      expect(DeliveryState.fromValue(null), isNull);
    });
  });

  group('deliveryAfterHandOff', () {
    test('a direct LAN or BLE delivery is sent', () {
      expect(deliveryAfterHandOff(TransportType.lan, relayAlreadyAccepted: false),
          DeliveryState.sent);
      expect(deliveryAfterHandOff(TransportType.ble, relayAlreadyAccepted: false),
          DeliveryState.sent);
    });

    test('a relay hand-off waits for the relay', () {
      expect(
          deliveryAfterHandOff(TransportType.nostr, relayAlreadyAccepted: false),
          DeliveryState.sending);
    });

    test('a relay that already answered makes it sent', () {
      expect(
          deliveryAfterHandOff(TransportType.nostr, relayAlreadyAccepted: true),
          DeliveryState.sent);
    });
  });

  test('the Nostr transport fails loudly before it has keys (audit Z-3)',
      () async {
    final transport = NostrTransport(
      localDid: 'did:key:a',
      localPseudonym: 'A',
      relayManager: NostrRelayManager(relayUrls: const []),
    );

    await expectLater(
      transport.sendMessage(
          NexusMessage.create(fromDid: 'did:key:a', toDid: 'did:key:b', body: 'x'),
          recipientDid: 'did:key:b'),
      throwsA(isA<StateError>()),
    );
  });

  group('messageListChanged (device test 14.11.2026)', () {
    NexusMessage msg(String id, String? state) => NexusMessage(
          id: id,
          fromDid: 'did:key:a',
          toDid: 'did:key:b',
          type: NexusMessageType.text,
          body: 'x',
          timestamp: DateTime.utc(2026, 11, 14),
          metadata: state == null ? null : {localDeliveryMetaKey: state},
        );

    test('a delivery state change alone triggers a refresh', () {
      expect(
        messageListChanged(
            [msg('1', DeliveryState.sending.value)], [msg('1', null)]),
        isTrue,
        reason: '„wartet“ must disappear without leaving the chat',
      );
    });

    test('identical lists do not refresh (no rebuild loop)', () {
      expect(messageListChanged([msg('1', null)], [msg('1', null)]), isFalse);
    });

    test('new or replaced messages refresh', () {
      expect(messageListChanged([msg('1', null)], [msg('1', null), msg('2', null)]),
          isTrue);
      expect(messageListChanged([msg('1', null)], [msg('2', null)]), isTrue);
    });
  });
}
