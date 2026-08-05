import '../../models/garment.dart';
import '../../models/outfit.dart';
import '../../models/thermal_profile.dart';
import '../recommendation/recommendation_context.dart';
import '../recommendation/recommendation_engine.dart';
import '../../features/styles/style_repository.dart';

/// Immutable input snapshot for outfit generation. StyleAnalysis and thermal
/// profiles are deliberately read through each garment's `effective*` getters,
/// so callers can reuse the profiles already computed by the AI context.
class OutfitGenerationRequest {
  final Iterable<Garment> wardrobe;
  final RecommendationContext context;
  final RecommendationPreferences preferences;
  final Iterable<GarmentRecommendationCorrection> corrections;
  final int proposalCount;

  const OutfitGenerationRequest({
    required this.wardrobe,
    this.context = const RecommendationContext(),
    this.preferences = const RecommendationPreferences(),
    this.corrections = const [],
    this.proposalCount = 3,
  }) : assert(proposalCount >= 0);
}

class OutfitGenerationProposal {
  final Outfit outfit;
  final double score;
  final List<String> reasons;
  final List<String> respectedConstraints;

  const OutfitGenerationProposal({
    required this.outfit,
    required this.score,
    required this.reasons,
    this.respectedConstraints = const [],
  });

  List<Garment> get garments => outfit.allGarments;
  List<String> get garmentIds =>
      List.unmodifiable(garments.map((garment) => garment.id));
}

class OutfitGenerationResult {
  static const incompleteOutfitMessage =
      'Il manque des éléments pour constituer une tenue complète.';

  final List<OutfitGenerationProposal> proposals;
  final List<String> messages;
  const OutfitGenerationResult._(this.proposals, [this.messages = const []]);
}

enum OutfitCompleteness { incomplete, acceptable, recommended }

/// Central, UI-independent two-stage engine: bounded candidate generation,
/// followed by deterministic scoring and explanation.
class OutfitGenerationEngine {
  final RecommendationEngine recommendationEngine;
  final DateTime Function() clock;

  const OutfitGenerationEngine({
    this.recommendationEngine = const RecommendationEngine(),
    this.clock = DateTime.now,
  });

  OutfitGenerationResult generate(OutfitGenerationRequest request) {
    if (request.proposalCount == 0) return const OutfitGenerationResult._([]);
    final wardrobe = request.wardrobe.toList(growable: false);
    if (wardrobe.isEmpty) return const OutfitGenerationResult._([]);

    // Rank each category once. This bounds work to O(n log n), rather than
    // enumerating the Cartesian product (which does not scale to large closets).
    final pools = <OutfitCategory, List<Garment>>{};
    for (final category in OutfitCategory.values) {
      final items = wardrobe.where((item) => categoryFor(item) == category);
      final ranked = recommendationEngine.recommend(
        wardrobe: items,
        context: request.context,
        preferences: request.preferences,
        corrections: request.corrections,
        alternativeCount: request.proposalCount + 2,
      );
      if (ranked.choices.isNotEmpty) {
        pools[category] = ranked.choices.map((item) => item.garment).toList(growable: false);
      }
    }

    final generated = <Outfit>[];
    final signatures = <String>{};
    // Rotating offsets create alternatives without allowing one category with
    // many similar garments to monopolise all proposals.
    for (var offset = 0; offset < request.proposalCount * 3 && generated.length < request.proposalCount; offset++) {
      final selected = <OutfitCategory, List<Garment>>{};
      for (final category in OutfitCategory.values) {
        final pool = pools[category];
        if (pool == null || pool.isEmpty) continue;
        selected[category] = [pool[offset % pool.length]];
      }
      final ids = selected.values.expand((items) => items).map((item) => item.id).toList()..sort();
      if (ids.isEmpty || !signatures.add(ids.join('|'))) continue;
      final now = clock();
      generated.add(Outfit(
        id: 'generated-${now.microsecondsSinceEpoch}-${generated.length}',
        name: generated.isEmpty ? 'Tenue recommandée' : 'Tenue recommandée — ${generated.length + 1}',
        createdAt: now,
        updatedAt: now,
        garments: _freeze(selected),
      ));
    }

    final messages = <String>[];
    final validGenerated = generated.where((outfit) {
      final valid = validateOutfit(outfit) != OutfitCompleteness.incomplete;
      if (!valid && !messages.contains(OutfitGenerationResult.incompleteOutfitMessage)) {
        messages.add(OutfitGenerationResult.incompleteOutfitMessage);
      }
      return valid;
    }).toList(growable: false);
    final scored = validGenerated.map((outfit) => _score(outfit, request)).toList()
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0 ? score : _signature(a.outfit).compareTo(_signature(b.outfit));
      });
    return OutfitGenerationResult._(List.unmodifiable(scored), List.unmodifiable(messages));
  }

  OutfitGenerationProposal _score(Outfit outfit, OutfitGenerationRequest request) {
    final items = outfit.allGarments;
    final details = <String, List<double>>{};
    for (var index = 0; index < items.length; index++) {
      final evaluated = recommendationEngine.recommend(
        wardrobe: [items[index]],
        anchor: index == 0 ? null : items.first,
        context: request.context,
        preferences: request.preferences,
        corrections: request.corrections,
        alternativeCount: 0,
      ).bestChoice;
      for (final detail in evaluated?.details ?? const []) {
        details.putIfAbsent(detail.criterion, () => []).add(detail.score);
      }
    }
    double average(String key, [double fallback = .7]) {
      final values = details[key];
      return values == null || values.isEmpty ? fallback : values.reduce((a, b) => a + b) / values.length;
    }
    final style = (average('style') + average('couleurs')) / 2;
    final thermal = _outfitThermalScore(items, request.context) ?? average('température');
    final layering = average('superposition');
    final formality = average('formalité');
    final diversity = (items.length / 5).clamp(0, 1).toDouble();
    final rotation = items.isEmpty
        ? 0.0
        : items.map((item) => 1 / (1 + item.wearCount)).reduce((a, b) => a + b) / items.length;
    final score = style * .25 + thermal * .20 + layering * .15 + formality * .15 +
        diversity * .10 + rotation * .15;
    final temperature = request.context.weather?.temperature;
    final reasons = <String>[
      if (thermal >= .7 && temperature != null)
        'Choisie car adaptée à ${temperature.round()} °C${request.context.weather?.isRaining == true ? ' avec pluie légère' : ''}.',
      if (request.context.weather?.isRaining == true && items.any((item) => _thermal(item).rainCompatibility != WeatherProtection.none))
        'Ajoutée comme couche extérieure contre la pluie.',
      if ((request.context.weather?.windSpeed ?? 0) >= 15 && items.any((item) => _thermal(item).windProtection != WeatherProtection.none))
        'Ajoutée comme couche extérieure contre le vent.',
      if (thermal >= .7 && request.context.weather == null) 'Bonne compatibilité thermique.',
      if (style >= .7) 'Couleurs et styles harmonieux.',
      if (layering >= .7) 'Couches compatibles entre elles.',
      if (formality >= .7 && request.context.desiredStyle != null)
        'Adapté au registre ${StyleCatalog.displayName(request.context.desiredStyle!)}.',
      if (rotation >= .7) 'La sélection privilégie des pièces rarement portées.',
      if (items.any((item) => item.lastWorn != null) && rotation >= .5)
        'La rotation évite les pièces portées le plus récemment.',
      if (diversity >= .6) 'La tenue combine des catégories complémentaires.',
    ];
    if (reasons.isEmpty) reasons.add('Meilleur équilibre disponible dans le dressing actuel.');
    final criterion = OutfitScore(
      styleCoherence: OutfitCriterionScore(value: style, explanation: 'Cohérence des styles et couleurs.'),
      weatherSuitability: OutfitCriterionScore(value: thermal, explanation: 'Compatibilité avec la météo disponible.'),
      temperatureSuitability: OutfitCriterionScore(value: thermal, explanation: 'Compatibilité thermique des profils calculés.'),
      formality: OutfitCriterionScore(value: formality, explanation: 'Cohérence des niveaux de formalité.'),
      diversity: OutfitCriterionScore(value: diversity, explanation: 'Diversité des catégories sélectionnées.'),
      overallConfidence: OutfitCriterionScore(value: score.clamp(0, 1).toDouble(), explanation: 'Score pondéré global; la rotation reste un critère secondaire.'),
    );
    return OutfitGenerationProposal(
      outfit: outfit.copyWith(score: criterion, justification: List.unmodifiable(reasons)),
      score: score,
      reasons: List.unmodifiable(reasons),
      respectedConstraints: List.unmodifiable([
        if (request.context.weather != null) 'Météo',
        if (request.context.occasion != null) 'Occasion',
        if (request.context.desiredStyle != null) 'Style souhaité',
        if (request.context.weather?.temperature != null) 'Température',
        if (request.context.weather?.isRaining != null) 'Pluie',
        if (items.any((item) => (item.thermalProfile?.primaryRole.name ?? item.layerType ?? '').isNotEmpty)) 'Rôles de couche',
        if (request.preferences.preferredColors.isNotEmpty) 'Couleurs préférées',
        if (request.preferences.preferredStyles.isNotEmpty) 'Styles préférés',
        if (request.preferences.avoidedMaterials.isNotEmpty) 'Matières évitées',
      ]),
    );
  }

  double? _outfitThermalScore(List<Garment> items, RecommendationContext context) {
    final apparent = context.weather?.apparentTemperature;
    if (apparent == null || items.isEmpty) return null;
    final profiles = items.map(_thermal).toList(growable: false);
    final baseMax = profiles.map((p) => p.standaloneMaxC).reduce((a, b) => a > b ? a : b);
    final contribution = profiles.fold<double>(0, (sum, p) => sum + p.thermalContributionC);
    final hasOuter = profiles.any((p) => p.primaryRole == LayerRole.outer);
    final hasMid = profiles.any((p) => p.primaryRole == LayerRole.mid);
    final layeredMin = (24 - contribution - (hasOuter && hasMid ? 1.5 : 0)).clamp(-15, baseMax).toDouble();
    final layeredMax = (baseMax - (profiles.length >= 3 ? 3 : profiles.length == 2 ? 1.5 : 0)).toDouble();
    var score = apparent < layeredMin
        ? 1 - (layeredMin - apparent) / 12
        : apparent > layeredMax
            ? 1 - (apparent - layeredMax) / 10
            : 1.0;
    if (context.weather?.isRaining == true && !profiles.any((p) => p.primaryRole == LayerRole.outer && p.rainCompatibility != WeatherProtection.none)) {
      score = score > .45 ? .45 : score;
    }
    if ((context.weather?.windSpeed ?? 0) >= 15 && !profiles.any((p) => p.primaryRole == LayerRole.outer && p.windProtection != WeatherProtection.none)) {
      score = score > .6 ? .6 : score;
    }
    return score.clamp(0, 1).toDouble();
  }

  static OutfitCompleteness validateOutfit(Outfit outfit) {
    final count = outfit.allGarments.length;
    if (count <= 1) return OutfitCompleteness.incomplete;
    if (count == 2) return OutfitCompleteness.acceptable;
    return OutfitCompleteness.recommended;
  }

  static ThermalProfile _thermal(Garment item) => item.thermalProfile ?? _outfitFallbackThermalProfile;

  static OutfitCategory categoryFor(Garment garment) {
    final value = '${garment.category} ${garment.sousCategorie ?? ''} ${garment.thermalProfile?.primaryRole.name ?? garment.layerType ?? ''}'.toLowerCase();
    if (value.contains('chauss') || value.contains('basket') || value.contains('botte')) return OutfitCategory.shoes;
    if (value.contains('pantal') || value.contains('jupe') || value.contains('short') || value.contains('bas')) return OutfitCategory.bottom;
    if (value.contains('manteau') || value.contains('parka') || value.contains('doudoune')) return OutfitCategory.coat;
    if (value.contains('veste') || value.contains('blazer') || value.contains('trench') || value.contains('outer') || value.contains('outerwear')) return OutfitCategory.jacket;
    if (value.contains('sac')) return OutfitCategory.bag;
    if (value.contains('bijou') || value.contains('collier') || value.contains('bracelet')) return OutfitCategory.jewelry;
    if (value.contains('access')) return OutfitCategory.accessory;
    if (value.contains('haut') || value.contains('top') || value.contains('chemise') || value.contains('pull') || value.contains('polo') || value.contains('t-shirt')) return OutfitCategory.top;
    return OutfitCategory.otherLayer;
  }

  static String _signature(Outfit value) {
    final ids = value.allGarments.map((item) => item.id).toList()..sort();
    return ids.join('|');
  }
  static Map<OutfitCategory, List<Garment>> _freeze(Map<OutfitCategory, List<Garment>> source) =>
      Map.unmodifiable(source.map((key, value) => MapEntry(key, List.unmodifiable(value))));
}

final _outfitFallbackThermalProfile = ThermalProfile(
  standaloneMinC: 12,
  standaloneMaxC: 24,
  layeredMinC: 8,
  layeredMaxC: 22,
  level: ThermalLevel.moderate,
  insulation: InsulationLevel.medium,
  thickness: ThicknessLevel.medium,
  thermalContributionC: 5,
  breathability: BreathabilityLevel.medium,
  windProtection: WeatherProtection.none,
  rainCompatibility: WeatherProtection.none,
  primaryRole: LayerRole.mid,
  inputFingerprint: 'outfit-fallback',
  calculatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  confidence: .3,
);
