import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/chat/channel_payload.dart';
import 'package:nexus_oneapp/features/chat/chat_provider.dart';
import 'package:nexus_oneapp/features/chat/group_channel.dart';

const _admin = 'did:key:admin';
const _member = 'did:key:member';

GroupChannel _private() => GroupChannel.create(
      name: '#geheim',
      description: '',
      createdBy: _admin,
      isPublic: false,
    ).copyWith(members: [_admin, _member, 'did:key:removed']);

void main() {
  group('GroupChannel.withRotatedSecret (audit S-4)', () {
    test('the old secret moves to the earlier secrets', () {
      final channel = _private();
      final oldSecret = channel.channelSecret!;
      final newSecret = GroupChannel.generateSecret();

      final rotated = channel.withRotatedSecret(newSecret);

      expect(rotated.channelSecret, newSecret);
      expect(rotated.previousSecrets, [oldSecret]);
      expect(rotated.members, channel.members);
    });

    test('at most ten earlier secrets are kept, newest first', () {
      var channel = _private();
      final secrets = <String>[];
      for (var i = 0; i < 12; i++) {
        secrets.add(channel.channelSecret!);
        channel = channel.withRotatedSecret(GroupChannel.generateSecret());
      }

      expect(channel.previousSecrets, hasLength(GroupChannel.maxPreviousSecrets));
      expect(channel.previousSecrets.first, secrets.last);
    });

    test('earlier secrets survive storage, copyWith keeps them', () {
      final rotated =
          _private().withRotatedSecret(GroupChannel.generateSecret());

      final restored = GroupChannel.fromJson(rotated.toJson());
      expect(restored.previousSecrets, rotated.previousSecrets);
      expect(restored.copyWith(description: 'neu').previousSecrets,
          rotated.previousSecrets);
    });

    test('a fresh secret is 64 hex characters', () {
      expect(GroupChannel.generateSecret(), matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  group('posts from before the key change', () {
    test('stay readable with the earlier secret', () async {
      final channel = _private();
      final oldPost = await sealChannelPayload(
        body: 'vor dem Wechsel',
        channelId: channel.id,
        channelSecret: channel.channelSecret,
      );
      final rotated = channel.withRotatedSecret(GroupChannel.generateSecret());

      final opened = await openChannelPayload(
        body: oldPost.body,
        metadata: oldPost.metadata,
        channelId: rotated.id,
        channelSecret: rotated.channelSecret!,
        previousSecrets: rotated.previousSecrets,
      );

      expect(opened!.body, 'vor dem Wechsel');
    });

    test('new posts cannot be read with the old secret', () async {
      final channel = _private();
      final oldSecret = channel.channelSecret!;
      final rotated = channel.withRotatedSecret(GroupChannel.generateSecret());
      final newPost = await sealChannelPayload(
        body: 'nach dem Wechsel',
        channelId: rotated.id,
        channelSecret: rotated.channelSecret,
      );

      expect(
        await openChannelPayload(
          body: newPost.body,
          metadata: newPost.metadata,
          channelId: channel.id,
          channelSecret: oldSecret,
        ),
        isNull,
      );
    });
  });

  group('channelKeyChangeDecision (receive is a trust boundary)', () {
    final secret = GroupChannel.generateSecret();

    test('accepts a new key from the confirmed admin', () {
      expect(
        channelKeyChangeDecision(
            channel: _private(),
            senderDid: _admin,
            senderVerified: true,
            newSecret: secret),
        isNull,
      );
    });

    test('rejects a key from a member who is not the admin', () {
      expect(
        channelKeyChangeDecision(
            channel: _private(),
            senderDid: _member,
            senderVerified: true,
            newSecret: secret),
        isNotNull,
      );
    });

    test('rejects a key from an unconfirmed sender claiming to be admin', () {
      expect(
        channelKeyChangeDecision(
            channel: _private(),
            senderDid: _admin,
            senderVerified: false,
            newSecret: secret),
        isNotNull,
      );
    });

    test('rejects unknown and public channels and malformed keys', () {
      expect(
          channelKeyChangeDecision(
              channel: null,
              senderDid: _admin,
              senderVerified: true,
              newSecret: secret),
          isNotNull);
      expect(
          channelKeyChangeDecision(
              channel: GroupChannel.create(
                  name: '#offen', description: '', createdBy: _admin),
              senderDid: _admin,
              senderVerified: true,
              newSecret: secret),
          isNotNull);
      expect(
          channelKeyChangeDecision(
              channel: _private(),
              senderDid: _admin,
              senderVerified: true,
              newSecret: 'kurz'),
          isNotNull);
    });
  });
}
