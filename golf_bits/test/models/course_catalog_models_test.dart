import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/models/course_catalog_models.dart';

CourseTeeHoleRow _hole(int n, {int par = 4, int? yards}) {
  return CourseTeeHoleRow(holeNumber: n, par: par, yardageYds: yards);
}

List<CourseTeeHoleRow> _eighteen({int baseYards = 400}) {
  return List.generate(18, (i) => _hole(i + 1, yards: baseYards + i));
}

void main() {
  group('prepareTeesForDisplay', () {
    test('drops tees with no holes', () {
      final result = prepareTeesForDisplay([
        const CourseTeeOption(id: 'empty', label: 'Blue', holes: []),
        CourseTeeOption(id: 'full', label: 'White', holes: _eighteen()),
      ]);
      expect(result, hasLength(1));
      expect(result.single.label, 'White');
    });

    test('dedupes by label and color, keeping fuller 18-hole tee', () {
      final short = CourseTeeOption(
        id: 'a',
        label: 'Blue',
        colorHint: 'Blue',
        holes: List.generate(9, (i) => _hole(i + 1, yards: 350)),
      );
      final full = CourseTeeOption(
        id: 'b',
        label: 'Blue',
        colorHint: 'Blue',
        holes: _eighteen(baseYards: 420),
      );
      final result = prepareTeesForDisplay([short, full]);
      expect(result, hasLength(1));
      expect(result.single.id, 'b');
      expect(result.single.hasEighteenDistinctHoles, isTrue);
    });

    test('sorts full 18-hole tees before partial tees', () {
      final partial = CourseTeeOption(
        id: 'p',
        label: 'Front',
        holes: List.generate(9, (i) => _hole(i + 1)),
      );
      final full = CourseTeeOption(id: 'f', label: 'Championship', holes: _eighteen());
      final result = prepareTeesForDisplay([partial, full]);
      expect(result.first.hasEighteenDistinctHoles, isTrue);
      expect(result.last.hasEighteenDistinctHoles, isFalse);
    });
  });
}
