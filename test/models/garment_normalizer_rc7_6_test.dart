import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/models/garment_normalizer.dart';

void main() {
  group('RC7.6 text normalization', () {
    test('normalizes whitespace and classification casing from every source', () {
      expect(GarmentNormalizer.classification('  bleu   marine '), 'Bleu marine');
      expect(GarmentNormalizer.classification('trench'), 'Trench');
    });

    test('deduplicates without case differences', () {
      expect(GarmentNormalizer.values(['Trench', ' trench ', 'TRENCH']), ['Trench']);
    });

    test('preserves acronyms and intentional brand casing', () {
      expect(GarmentNormalizer.brand('COS'), 'COS');
      expect(GarmentNormalizer.brand('iBlues'), 'iBlues');
      expect(GarmentNormalizer.brand('RALPH LAUREN'), 'Ralph Lauren');
    });

    test('does not alter composition semantics', () {
      expect(GarmentNormalizer.composition('  80% Coton   20% PA '), '80% Coton 20% PA');
    });

    test('keeps an unknown subcategory instead of returning null', () {
      expect(GarmentNormalizer.normalizeType(category: 'Vestes', subcategory: 'Mac long').subcategory, 'Mac long');
    });
  });
}
