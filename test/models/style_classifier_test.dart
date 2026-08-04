import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/style_analysis.dart';
import 'package:wardrobeos/models/style_classifier.dart';

void main() {
  const classifier = StyleClassifier();

  test('applique les contraintes de cohérence avant la formalité', () {
    final hoodie = classifier.classify(const StyleInput(
      category: 'Hauts', subcategory: 'Sweat à capuche',
      formality: 'Business formel', material: 'Coton'));
    final suitTrousers = classifier.classify(const StyleInput(
      category: 'Bas', subcategory: 'Pantalon de costume',
      construction: 'structuré à pinces'));

    expect(hoodie.register, 'casual');
    expect(hoodie.evidence, contains(contains('Contrainte')));
    expect(suitTrousers.register, 'dressy');
    expect(suitTrousers.secondaryStyles, isNot(contains('streetwear')));
  });

  test('Oxford utilise sous-catégorie, coupe, motif et détails', () {
    final result = classifier.classify(const StyleInput(
      category: 'Chemises', subcategory: 'Chemise Oxford', fit: 'ajustée',
      color: 'Bleu ciel', pattern: 'uni', construction: 'col boutonné'));
    expect(result.register, 'smart_casual');
    expect(result.secondaryStyles, containsAll(['preppy', 'minimalist']));
    expect(result.characteristics, contains('understated'));
  });

  test('recalcule après une entrée pertinente sans rescannage', () {
    final first = classifier.ensureCurrent(const StyleInput(
      category: 'Vestes', subcategory: 'Blazer'), null,
      calculatedAt: DateTime.utc(2026));
    final changed = classifier.ensureCurrent(const StyleInput(
      category: 'Vestes', subcategory: 'Parka', material: 'Gore-Tex'), first,
      calculatedAt: DateTime.utc(2026, 1, 2));
    expect(changed.inputFingerprint, isNot(first.inputFingerprint));
    expect(changed.register, 'technical');
    expect(changed.calculatedAt, DateTime.utc(2026, 1, 2));
  });

  test('une correction utilisateur survit au recalcul des suggestions', () {
    final corrected = classifier.classify(const StyleInput(
      category: 'Chemises', subcategory: 'Oxford')).withUserCorrections(
        register: 'casual', secondaryStyles: const ['preppy']);
    final recomputed = classifier.classify(const StyleInput(
      category: 'Chemises', subcategory: 'Oxford', color: 'Rose'),
      previous: corrected);
    expect(recomputed.register, 'casual');
    expect(recomputed.userSecondaryStyles, ['preppy']);
    expect(recomputed.hasUserCorrections, isTrue);
  });

  test('lit une ancienne fiche et la migre progressivement', () {
    final legacy = Garment.fromMap({
      'id': 'old', 'name': 'Oxford', 'category': 'Chemises',
      'style_principal': 'Smart Casual', 'styles_secondaires': '["Preppy"]',
      'created_at': '2020-01-01T00:00:00Z',
      'updated_at': '2020-01-01T00:00:00Z',
    });
    expect(legacy.styleAnalysis, isNull);
    expect(legacy.effectiveStyleAnalysis.register, 'smart_casual');
    final migrated = legacy.withCurrentStyleAnalysis(
      calculatedAt: DateTime.utc(2026));
    expect(StyleAnalysis.decode(migrated.toMap()['style_analysis']), isNotNull);
  });

  test('sérialise séparément suggestions et choix utilisateur', () {
    final source = classifier.classify(const StyleInput(category: 'Bas'))
        .withUserCorrections(characteristics: const ['retro']);
    final restored = StyleAnalysis.decode(source.encode())!;
    expect(restored.suggestedRegister, source.suggestedRegister);
    expect(restored.characteristics, ['retro']);
  });
}
