import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/scanner/ai/garment_analysis_mapper.dart';
import 'package:wardrobeos/features/scanner/ai/garment_analysis_result.dart';
import 'package:wardrobeos/models/garment_normalizer.dart';

void main() {
  test('normalise Trench et Polo depuis le nom sans écraser un type explicite', () {
    final trench = GarmentNormalizer.normalizeType(name: 'Trench noir');
    expect((trench.category, trench.subcategory), ('Vestes', 'Trench'));

    final polo = GarmentNormalizer.normalizeType(name: 'Polo bleu');
    expect((polo.category, polo.subcategory), ('Hauts', 'Polo'));

    final explicit = GarmentNormalizer.normalizeType(
      name: 'Trench noir', subcategory: 'Manteau croisé');
    expect(explicit.subcategory, 'Manteau croisé');
  });

  test('les catalogues ouverts conservent couleur et matière inconnues', () {
    const mapper = GarmentAnalysisMapper(
      categories: ['Hauts'], colors: ['Bleu'], materials: ['Coton'],
      seasons: ['Été']);
    final analysis = GarmentAnalysisResult(
      isUsableImage: true,
      suggestedName: 'Polo chiné', category: 'Maille',
      primaryColor: 'Bleu pétrole chiné', material: 'Coton Pima',
      season: 'Mi-saison', globalConfidence: 1,
    );
    final mapped = mapper.map(analysis, current: const GarmentFormValues(
      name: '', category: '', color: '', material: '', season: '', brand: ''));
    expect(mapped.category, 'Maille');
    expect(mapped.color, 'Bleu pétrole chiné');
    expect(mapped.material, 'Coton Pima');
    expect(mapped.season, 'Mi-saison');
  });
}
