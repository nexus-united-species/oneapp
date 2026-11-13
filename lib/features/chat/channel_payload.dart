import 'dart:convert';

import '../../core/crypto/channel_encryption.dart';

/// Metadata key holding the encrypted metadata of a private channel post.
const String channelEncryptedMetaKey = 'ch_enc_meta';

/// Metadata that describes the sender's own device and never goes out.
const Set<String> localOnlyMetaKeys = {'audio_local_path'};

/// Wire form of a channel post.
typedef ChannelWirePayload = ({
  String body,
  Map<String, dynamic>? metadata,
  bool encrypted,
});

/// Prepares a channel post for sending (audit S-4).
///
/// For a private channel ([channelSecret] set) the body is encrypted, and
/// so is all metadata (thumbnails, reply previews, dimensions) inside
/// [channelEncryptedMetaKey]; only the `ch_enc` marker stays readable.
/// Local-only keys are always removed. Throws [StateError] when encryption
/// fails, so a private post is never sent in plain text by accident.
Future<ChannelWirePayload> sealChannelPayload({
  required String body,
  Map<String, dynamic>? metadata,
  required String channelId,
  String? channelSecret,
}) async {
  final wireMeta = Map<String, dynamic>.from(metadata ?? const {})
    ..removeWhere((key, _) => localOnlyMetaKeys.contains(key));

  if (channelSecret == null) {
    return (
      body: body,
      metadata: wireMeta.isEmpty ? null : wireMeta,
      encrypted: false,
    );
  }

  final encryptedBody =
      await ChannelEncryption.encrypt(body, channelSecret, channelId);
  final encryptedMeta = wireMeta.isEmpty
      ? null
      : await ChannelEncryption.encrypt(
          jsonEncode(wireMeta), channelSecret, channelId);
  if (encryptedBody == null || (wireMeta.isNotEmpty && encryptedMeta == null)) {
    throw StateError('Channel encryption failed for $channelId');
  }
  return (
    body: encryptedBody,
    metadata: {
      'ch_enc': true,
      if (encryptedMeta != null) channelEncryptedMetaKey: encryptedMeta,
    },
    encrypted: true,
  );
}

/// Decrypts a private channel post. Returns null when the body cannot be
/// decrypted. Metadata from [channelEncryptedMetaKey] is merged in; older
/// posts without it keep their plain metadata.
Future<({String body, Map<String, dynamic> metadata})?> openChannelPayload({
  required String body,
  Map<String, dynamic>? metadata,
  required String channelId,
  required String channelSecret,
}) async {
  final plainBody =
      await ChannelEncryption.decrypt(body, channelSecret, channelId);
  if (plainBody == null) return null;

  final merged = Map<String, dynamic>.from(metadata ?? const {})
    ..remove(channelEncryptedMetaKey);
  final sealedMeta = metadata?[channelEncryptedMetaKey];
  if (sealedMeta is String) {
    final plainMeta =
        await ChannelEncryption.decrypt(sealedMeta, channelSecret, channelId);
    if (plainMeta != null) {
      try {
        final decoded = jsonDecode(plainMeta);
        if (decoded is Map) merged.addAll(Map<String, dynamic>.from(decoded));
      } on FormatException {
        // Keep the post readable without its extra metadata.
      }
    }
  }
  merged.removeWhere((key, _) => localOnlyMetaKeys.contains(key));
  return (body: plainBody, metadata: merged);
}
