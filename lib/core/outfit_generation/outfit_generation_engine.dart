import '../../models/garment.dart';
import '../../models/outfit.dart';
import '../recommendation/recommendation_context.dart';
import '../recommendation/recommendation_engine.dart';

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

  const OutfitGenerationProposal({required this.outfit, required this.score, required this.reasons});
}

class OutfitGenerationResult {
  final List<OutfitGenerationProposal> proposals;
  const OutfitGenerationResult._(this.proposals);
}

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

    final scored = generated.map((outfit) => _score(outfit, request)).toList()
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0 ? score : _signature(a.outfit).compareTo(_signature(b.outfit));
      });
    return OutfitGenerationResult._(List.unmodifiable(scored));
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
    final thermal = average('température');
    final layering = average('superposition');
    final formality = average('formalité');
    final diversity = (outfit.garments.length / 5).clamp(0, 1).toDouble();
    final rotation = items.isEmpty
        ? 0.0
        : items.map((item) => 1 / (1 + item.wearCount)).reduce((a, b) => a + b) / items.length;
    final score = style * .25 + thermal * .20 + layering * .15 + formality * .15 +
        diversity * .10 + rotation * .15;
    final reasons = <String>[
      if (thermal >= .7) 'Bonne compatibilité thermique.',
      if (style >= .7) 'Couleurs et styles harmonieux.',
      if (layering >= .7) 'Couches compatibles entre elles.',
      if (formality >= .7 && request.context.desiredStyle != null)
        'Adapté au registre ${request.context.desiredStyle}.',
      if (rotation >= .7) 'La sélection privilégie des pièces rarement portées.',
      if (diversity >= .6) 'La tenue combine des catégories complémentaires.',
    ];
    if (reasons.isEmpty) reasons.add('Meilleur équilibre disponible dans le dressing actuel.');
    final criterion = OutfitScore(
      styleCoherence: OutfitCriterionScore(value: style, explanation: 'Cohérence des styles et couleurs.'),
      weatherSuitability: OutfitCriterionScore(value: thermal, explanation: 'Compatibilité avec la météo disponible.'),
      temperatureSuitability: OutfitCriterionScore(value: thermal, explanation: 'Compatibilité thermique des profils calculés.'),
      formality: OutfitCriterionScore(value: formality, explanation: 'Cohérence des niveaux de formalité.'),
      diversity: OutfitCriterionScore(value: diversity, explanation: 'Diversité des catégories sélectionnées.'),
      overallConfidence: OutfitCriterionScore(value: score.clamp(0, 1).toDouble(), explanation: 'Score pondéré global incluant superposition et rotation.'),
    );
    return OutfitGenerationProposal(
      outfit: outfit.copyWith(score: criterion, justification: List.unmodifiable(reasons)),
      score: score,
      reasons: List.unmodifiable(reasons),
    );
  }

  static OutfitCategory categoryFor(Garment garment) {
    final value = '${garment.category} ${garment.sousCategorie ?? ''} ${garment.effectiveThermalProfile.primaryRole.name}'.toLowerCase();
    if (value.contains('chauss') || value.contains('basket') || value.contains('botte')) return OutfitCategory.shoes;
    if (value.contains('pantal') || value.contains('jupe') || value.contains('short') || value.contains('bas')) return OutfitCategory.bottom;
    if (value.contains('manteau') || value.contains('parka')) return OutfitCategory.coat;
    if (value.contains('veste') || value.contains('blazer')) return OutfitCategory.jacket;
    if (value.contains('sac')) return OutfitCategory.bag;
    if (value.contains('bijou') || value.contains('collier') || value.contains('bracelet')) return OutfitCategory.jewelry;
    if (value.contains('access')) return OutfitCategory.accessory;
    if (value.contains('haut') || value.contains('chemise') || value.contains('pull') || value.contains('t-shirt')) return OutfitCategory.top;
    return OutfitCategory.otherLayer;
  }

  static String _signature(Outfit value) {
    final ids = value.allGarments.map((item) => item.id).toList()..sort();
    return ids.join('|');
  }
  static Map<OutfitCategory, List<Garment>> _freeze(Map<OutfitCategory, List<Garment>> source) =>
      Map.unmodifiable(source.map((key, value) => MapEntry(key, List.unmodifiable(value))));
}
