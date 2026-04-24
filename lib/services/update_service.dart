import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds information about an available update.
class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;

  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
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

      // Select the download URL for the current platform.
      final downloadUrl = _selectDownloadUrl(apkUrl, exeUrl, platformOverride);

      // Get local version_code from the build number (+N in pubspec.yaml).
      final ownVersionCode = currentVersionCodeOverride ??
          int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ??
          0;

      debugPrint('[UPDATE-CHECK] Current: $ownVersionCode, Remote: $remoteVersionCode');

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
      debugPrint('[UPDATE-CHECK] Update available: v$remoteVersion — showing dialog');

      final info = UpdateInfo(
        version: remoteVersion,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
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
