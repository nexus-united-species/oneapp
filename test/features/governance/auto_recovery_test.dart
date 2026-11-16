import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';
import 'package:nexus_oneapp/features/governance/cell_service.dart';

const _me = 'did:key:me';

Cell _cell({String createdBy = _me}) => Cell.create(
      name: 'test1211',
      description: '',
      createdBy: createdBy,
      cellType: CellType.thematic,
    );

void main() {
  group('shouldAutoRecoverOwnCell (device test 16.11.2026)', () {
    test('restores my own cell after data loss', () {
      expect(
        shouldAutoRecoverOwnCell(cell: _cell(), myDid: _me, leftCellIds: {}),
        isTrue,
      );
    });

    test('does not re-join a cell I left, e.g. after a founder handover', () {
      final cell = _cell();
      expect(
        shouldAutoRecoverOwnCell(
            cell: cell, myDid: _me, leftCellIds: {cell.id}),
        isFalse,
      );
    });

    test('never for a cell someone else created', () {
      expect(
        shouldAutoRecoverOwnCell(
            cell: _cell(createdBy: 'did:key:other'),
            myDid: _me,
            leftCellIds: {}),
        isFalse,
      );
    });

    test('never without an identity', () {
      expect(
        shouldAutoRecoverOwnCell(cell: _cell(), myDid: null, leftCellIds: {}),
        isFalse,
      );
    });
  });
}
