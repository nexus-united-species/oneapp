import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/chat/voice_limits.dart';

void main() {
  group('maxVoiceDuration (Block 3, Windows voice compression)', () {
    test('Windows AAC fits about 17 s into an encrypted direct message', () {
      final d = maxVoiceDuration(
          audioBytesPerSecond: 12000, expansion: dmVoiceExpansion);
      expect(d.inSeconds, inInclusiveRange(15, 18));
    });

    test('uncompressed WAV would only fit a few seconds', () {
      final d = maxVoiceDuration(
          audioBytesPerSecond: 32000, expansion: dmVoiceExpansion);
      expect(d.inSeconds, lessThan(8));
    });

    test('Android AAC allows longer channel posts than direct messages', () {
      final dm = maxVoiceDuration(
          audioBytesPerSecond: 4000, expansion: dmVoiceExpansion);
      final channel = maxVoiceDuration(
          audioBytesPerSecond: 4000, expansion: channelVoiceExpansion);
      expect(channel, greaterThan(dm));
    });

    test('the encoded event stays under the outbox limit', () {
      const bps = 12000;
      final d = maxVoiceDuration(
          audioBytesPerSecond: bps, expansion: dmVoiceExpansion);
      final eventBytes =
          d.inSeconds * bps * dmVoiceExpansion + voiceEventOverheadBytes;
      expect(eventBytes, lessThanOrEqualTo(500 * 1024));
    });

    test('never longer than five minutes', () {
      expect(
          maxVoiceDuration(audioBytesPerSecond: 1, expansion: 1),
          maxVoiceDurationCap);
    });
  });

  group('voiceFileExtension', () {
    Uint8List bytes(List<int> head) =>
        Uint8List.fromList([...head, ...List.filled(16, 0)]);

    test('recognises WAV from Windows (old versions)', () {
      expect(
          voiceFileExtension(bytes('RIFF'.codeUnits), fallback: 'm4a'), 'wav');
    });

    test('recognises AAC in MPEG-4', () {
      expect(
          voiceFileExtension(bytes([0, 0, 0, 0x18, ...'ftyp'.codeUnits]),
              fallback: 'wav'),
          'm4a');
    });

    test('falls back for unknown data', () {
      expect(voiceFileExtension(bytes([1, 2, 3]), fallback: 'wav'), 'wav');
    });
  });
}
