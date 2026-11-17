import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/did.dart';
import 'package:nexus_oneapp/core/identity/identity_proof.dart';
import 'package:nexus_oneapp/core/transport/nostr/sender_check.dart';

Future<({SimpleKeyPair keyPair, String did})> _identity(int seedByte) async {
  final keyPair =
      await Ed25519().newKeyPairFromSeed(List<int>.filled(32, seedByte));
  final publicKey = await keyPair.extractPublicKey();
  return (keyPair: keyPair, did: DidKey.fromPublicKeyBytes(publicKey.bytes));
}

const _nostrA = 'aa11223344556677889900aabbccddeeff00112233445566778899aabbccddee';
const _nostrB = 'bb11223344556677889900aabbccddeeff00112233445566778899aabbccddee';

void main() {
  group('checkSender (audit S-1)', () {
    test('a valid proof for the claimed DID is verified', () async {
      final alice = await _identity(1);
      final proof = await IdentityProof.create(
          signingKeyPair: alice.keyPair, did: alice.did, nostrPubkeyHex: _nostrA);

      expect(
        await checkSender(
            proof: proof, signerPubkey: _nostrA, claimedDid: alice.did),
        SenderCheck.verified,
      );
    });

    test('a valid proof wins over an older known key (key change)', () async {
      final alice = await _identity(1);
      final proof = await IdentityProof.create(
          signingKeyPair: alice.keyPair, did: alice.did, nostrPubkeyHex: _nostrA);

      expect(
        await checkSender(
            proof: proof,
            signerPubkey: _nostrA,
            claimedDid: alice.did,
            knownPubkey: _nostrB),
        SenderCheck.verified,
      );
    });

    test('a proof for another DID is forged', () async {
      final alice = await _identity(1);
      final mallory = await _identity(2);
      final proof = await IdentityProof.create(
          signingKeyPair: mallory.keyPair,
          did: mallory.did,
          nostrPubkeyHex: _nostrA);

      expect(
        await checkSender(
            proof: proof, signerPubkey: _nostrA, claimedDid: alice.did),
        SenderCheck.forged,
      );
    });

    test('a proof replayed under another Nostr key is forged', () async {
      final alice = await _identity(1);
      final proof = await IdentityProof.create(
          signingKeyPair: alice.keyPair, did: alice.did, nostrPubkeyHex: _nostrA);

      expect(
        await checkSender(
            proof: proof, signerPubkey: _nostrB, claimedDid: alice.did),
        SenderCheck.forged,
      );
    });

    test('a malformed proof is forged, not silently accepted', () async {
      expect(
        await checkSender(
            proof: {'did': 'x', 'sig': 'y'},
            signerPubkey: _nostrA,
            claimedDid: 'did:key:alice'),
        SenderCheck.forged,
      );
    });

    test('without proof an unknown sender is unverified', () async {
      expect(
        await checkSender(
            proof: null, signerPubkey: _nostrA, claimedDid: 'did:key:alice'),
        SenderCheck.unverified,
      );
    });

    test('without proof the known key of the DID is unverified', () async {
      expect(
        await checkSender(
            proof: null,
            signerPubkey: _nostrA,
            claimedDid: 'did:key:alice',
            knownPubkey: _nostrA),
        SenderCheck.unverified,
      );
    });

    test('without proof a known DID under another key is forged', () async {
      expect(
        await checkSender(
            proof: null,
            signerPubkey: _nostrB,
            claimedDid: 'did:key:alice',
            knownPubkey: _nostrA),
        SenderCheck.forged,
      );
    });
  });

  group('isOwnDeviceMessage (device test 16.11.2026)', () {
    const me = 'did:key:z6MkMe';

    test('a post from our other device carries our DID', () {
      expect(isOwnDeviceMessage(me, me), isTrue);
    });

    test('our key with a foreign DID is not accepted as ours', () {
      expect(isOwnDeviceMessage('did:key:z6MkOther', me), isFalse);
    });

    test('never without an own identity', () {
      expect(isOwnDeviceMessage('', ''), isFalse);
    });
  });
}
