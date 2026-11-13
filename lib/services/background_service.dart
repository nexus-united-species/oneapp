import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/transport/nostr/nostr_event.dart';
import '../core/transport/nostr/nostr_keys.dart';
import '../core/transport/nostr/relay_config.dart';
import '../core/transport/nostr/seen_event_ids.dart';
import 'notification_settings_service.dart';

/// Configures and starts the Android foreground service.
/// No-op on non-Android platforms.
class BackgroundServiceManager {
  static final instance = BackgroundServiceManager._();
  BackgroundServiceManager._();

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId: 'nexus_service',
          initialNotificationTitle: 'NEXUS aktiv',
          initialNotificationContent: 'Verbinde…',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
      );
      await service.startService();
    } catch (e) {
      debugPrint('[BGS] init failed: $e');
    }
  }

  /// Called by ChatProvider when the main app is in foreground and takes over
  /// the Nostr connection – the background service pauses its own WS.
  Future<void> pauseNostr() async {
    if (!Platform.isAndroid) return;
    FlutterBackgroundService().invoke('pauseNostr');
  }

  /// Called when app goes to background – the service resumes its WS.
  Future<void> resumeNostr() async {
    if (!Platform.isAndroid) return;
    FlutterBackgroundService().invoke('resumeNostr');
  }
}

// ── Background isolate entry points ──────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true; // iOS does not use this service.
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  // Architektonischer Fix: Baut die Brücke zu nativen Plugins im Background Isolate auf,
  // um MissingPluginExceptions und daraus resultierende Crash-Loops (z. B. bei Samsung) zu verhindern.
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  bool paused = false;
  // TD-47: one connection per relay instead of only the first one.
  var relayUrls = defaultRelays;
  final sockets = <String, WebSocketChannel>{};
  final socketSubs = <String, StreamSubscription<dynamic>>{};
  final reconnectTimers = <String, Timer>{};
  // The same DM arrives once per relay; notify only once.
  final seenDmIds = SeenEventIds();

  // ── Foreground notification helpers ──────────────────────────────────────
  void updateForeground(String content) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'NEXUS aktiv',
        content: content,
      );
    }
  }

  // ── Message notifications ─────────────────────────────────────────────────
  final notifPlugin = FlutterLocalNotificationsPlugin();
  await notifPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await NotificationSettingsService.instance.load();

  Future<void> showNotif(String sender, String preview) async {
    final s = NotificationSettingsService.instance;
    if (!s.enabled || s.isInDndWindow()) return;
    final body = s.showPreview ? preview : 'Neue Nachricht';
    await notifPlugin.show(
      sender.hashCode.abs() % 100000,
      sender,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'nexus_messages',
          'NEXUS Nachrichten',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
        ),
      ),
      payload: 'background',
    );
  }

  // ── Identity + Nostr keys ─────────────────────────────────────────────────
  String? pubKeyHex;
  NostrKeys? nostrKeys;
  String? localDid;
  String? localPseudonym;
  try {
    const storage = FlutterSecureStorage();
    pubKeyHex = await storage.read(key: 'nostr_public_key');
    localDid = await storage.read(key: 'nexus_did');
    localPseudonym = await storage.read(key: 'nexus_pseudonym');
    // Reconstruct NostrKeys from cached hex values (seed not needed if keys
    // are already stored, which they always are after first launch).
    if (pubKeyHex != null) {
      nostrKeys = await NostrKeys.loadOrDerive(Uint8List(0));
    }
  } catch (_) {}

  // ── Presence heartbeat ────────────────────────────────────────────────────
  Timer? presenceTimer;

  Future<void> sendPresenceHeartbeat() async {
    if (sockets.isEmpty || nostrKeys == null || localDid == null) return;
    try {
      final event = NostrEvent.create(
        keys: nostrKeys,
        kind: 30078, // NostrKind.presence
        content: jsonEncode({
          'did': localDid,
          'pseudonym': localPseudonym ?? '',
        }),
        tags: [
          ['d', 'nexus-presence'],
          ['t', 'nexus-presence'],
          ['did', localDid],
          ['name', localPseudonym ?? ''],
        ],
      );
      final message = jsonEncode(['EVENT', event.toJson()]);
      for (final entry in sockets.entries) {
        try {
          entry.value.sink.add(message);
        } catch (e) {
          debugPrint('[BGS] presence heartbeat to ${entry.key} failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[BGS] presence heartbeat failed: $e');
    }
  }

  void startPresenceTimer() {
    presenceTimer?.cancel();
    presenceTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      sendPresenceHeartbeat();
    });
  }

  void updateConnectionStatus() {
    if (sockets.isEmpty) {
      updateForeground('Verbinde…');
    } else {
      updateForeground(
          'Verbunden mit ${sockets.length} von ${relayUrls.length} Relays');
    }
  }

  void closeRelay(String url) {
    reconnectTimers.remove(url)?.cancel();
    socketSubs.remove(url)?.cancel();
    sockets.remove(url)?.sink.close();
  }

  // Assigned below; scheduleReconnect and connectRelay call each other.
  late final Future<void> Function(String url) connectRelay;

  void scheduleReconnect(String url, Duration delay) {
    reconnectTimers.remove(url)?.cancel();
    if (paused) return;
    reconnectTimers[url] = Timer(delay, () => connectRelay(url));
  }

  void handleRelayMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as List<dynamic>;
      if (msg.length < 3 || msg[0] != 'EVENT') return;
      final event = msg[2] as Map<String, dynamic>;
      if ((event['kind'] as int? ?? 0) != 4) return;
      final id = event['id'] as String? ?? '';
      if (id.isEmpty || !seenDmIds.add(id)) return;
      final senderPubkey = event['pubkey'] as String? ?? '';
      final shortSender = senderPubkey.length >= 8
          ? 'Peer ${senderPubkey.substring(0, 8)}'
          : 'Unbekannt';
      showNotif(shortSender, 'Neue verschlüsselte Nachricht');
    } catch (e) {
      debugPrint('[BGS] unreadable relay message: $e');
    }
  }

  connectRelay = (String url) async {
    if (paused || pubKeyHex == null) return;
    closeRelay(url);
    final ws = WebSocketChannel.connect(Uri.parse(url));
    try {
      await ws.ready;
    } catch (e) {
      debugPrint('[BGS] relay $url not reachable: $e');
      scheduleReconnect(url, const Duration(seconds: 15));
      updateConnectionStatus();
      return;
    }
    if (paused) {
      await ws.sink.close();
      return;
    }
    sockets[url] = ws;

    // Subscribe to incoming NIP-04 DMs for our pubkey.
    ws.sink.add(jsonEncode([
      'REQ',
      'bg-sub-1',
      {
        'kinds': [4],
        '#p': [pubKeyHex],
        'since': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60,
      }
    ]));

    socketSubs[url] = ws.stream.listen(
      handleRelayMessage,
      onDone: () {
        sockets.remove(url);
        socketSubs.remove(url);
        updateConnectionStatus();
        scheduleReconnect(url, const Duration(seconds: 5));
      },
      onError: (Object e) {
        debugPrint('[BGS] relay $url error: $e');
        sockets.remove(url);
        socketSubs.remove(url)?.cancel();
        updateConnectionStatus();
        scheduleReconnect(url, const Duration(seconds: 10));
      },
    );
    updateConnectionStatus();
  };

  Future<void> connectNostr() async {
    if (paused || pubKeyHex == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // The main isolate writes custom relays; drop this isolate's cache.
      await prefs.reload();
      relayUrls = effectiveRelays(await loadCustomRelays(prefs));
    } catch (e) {
      debugPrint('[BGS] relay list unavailable, using defaults: $e');
      relayUrls = defaultRelays;
    }
    debugPrint('[BGS] connecting to ${relayUrls.length} relays: $relayUrls');
    await Future.wait(relayUrls.map(connectRelay));

    // Send an immediate heartbeat, then every 90 s.
    await sendPresenceHeartbeat();
    startPresenceTimer();
  }

  await connectNostr();

  // ── Service control events ────────────────────────────────────────────────
  service.on('pauseNostr').listen((_) {
    paused = true;
    presenceTimer?.cancel();
    presenceTimer = null;
    for (final url in {...sockets.keys, ...reconnectTimers.keys}) {
      closeRelay(url);
    }
    updateForeground('App im Vordergrund');
  });

  service.on('resumeNostr').listen((_) async {
    paused = false;
    await connectNostr();
  });

  service.on('stopService').listen((_) => service.stopSelf());
}
