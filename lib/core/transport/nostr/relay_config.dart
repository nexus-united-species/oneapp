import 'package:shared_preferences/shared_preferences.dart';

/// Default Nostr relays (TD-47, revised 10.11.2026).
///
/// - `relay.nexus-terminal.org`: own strfry relay on the project VPS,
///   permanent retention, accepts only the event kinds of the app.
/// - `relay.damus.io`, `nos.lol`: public fallbacks. `nos.lol` caps events at
///   128 KB, so large inline images may only reach the other two.
///
/// Removed: `relay.snort.social` (memory only, stores nothing permanently)
/// and `relay.nostr.band` (unreachable since 06.11.2026).
const defaultRelays = [
  'wss://relay.nexus-terminal.org',
  'wss://relay.damus.io',
  'wss://nos.lol',
];

/// SharedPreferences key for relays the user added in the settings.
/// Stored separately from [defaultRelays] so that a later change of the
/// defaults reaches every installation.
const customRelaysPrefKey = 'nostr_custom_relays';

/// Returns a canonical form of [raw] (`wss://host[:port][/path]`, lower-case
/// scheme and host, no trailing slash), or `null` if it is not a usable
/// relay URL.
String? normalizeRelayUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'wss' && scheme != 'ws') return null;
  final host = uri.host.toLowerCase();
  if (host.isEmpty || host.contains(' ')) return null;
  if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) return null;

  final port = uri.hasPort ? ':${uri.port}' : '';
  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return '$scheme://$host$port$path';
}

/// Whether [url] is one of the [defaultRelays] (after normalisation).
bool isDefaultRelay(String url) {
  final normalized = normalizeRelayUrl(url);
  return normalized != null && defaultRelays.contains(normalized);
}

/// The relays the app connects to: [defaultRelays] first, then the valid,
/// not yet contained [custom] relays in their stored order.
List<String> effectiveRelays(Iterable<String> custom) {
  final result = <String>[...defaultRelays];
  for (final url in custom) {
    final normalized = normalizeRelayUrl(url);
    if (normalized != null && !result.contains(normalized)) {
      result.add(normalized);
    }
  }
  return List.unmodifiable(result);
}

/// Loads the user's own relays (normalised, without defaults or duplicates).
Future<List<String>> loadCustomRelays([SharedPreferences? prefs]) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  final stored = p.getStringList(customRelaysPrefKey) ?? const <String>[];
  return effectiveRelays(stored).skip(defaultRelays.length).toList();
}

/// Adds [url] to the user's own relays and persists the list.
///
/// Returns the normalised URL, or `null` if [url] is invalid. Adding a
/// default relay or an existing entry changes nothing but still returns the
/// normalised URL.
Future<String?> addCustomRelay(String url, [SharedPreferences? prefs]) async {
  final normalized = normalizeRelayUrl(url);
  if (normalized == null) return null;
  final p = prefs ?? await SharedPreferences.getInstance();
  final current = await loadCustomRelays(p);
  if (!defaultRelays.contains(normalized) && !current.contains(normalized)) {
    await p.setStringList(customRelaysPrefKey, [...current, normalized]);
  }
  return normalized;
}

/// Removes [url] from the user's own relays. Default relays cannot be
/// removed; returns whether a stored entry was removed.
Future<bool> removeCustomRelay(String url, [SharedPreferences? prefs]) async {
  final normalized = normalizeRelayUrl(url);
  if (normalized == null) return false;
  final p = prefs ?? await SharedPreferences.getInstance();
  final current = await loadCustomRelays(p);
  if (!current.contains(normalized)) return false;
  await p.setStringList(
    customRelaysPrefKey,
    current.where((u) => u != normalized).toList(),
  );
  return true;
}
