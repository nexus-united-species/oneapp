import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/cell.dart';
import 'package:nexus_oneapp/features/governance/cell_hub_screen.dart';

Cell _cell(String name, CellType type, {String? geohash}) => Cell.create(
      name: name,
      description: '',
      createdBy: 'did:key:founder',
      cellType: type,
      geohash: geohash,
    );

void main() {
  test('lists far and location-less local cells, not nearby or thematic', () {
    final nearby = _cell('Teneriffa Nord', CellType.local, geohash: 'eswk');
    final far = _cell('Würzburg', CellType.local, geohash: 'u0xm');
    final noLocation = _cell('Altona', CellType.local);
    final thematic = _cell('Freiheit und Frieden', CellType.thematic);

    final result = remoteLocalCellsForAdmin(
      [nearby, far, noLocation, thematic],
      [nearby],
    );

    expect(result.map((c) => c.name), ['Altona', 'Würzburg']);
  });

  test('is empty when every local cell is nearby', () {
    final nearby = _cell('Teneriffa Süd', CellType.local, geohash: 'eswj');

    expect(remoteLocalCellsForAdmin([nearby], [nearby]), isEmpty);
  });

  group('nearbyCells without a location (device test 16.11.2026)', () {
    final nord = _cell('Region Teneriffa Nord', CellType.local, geohash: 'esupxp');
    final sued = _cell('Region Teneriffa Süd', CellType.local, geohash: 'esupxp');
    final thematic = _cell('Freiheit und Frieden', CellType.thematic);

    test('lists every local cell by name when GPS is unavailable', () {
      final result =
          nearbyCells([sued, thematic, nord], null, gpsUnavailable: true);
      expect(result.map((c) => c.name),
          ['Region Teneriffa Nord', 'Region Teneriffa Süd']);
    });

    test('shows nothing while the location is still being looked up', () {
      expect(nearbyCells([nord, sued], null), isEmpty);
    });

    test('with a location only nearby cells count', () {
      final far = _cell('Würzburg', CellType.local, geohash: 'u0xm');
      expect(nearbyCells([nord, far], 'esupxp').map((c) => c.name),
          ['Region Teneriffa Nord']);
    });
  });
}
