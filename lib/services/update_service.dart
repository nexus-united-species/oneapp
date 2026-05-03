import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds information about an available update.
class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;

  /// Optional SHA-256 hex digest for the Android APK.
  /// If present, the downloaded file is verified before opening the installer.
  final String? sha256Apk;

  /// Optional SHA-256 hex digest for the Windows installer.
  /// If present, the downloaded file is verified before opening the installer.
  final String? sha256Exe;

  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    this.sha256Apk,
    this.sha256Exe,
  });
}

/// Checks GitHub Pages version.json for available updates.
///
/// Usage:
/// ```dart
/// await UpdateService.instance.startPeriodicCheck();
/// UpdateService.instance.updateStream.listen((info) { … });
/// ```
class UpdateService {
  UpdateService._();
  static final instance = UpdateService._();

  static const _kVersionJsonUrl =
      'https://project-nexus-official.github.io/terminal/downloads/version.json';
  static const _kLastCheckKey = 'nexus_last_update_check';
  static const _kLastDialogKey = 'last_update_dialog_shown';
  static const _kSkippedVersionKey = 'nexus_skipped_version';
  static const _checkIntervalHours = 6;
  static const _dialogIntervalHours = 24;

  final _controller = StreamController<UpdateInfo?>.broadcast();

  /// Broadcast stream: emits whenever [current] changes (new update or dismissed).
  Stream<UpdateInfo?> get updateStream => _controller.stream;

  UpdateInfo? _current;

  /// Last known update info, or null if up to date / not yet checked.
  UpdateInfo? get current => _current;

  Timer? _timer;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Starts the periodic check cycle.
  ///
  /// The first check respects the 6-hour rate limit. Subsequent checks run
  /// every 6 hours via a background [Timer]. The dialog is shown at most once
  /// per 24 hours.
  Future<void> startPeriodicCheck() async {
    await _checkWithRateLimit();
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(hours: _checkIntervalHours),
      (_) => _checkWithRateLimit(),
    );
  }

  /// Stops the periodic timer (e.g. when the app is paused).
  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }

  /// Forces an immediate check, bypassing both the 6-hour API rate limit and
  /// the 24-hour dialog throttle. Use this for the "Nach Updates suchen" button.
  Future<UpdateInfo?> checkNow() =>
      _fetchAndEvaluate(skipDialogThrottle: true);

  /// Hides the update banner for this session only (until next cold start).
  void dismissForSession() {
    _current = null;
    _controller.add(null);
  }

  /// Permanently skips [version]: stores it in SharedPreferences so the banner
  /// is never shown again for this specific release.
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSkippedVersionKey, version);
    _current = null;
    _controller.add(null);
  }

  /// Downloads the update file for [info], optionally verifies its SHA-256
  /// checksum, and hands it off to the OS installer (Android: system package
  /// installer, Windows: UAC-guarded setup wizard).
  ///
  /// Returns true when the installer was successfully launched.
  /// Returns false on any error (network, hash mismatch, unsupported platform)
  /// without throwing — all errors are logged with [debugPrint].
  ///
  /// Progress is reported via [onProgress] as a value in [0.0, 1.0].
  /// When the total response size is unknown, [onProgress] is not called.
  ///
  /// [platformOverride] is used in tests only (`'android'` or `'windows'`).
  Future<bool> downloadAndInstall(
    UpdateInfo info, {
    required void Function(double progress) onProgress,
    String? platformOverride,
  }) async {
    if (info.downloadUrl.isEmpty) {
      debugPrint('[UPDATE] No download URL available — aborting');
      return false;
    }

    try {
      // Resolve target directory: <tmp>/nexus_update/
      final tmp = await getTemporaryDirectory();
      final updateDir = Directory('${tmp.path}/nexus_update');
      await updateDir.create(recursive: true);

      final fileName = _targetFileNameForPlatform(platformOverride);
      final file = File('${updateDir.path}/$fileName');

      // Stream-download the update file and track progress.
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(info.downloadUrl));
        final response = await client
            .send(request)
            .timeout(const Duration(minutes: 10));

        if (response.statusCode != 200) {
          debugPrint('[UPDATE] Download failed (HTTP ${response.statusCode})');
          return false;
        }

        final total = response.contentLength ?? -1;
        var received = 0;
        final sink = file.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total);
        }
        await sink.close();
      } finally {
        client.close();
      }

      debugPrint('[UPDATE] Download complete: ${file.path}');

      // SHA-256 verification: skip silently when no hash is provided (alpha builds).
      final expectedHash = _expectedSha256For(info, platformOverride);
      if (expectedHash != null) {
        final verified = await _verifySha256(file, expectedHash);
        if (!verified) {
          // _verifySha256 already logs the mismatch detail.
          await file.delete();
          debugPrint('[UPDATE] Corrupt download deleted — aborting installation');
          return false;
        }
        debugPrint('[UPDATE] SHA256 verified OK');
      } else {
        debugPrint(
            '[UPDATE] No SHA256 provided; skipping verification for alpha build');
      }

      // Hand the file off to the OS installer — no silent installs.
      return await _launchInstaller(file, platformOverride);
    } catch (e) {
      debugPrint('[UPDATE] downloadAndInstall error: $e');
      return false;
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _checkWithRateLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_kLastCheckKey);
    if (lastCheck != null) {
      final last = DateTime.tryParse(lastCheck);
      if (last != null &&
          DateTime.now().difference(last).inHours < _checkIntervalHours) {
        return; // too soon — respect rate limit
      }
    }
    await _fetchAndEvaluate();
  }

  /// Fetches version.json from GitHub Pages, compares version_code with the
  /// installed build number, and updates [current] / [updateStream] if a newer
  /// version is available and the 24-hour dialog throttle allows it.
  ///
  /// [clientOverride], [currentVersionCodeOverride] and [platformOverride] are
  /// used in tests only. [platformOverride] accepts `'android'` or `'windows'`
  /// to simulate platform-specific URL selection without real device context.
  /// [skipDialogThrottle] bypasses the 24-hour dialog check (used by [checkNow]).
  Future<UpdateInfo?> _fetchAndEvaluate({
    http.Client? clientOverride,
    int? currentVersionCodeOverride,
    String? platformOverride,
    bool skipDialogThrottle = false,
  }) async {
    final ownClient = clientOverride == null;
    final client = clientOverride ?? http.Client();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastCheckKey, DateTime.now().toIso8601String());

      debugPrint('[UPDATE-CHECK] Checking: $_kVersionJsonUrl');
      final response = await client
          .get(Uri.parse(_kVersionJsonUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[UPDATE-CHECK] Check failed (HTTP ${response.statusCode})');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteVersionCode = data['version_code'] as int? ?? 0;
      final remoteVersion = data['version'] as String? ?? '';
      final rawNotes = data['release_notes'] as String? ?? '';
      final releaseNotes =
          rawNotes.length > 500 ? '${rawNotes.substring(0, 500)}…' : rawNotes;
      final apkUrl = data['apk_url'] as String? ?? '';
      final exeUrl = data['exe_url'] as String? ?? '';

      // Optional SHA-256 fields — absent in older version.json releases.
      final sha256Apk = data['sha256_apk'] as String?;
      final sha256Exe = data['sha256_exe'] as String?;

      // Select the download URL for the current platform.
      final downloadUrl = _selectDownloadUrl(apkUrl, exeUrl, platformOverride);

      // Get local version_code from the build number (+N in pubspec.yaml).
      final ownVersionCode = currentVersionCodeOverride ??
          int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ??
          0;

      debugPrint(
          '[UPDATE-CHECK] Current: $ownVersionCode, Remote: $remoteVersionCode');

      if (remoteVersionCode <= ownVersionCode) {
        debugPrint('[UPDATE-CHECK] Up to date');
        return null;
      }

      // Check whether the user has permanently skipped this release.
      final skipped = prefs.getString(_kSkippedVersionKey);
      if (skipped == remoteVersion) return null;

      // 24-hour dialog throttle.
      if (!skipDialogThrottle) {
        final lastDialogStr = prefs.getString(_kLastDialogKey);
        if (lastDialogStr != null) {
          final lastDialog = DateTime.tryParse(lastDialogStr);
          if (lastDialog != null &&
              DateTime.now().difference(lastDialog).inHours <
                  _dialogIntervalHours) {
            debugPrint(
                '[UPDATE-CHECK] Update available but dialog shown < 24h ago, skipping');
            return null;
          }
        }
      }

      await prefs.setString(_kLastDialogKey, DateTime.now().toIso8601String());
      debugPrint(
          '[UPDATE-CHECK] Update available: v$remoteVersion — showing dialog');

      final info = UpdateInfo(
        version: remoteVersion,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
        sha256Apk: sha256Apk,
        sha256Exe: sha256Exe,
      );
      _current = info;
      _controller.add(info);
      return info;
    } catch (e) {
      debugPrint('[UPDATE-CHECK] Check failed (network error): $e');
      return null;
    } finally {
      if (ownClient) client.close();
    }
  }

  /// Opens the downloaded installer via the appropriate OS mechanism.
  ///
  /// Android → system package installer (via open_file).
  /// Windows → UAC-guarded setup wizard (via Process.start, no shell).
  /// Other platforms → not supported in this sprint; returns false.
  Future<bool> _launchInstaller(File file, String? platformOverride) async {
    final isWindows = platformOverride != null
        ? platformOverride == 'windows'
        : (!kIsWeb && Platform.isWindows);
    final isAndroid = platformOverride != null
        ? platformOverride == 'android'
        : (!kIsWeb && Platform.isAndroid);

    if (isWindows) {
      debugPrint('[UPDATE] Launching Windows installer: ${file.path}');
      // runInShell: false prevents command injection; the path is controlled
      // (written to our own temp directory moments earlier).
      await Process.start(file.path, [], runInShell: false);
      debugPrint('[UPDATE] Windows installer started — awaiting user confirmation');
      return true;
    }

    if (isAndroid) {
      debugPrint('[UPDATE] Opening APK installer: ${file.path}');
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        debugPrint('[UPDATE] open_file failed: ${result.message}');
        return false;
      }
      return true;
    }

    // iOS, Linux, macOS, web — not in scope for this sprint.
    final platform = platformOverride ?? Platform.operatingSystem;
    debugPrint('[UPDATE] In-app install not supported on platform: $platform');
    return false;
  }

  // ── Test helpers ───────────────────────────────────────────────────────────

  /// For unit tests only: bypasses SharedPreferences rate limit and
  /// [PackageInfo.fromPlatform].
  ///
  /// [platformOverride]: `'android'` or `'windows'` to test platform-specific
  /// URL selection. Defaults to `'android'` (the most common test case).
  /// Set [skipDialogThrottle] to false to test the 24-hour dialog throttle.
  @visibleForTesting
  Future<UpdateInfo?> checkForUpdateWithMock({
    required http.Client client,
    required int currentVersionCode,
    String platformOverride = 'android',
    bool skipDialogThrottle = true,
  }) =>
      _fetchAndEvaluate(
        clientOverride: client,
        currentVersionCodeOverride: currentVersionCode,
        platformOverride: platformOverride,
        skipDialogThrottle: skipDialogThrottle,
      );
}

// ── Download helpers (testable) ───────────────────────────────────────────────

/// Returns the platform-appropriate filename for the downloaded update.
///
/// Windows → `'NexusOneApp_update.exe'`
/// Android / others → `'NexusOneApp_update.apk'`
///
/// [platformOverride] is used in tests only (`'android'` or `'windows'`).
@visibleForTesting
String targetFileNameForPlatform([String? platformOverride]) =>
    _targetFileNameForPlatform(platformOverride);

String _targetFileNameForPlatform([String? platformOverride]) {
  final isWin = platformOverride != null
      ? platformOverride == 'windows'
      : (!kIsWeb && Platform.isWindows);
  return isWin ? 'NexusOneApp_update.exe' : 'NexusOneApp_update.apk';
}

/// Returns the expected SHA-256 hash for the current platform's artifact,
/// or null if no hash was provided (alpha / legacy version.json).
///
/// [platformOverride] is used in tests only (`'android'` or `'windows'`).
@visibleForTesting
String? expectedSha256For(UpdateInfo info, [String? platformOverride]) =>
    _expectedSha256For(info, platformOverride);

String? _expectedSha256For(UpdateInfo info, [String? platformOverride]) {
  final isWin = platformOverride != null
      ? platformOverride == 'windows'
      : (!kIsWeb && Platform.isWindows);
  return isWin ? info.sha256Exe : info.sha256Apk;
}

/// Hashes [file] with SHA-256 and compares the result to [expectedHash].
///
/// [expectedHash] is normalised (trimmed, lowercased, spaces removed) before
/// comparison so that copy-paste artefacts in version.json don't cause false
/// negatives.
///
/// Returns true when the digests match.
@visibleForTesting
Future<bool> verifySha256(File file, String expectedHash) =>
    _verifySha256(file, expectedHash);

Future<bool> _verifySha256(File file, String expectedHash) async {
  final bytes = await file.readAsBytes();
  final actual = sha256.convert(bytes).toString(); // always lowercase hex
  final normalised =
      expectedHash.trim().toLowerCase().replaceAll(' ', '');
  if (actual != normalised) {
    debugPrint('[UPDATE] SHA256 mismatch: expected $normalised, got $actual');
    return false;
  }
  return true;
}

// ── Platform helper ───────────────────────────────────────────────────────────

/// Returns the appropriate download URL for the current platform.
///
/// On Windows → [exeUrl] (installer, opened via url_launcher in the UI).
/// On all other platforms (Android, etc.) → [apkUrl].
///
/// [platformOverride] is used in tests only (`'android'` or `'windows'`).
@visibleForTesting
String selectDownloadUrl(String apkUrl, String exeUrl,
        [String? platformOverride]) =>
    _selectDownloadUrl(apkUrl, exeUrl, platformOverride);

String _selectDownloadUrl(
    String apkUrl, String exeUrl, String? platformOverride) {
  if (platformOverride != null) {
    return platformOverride == 'windows' ? exeUrl : apkUrl;
  }
  if (!kIsWeb && Platform.isWindows) return exeUrl;
  return apkUrl;
}

// ── Pure version helpers (kept for external use / tests) ─────────────────────

/// Parses a semver-ish string into [major, minor, patch].
///
/// Handles:
/// - Leading "v": `"v0.1.1"` → `[0, 1, 1]`
/// - Build metadata: `"0.1.3+3"` → `[0, 1, 3]`
/// - Pre-release suffix: `"0.1.1-alpha"` → `[0, 1, 1]`
///
/// Returns null if parsing fails.
@visibleForTesting
List<int>? parseVersion(String raw) {
  var s = raw.trim();
  if (s.startsWith('v')) s = s.substring(1);
  // Strip build metadata
  final plusIdx = s.indexOf('+');
  if (plusIdx >= 0) s = s.substring(0, plusIdx);
  // Strip pre-release suffix
  final dashIdx = s.indexOf('-');
  if (dashIdx >= 0) s = s.substring(0, dashIdx);

  final parts = s.split('.');
  if (parts.length < 3) return null;
  final nums = <int>[];
  for (final p in parts.take(3)) {
    final n = int.tryParse(p);
    if (n == null) return null;
    nums.add(n);
  }
  return nums;
}

/// Returns true if [remote] is strictly newer than [local].
/// Compares major → minor → patch in order.
@visibleForTesting
bool isNewer(List<int> remote, List<int> local) {
  for (int i = 0; i < 3; i++) {
    if (remote[i] > local[i]) return true;
    if (remote[i] < local[i]) return false;
  }
  return false; // equal versions
}
