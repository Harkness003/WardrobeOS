import '../../models/garment.dart';
import '../../models/outfit.dart';
import '../outfit_generation/outfit_generation_engine.dart';
import '../recommendation/recommendation_context.dart';
import '../recommendation/recommendation_engine.dart';

class OutfitValidation {
  final bool isValid;
  final List<String> issues;

  OutfitValidation({required this.isValid, required Iterable<String> issues})
    : issues = List.unmodifiable(issues);
}

/// Point d'entrée métier unique pour composer, noter, expliquer et décliner
/// des tenues. Les calculs de compatibilité restent délégués au moteur de
/// recommandation existant.
class OutfitEngine {
  final RecommendationEngine recommendationEngine;

  const OutfitEngine({this.recommendationEngine = const RecommendationEngine()});

  Outfit? generateBestOutfit({
    required Iterable<Garment> wardrobe,
    RecommendationContext context = const RecommendationContext(),
  }) {
    final central = OutfitGenerationEngine(recommendationEngine: recommendationEngine).generate(
      OutfitGenerationRequest(wardrobe: wardrobe, context: context, proposalCount: 1),
    );
    if (central.proposals.isNotEmpty) return central.proposals.first.outfit;
    final available = wardrobe.toList(growable: false);
    if (available.isEmpty) return null;
    final selected = <OutfitCategory, List<Garment>>{};
    Garment? anchor;
    for (final category in const [
      OutfitCategory.top,
      OutfitCategory.bottom,
      OutfitCategory.shoes,
      OutfitCategory.jacket,
      OutfitCategory.coat,
      OutfitCategory.bag,
      OutfitCategory.accessory,
      OutfitCategory.jewelry,
      OutfitCategory.otherLayer,
    ]) {
      final pool = available
          .where((item) => categoryFor(item) == category)
          .where((item) => !selected.values.expand((items) => items).contains(item));
      final choice = recommendationEngine
          .recommend(wardrobe: pool, anchor: anchor, context: context, alternativeCount: 0)
          .bestChoice
          ?.garment;
      if (choice != null) {
        selected.putIfAbsent(category, () => []).add(choice);
        anchor ??= choice;
      }
    }
    if (selected.isEmpty) return null;
    final draft = Outfit(
      id: 'generated-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Tenue recommandée',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      garments: _freeze(selected),
    );
    final score = scoreOutfit(draft, context: context);
    return draft.copyWith(score: score, justification: explainOutfit(draft, score: score));
  }

  List<Outfit> generateAlternatives(
    Outfit outfit, {
    required Iterable<Garment> wardrobe,
    RecommendationContext context = const RecommendationContext(),
    int limit = 4,
  }) {
    final variants = <Outfit>[];
    const replaceable = [
      OutfitCategory.shoes,
      OutfitCategory.jacket,
      OutfitCategory.coat,
      OutfitCategory.accessory,
    ];
    for (final category in replaceable) {
      if (variants.length == limit) break;
      final currentIds = outfit.allGarments.map((item) => item.id).toSet();
      final anchor = outfit.allGarments.where((item) => categoryFor(item) != category).firstOrNull;
      final replacement = recommendationEngine
          .recommend(
            wardrobe: wardrobe.where(
              (item) => categoryFor(item) == category && !currentIds.contains(item.id),
            ),
            anchor: anchor,
            context: context,
            alternativeCount: 0,
          )
          .bestChoice
          ?.garment;
      if (replacement == null) continue;
      final items = <OutfitCategory, List<Garment>>{
        for (final entry in outfit.garments.entries) entry.key: [...entry.value],
        category: [replacement],
      };
      var variant = outfit.copyWith(
        name: '${outfit.name} — variante ${_label(category)}',
        garments: _freeze(items),
        updatedAt: DateTime.now(),
      );
      final score = scoreOutfit(variant, context: context);
      variant = variant.copyWith(score: score, justification: explainOutfit(variant, score: score));
      variants.add(variant);
    }
    return List.unmodifiable(variants);
  }

  OutfitScore scoreOutfit(
    Outfit outfit, {
    RecommendationContext context = const RecommendationContext(),
  }) {
    final items = outfit.allGarments;
    final evaluations = <String, List<double>>{};
    for (var index = 0; index < items.length; index++) {
      final anchor = index == 0 ? null : items.first;
      final result = recommendationEngine.recommend(
        wardrobe: [items[index]], anchor: anchor, context: context, alternativeCount: 0,
      );
      for (final detail in result.bestChoice?.details ?? const []) {
        evaluations.putIfAbsent(detail.criterion, () => []).add(detail.score);
      }
    }
    double average(String key, [double fallback = .7]) {
      final values = evaluations[key];
      return values == null || values.isEmpty
          ? fallback
          : values.reduce((a, b) => a + b) / values.length;
    }
    final styles = average('style');
    final colors = average('couleurs');
    final weather = average('température');
    final formality = average('formalité');
    final uniqueCategories = outfit.garments.values.where((items) => items.isNotEmpty).length;
    final diversity = items.isEmpty ? 0.0 : (uniqueCategories / 5).clamp(0, 1).toDouble();
    final confidenceValues = items.map((item) => item.confianceGlobale).whereType<double>();
    final confidence = confidenceValues.isEmpty
        ? .65
        : confidenceValues.reduce((a, b) => a + b) / confidenceValues.length;
    return OutfitScore(
      styleCoherence: OutfitCriterionScore(value: (styles + colors) / 2, explanation: 'Compatibilité moyenne des styles et couleurs.'),
      weatherSuitability: OutfitCriterionScore(value: weather, explanation: 'Compatibilité avec les conditions météo disponibles.'),
      temperatureSuitability: OutfitCriterionScore(value: weather, explanation: 'Respect des plages de température des vêtements.'),
      formality: OutfitCriterionScore(value: formality, explanation: 'Cohérence des niveaux de formalité.'),
      diversity: OutfitCriterionScore(value: diversity, explanation: '$uniqueCategories catégories complémentaires représentées.'),
      overallConfidence: OutfitCriterionScore(value: confidence.clamp(0, 1).toDouble(), explanation: 'Moyenne des confiances issues de l’analyse des vêtements.'),
    );
  }

  List<String> explainOutfit(Outfit outfit, {OutfitScore? score}) {
    final result = score ?? outfit.score ?? scoreOutfit(outfit);
    return List.unmodifiable([
      if (result.styleCoherence.value >= .6) 'Les couleurs et les styles sont harmonieux.',
      if (result.formality.value >= .6) 'Les niveaux de formalité sont cohérents.',
      if (result.temperatureSuitability.value >= .6) 'La température prévue est adaptée.',
      if (result.weatherSuitability.value < .6) 'Certains éléments sont moins adaptés à la météo prévue.',
    ]);
  }

  OutfitValidation validateOutfit(Outfit outfit) {
    final issues = <String>[];
    if (outfit.allGarments.isEmpty) issues.add('La tenue ne contient aucun vêtement.');
    if (outfit.itemsFor(OutfitCategory.top).isEmpty &&
        outfit.itemsFor(OutfitCategory.otherLayer).isEmpty) {
      issues.add('La tenue ne contient ni haut ni autre couche.');
    }
    return OutfitValidation(isValid: issues.isEmpty, issues: issues);
  }

  static OutfitCategory categoryFor(Garment garment) {
    final value = '${garment.category} ${garment.sousCategorie ?? ''} '
        '${garment.effectiveThermalProfile.primaryRole.name}'.toLowerCase();
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

  static Map<OutfitCategory, List<Garment>> _freeze(Map<OutfitCategory, List<Garment>> source) =>
      Map.unmodifiable(source.map((key, value) => MapEntry(key, List.unmodifiable(value))));

  static String _label(OutfitCategory category) => category.name;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
