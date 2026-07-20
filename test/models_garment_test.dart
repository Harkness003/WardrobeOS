import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/garment_normalizer.dart';

void main() {
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
      createdAt: now,
      updatedAt: now,
    );
    final restored = Garment.fromMap(garment.toMap());
    expect(restored, garment);
    expect(restored.copyWith(name: 'Nouveau').name, 'Nouveau');
    expect(restored.validate(), isNull);
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

  test('normalizes canonical values, blanks and duplicates', () {
    expect(GarmentNormalizer.value('Dark blue'), 'Bleu marine');
    expect(GarmentNormalizer.value('Slim Fit'), 'Slim');
    expect(
      GarmentNormalizer.values(['Bleu nuit', '', 'dark blue']),
      ['Bleu marine'],
    );
  });
}
