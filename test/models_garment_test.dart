import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/garment_normalizer.dart';

void main() {
  test('effectiveOccasions preserves multiple uses and supports legacy data', () {
    final now = DateTime(2026);
    final legacy = Garment(
      id: 'legacy',
      name: 'Chemise',
      category: 'Chemises',
      occasion: 'Travail',
      createdAt: now,
      updatedAt: now,
    );
    final multiple = Garment(
      id: 'multiple',
      name: 'Veste',
      category: 'Vestes',
      occasion: 'Quotidien',
      occasions: const ['Travail', 'Voyage', 'Travail'],
      createdAt: now,
      updatedAt: now,
    );

    expect(legacy.effectiveOccasions, ['Travail']);
    expect(multiple.effectiveOccasions, ['Travail', 'Voyage']);
  });

  final now = DateTime.utc(2026, 7, 20);

  test('supports minimal creation and legacy maps', () {
    final garment = Garment(
      id: 'g1',
      name: 'Chemise',
      category: 'Chemises',
      createdAt: now,
      updatedAt: now,
    );
    expect(Garment.fromMap(garment.toMap()), garment);
    expect(garment.validate(), isNull);
  });

  test('uses multiple seasons and falls back to the legacy season', () {
    final legacy = Garment.fromMap({
      'id': 'legacy',
      'name': 'Manteau',
      'category': 'Vestes',
      'season': 'Hiver',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    expect(legacy.effectiveSeasons, ['Hiver']);
    expect(legacy.saisons, ['Hiver']);

    final garment = legacy.copyWith(
      saisons: const ['Automne', 'Hiver', 'Hiver'],
    );
    expect(garment.effectiveSeasons, ['Automne', 'Hiver']);
    expect(
      jsonDecode(garment.toMap()['saisons']! as String),
      ['Automne', 'Hiver'],
    );
  });

  test('serializes, copies and compares every rich field', () {
    final garment = Garment(
      id: 'g1',
      name: 'Veste',
      category: 'Vestes',
      sousCategorie: 'Blazer',
      typePrecis: 'Blazer croisé',
      descriptionIA: 'Veste structurée',
      couleurPrincipale: 'Bleu marine',
      couleursSecondaires: const ['Blanc'],
      motif: 'Rayures',
      texture: 'Lisse',
      logoVisible: false,
      stylePrincipal: 'Business casual',
      stylesSecondaires: const ['Élégant'],
      niveauFormalite: 'Formel',
      coupe: 'Slim',
      longueur: 'Standard',
      longueurManches: 'Longues',
      typeCol: 'Revers',
      typeFermeture: 'Boutons',
      matierePrincipale: 'Laine',
      matieresSecondaires: const ['Soie'],
      confianceMatiere: .8,
      saisons: const ['Automne', 'Hiver'],
      occasions: const ['Travail'],
      temperatureMinimum: 3,
      temperatureMaximum: 18,
      compatiblePluie: false,
      compatibleChaleur: false,
      superposable: true,
      etatVisuel: 'Excellent',
      usureVisible: 'Aucune',
      defautsVisibles: const [],
      confianceGlobale: .9,
      avertissementsIA: const ['Matière à confirmer'],
      resumeStylistique: 'Un blazer formel et structuré.',
      pointsForts: const ['Coupe nette'],
      pointsFaibles: const ['Peu décontracté'],
      conseils: const ['Associer à une chemise claire'],
      verdict: 'Une pièce forte pour le bureau.',
      couleursCompatibles: const ['Écru', 'Marine'],
      couleursMoinsAdaptees: const ['Orange vif'],
      basCompatibles: const ['Pantalon droit'],
      chaussuresCompatibles: const ['Derbies'],
      explicationPolyvalence: 'Polyvalence moyenne.',
      occasionsDeconseillees: const ['Sport'],
      compositionEstimee: 'Laine majoritaire, doublure synthétique',
      lavage: 'Nettoyage professionnel recommandé',
      sechage: 'Séchage sur cintre',
      repassage: 'Fer doux avec pattemouille',
      nettoyage: 'Nettoyage à sec',
      boulochage: 'Léger aux poignets',
      taches: 'Aucune visible',
      limitesAnalyse: const ['Étiquette non visible'],
      createdAt: now,
      updatedAt: now,
    );
    final restored = Garment.fromMap(garment.toMap());
    expect(restored, garment);
    expect(restored.copyWith(name: 'Nouveau').name, 'Nouveau');
    expect(restored.validate(), isNull);
    expect(restored.resumeStylistique, contains('formel'));
    expect(restored.limitesAnalyse, ['Étiquette non visible']);
    expect(restored.couleursCompatibles, ['Écru', 'Marine']);
    expect(restored.explicationPolyvalence, 'Polyvalence moyenne.');
  });

  test('validates temperatures and confidence', () {
    final invalid = Garment(
      id: 'g',
      name: 'Test',
      category: 'Autre',
      temperatureMinimum: 20,
      temperatureMaximum: 10,
      confianceGlobale: 2,
      createdAt: now,
      updatedAt: now,
    );
    expect(invalid.validate(), isNotNull);
  });

  test('preserves null and empty stylistic association values', () {
    final garment = Garment(
      id: 'empty',
      name: 'Pièce',
      category: 'Autre',
      couleursCompatibles: const [],
      couleursMoinsAdaptees: null,
      basCompatibles: const [],
      chaussuresCompatibles: null,
      createdAt: now,
      updatedAt: now,
    );

    final restored = Garment.fromMap(garment.toMap());
    expect(restored.couleursCompatibles, isEmpty);
    expect(restored.couleursMoinsAdaptees, isNull);
    expect(restored.basCompatibles, isEmpty);
    expect(restored.chaussuresCompatibles, isNull);
  });

  test('normalizes canonical values, blanks and duplicates', () {
    expect(GarmentNormalizer.value('Dark blue'), 'Bleu marine');
    expect(GarmentNormalizer.value('Slim Fit'), 'Slim');
    expect(
      GarmentNormalizer.values(['Bleu nuit', '', 'dark blue']),
      ['Bleu marine'],
    );
  });
}
