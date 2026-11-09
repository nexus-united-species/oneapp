import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/did.dart';
import 'package:nexus_oneapp/core/identity/did_key_decoder.dart';
import 'package:nexus_oneapp/core/identity/identity_proof.dart';

Future<({SimpleKeyPair keyPair, String did})> _identity(int seedByte) async {
  final keyPair =
      await Ed25519().newKeyPairFromSeed(List<int>.filled(32, seedByte));
  final publicKey = await keyPair.extractPublicKey();
  return (keyPair: keyPair, did: DidKey.fromPublicKeyBytes(publicKey.bytes));
}

const _nostrA = 'aa11223344556677889900aabbccddeeff00112233445566778899aabbccddee';
const _nostrB = 'bb11223344556677889900aabbccddeeff00112233445566778899aabbccddee';

void main() {
  group('DidKeyDecoder.publicKeyBytes', () {
    test('round-trips the Ed25519 public key', () async {
      final keyPair =
          await Ed25519().newKeyPairFromSeed(List<int>.filled(32, 7));
      final publicKey = (await keyPair.extractPublicKey()).bytes;
      final did = DidKey.fromPublicKeyBytes(publicKey);

      expect(DidKeyDecoder.publicKeyBytes(did), publicKey);
    });

    test('rejects non-did:key and malformed input', () {
      expect(DidKeyDecoder.publicKeyBytes('did:web:example.org'), isNull);
      expect(DidKeyDecoder.publicKeyBytes('did:key:z0OIl'), isNull);
      expect(DidKeyDecoder.publicKeyBytes('did:key:zabc'), isNull);
    });
  });

  group('IdentityProof', () {
    test('verifies a proof for the bound Nostr key', () async {
      final alice = await _identity(1);
      final proof = await IdentityProof.create(
        signingKeyPair: alice.keyPair,
        did: alice.did,
        nostrPubkeyHex: _nostrA,
      );

      expect(
        await IdentityProof.verifiedDid(proof: proof, nostrPubkeyHex: _nostrA),
        alice.did,
      );
    });

    test('rejects the proof when replayed by another Nostr key', () async {
      final alice = await _identity(1);
      final proof = await IdentityProof.create(
        signingKeyPair: alice.keyPair,
        did: alice.did,
        nostrPubkeyHex: _nostrA,
      );

      expect(
        await IdentityProof.verifiedDid(proof: proof, nostrPubkeyHex: _nostrB),
        isNull,
      );
    });

    test('rejects a proof that claims a foreign DID', () async {
      final alice = await _identity(1);
      final mallory = await _identity(2);
      final proof = await IdentityProof.create(
        signingKeyPair: mallory.keyPair,
        did: mallory.did,
        nostrPubkeyHex: _nostrB,
      );
      final forged = {'did': alice.did, 'sig': proof['sig']!};

      expect(
        await IdentityProof.verifiedDid(proof: forged, nostrPubkeyHex: _nostrB),
        isNull,
      );
    });

    test('treats missing or malformed proofs as unverified', () async {
      expect(
        await IdentityProof.verifiedDid(proof: null, nostrPubkeyHex: _nostrA),
        isNull,
      );
      expect(
        await IdentityProof.verifiedDid(
          proof: {'did': 'did:key:zabc', 'sig': '%%%'},
          nostrPubkeyHex: _nostrA,
        ),
        isNull,
      );
    });
  });
}
