import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/transport/nexus_message.dart';
import 'chat_provider.dart';
import 'delivery_status.dart';

/// Delivery state under an own message (audit Z-3/Z-4): a clock while no
/// relay has accepted it, a red hint with resend when it was not sent.
/// Shows nothing once sent and for older messages.
class DeliveryIndicator extends StatelessWidget {
  const DeliveryIndicator({super.key, required this.message});

  final NexusMessage message;

  @override
  Widget build(BuildContext context) {
    final state = DeliveryState.fromValue(
        message.metadata?[localDeliveryMetaKey] as String?);
    switch (state) {
      case DeliveryState.sending:
        return const Padding(
          padding: EdgeInsets.only(top: 2, right: 4),
          child: Tooltip(
            message: 'Wartet auf Zustellung',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 11, color: Colors.grey),
                SizedBox(width: 3),
                Text('wartet',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      case DeliveryState.failed:
        return Padding(
          padding: const EdgeInsets.only(top: 2, right: 4),
          child: InkWell(
            onTap: () =>
                context.read<ChatProvider>().resendFailedMessage(message),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 13, color: Colors.redAccent),
                SizedBox(width: 4),
                Text(
                  'Nicht gesendet – erneut senden',
                  style: TextStyle(fontSize: 11, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        );
      case DeliveryState.sent:
      case null:
        return const SizedBox.shrink();
    }
  }
}
