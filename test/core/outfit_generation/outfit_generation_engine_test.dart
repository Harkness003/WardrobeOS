import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/outfit_generation/outfit_generation_engine.dart';
import 'package:wardrobeos/core/recommendation/recommendation_context.dart';
import 'package:wardrobeos/models/garment.dart';
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
    standaloneMinC: min, standaloneMaxC: max, layeredMinC: min - contribution, layeredMaxC: max - 1,
    level: ThermalLevel.moderate, insulation: InsulationLevel.medium, thickness: ThicknessLevel.medium,
    thermalContributionC: contribution, breathability: BreathabilityLevel.medium,
    windProtection: wind, rainCompatibility: rain, primaryRole: role,
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
