import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/diagnostics/diagnostic_service.dart';
import 'package:wardrobeos/core/outfit_generation/outfit_generation_engine.dart';
import 'package:wardrobeos/core/recommendation/recommendation_context.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/outfit.dart';
import 'package:wardrobeos/models/thermal_profile.dart';

void main() {
  final now = DateTime(2026, 8, 4);
  Garment garment(String id, String category, {int wearCount = 0}) => Garment(
    id: id,
    name: id,
    category: category,
    wearCount: wearCount,
    createdAt: now,
    updatedAt: now,
  );
  OutfitGenerationEngine engine() => OutfitGenerationEngine(clock: () => now);

  ThermalProfile thermal({
    required double min,
    required double max,
    required LayerRole role,
    required double contribution,
    WeatherProtection rain = WeatherProtection.none,
    WeatherProtection wind = WeatherProtection.none,
  }) => ThermalProfile(
    insulation: contribution >= 10 ? InsulationLevel.veryHigh : contribution >= 5 ? InsulationLevel.medium : InsulationLevel.veryLow, thickness: ThicknessLevel.medium, breathability: BreathabilityLevel.medium,
    windProtection: wind, rainProtection: rain, primaryRole: role,
    acceptsUnder: role == LayerRole.outer ? const [LayerRole.base, LayerRole.mid] : const [],
    acceptsOver: role == LayerRole.base ? const [LayerRole.mid, LayerRole.outer] : role == LayerRole.mid ? const [LayerRole.outer] : const [],
    inputFingerprint: 'fixture', calculatedAt: now,
  );

  Garment thermalGarment(String id, String category, ThermalProfile profile) =>
      garment(id, category).copyWith(thermalProfile: profile);

  test('gère un dressing très réduit sans inventer de pièce', () {
    final result = engine().generate(OutfitGenerationRequest(
      wardrobe: [garment('top', 'Hauts')],
      proposalCount: 3,
    ));
    expect(result.proposals, isEmpty);
    expect(result.messages, contains(OutfitGenerationResult.incompleteOutfitMessage));
  });

  test('reconnaît la taxonomie Scanner et les valeurs historiques', () {
    final cases = <String, OutfitCategory>{
      'Chemise': OutfitCategory.top,
      'T-shirt': OutfitCategory.top,
      'Polo': OutfitCategory.top,
      'Jean': OutfitCategory.bottom,
      'Pantalon': OutfitCategory.bottom,
      'Chino': OutfitCategory.bottom,
      'Chaussures': OutfitCategory.shoes,
      'Veste': OutfitCategory.jacket,
      'Manteau': OutfitCategory.coat,
      // Values persisted by older/foreign Scanner responses remain readable.
      'shirt': OutfitCategory.top,
      'pants': OutfitCategory.bottom,
      'shoes': OutfitCategory.shoes,
      'coat': OutfitCategory.coat,
    };
    for (final entry in cases.entries) {
      expect(OutfitGenerationEngine.categoryFor(
        garment(entry.key, 'Autre').copyWith(typePrecis: entry.key),
      ), entry.value, reason: entry.key);
    }
  });

  test('diagnostique les rôles reconnus sans exposer les vêtements', () {
    final result = engine().generate(OutfitGenerationRequest(wardrobe: [
      garment('shirt', 'Chemises'), garment('jean', 'Bas'),
      garment('shoes', 'Chaussures'), garment('unknown', 'Autre'),
    ]));
    expect(result.diagnostic.recognizedByRole[OutfitCategory.top], 1);
    expect(result.diagnostic.recognizedByRole[OutfitCategory.bottom], 1);
    expect(result.diagnostic.recognizedByRole[OutfitCategory.shoes], 1);
    expect(result.diagnostic.recognizedByRole,
      isA<Map<OutfitCategory, int>>());
    expect(result.diagnostic.unclassifiedCount, 1);
    expect(result.diagnostic.topsRecognized, 1);
    expect(result.diagnostic.topsEligible, 1);
    expect(result.diagnostic.topsRejectedBeforeGeneration, 0);
    expect(result.diagnostic.classifications.first.toSafeMap(), {
      'index': 1,
      'categoryRaw': 'Chemises',
      'categoryCanonical': 'chemises',
      'subcategoryCanonical': 'chemise',
      'roleResolved': 'top',
      'availableForOutfit': true,
    });
    expect(result.diagnostic.classifications.first.toSafeMap().keys,
      isNot(contains(anyOf('id', 'name', 'brand', 'photos', 'notes'))));
  });

  test('classe une taxonomie nulle ou partielle sans erreur de type', () {
    final nullable = Garment.fromMap({
      'id': 'nullable', 'name': 'Legacy', 'category': null,
      'sous_categorie': null, 'type_precis': null,
      'created_at': '2025-01-01', 'updated_at': '2025-01-01',
    });
    final unclassified = OutfitGenerationEngine.classificationFor(nullable);
    expect(unclassified.roleResolved, OutfitCategory.otherLayer);
    expect(unclassified.reasonIfUnclassified, 'missingCategory');

    for (final fields in <Map<String, Object?>>[
      {'category': 'Hauts'},
      {'sous_categorie': 'T_SHIRT'},
      {'type_precis': 'shirt'},
    ]) {
      final partial = Garment.fromMap({
        'id': 'partial', 'name': 'Legacy', ...fields,
        'created_at': '2025-01-01', 'updated_at': '2025-01-01',
      });
      expect(OutfitGenerationEngine.categoryFor(partial), OutfitCategory.top,
        reason: fields.toString());
    }
  });

  test('sérialise le diagnostic anonymisé réellement produit', () {
    final diagnostics = DiagnosticService.instance
      ..clear()
      ..setEnabled(true);
    final result = engine().generate(OutfitGenerationRequest(wardrobe: [
      garment('top', 'Hauts'), garment('bottom', 'Bas'),
    ]));
    diagnostics.publish(module: DiagnosticModule.outfits,
      level: AppDiagnosticLevel.success, state: 'Prêt', summary: 'Test',
      source: 'outfit_generation_engine_test', details: {
        'classification': result.diagnostic.classifications
            .map((item) => item.toSafeMap()).toList(growable: false),
      });

    expect(() => jsonDecode(diagnostics.exportReport()), returnsNormally);
    diagnostics.setEnabled(false);
  });

  test('classe comme le Scanner une ligne réellement restaurée', () {
    final restored = Garment.fromMap({
      'id': 'legacy-private-id',
      'name': 'Texte utilisateur non consommé',
      'category': 'AUTRE',
      'sous_categorie': '  T_SHIRT  ',
      'type_precis': 'T_SHIRT',
      'created_at': '2025-01-01T00:00:00.000Z',
      'updated_at': '2025-01-01T00:00:00.000Z',
    });
    final recentlyImported = garment('new', 'Hauts').copyWith(
      sousCategorie: 'T-shirt', typePrecis: 'T-shirt');

    expect(OutfitGenerationEngine.categoryFor(restored), OutfitCategory.top);
    expect(OutfitGenerationEngine.categoryFor(recentlyImported), OutfitCategory.top);
    final result = engine().generate(OutfitGenerationRequest(wardrobe: [
      restored,
      garment('bottom', 'Bas'),
    ]));
    expect(result.diagnostic.topsRecognized, 1);
    expect(result.diagnostic.topsEligible, 1);
    expect(result.diagnostic.topsRejectedBeforeGeneration, 0);
    expect(result.diagnostic.classifications.first.subcategoryRaw, 'T_SHIRT');
    expect(result.diagnostic.classifications.first.subcategoryCanonical, 't-shirt');
  });

  test('génère depuis des lignes DB avec collections et nombres JSON typés', () {
    Map<String, Object?> row(String id, String category, num confidence,
        num styleScore) => {
      'id': id,
      'name': 'Fixture DB',
      'category': category,
      'wear_count': confidence,
      'confiance_globale': confidence,
      'created_at': '2026-08-08T00:00:00.000Z',
      'updated_at': '2026-08-08T00:00:00.000Z',
      'style_analysis': jsonEncode({
        'inputFingerprint': 'fixture',
        'suggestedRegister': 'casual',
        'suggestedCompatibilities': [
          {'styleId': 'casual', 'score': styleScore, 'confidence': confidence,
            'justification': 'fixture'},
        ],
        'calculatedAt': '2026-08-08T00:00:00.000Z',
      }),
      'thermal_profile': jsonEncode({
        'breathability': 'medium',
        'windProtection': 'none',
        'rainProtection': 'none',
        'primaryRole': category == 'Hauts' ? 'base' : 'mid',
        'inputFingerprint': 'fixture',
        'confidence': confidence,
        'calculatedAt': '2026-08-08T00:00:00.000Z',
      }),
    };

    final wardrobe = <Garment>[
      Garment.fromMap(row('db-top', 'Hauts', 1, 1)),
      Garment.fromMap(row('db-bottom', 'Pantalons', .5, .75)),
      Garment.fromMap(row('db-shoes', 'Chaussures', 0, 0)),
    ];
    final result = engine().generate(OutfitGenerationRequest(
      wardrobe: wardrobe,
      proposalCount: 1,
    ));

    expect(result.proposals, hasLength(1));
    expect(result.proposals.single.garmentIds,
      containsAll(<String>['db-top', 'db-bottom', 'db-shoes']));
    expect(result.proposals.single.outfit.garments,
      isA<Map<OutfitCategory, List<Garment>>>());
    expect(result.proposals.single.score, isA<double>());
  });

  test('conserve les identités DB legacy jusque dans la proposition', () {
    Garment restored(String id, String category) => Garment.fromMap({
      'id': id, 'name': 'Legacy', 'category': category,
      'created_at': '2025-01-01T00:00:00.000Z',
      'updated_at': '2025-01-01T00:00:00.000Z',
    });
    const ids = ['legacy-top-id', 'legacy-bottom-id', 'legacy-shoes-id'];
    final result = engine().generate(OutfitGenerationRequest(wardrobe: [
      restored(ids[0], 'Hauts'),
      restored(ids[1], 'Pantalons'),
      restored(ids[2], 'Chaussures'),
    ], proposalCount: 1));

    expect(result.proposals, hasLength(1));
    expect(result.proposals.single.outfit.allGarments.map((item) => item.id),
      containsAll(ids));
  });

  test('couvre les séparateurs legacy sans contains générique', () {
    for (final value in ['tshirt', 't-shirt', 't_shirt', 'polo_shirt']) {
      final restored = Garment.fromMap({
        'id': 'legacy', 'name': 'Sans signal de type', 'category': 'Autre',
        'sous_categorie': value, 'created_at': '2025-01-01',
        'updated_at': '2025-01-01',
      });
      expect(OutfitGenerationEngine.categoryFor(restored), OutfitCategory.top,
        reason: value);
    }
  });

  test('borne la génération pour un dressing important', () {
    final wardrobe = List.generate(300, (index) =>
      garment('item-$index', index.isEven ? 'Hauts' : 'Pantalons'));
    final result = engine().generate(OutfitGenerationRequest(
      wardrobe: wardrobe,
      proposalCount: 5,
    ));
    expect(result.proposals, hasLength(5));
    expect(result.proposals.every((item) => item.outfit.allGarments.length == 2), isTrue);
  });

  test('refuse les tenues à une seule pièce', () {
    final result = engine().generate(OutfitGenerationRequest(
      wardrobe: List.generate(6, (index) => garment('pull-$index', 'Hauts')),
      proposalCount: 4,
    ));
    expect(result.proposals, isEmpty);
    expect(result.messages, contains(OutfitGenerationResult.incompleteOutfitMessage));
  });

  test('accepte une météo absente et fournit des explications', () {
    final result = engine().generate(OutfitGenerationRequest(
      wardrobe: [garment('top', 'Hauts'), garment('bottom', 'Pantalons')],
    ));
    expect(result.proposals.single.reasons, isNotEmpty);
    expect(result.proposals.single.score, inInclusiveRange(0, 1));
    expect(result.proposals.single.garmentIds, ['top', 'bottom']);
    expect(result.proposals.single.garmentIds.toSet(), hasLength(2));
  });

  test('expose les contraintes respectées dans le contrat canonique', () {
    final proposal = engine().generate(OutfitGenerationRequest(
      wardrobe: [garment('top', 'Hauts'), garment('bottom', 'Pantalons')],
      context: const RecommendationContext(
        season: 'Été',
        desiredStyle: 'casual',
        weather: RecommendationWeather(temperature: 22),
      ),
    )).proposals.single;

    expect(proposal.respectedConstraints, containsAll(['Météo', 'Température', 'Style souhaité', 'Saison']));
  });

  test('retourne plusieurs propositions à la demande', () {
    final wardrobe = [
      for (var i = 0; i < 4; i++) garment('top-$i', 'Hauts'),
      for (var i = 0; i < 4; i++) garment('bottom-$i', 'Pantalons'),
    ];
    expect(engine().generate(OutfitGenerationRequest(
      wardrobe: wardrobe,
      proposalCount: 3,
    )).proposals, hasLength(3));
  });

  test('le classement est stable et favorise la rotation', () {
    final wardrobe = [
      garment('often', 'Hauts', wearCount: 20),
      garment('rare', 'Hauts'),
      garment('bottom-a', 'Pantalons'),
      garment('bottom-b', 'Pantalons'),
    ];
    List<String> ranking() => engine().generate(OutfitGenerationRequest(
      wardrobe: wardrobe,
      context: const RecommendationContext(),
      proposalCount: 2,
    )).proposals.map((item) => item.outfit.allGarments.map((g) => g.id).join('|')).toList();
    expect(ranking(), ranking());
    expect(ranking().first, contains('rare'));
  });

  test('rejette le t-shirt seul à 10 °C et favorise le t-shirt à 25 °C', () {
    final tshirt = thermalGarment('tshirt', 'Hauts', thermal(min: 18, max: 30, role: LayerRole.base, contribution: 1.5));
    final bottom = garment('bottom', 'Pantalons');
    final cold = engine().generate(OutfitGenerationRequest(
      wardrobe: [tshirt, bottom],
      context: const RecommendationContext(weather: RecommendationWeather(temperature: 10)),
    )).proposals.single;
    final warm = engine().generate(OutfitGenerationRequest(
      wardrobe: [tshirt, bottom],
      context: const RecommendationContext(weather: RecommendationWeather(temperature: 25)),
    )).proposals.single;
    expect(cold.score, lessThan(warm.score));
  });

  test('superposition pull et trench répond à 10 °C avec pluie et vent', () {
    final top = thermalGarment('tshirt', 'Hauts', thermal(min: 18, max: 30, role: LayerRole.base, contribution: 1.5));
    final pull = thermalGarment('pull', 'Pull', thermal(min: 8, max: 20, role: LayerRole.mid, contribution: 6));
    final trench = thermalGarment('trench', 'Outerwear trench', thermal(
      min: 8, max: 18, role: LayerRole.outer, contribution: 7,
      rain: WeatherProtection.resistant, wind: WeatherProtection.resistant,
    ));
    final proposal = engine().generate(OutfitGenerationRequest(
      wardrobe: [top, pull, trench, garment('bottom', 'Pantalons')],
      context: const RecommendationContext(weather: RecommendationWeather(temperature: 10, isRaining: true, windSpeed: 20)),
    )).proposals.first;
    expect(proposal.score, greaterThan(.65));
    expect(proposal.reasons.join(' '), contains('pluie'));
    expect(proposal.reasons.join(' '), contains('vent'));
  });
}
