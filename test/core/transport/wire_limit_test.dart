import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/nexus_message.dart';

void main() {
  group('NexusMessage.fromWireBytes size limit (audit S-3)', () {
    test('a normal message round-trips', () {
      final msg = NexusMessage.create(fromDid: 'did:key:zA', body: 'Hallo');
      final decoded = NexusMessage.fromWireBytes(msg.toWireBytes());
      expect(decoded.id, msg.id);
      expect(decoded.body, 'Hallo');
    });

    test('a small payload that expands beyond the limit is rejected', () {
      // ~17 MB of zeros compresses to a few kilobytes.
      final bomb = Uint8List.fromList(zlib.encode(
          Uint8List(NexusMessage.maxDecodedWireBytes + 1024 * 1024)));
      expect(bomb.length, lessThan(100 * 1024));
      expect(() => NexusMessage.fromWireBytes(bomb),
          throwsA(isA<FormatException>()));
    });
  });
}
