import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Thin wrapper around the `record` package.
///
/// Usage:
///   1. Check / request permission once via [hasPermission] / [requestPermission].
///   2. Call [start] → UI shows recording indicator.
///   3. Call [stop] → returns the file path; caller sends the file.
///      OR call [cancel] → discards the partial file.
class VoiceRecorder {
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _currentPath;
  int _audioBytesPerSecond = _mobileAacBytesPerSecond;

  bool get isRecording => _isRecording;

  /// Size of one second of the current (or last) recording, used to stop
  /// before the message gets too large to send.
  int get audioBytesPerSecond => _audioBytesPerSecond;

  // Android/iOS: AAC with the requested 32 kbit/s.
  static const int _mobileAacBytesPerSecond = 32000 ~/ 8;
  // Windows Media Foundation encodes AAC at 44.1 kHz with at least 96 kbit/s
  // and ignores lower requested bitrates.
  static const int _desktopAacBytesPerSecond = 96000 ~/ 8;
  // Uncompressed fallback: 16 kHz, 16 bit, mono.
  static const int _wavBytesPerSecond = 16000 * 2;

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> requestPermission() async {
    // Desktop platforms don't use permission_handler for microphone.
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  // ── Recording lifecycle ────────────────────────────────────────────────────

  /// Starts recording and returns the file path where audio will be saved.
  /// Returns null if the recorder is already active or fails to start.
  Future<String?> start() async {
    if (_isRecording) return null;

    final dir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory('${dir.path}/nexus_voice');
    if (!voiceDir.existsSync()) voiceDir.createSync(recursive: true);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final config = await _config();
    final ext = config.encoder == AudioEncoder.wav ? 'wav' : 'm4a';
    final path = '${voiceDir.path}/voice_$ts.$ext';

    await _recorder.start(config, path: path);

    _isRecording = true;
    _currentPath = path;
    return path;
  }

  /// AAC everywhere it is available; on Windows (Block 3) instead of the
  /// former uncompressed WAV, which made even short messages too large.
  Future<RecordConfig> _config() async {
    if (Platform.isAndroid || Platform.isIOS) {
      _audioBytesPerSecond = _mobileAacBytesPerSecond;
      return const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        bitRate: 32000,
        numChannels: 1,
      );
    }
    var aac = false;
    try {
      aac = await _recorder.isEncoderSupported(AudioEncoder.aacLc);
    } on Exception catch (e) {
      print('[VOICE] AAC check failed: $e');
    }
    print('[VOICE] Desktop encoder: ${aac ? 'aacLc 44.1 kHz' : 'wav (no AAC)'}');
    if (aac) {
      _audioBytesPerSecond = _desktopAacBytesPerSecond;
      return const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 96000,
        numChannels: 1,
      );
    }
    _audioBytesPerSecond = _wavBytesPerSecond;
    return const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  /// Stops recording and returns the final file path, or null on failure.
  Future<String?> stop() async {
    if (!_isRecording) return null;
    _isRecording = false;
    final path = await _recorder.stop();
    _currentPath = null;
    return path;
  }

  /// Cancels the current recording and deletes the partial file.
  Future<void> cancel() async {
    if (!_isRecording) return;
    _isRecording = false;
    await _recorder.cancel();
    if (_currentPath != null) {
      final file = File(_currentPath!);
      if (file.existsSync()) file.deleteSync();
      _currentPath = null;
    }
  }

  void dispose() => _recorder.dispose();
}
