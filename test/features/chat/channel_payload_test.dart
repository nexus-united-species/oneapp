import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/crypto/channel_encryption.dart';
import 'package:nexus_oneapp/features/chat/channel_payload.dart';

const _secret =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _otherSecret =
    'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';
const _channelId = 'channel-1';

void main() {
  group('sealChannelPayload (audit S-4)', () {
    test('a public channel post stays readable without local-only keys',
        () async {
      final wire = await sealChannelPayload(
        body: 'Hallo',
        metadata: {'duration_ms': 1200, 'audio_local_path': r'C:\x\a.wav'},
        channelId: _channelId,
      );

      expect(wire.encrypted, isFalse);
      expect(wire.body, 'Hallo');
      expect(wire.metadata, {'duration_ms': 1200});
    });

    test('a private image hides content, thumbnail and size', () async {
      final wire = await sealChannelPayload(
        body: 'BILD-BASE64',
        metadata: {'width': 640, 'height': 480, 'thumbnail': 'THUMB-BASE64'},
        channelId: _channelId,
        channelSecret: _secret,
      );

      expect(wire.encrypted, isTrue);
      expect(wire.body, isNot(contains('BILD')));
      expect(wire.metadata!.keys,
          unorderedEquals(['ch_enc', channelEncryptedMetaKey]));
      expect(jsonEncode(wire.metadata), isNot(contains('THUMB')));
    });

    test('a private reply does not reveal the quoted text', () async {
      final wire = await sealChannelPayload(
        body: 'Antwort',
        metadata: {'reply_to_preview': 'geheimer Text'},
        channelId: _channelId,
        channelSecret: _secret,
      );

      expect(jsonEncode(wire.metadata), isNot(contains('geheim')));
    });
  });

  group('openChannelPayload', () {
    test('restores body and metadata of a private voice post', () async {
      final wire = await sealChannelPayload(
        body: 'AUDIO-BASE64',
        metadata: {'duration_ms': 3000, 'audio_local_path': '/tmp/a.m4a'},
        channelId: _channelId,
        channelSecret: _secret,
      );

      final opened = await openChannelPayload(
        body: wire.body,
        metadata: wire.metadata,
        channelId: _channelId,
        channelSecret: _secret,
      );

      expect(opened!.body, 'AUDIO-BASE64');
      expect(opened.metadata['duration_ms'], 3000);
      expect(opened.metadata['ch_enc'], isTrue);
      expect(opened.metadata.containsKey('audio_local_path'), isFalse);
      expect(opened.metadata.containsKey(channelEncryptedMetaKey), isFalse);
    });

    test('older posts with plain metadata stay readable', () async {
      final body = await ChannelEncryption.encrypt('alt', _secret, _channelId);

      final opened = await openChannelPayload(
        body: body!,
        metadata: {'ch_enc': true, 'reply_to_id': 'abc'},
        channelId: _channelId,
        channelSecret: _secret,
      );

      expect(opened!.body, 'alt');
      expect(opened.metadata['reply_to_id'], 'abc');
    });

    test('the wrong secret yields null', () async {
      final wire = await sealChannelPayload(
        body: 'Hallo',
        channelId: _channelId,
        channelSecret: _secret,
      );

      expect(
        await openChannelPayload(
          body: wire.body,
          metadata: wire.metadata,
          channelId: _channelId,
          channelSecret: _otherSecret,
        ),
        isNull,
      );
    });
  });
}
