import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/proposal_option.dart';

void main() {
  group('OptionStatus enum', () {
    test('has correct values (ACTIVE, WITHDRAWN)', () {
      expect(OptionStatus.values.map((e) => e.name).toList(),
          containsAll(['ACTIVE', 'WITHDRAWN']));
      expect(OptionStatus.values.length, equals(2));
    });
  });

  group('ProposalOption.create', () {
    test('generates unique IDs', () {
      final a = ProposalOption.create(proposalId: 'p1', label: 'Option A');
      final b = ProposalOption.create(proposalId: 'p1', label: 'Option B');
      expect(a.optionId, isNotEmpty);
      expect(b.optionId, isNotEmpty);
      expect(a.optionId, isNot(equals(b.optionId)));
    });

    test('sets status to ACTIVE by default', () {
      final opt = ProposalOption.create(proposalId: 'p1', label: 'X');
      expect(opt.status, equals(OptionStatus.ACTIVE));
    });

    test('sets position to 0 by default', () {
      final opt = ProposalOption.create(proposalId: 'p1', label: 'X');
      expect(opt.position, equals(0));
    });

    test('DateTime is preserved as UTC', () {
      final before = DateTime.now().toUtc();
      final opt = ProposalOption.create(proposalId: 'p1', label: 'X');
      final after = DateTime.now().toUtc();
      expect(opt.createdAt.isUtc, isTrue);
      expect(opt.updatedAt.isUtc, isTrue);
      expect(opt.createdAt.isAfter(before) || opt.createdAt.isAtSameMomentAs(before), isTrue);
      expect(opt.createdAt.isBefore(after) || opt.createdAt.isAtSameMomentAs(after), isTrue);
    });

    test('candidate fields default to null', () {
      final opt = ProposalOption.create(proposalId: 'p1', label: 'X');
      expect(opt.candidateDid, isNull);
      expect(opt.candidatePseudonym, isNull);
      expect(opt.candidateAcceptedAt, isNull);
      expect(opt.candidateWithdrawnAt, isNull);
    });
  });

  group('ProposalOption.toMap', () {
    late ProposalOption opt;

    setUp(() {
      opt = ProposalOption.create(
        proposalId: 'prop_abc',
        label: 'Yes',
        description: 'Approve',
        candidateDid: 'did:key:z6Mk',
        candidatePseudonym: 'Pioneer',
        position: 2,
      );
    });

    test('returns all 12 fields', () {
      final m = opt.toMap();
      expect(m.keys.length, equals(12));
    });

    test('uses snake_case keys', () {
      final m = opt.toMap();
      expect(m.containsKey('option_id'), isTrue);
      expect(m.containsKey('proposal_id'), isTrue);
      expect(m.containsKey('candidate_did'), isTrue);
      expect(m.containsKey('candidate_pseudonym'), isTrue);
      expect(m.containsKey('candidate_accepted_at'), isTrue);
      expect(m.containsKey('candidate_withdrawn_at'), isTrue);
      expect(m.containsKey('created_at'), isTrue);
      expect(m.containsKey('updated_at'), isTrue);
      // Ensure no camelCase leaks
      expect(m.containsKey('optionId'), isFalse);
      expect(m.containsKey('candidateDid'), isFalse);
    });

    test('status is serialised as name string', () {
      final m = opt.toMap();
      expect(m['status'], equals('ACTIVE'));
    });

    test('timestamps are stored as millisecondsSinceEpoch integers', () {
      final m = opt.toMap();
      expect(m['created_at'], isA<int>());
      expect(m['updated_at'], isA<int>());
    });

    test('nullable candidate fields are null in map when not set', () {
      final simple = ProposalOption.create(proposalId: 'p1', label: 'L');
      final m = simple.toMap();
      expect(m['candidate_did'], isNull);
      expect(m['candidate_accepted_at'], isNull);
      expect(m['candidate_withdrawn_at'], isNull);
    });
  });

  group('ProposalOption.fromMap', () {
    test('correctly parses minimum required fields', () {
      final now = DateTime.now().toUtc();
      final m = {
        'option_id': 'opt_001',
        'proposal_id': 'prop_001',
        'label': 'Nein',
        'description': null,
        'candidate_did': null,
        'candidate_pseudonym': null,
        'candidate_accepted_at': null,
        'candidate_withdrawn_at': null,
        'status': 'ACTIVE',
        'position': 0,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      };
      final opt = ProposalOption.fromMap(m);
      expect(opt.optionId, equals('opt_001'));
      expect(opt.proposalId, equals('prop_001'));
      expect(opt.label, equals('Nein'));
      expect(opt.status, equals(OptionStatus.ACTIVE));
    });

    test('handles null candidate fields', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final m = {
        'option_id': 'opt_002',
        'proposal_id': 'prop_002',
        'label': 'Option',
        'description': null,
        'candidate_did': null,
        'candidate_pseudonym': null,
        'candidate_accepted_at': null,
        'candidate_withdrawn_at': null,
        'status': 'ACTIVE',
        'position': 0,
        'created_at': now,
        'updated_at': now,
      };
      final opt = ProposalOption.fromMap(m);
      expect(opt.candidateDid, isNull);
      expect(opt.candidatePseudonym, isNull);
      expect(opt.candidateAcceptedAt, isNull);
      expect(opt.candidateWithdrawnAt, isNull);
    });

    test('defaults status to ACTIVE for unknown values', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final m = {
        'option_id': 'opt_003',
        'proposal_id': 'prop_003',
        'label': 'X',
        'description': null,
        'candidate_did': null,
        'candidate_pseudonym': null,
        'candidate_accepted_at': null,
        'candidate_withdrawn_at': null,
        'status': 'TOTALLY_UNKNOWN',
        'position': 0,
        'created_at': now,
        'updated_at': now,
      };
      final opt = ProposalOption.fromMap(m);
      expect(opt.status, equals(OptionStatus.ACTIVE));
    });

    test('defaults status to ACTIVE for null status', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final m = {
        'option_id': 'opt_004',
        'proposal_id': 'prop_004',
        'label': 'Y',
        'description': null,
        'candidate_did': null,
        'candidate_pseudonym': null,
        'candidate_accepted_at': null,
        'candidate_withdrawn_at': null,
        'status': null,
        'position': 0,
        'created_at': now,
        'updated_at': now,
      };
      final opt = ProposalOption.fromMap(m);
      expect(opt.status, equals(OptionStatus.ACTIVE));
    });

    test('parses WITHDRAWN status correctly', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final m = {
        'option_id': 'opt_005',
        'proposal_id': 'prop_005',
        'label': 'Z',
        'description': null,
        'candidate_did': null,
        'candidate_pseudonym': null,
        'candidate_accepted_at': null,
        'candidate_withdrawn_at': null,
        'status': 'WITHDRAWN',
        'position': 1,
        'created_at': now,
        'updated_at': now,
      };
      final opt = ProposalOption.fromMap(m);
      expect(opt.status, equals(OptionStatus.WITHDRAWN));
    });
  });

  group('Round-trip', () {
    test('create -> toMap -> fromMap returns equivalent object', () {
      final acceptedAt = DateTime.utc(2026, 1, 15, 10, 30);
      final now = DateTime.now().toUtc();
      final original = ProposalOption(
        optionId: 'opt_rt1',
        proposalId: 'prop_rt1',
        label: 'Kandidat A',
        description: 'Erfahrener Pionier',
        candidateDid: 'did:key:z6MkTest',
        candidatePseudonym: 'TestPioneer',
        candidateAcceptedAt: acceptedAt,
        candidateWithdrawnAt: null,
        status: OptionStatus.ACTIVE,
        position: 3,
        createdAt: now,
        updatedAt: now,
      );

      final restored = ProposalOption.fromMap(original.toMap());

      expect(restored.optionId, equals(original.optionId));
      expect(restored.proposalId, equals(original.proposalId));
      expect(restored.label, equals(original.label));
      expect(restored.description, equals(original.description));
      expect(restored.candidateDid, equals(original.candidateDid));
      expect(restored.candidatePseudonym, equals(original.candidatePseudonym));
      expect(restored.candidateAcceptedAt?.millisecondsSinceEpoch,
          equals(acceptedAt.millisecondsSinceEpoch));
      expect(restored.candidateWithdrawnAt, isNull);
      expect(restored.status, equals(OptionStatus.ACTIVE));
      expect(restored.position, equals(3));
      expect(restored.createdAt.millisecondsSinceEpoch,
          equals(original.createdAt.millisecondsSinceEpoch));
      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.updatedAt.isUtc, isTrue);
    });
  });
}
