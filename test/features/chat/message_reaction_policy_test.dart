import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_oneapp/core/transport/nexus_message.dart';
import 'package:nexus_oneapp/features/chat/message_reaction_policy.dart';

const _myDid = 'did:key:ich';
const _bobDid = 'did:key:bob';
final _myKey = 'ab' * 32;
final _bobKey = '44' * 32;
final _malloryKey = '55' * 32;

String? _contacts(String pubkey) => pubkey == _bobKey ? _bobDid : null;

String? _resolve(NexusMessage message, String signer, {bool channel = false}) =>
    resolveReactorId(
      message: message,
      isChannel: channel,
      signerPubkey: signer,
      myDid: _myDid,
      myNostrPubkey: _myKey,
      contactDidForNostrPubkey: _contacts,
    );

void main() {
  final directToBob =
      NexusMessage.create(fromDid: _myDid, toDid: _bobDid, body: 'hallo');
  final directFromBob =
      NexusMessage.create(fromDid: _bobDid, toDid: _myDid, body: 'hallo');
  final channelPost = NexusMessage.create(
    fromDid: _bobDid,
    toDid: NexusMessage.broadcastDid,
    channel: '#kanal',
    body: 'beitrag',
  );

  group('resolveReactorId', () {
    test('records the own key as my DID', () {
      expect(_resolve(directToBob, _myKey), _myDid);
      expect(_resolve(channelPost, _myKey, channel: true), _myDid);
    });

    test('accepts the conversation partner in a direct chat', () {
      expect(_resolve(directToBob, _bobKey), _bobDid);
      expect(_resolve(directFromBob, _bobKey), _bobDid);
    });

    test('rejects strangers in a direct chat', () {
      expect(_resolve(directToBob, _malloryKey), isNull);
    });

    test('rejects a known contact who is not part of the direct chat', () {
      final directToCarol = NexusMessage.create(
        fromDid: _myDid,
        toDid: 'did:key:carol',
        body: 'hallo',
      );
      expect(_resolve(directToCarol, _bobKey), isNull);
    });

    test('records a known contact in a channel by DID', () {
      expect(_resolve(channelPost, _bobKey, channel: true), _bobDid);
    });

    test('records an unknown signer in a channel by Nostr key', () {
      expect(_resolve(channelPost, _malloryKey, channel: true), _malloryKey);
    });

    test('compares keys case-insensitively', () {
      expect(_resolve(directToBob, _myKey.toUpperCase()), _myDid);
    });

    test('rejects an empty signer', () {
      expect(_resolve(channelPost, '', channel: true), isNull);
    });
  });

  group('normalizeReactionContent', () {
    test('keeps an emoji', () {
      expect(normalizeReactionContent('🔥'), '🔥');
      expect(normalizeReactionContent(' ❤️ '), '❤️');
    });

    test('turns a NIP-25 like into 👍', () {
      expect(normalizeReactionContent('+'), '👍');
      expect(normalizeReactionContent(''), '👍');
      expect(normalizeReactionContent(null), '👍');
    });

    test('drops a dislike and oversized text', () {
      expect(normalizeReactionContent('-'), isNull);
      expect(normalizeReactionContent('x' * (maxReactionLength + 1)), isNull);
    });
  });
}
