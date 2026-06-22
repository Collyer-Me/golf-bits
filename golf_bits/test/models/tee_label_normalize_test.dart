import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/models/course_catalog_models.dart';
import 'package:golf_bits/models/tee_label_normalize.dart';

CourseTeeHoleRow _hole(int n, {int yards = 400}) {
  return CourseTeeHoleRow(holeNumber: n, par: 4, yardageYds: yards);
}

List<CourseTeeHoleRow> _eighteen({int baseYards = 400}) {
  return List.generate(18, (i) => _hole(i + 1, yards: baseYards + i));
}

void main() {
  group('parseProviderTeeLabel', () {
    test('parses USGA comma-separated men blue tee', () {
      final m = parseProviderTeeLabel('60116, USGA, Blue, Men');
      expect(m.color, 'Blue');
      expect(m.gender, 'men');
      expect(m.isHistorical, isFalse);
    });

    test('flags NOV21 historical variant', () {
      final m = parseProviderTeeLabel('60116, USGA, Blue, Men NOV21');
      expect(m.isHistorical, isTrue);
      expect(m.color, 'Blue');
      expect(m.gender, 'men');
    });

    test('plain color name without commas', () {
      final m = parseProviderTeeLabel('Silver');
      expect(m.color, 'Silver');
      expect(m.gender, isNull);
    });
  });

  group('prepareTeesForDisplay provider rules', () {
    test('collapses Royal Perth style duplicates to one blue men', () {
      final current = CourseTeeOption(
        id: 'current',
        label: '60116, USGA, Blue, Men',
        holes: _eighteen(baseYards: 500),
      );
      final historical = CourseTeeOption(
        id: 'old',
        label: '60116, USGA, Blue, Men NOV21',
        holes: _eighteen(baseYards: 490),
      );
      final result = prepareTeesForDisplay([historical, current]);
      expect(result, hasLength(1));
      expect(result.single.id, 'current');
      expect(result.single.displayLabel, 'Blue');
    });

    test('keeps separate men and women blues when both present', () {
      final men = CourseTeeOption(
        id: 'm',
        label: '60116, USGA, Blue, Men',
        holes: _eighteen(),
      );
      final women = CourseTeeOption(
        id: 'w',
        label: '60116, USGA, Blue, Women',
        holes: _eighteen(baseYards: 380),
      );
      final result = prepareTeesForDisplay([men, women]);
      expect(result, hasLength(2));
      expect(result.map((t) => t.displayLabel).toSet(), {'Blue (Men)', 'Blue (Women)'});
    });

    test('drops 9-hole SP variant when 18-hole exists for same family', () {
      final full = CourseTeeOption(
        id: '18',
        label: '50103, USGA, Red, Women',
        holes: _eighteen(),
      );
      final nine = CourseTeeOption(
        id: '9',
        label: '50103, USGA, Red, Women, SP 9 Holes',
        holes: List.generate(9, (i) => _hole(i + 1)),
      );
      final result = prepareTeesForDisplay([nine, full]);
      expect(result, hasLength(1));
      expect(result.single.id, '18');
    });
  });
}
