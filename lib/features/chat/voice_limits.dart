import 'dart:typed_data';

import '../../core/transport/nostr/nostr_outbox.dart';

/// How much a voice recording grows on its way into a Nostr event.
///
/// Every layer encodes the previous one as base64 (factor 4/3):
/// - E2E direct message: audio → base64 body → encrypted body (base64)
///   → NIP-04 content (base64) = (4/3)³.
/// - Channel post: audio → base64 body → channel encryption (base64) in
///   private channels = (4/3)²; public channels grow less, but one limit
///   for all channels keeps it simple.
const double dmVoiceExpansion = 64 / 27;
const double channelVoiceExpansion = 16 / 9;

/// Room for everything around the audio: tags, signature, identity proof,
/// metadata.
const int voiceEventOverheadBytes = 8 * 1024;

/// Never record longer than this, even with plenty of room.
const Duration maxVoiceDurationCap = Duration(minutes: 5);

/// Longest recording whose event still fits under the outbox size limit
/// (device test 16.11.2026: a 45 s Windows WAV made every relay drop the
/// connection).
Duration maxVoiceDuration({
  required int audioBytesPerSecond,
  required double expansion,
  int maxEventBytes = NostrOutbox.maxEventBytes,
}) {
  if (audioBytesPerSecond <= 0) return maxVoiceDurationCap;
  final room = maxEventBytes - voiceEventOverheadBytes;
  if (room <= 0) return Duration.zero;
  final seconds = (room / expansion / audioBytesPerSecond).floor();
  final limit = Duration(seconds: seconds);
  return limit > maxVoiceDurationCap ? maxVoiceDurationCap : limit;
}

/// File extension for received voice audio, taken from the data itself so
/// that a Windows recording plays on Android and vice versa.
String voiceFileExtension(Uint8List bytes, {required String fallback}) {
  if (bytes.length >= 12) {
    // RIFF....WAVE
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'wav';
    }
    // ....ftyp (MPEG-4 / AAC)
    if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      return 'm4a';
    }
  }
  return fallback;
}
