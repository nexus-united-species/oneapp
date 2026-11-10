import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/bip39.dart';
import 'package:nexus_oneapp/core/identity/did.dart';
import 'package:nexus_oneapp/core/identity/identity_proof.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_event.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_keys.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_relay_manager.dart';
import 'package:nexus_oneapp/core/transport/nostr/nostr_transport.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';
import 'package:nexus_oneapp/features/governance/governance_authorization.dart';
import 'package:nexus_oneapp/features/governance/cell_member.dart';
import 'package:nexus_oneapp/features/governance/cell_roster.dart';

class _FakeRelayManager extends NostrRelayManager {
  _FakeRelayManager() : super(relayUrls: []);

  final _eventCtrl = StreamController<NostrEvent>.broadcast();
  final List<NostrEvent> published = [];

  @override
  Stream<NostrEvent> get onEvent => _eventCtrl.stream;

  @override
  Stream<String> get onRelayConnected => const Stream.empty();

  @override
  bool get hasConnectedRelay => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void publishFireAndForget(NostrEvent event) => published.add(event);

  @override
  String subscribe(Map<String, dynamic> filter) => generateSubId();

  @override
  void closeSubscription(String subId) {}

  void injectEvent(NostrEvent event) => _eventCtrl.add(event);
}

const _founderMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _strangerMnemonic = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';

NostrKeys _nostrKeys(String mnemonic) =>
    NostrKeys.fromBip39Seed(Uint8List.fromList(Bip39.mnemonicToSeed(mnemonic)));

Future<({String did, Map<String, String> proof})> _identity(
  int seedByte,
  NostrKeys nostrKeys,
) async {
  final keyPair =
      await Ed25519().newKeyPairFromSeed(List<int>.filled(32, seedByte));
  final did =
      DidKey.fromPublicKeyBytes((await keyPair.extractPublicKey()).bytes);
  final proof = await IdentityProof.create(
    signingKeyPair: keyPair,
    did: did,
    nostrPubkeyHex: nostrKeys.publicKeyHex,
  );
  return (did: did, proof: proof);
}

Cell _cellFoundedBy(String did) => Cell.create(
      name: 'Gartenzelle',
      description: 'Test',
      createdBy: did,
      cellType: CellType.thematic,
    );

void main() {
  final founderKeys = _nostrKeys(_founderMnemonic);
  final strangerKeys = _nostrKeys(_strangerMnemonic);

  group('authorizeCellDissolution', () {
    test('allows the founder with a valid identity proof', () async {
      final founder = await _identity(1, founderKeys);

      final decision = await authorizeCellDissolution(
        cell: _cellFoundedBy(founder.did),
        signerPubkey: founderKeys.publicKeyHex,
        idProof: founder.proof,
      );

      expect(decision, GovernanceAuthDecision.allowed);
    });

    test('rejects a member who is not the founder', () async {
      final founder = await _identity(1, founderKeys);
      final stranger = await _identity(2, strangerKeys);

      final decision = await authorizeCellDissolution(
        cell: _cellFoundedBy(founder.did),
        signerPubkey: strangerKeys.publicKeyHex,
        idProof: stranger.proof,
      );

      expect(decision, GovernanceAuthDecision.notAuthorized);
    });

    test('rejects the founder proof replayed under another key', () async {
      final founder = await _identity(1, founderKeys);

      final decision = await authorizeCellDissolution(
        cell: _cellFoundedBy(founder.did),
        signerPubkey: strangerKeys.publicKeyHex,
        idProof: founder.proof,
      );

      expect(decision, GovernanceAuthDecision.missingProof);
    });

    test('rejects dissolutions without proof or for unknown cells', () async {
      final founder = await _identity(1, founderKeys);

      expect(
        await authorizeCellDissolution(
          cell: _cellFoundedBy(founder.did),
          signerPubkey: founderKeys.publicKeyHex,
          idProof: null,
        ),
        GovernanceAuthDecision.missingProof,
      );
      expect(
        await authorizeCellDissolution(
          cell: null,
          signerPubkey: founderKeys.publicKeyHex,
          idProof: founder.proof,
        ),
        GovernanceAuthDecision.unknownCell,
      );
    });
  });

  group('authorizeCellAnnouncement', () {
    test('accepts a new cell announced by its founder', () async {
      final founder = await _identity(1, founderKeys);

      expect(
        await authorizeCellAnnouncement(
          existing: null,
          incoming: _cellFoundedBy(founder.did),
          signerPubkey: founderKeys.publicKeyHex,
          idProof: founder.proof,
        ),
        GovernanceAuthDecision.allowed,
      );
    });

    test('rejects a rename of a known cell by someone else', () async {
      final founder = await _identity(1, founderKeys);
      final stranger = await _identity(2, strangerKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await authorizeCellAnnouncement(
          existing: cell,
          incoming: cell.copyWith(name: 'Gekapert'),
          signerPubkey: strangerKeys.publicKeyHex,
          idProof: stranger.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects an announcement that changes the founder', () async {
      final founder = await _identity(1, founderKeys);
      final stranger = await _identity(2, strangerKeys);
      final cell = _cellFoundedBy(founder.did);
      final hijacked = Cell.fromJson({...cell.toJson(), 'createdBy': stranger.did});

      expect(
        await authorizeCellAnnouncement(
          existing: cell,
          incoming: hijacked,
          signerPubkey: strangerKeys.publicKeyHex,
          idProof: stranger.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('allows first discovery without proof (older app versions)',
        () async {
      final founder = await _identity(1, founderKeys);

      expect(
        await authorizeCellAnnouncement(
          existing: null,
          incoming: _cellFoundedBy(founder.did),
          signerPubkey: founderKeys.publicKeyHex,
          idProof: null,
        ),
        GovernanceAuthDecision.allowedLegacyDiscovery,
      );
    });

    test('rejects changes to a known cell without proof', () async {
      final founder = await _identity(1, founderKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await authorizeCellAnnouncement(
          existing: cell,
          incoming: cell.copyWith(name: 'Umbenannt'),
          signerPubkey: founderKeys.publicKeyHex,
          idProof: null,
        ),
        GovernanceAuthDecision.missingProof,
      );
    });

    test('rejects a forged proof on first discovery', () async {
      final founder = await _identity(1, founderKeys);
      final stranger = await _identity(2, strangerKeys);

      expect(
        await authorizeCellAnnouncement(
          existing: null,
          incoming: _cellFoundedBy(founder.did),
          signerPubkey: strangerKeys.publicKeyHex,
          idProof: stranger.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });
  });

  group('authorizeMemberUpdate', () {
    CellMember member(String cellId, String did, MemberRole role) => CellMember(
          cellId: cellId,
          did: did,
          joinedAt: DateTime.utc(2026, 11, 8),
          role: role,
        );

    test('lets a member announce their own departure only', () async {
      final founder = await _identity(1, founderKeys);
      final stranger = await _identity(2, strangerKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await authorizeMemberUpdate(
          cell: cell,
          members: const [],
          action: 'left',
          targetDid: stranger.did,
          signerPubkey: strangerKeys.publicKeyHex,
          idProof: stranger.proof,
        ),
        GovernanceAuthDecision.allowed,
      );
      expect(
        await authorizeMemberUpdate(
          cell: cell,
          members: const [],
          action: 'left',
          targetDid: 'did:key:z6MkSomeoneElse',
          signerPubkey: strangerKeys.publicKeyHex,
          idProof: stranger.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('allows removals by the founder or a known moderator', () async {
      final founder = await _identity(1, founderKeys);
      final moderator = await _identity(2, strangerKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await authorizeMemberUpdate(
          cell: cell,
          members: const [],
          action: 'removed',
          targetDid: 'did:key:z6MkMember',
          signerPubkey: founderKeys.publicKeyHex,
          idProof: founder.proof,
        ),
        GovernanceAuthDecision.allowed,
      );
      expect(
        await authorizeMemberUpdate(
          cell: cell,
          members: [member(cell.id, moderator.did, MemberRole.moderator)],
          action: 'removed',
          targetDid: 'did:key:z6MkMember',
          signerPubkey: strangerKeys.publicKeyHex,
          idProof: moderator.proof,
        ),
        GovernanceAuthDecision.allowed,
      );
    });

    test('rejects removals by plain members and removal of the founder',
        () async {
      final founder = await _identity(1, founderKeys);
      final plain = await _identity(2, strangerKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await authorizeMemberUpdate(
          cell: cell,
          members: [member(cell.id, plain.did, MemberRole.member)],
          action: 'removed',
          targetDid: 'did:key:z6MkMember',
          signerPubkey: strangerKeys.publicKeyHex,
          idProof: plain.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await authorizeMemberUpdate(
          cell: cell,
          members: const [],
          action: 'removed',
          targetDid: founder.did,
          signerPubkey: founderKeys.publicKeyHex,
          idProof: founder.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('moderators cannot remove other moderators', () async {
      final founder = await _identity(1, founderKeys);
      final moderator = await _identity(2, strangerKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await authorizeMemberUpdate(
          cell: cell,
          members: [
            member(cell.id, moderator.did, MemberRole.moderator),
            member(cell.id, 'did:key:z6MkOtherMod', MemberRole.moderator),
          ],
          action: 'removed',
          targetDid: 'did:key:z6MkOtherMod',
          signerPubkey: strangerKeys.publicKeyHex,
          idProof: moderator.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects updates for cells I am not a member of', () async {
      final founder = await _identity(1, founderKeys);

      expect(
        await authorizeMemberUpdate(
          cell: null,
          members: const [],
          action: 'joined',
          targetDid: 'did:key:z6MkMember',
          signerPubkey: founderKeys.publicKeyHex,
          idProof: founder.proof,
        ),
        GovernanceAuthDecision.unknownCell,
      );
    });
  });

  group('NostrTransport cell dissolution', () {

    test('attaches the proof to announcements and member updates', () async {
      final founder = await _identity(1, founderKeys);
      final relay = _FakeRelayManager();
      final transport = NostrTransport(
        localDid: founder.did,
        localPseudonym: 'Gründerin',
        relayManager: relay,
      );
      await transport.start(keysOverride: founderKeys);
      transport.setIdentityProof(founder.proof);
      relay.published.clear();

      final cell = _cellFoundedBy(founder.did);
      transport.publishCellAnnouncement(cell.toJson());
      transport.publishCellMemberUpdate(
        cellId: cell.id,
        targetDid: 'did:key:z6MkMember',
        action: 'removed',
      );

      expect(relay.published, hasLength(2));
      for (final event in relay.published) {
        final content = jsonDecode(event.content) as Map<String, dynamic>;
        expect(content[IdentityProof.contentKey], founder.proof);
      }

      await transport.stop();
    });
    test('publishes the identity proof and forwards signer and proof',
        () async {
      final founder = await _identity(1, founderKeys);
      final sender = _FakeRelayManager();
      final senderTransport = NostrTransport(
        localDid: founder.did,
        localPseudonym: 'Gründerin',
        relayManager: sender,
      );
      await senderTransport.start(keysOverride: founderKeys);
      senderTransport.setIdentityProof(founder.proof);
      sender.published.clear();

      final cell = _cellFoundedBy(founder.did);
      senderTransport.publishCellDissolution(cell.toJson());

      final event = sender.published.single;
      final content = jsonDecode(event.content) as Map<String, dynamic>;
      expect(content[IdentityProof.contentKey], founder.proof);

      final receiver = _FakeRelayManager();
      final receiverTransport = NostrTransport(
        localDid: 'did:key:receiver',
        localPseudonym: 'Empfänger',
        relayManager: receiver,
      );
      await receiverTransport.start(keysOverride: strangerKeys);
      final deletions = <Map<String, dynamic>>[];
      final sub = receiverTransport.onCellDeleted.listen(deletions.add);

      receiver.injectEvent(event);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(deletions, hasLength(1));
      expect(deletions.single['_nostr_pubkey'], founderKeys.publicKeyHex);
      expect(deletions.single[IdentityProof.contentKey], founder.proof);

      await sub.cancel();
      await senderTransport.stop();
      await receiverTransport.stop();
    });
  });

  group('authorizeMembershipConfirmation', () {
    const myDid = 'did:key:z6MkApplicant';

    CellMember confirmation(String cellId, String? confirmedBy,
            {String did = myDid, MemberRole role = MemberRole.member}) =>
        CellMember(
          cellId: cellId,
          did: did,
          joinedAt: DateTime.now().toUtc(),
          role: role,
          confirmedBy: confirmedBy,
        );

    Future<GovernanceAuthDecision> decide({
      required Cell? known,
      required Cell payload,
      required CellMember member,
      List<CellMember> knownMembers = const [],
      bool alreadyMember = false,
      bool pending = true,
      required NostrKeys signer,
      required Object? proof,
    }) =>
        authorizeMembershipConfirmation(
          knownCell: known,
          knownMembers: knownMembers,
          payloadCell: payload,
          member: member,
          myDid: myDid,
          isAlreadyMember: alreadyMember,
          hasPendingRequest: pending,
          signerPubkey: signer.publicKeyHex,
          idProof: proof,
        );

    test('allows the founder to confirm my pending request', () async {
      final founder = await _identity(1, founderKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await decide(
          known: cell,
          payload: cell,
          member: confirmation(cell.id, founder.did),
          signer: founderKeys,
          proof: founder.proof,
        ),
        GovernanceAuthDecision.allowed,
      );
    });

    test('allows a locally known moderator, not an unknown signer', () async {
      final founder = await _identity(1, founderKeys);
      final moderator = await _identity(2, strangerKeys);
      final cell = _cellFoundedBy(founder.did);
      final knownModerator = CellMember(
        cellId: cell.id,
        did: moderator.did,
        joinedAt: DateTime.now().toUtc(),
        role: MemberRole.moderator,
      );

      expect(
        await decide(
          known: cell,
          knownMembers: [knownModerator],
          payload: cell,
          member: confirmation(cell.id, moderator.did),
          signer: strangerKeys,
          proof: moderator.proof,
        ),
        GovernanceAuthDecision.allowed,
      );
      // A stranger naming themself as confirmedBy is not an approver.
      expect(
        await decide(
          known: cell,
          payload: cell,
          member: confirmation(cell.id, moderator.did),
          signer: strangerKeys,
          proof: moderator.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects a replay once I am already a member', () async {
      final founder = await _identity(1, founderKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await decide(
          known: cell,
          payload: cell,
          member: confirmation(cell.id, founder.did),
          alreadyMember: true,
          signer: founderKeys,
          proof: founder.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects a confirmation without a pending request of mine',
        () async {
      final founder = await _identity(1, founderKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await decide(
          known: cell,
          payload: cell,
          member: confirmation(cell.id, founder.did),
          pending: false,
          signer: founderKeys,
          proof: founder.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects a payload that swaps the founder of the known cell',
        () async {
      final founder = await _identity(1, founderKeys);
      final stranger = await _identity(2, strangerKeys);
      final known = _cellFoundedBy(founder.did);
      final forged = Cell.fromJson({
        ...known.toJson(),
        'createdBy': stranger.did,
      });

      expect(
        await decide(
          known: known,
          payload: forged,
          member: confirmation(known.id, stranger.did),
          signer: strangerKeys,
          proof: stranger.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects confirmations for someone else or with a higher role',
        () async {
      final founder = await _identity(1, founderKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await decide(
          known: cell,
          payload: cell,
          member: confirmation(cell.id, founder.did, did: 'did:key:z6MkOther'),
          signer: founderKeys,
          proof: founder.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await decide(
          known: cell,
          payload: cell,
          member: confirmation(cell.id, founder.did,
              role: MemberRole.moderator),
          signer: founderKeys,
          proof: founder.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
    });

    test('rejects a signer who does not prove the confirmedBy DID', () async {
      final founder = await _identity(1, founderKeys);
      final stranger = await _identity(2, strangerKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await decide(
          known: cell,
          payload: cell,
          member: confirmation(cell.id, founder.did),
          signer: strangerKeys,
          proof: stranger.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await decide(
          known: cell,
          payload: cell,
          member: confirmation(cell.id, founder.did),
          signer: founderKeys,
          proof: null,
        ),
        GovernanceAuthDecision.missingProof,
      );
    });

    test('rejects confirmations for unknown cells', () async {
      final founder = await _identity(1, founderKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await decide(
          known: null,
          payload: cell,
          member: confirmation(cell.id, founder.did),
          signer: founderKeys,
          proof: founder.proof,
        ),
        GovernanceAuthDecision.unknownCell,
      );
    });

    test('transport attaches the proof and forwards the signer', () async {
      final founder = await _identity(1, founderKeys);
      final sender = _FakeRelayManager();
      final senderTransport = NostrTransport(
        localDid: founder.did,
        localPseudonym: 'Gründerin',
        relayManager: sender,
      );
      await senderTransport.start(keysOverride: founderKeys);
      senderTransport.setIdentityProof(founder.proof);
      sender.published.clear();

      final cell = _cellFoundedBy(founder.did);
      senderTransport.publishCellMembershipConfirmed(
        cell.toJson(),
        confirmation(cell.id, founder.did).toJson(),
        strangerKeys.publicKeyHex,
      );
      final event = sender.published.single;

      final receiver = _FakeRelayManager();
      final receiverTransport = NostrTransport(
        localDid: myDid,
        localPseudonym: 'Bewerber',
        relayManager: receiver,
      );
      await receiverTransport.start(keysOverride: strangerKeys);
      final received = <Map<String, dynamic>>[];
      final sub =
          receiverTransport.onCellMembershipConfirmed.listen(received.add);

      receiver.injectEvent(event);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(received, hasLength(1));
      expect(received.single['_nostr_pubkey'], founderKeys.publicKeyHex);
      expect(received.single[IdentityProof.contentKey], founder.proof);

      await sub.cancel();
      await senderTransport.stop();
      await receiverTransport.stop();
    });
  });

  group('authorizeCellRoster (TD-33)', () {
    CellRoster rosterOf(Cell cell, String founderDid) => CellRoster(
          cellId: cell.id,
          updatedAtMs: 1000,
          members: [
            CellRosterEntry(
                did: founderDid, role: MemberRole.founder, joinedAtMs: 1),
          ],
        );

    test('accepts the roster of the proven founder', () async {
      final founder = await _identity(1, founderKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await authorizeCellRoster(
          cell: cell,
          roster: rosterOf(cell, founder.did),
          signerPubkey: founderKeys.publicKeyHex,
          idProof: founder.proof,
        ),
        GovernanceAuthDecision.allowed,
      );
    });

    test('rejects rosters from anyone else or naming another founder',
        () async {
      final founder = await _identity(1, founderKeys);
      final stranger = await _identity(2, strangerKeys);
      final cell = _cellFoundedBy(founder.did);

      expect(
        await authorizeCellRoster(
          cell: cell,
          roster: rosterOf(cell, founder.did),
          signerPubkey: strangerKeys.publicKeyHex,
          idProof: stranger.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await authorizeCellRoster(
          cell: cell,
          roster: rosterOf(cell, stranger.did),
          signerPubkey: strangerKeys.publicKeyHex,
          idProof: stranger.proof,
        ),
        GovernanceAuthDecision.notAuthorized,
      );
      expect(
        await authorizeCellRoster(
          cell: cell,
          roster: rosterOf(cell, founder.did),
          signerPubkey: founderKeys.publicKeyHex,
          idProof: null,
        ),
        GovernanceAuthDecision.missingProof,
      );
      expect(
        await authorizeCellRoster(
          cell: null,
          roster: rosterOf(cell, founder.did),
          signerPubkey: founderKeys.publicKeyHex,
          idProof: founder.proof,
        ),
        GovernanceAuthDecision.unknownCell,
      );
    });

    test('transport publishes the roster with proof and forwards the signer',
        () async {
      final founder = await _identity(1, founderKeys);
      final cell = _cellFoundedBy(founder.did);
      final sender = _FakeRelayManager();
      final senderTransport = NostrTransport(
        localDid: founder.did,
        localPseudonym: 'Gründerin',
        relayManager: sender,
      );
      await senderTransport.start(keysOverride: founderKeys);
      senderTransport.setIdentityProof(founder.proof);
      sender.published.clear();

      senderTransport.publishCellRoster(rosterOf(cell, founder.did).toJson());
      final event = sender.published.single;
      expect(event.kind, NostrKind.cellRoster);
      expect(event.tagValue('d'), cell.id);

      final receiver = _FakeRelayManager();
      final receiverTransport = NostrTransport(
        localDid: 'did:key:receiver',
        localPseudonym: 'Mitglied',
        relayManager: receiver,
      );
      await receiverTransport.start(keysOverride: strangerKeys);
      final received = <Map<String, dynamic>>[];
      final sub = receiverTransport.onCellRoster.listen(received.add);

      receiver.injectEvent(event);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(received, hasLength(1));
      expect(received.single['_nostr_pubkey'], founderKeys.publicKeyHex);
      expect(received.single[IdentityProof.contentKey], founder.proof);
      expect(CellRoster.tryParse(received.single)?.founderDid, founder.did);

      await sub.cancel();
      await senderTransport.stop();
      await receiverTransport.stop();
    });
  });
}
