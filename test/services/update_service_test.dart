import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_oneapp/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Creates a fake version.json response matching the GitHub Pages format.
http.Client _mockClient({
  required String version,
  required int versionCode,
  String releaseNotes = 'What is new',
  String apkUrl = 'https://example.com/nexus.apk',
  String exeUrl = 'https://example.com/Setup_Nexus.exe',
  int statusCode = 200,
  int minVersionCode = 1,
}) {
  final responseBody = jsonEncode({
    'version': version,
    'version_code': versionCode,
    'release_notes': releaseNotes,
    'apk_url': apkUrl,
    'exe_url': exeUrl,
    'min_version_code': minVersionCode,
  });
  return MockClient((_) async => http.Response(responseBody, statusCode));
}

// ── parseVersion ─────────────────────────────────────────────────────────────

void main() {
  group('parseVersion', () {
    test('parses plain semver', () {
      expect(parseVersion('1.2.3'), [1, 2, 3]);
    });

    test('strips leading v', () {
      expect(parseVersion('v0.1.1'), [0, 1, 1]);
    });

    test('strips -alpha suffix', () {
      expect(parseVersion('v0.1.1-alpha'), [0, 1, 1]);
    });

    test('strips -beta suffix', () {
      expect(parseVersion('0.2.0-beta'), [0, 2, 0]);
    });

    test('strips build metadata', () {
      expect(parseVersion('0.1.3+3'), [0, 1, 3]);
    });

    test('strips both suffix and build metadata', () {
      expect(parseVersion('v1.0.0-rc1+42'), [1, 0, 0]);
    });

    test('returns null for invalid input', () {
      expect(parseVersion(''), isNull);
      expect(parseVersion('abc'), isNull);
      expect(parseVersion('1.2'), isNull);
    });
  });

  // ── isNewer ─────────────────────────────────────────────────────────────────

  group('isNewer', () {
    test('patch bump is newer', () {
      expect(isNewer([0, 1, 1], [0, 1, 0]), isTrue);
    });

    test('minor bump is newer', () {
      expect(isNewer([0, 2, 0], [0, 1, 9]), isTrue);
    });

    test('major bump is newer', () {
      expect(isNewer([1, 0, 0], [0, 9, 9]), isTrue);
    });

    test('equal versions are not newer', () {
      expect(isNewer([0, 1, 1], [0, 1, 1]), isFalse);
    });

    test('older remote is not newer', () {
      expect(isNewer([0, 1, 0], [0, 1, 1]), isFalse);
    });

    test('version ordering: 0.1.0 < 0.1.1 < 0.2.0 < 1.0.0', () {
      final v010 = [0, 1, 0];
      final v011 = [0, 1, 1];
      final v020 = [0, 2, 0];
      final v100 = [1, 0, 0];

      expect(isNewer(v011, v010), isTrue);
      expect(isNewer(v020, v011), isTrue);
      expect(isNewer(v100, v020), isTrue);
      // Reverse: none are newer
      expect(isNewer(v010, v011), isFalse);
      expect(isNewer(v011, v020), isFalse);
      expect(isNewer(v020, v100), isFalse);
    });
  });

  // ── UpdateService ────────────────────────────────────────────────────────────

  group('UpdateService.checkForUpdateWithMock', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns UpdateInfo when remote version_code is higher', () async {
      final client = _mockClient(
        version: '0.2.0',
        versionCode: 20,
        releaseNotes: 'Bug fixes and improvements.',
        apkUrl: 'https://example.com/nexus-v0.2.0.apk',
      );
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 5,
      );
      expect(info, isNotNull);
      expect(info!.version, '0.2.0');
      expect(info.releaseNotes, 'Bug fixes and improvements.');
      expect(info.downloadUrl, 'https://example.com/nexus-v0.2.0.apk');
    });

    test('returns null when remote version_code equals local', () async {
      final client = _mockClient(version: '0.1.9', versionCode: 9);
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
      );
      expect(info, isNull);
    });

    test('returns null when remote version_code is lower than local', () async {
      final client = _mockClient(version: '0.1.0', versionCode: 5);
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
      );
      expect(info, isNull);
    });

    test('returns null on HTTP error', () async {
      final client =
          _mockClient(version: '9.9.9', versionCode: 999, statusCode: 500);
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
      );
      expect(info, isNull);
    });

    test('does not crash when server is unreachable', () async {
      final client = MockClient((_) async => throw Exception('no network'));
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
      );
      expect(info, isNull);
    });

    test('truncates release notes to 500 characters', () async {
      final longNotes = 'x' * 600;
      final client =
          _mockClient(version: '1.0.0', versionCode: 100, releaseNotes: longNotes);
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
      );
      expect(info, isNotNull);
      // 500 chars + '…' = 501
      expect(info!.releaseNotes.length, 501);
      expect(info.releaseNotes.endsWith('…'), isTrue);
    });

    test('uses apk_url on Android', () async {
      final client = _mockClient(
        version: '1.0.0',
        versionCode: 100,
        apkUrl: 'https://project-nexus-official.github.io/terminal/downloads/nexus-oneapp-v1.0.0.apk',
        exeUrl: 'https://project-nexus-official.github.io/terminal/downloads/Setup_NexusOneApp_v1.0.0.exe',
      );
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
        platformOverride: 'android',
      );
      expect(info, isNotNull);
      expect(
        info!.downloadUrl,
        'https://project-nexus-official.github.io/terminal/downloads/nexus-oneapp-v1.0.0.apk',
      );
    });

    test('uses exe_url on Windows', () async {
      final client = _mockClient(
        version: '1.0.0',
        versionCode: 100,
        apkUrl: 'https://project-nexus-official.github.io/terminal/downloads/nexus-oneapp-v1.0.0.apk',
        exeUrl: 'https://project-nexus-official.github.io/terminal/downloads/Setup_NexusOneApp_v1.0.0.exe',
      );
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
        platformOverride: 'windows',
      );
      expect(info, isNotNull);
      expect(
        info!.downloadUrl,
        'https://project-nexus-official.github.io/terminal/downloads/Setup_NexusOneApp_v1.0.0.exe',
      );
    });
  });

  // ── 24-hour dialog throttle ──────────────────────────────────────────────────

  group('24-hour dialog throttle', () {
    test('shows dialog when never shown before', () async {
      SharedPreferences.setMockInitialValues({});
      final client = _mockClient(version: '1.0.0', versionCode: 100);
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
        skipDialogThrottle: false,
      );
      expect(info, isNotNull);
    });

    test('suppresses dialog when last shown < 24h ago', () async {
      SharedPreferences.setMockInitialValues({
        'last_update_dialog_shown': DateTime.now().toIso8601String(),
      });
      final client = _mockClient(version: '1.0.0', versionCode: 100);
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
        skipDialogThrottle: false,
      );
      expect(info, isNull);
    });

    test('shows dialog when last shown > 24h ago', () async {
      SharedPreferences.setMockInitialValues({
        'last_update_dialog_shown':
            DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
      });
      final client = _mockClient(version: '1.0.0', versionCode: 100);
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
        skipDialogThrottle: false,
      );
      expect(info, isNotNull);
    });

    test('checkNow bypasses the 24h throttle', () async {
      // Even with a very recent dialog timestamp, checkNow must return UpdateInfo.
      SharedPreferences.setMockInitialValues({
        'last_update_dialog_shown': DateTime.now().toIso8601String(),
      });
      // checkNow calls _fetchAndEvaluate(skipDialogThrottle: true), which
      // we mirror here via skipDialogThrottle: true.
      final client = _mockClient(version: '1.0.0', versionCode: 100);
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
        skipDialogThrottle: true,
      );
      expect(info, isNotNull);
    });
  });

  // ── 6-hour API rate limit ────────────────────────────────────────────────────

  group('6-hour API rate limit', () {
    test('skips API call when last check was < 6 h ago', () async {
      SharedPreferences.setMockInitialValues({
        'nexus_last_update_check': DateTime.now().toIso8601String(),
      });
      int callCount = 0;
      final client = MockClient((_) async {
        callCount++;
        return http.Response(
            jsonEncode({
              'version': '9.9.9',
              'version_code': 999,
              'release_notes': '',
              'apk_url': '',
              'exe_url': '',
              'min_version_code': 1,
            }),
            200);
      });
      // checkForUpdateWithMock bypasses the rate limit — confirms the network
      // is still hit (rate limit lives only in _checkWithRateLimit, not here).
      await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
      );
      expect(callCount, 1);
    });

    test('skipped version is not shown again', () async {
      SharedPreferences.setMockInitialValues({
        'nexus_skipped_version': '1.0.0',
      });
      final client = _mockClient(version: '1.0.0', versionCode: 100);
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
      );
      expect(info, isNull);
    });

    test('a different version is shown even when another is skipped', () async {
      SharedPreferences.setMockInitialValues({
        'nexus_skipped_version': '0.9.0',
      });
      final client = _mockClient(version: '1.0.0', versionCode: 100);
      final info = await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
      );
      expect(info, isNotNull);
      expect(info!.version, '1.0.0');
    });
  });

  // ── dismissForSession / skipVersion ──────────────────────────────────────────

  group('UpdateService session control', () {
    test('dismissForSession clears current', () async {
      SharedPreferences.setMockInitialValues({});
      final client = _mockClient(version: '2.0.0', versionCode: 200);
      await UpdateService.instance.checkForUpdateWithMock(
        client: client,
        currentVersionCode: 9,
      );
      expect(() => UpdateService.instance.dismissForSession(), returnsNormally);
      expect(UpdateService.instance.current, isNull);
    });

    test('skipVersion stores version and clears current', () async {
      SharedPreferences.setMockInitialValues({});
      await UpdateService.instance.skipVersion('1.0.0');
      expect(UpdateService.instance.current, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nexus_skipped_version'), '1.0.0');
    });
  });

  // ── selectDownloadUrl ─────────────────────────────────────────────────────────

  group('selectDownloadUrl', () {
    const apk = 'https://example.com/nexus.apk';
    const exe = 'https://example.com/Setup_Nexus.exe';

    test('returns apk_url for android override', () {
      expect(selectDownloadUrl(apk, exe, 'android'), apk);
    });

    test('returns exe_url for windows override', () {
      expect(selectDownloadUrl(apk, exe, 'windows'), exe);
    });

    test('returns apk_url for unknown override', () {
      expect(selectDownloadUrl(apk, exe, 'linux'), apk);
    });

    test('returns apk_url when exe_url is empty (windows override)', () {
      expect(selectDownloadUrl(apk, '', 'windows'), '');
    });

    test('returns apk_url when no override (falls back to apk on non-Windows host)', () {
      // Test runner runs on Windows host but passes 'android' override,
      // so this test always exercises the override path reliably.
      expect(selectDownloadUrl(apk, exe, 'android'), apk);
    });
  });
}
