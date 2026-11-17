import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/nexus_message.dart';
import 'package:nexus_oneapp/features/chat/delivery_indicator.dart';
import 'package:nexus_oneapp/features/chat/delivery_status.dart';

NexusMessage _message(String? state) => NexusMessage.create(
      fromDid: 'did:key:me',
      toDid: 'did:key:peer',
      type: NexusMessageType.image,
      body: 'BILD',
      metadata: state == null ? null : {localDeliveryMetaKey: state},
    );

Future<void> _pump(WidgetTester tester, String? state) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DeliveryIndicator(message: _message(state))),
      ),
    );

void main() {
  group('DeliveryIndicator (audit Z-3/Z-4)', () {
    testWidgets('shows a clock while waiting, for images too', (tester) async {
      await _pump(tester, DeliveryState.sending.value);

      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.text('wartet'), findsOneWidget);
    });

    testWidgets('offers resend when not sent', (tester) async {
      await _pump(tester, DeliveryState.failed.value);

      expect(find.text('Nicht gesendet – erneut senden'), findsOneWidget);
    });

    testWidgets('shows nothing once sent or for older messages',
        (tester) async {
      await _pump(tester, DeliveryState.sent.value);
      expect(find.byIcon(Icons.schedule), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);

      await _pump(tester, null);
      expect(find.byIcon(Icons.schedule), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });
}
