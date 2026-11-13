import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/transport/nostr/relay_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('defaultRelays (TD-47)', () {
    test('own relay comes first, dead relays are gone', () {
      expect(defaultRelays.first, 'wss://relay.nexus-terminal.org');
      expect(defaultRelays, contains('wss://relay.damus.io'));
      expect(defaultRelays, isNot(contains('wss://relay.snort.social')));
      expect(defaultRelays, isNot(contains('wss://relay.nostr.band')));
    });

    test('every default is already in normalised form', () {
      for (final url in defaultRelays) {
        expect(normalizeRelayUrl(url), url);
      }
    });
  });

  group('normalizeRelayUrl', () {
    test('lower-cases scheme and host and trims whitespace and slashes', () {
      expect(normalizeRelayUrl('  WSS://Relay.Example.ORG/  '),
          'wss://relay.example.org');
    });

    test('keeps port and path', () {
      expect(normalizeRelayUrl('wss://relay.example.org:4848/nostr/'),
          'wss://relay.example.org:4848/nostr');
    });

    test('accepts ws:// for local relays', () {
      expect(normalizeRelayUrl('ws://192.168.0.10:7777'),
          'ws://192.168.0.10:7777');
    });

    test('rejects other schemes, missing hosts and extra parts', () {
      expect(normalizeRelayUrl('https://relay.example.org'), isNull);
      expect(normalizeRelayUrl('relay.example.org'), isNull);
      expect(normalizeRelayUrl('wss://'), isNull);
      expect(normalizeRelayUrl(''), isNull);
      expect(normalizeRelayUrl('wss://user:pw@relay.example.org'), isNull);
      expect(normalizeRelayUrl('wss://relay.example.org?x=1'), isNull);
      expect(normalizeRelayUrl('wss://relay.example.org#frag'), isNull);
    });
  });

  group('effectiveRelays', () {
    test('defaults first, then custom relays without duplicates', () {
      final result = effectiveRelays([
        'wss://relay.example.org',
        'WSS://relay.damus.io/',
        'wss://relay.example.org/',
        'kaputt',
      ]);
      expect(result, [...defaultRelays, 'wss://relay.example.org']);
    });
  });

  group('custom relay persistence', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('added relays survive a reload, normalised and once', () async {
      expect(await addCustomRelay(' wss://Relay.Example.org/ ', prefs),
          'wss://relay.example.org');
      expect(await addCustomRelay('wss://relay.example.org', prefs),
          'wss://relay.example.org');

      expect(await loadCustomRelays(prefs), ['wss://relay.example.org']);
      expect(prefs.getStringList(customRelaysPrefKey),
          ['wss://relay.example.org']);
    });

    test('invalid URLs and default relays are not stored', () async {
      expect(await addCustomRelay('https://relay.example.org', prefs), isNull);
      expect(await addCustomRelay('wss://relay.damus.io', prefs),
          'wss://relay.damus.io');
      expect(await loadCustomRelays(prefs), isEmpty);
    });

    test('removing a custom relay works, defaults cannot be removed',
        () async {
      await addCustomRelay('wss://relay.example.org', prefs);

      expect(await removeCustomRelay('wss://relay.damus.io', prefs), isFalse);
      expect(await removeCustomRelay('WSS://relay.example.org/', prefs),
          isTrue);
      expect(await loadCustomRelays(prefs), isEmpty);
    });

    test('stored defaults and garbage from older versions are ignored',
        () async {
      SharedPreferences.setMockInitialValues({
        customRelaysPrefKey: [
          'wss://relay.nexus-terminal.org',
          'nonsense',
          'wss://relay.example.org',
        ],
      });
      prefs = await SharedPreferences.getInstance();

      expect(await loadCustomRelays(prefs), ['wss://relay.example.org']);
    });
  });

  test('isDefaultRelay recognises defaults in any spelling', () {
    expect(isDefaultRelay('WSS://relay.nexus-terminal.org/'), isTrue);
    expect(isDefaultRelay('wss://relay.example.org'), isFalse);
    expect(isDefaultRelay('kaputt'), isFalse);
  });
}
