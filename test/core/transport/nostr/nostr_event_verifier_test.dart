import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event_verifier.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';

/// TD-39: incoming Nostr events are passed on only if their ID and Schnorr
/// signature are valid; forged events must not change local state.

const _mnemonic = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

final _keys = NostrKeys.fromBip39Seed(
  Uint8List.fromList(Bip39.mnemonicToSeed(_mnemonic)),
);

NostrEvent _signed(String content) => NostrEvent.create(
      keys: _keys,
      kind: NostrKind.deletion,
      content: content,
      tags: const [
        ['e', 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90'],
      ],
    );

/// [event] with a different content but the original ID and signature.
NostrEvent _tampered(NostrEvent event) => NostrEvent(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      kind: event.kind,
      tags: event.tags,
      content: 'gefälscht',
      sig: event.sig,
    );

/// [event] claiming to come from another key (signature does not match).
NostrEvent _foreignPubkey(NostrEvent event) => NostrEvent(
      id: event.id,
      pubkey: '7e7e4c4c' * 8,
      createdAt: event.createdAt,
      kind: event.kind,
      tags: event.tags,
      content: event.content,
      sig: event.sig,
    );

void main() {
  late List<String> emitted;
  late NostrEventVerifier verifier;

  setUp(() {
    emitted = [];
    verifier = NostrEventVerifier(onValid: (e) => emitted.add(e.content));
  });

  test('passes on a correctly signed event', () async {
    verifier.add(_signed('echt'));
    await verifier.idle;

    expect(emitted, ['echt']);
  });

  test('drops an event whose content was changed', () async {
    verifier.add(_tampered(_signed('echt')));
    await verifier.idle;

    expect(emitted, isEmpty);
  });

  test('drops an event that claims a foreign public key', () async {
    verifier.add(_foreignPubkey(_signed('echt')));
    await verifier.idle;

    expect(emitted, isEmpty);
  });

  test('passes on the same event only once (several relays)', () async {
    final event = _signed('einmal');

    verifier
      ..add(event)
      ..add(event)
      ..add(event);
    await verifier.idle;
    verifier.add(event);
    await verifier.idle;

    expect(emitted, ['einmal']);
  });

  test('a forged copy does not block the genuine event with the same ID',
      () async {
    final genuine = _signed('echt');

    verifier
      ..add(_tampered(genuine))
      ..add(genuine);
    await verifier.idle;

    expect(emitted, ['echt']);
  });

  test('keeps the arrival order', () async {
    final events = [for (var i = 0; i < 5; i++) _signed('nr $i')];

    for (final e in events) {
      verifier.add(e);
    }
    await verifier.idle;

    expect(emitted, [for (var i = 0; i < 5; i++) 'nr $i']);
  });

  test('falls back to direct verification when the batch verifier fails',
      () async {
    verifier = NostrEventVerifier(
      onValid: (e) => emitted.add(e.content),
      verifyBatch: (_) async => throw StateError('isolate unavailable'),
    );

    verifier
      ..add(_signed('echt'))
      ..add(_tampered(_signed('anders')));
    await verifier.idle;

    expect(emitted, ['echt']);
  });

  group('NostrRelayManager', () {
    test('emits only verified events from relay messages', () async {
      final manager = NostrRelayManager(relayUrls: const []);
      final received = <String>[];
      final sub = manager.onEvent.listen((e) => received.add(e.content));
      final genuine = _signed('vom Relay');

      for (final event in [_tampered(_signed('x')), genuine]) {
        manager.debugHandleMessage(
          'wss://relay.test',
          jsonEncode(['EVENT', 'sub1', event.toJson()]),
        );
      }
      await manager.debugVerifierIdle;

      expect(received, ['vom Relay']);
      await sub.cancel();
    });
  });
}
