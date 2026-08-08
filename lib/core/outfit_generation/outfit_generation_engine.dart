import '../../models/garment.dart';
import '../../models/garment_normalizer.dart';
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
  final Duration contextLoadDuration;

  const OutfitGenerationRequest({
    required this.wardrobe,
    this.context = const RecommendationContext(),
    this.preferences = const RecommendationPreferences(),
    this.corrections = const [],
    this.proposalCount = 3,
    this.contextLoadDuration = Duration.zero,
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
  static const incompleteOutfitMessage = 'Il manque des éléments pour constituer une tenue complète.';

  final List<OutfitGenerationProposal> proposals;
  final List<String> messages;
  final OutfitGenerationDiagnostic diagnostic;
  const OutfitGenerationResult._(this.proposals, this.diagnostic, [this.messages = const []]);
}

enum OutfitGenerationFailure { emptyWardrobe, missingTop, missingBottom, incompatibleCombinations }

enum OutfitGenerationPhase {
  roleClassification,
  candidateConstruction,
  recommendation,
  proposalConstruction,
  diagnosticSerialization,
}

/// Privacy-safe boundary error: callers can locate a failure without exposing
/// garment data or a stack trace.
class OutfitGenerationException implements Exception {
  final OutfitGenerationPhase phase;
  final String exceptionType;
  final int garmentsCount;

  const OutfitGenerationException({required this.phase,
    required this.exceptionType, required this.garmentsCount});
}

class OutfitGenerationDiagnostic {
  final int garmentCount;
  final Set<OutfitCategory> categories;
  final int candidateCount;
  final int producedCount;
  final int rejectedCount;
  final OutfitGenerationFailure? failure;
  final Duration contextLoadDuration;
  final Duration generationDuration;
  final Map<OutfitCategory, int> recognizedByRole;
  final int unclassifiedCount;
  final int topsRecognized;
  final int topsEligible;
  final int topsRejectedBeforeGeneration;
  final List<GarmentClassificationDiagnostic> classifications;

  const OutfitGenerationDiagnostic({required this.garmentCount, required this.categories,
    required this.candidateCount, required this.producedCount, required this.rejectedCount,
    this.failure, this.contextLoadDuration = Duration.zero, required this.generationDuration,
    this.recognizedByRole = const {}, this.unclassifiedCount = 0,
    this.topsRecognized = 0, this.topsEligible = 0,
    this.topsRejectedBeforeGeneration = 0, this.classifications = const []});

  String? get userReason => switch (failure) {
    OutfitGenerationFailure.emptyWardrobe => 'Le dressing est vide.',
    OutfitGenerationFailure.missingTop => 'Aucun haut compatible n’est enregistré.',
    OutfitGenerationFailure.missingBottom => 'Aucun bas compatible n’est enregistré.',
    OutfitGenerationFailure.incompatibleCombinations => 'Toutes les combinaisons disponibles sont incompatibles.',
    null => null,
  };
}

/// Privacy-safe account of the exact taxonomy signals consumed by generation.
/// It deliberately excludes the garment id, name, brand, photos and notes.
class GarmentClassificationDiagnostic {
  final int index;
  final String? categoryRaw;
  final String? categoryCanonical;
  final String? subcategoryRaw;
  final String? subcategoryCanonical;
  final OutfitCategory roleResolved;
  final bool availableForOutfit;
  final String? reasonIfUnclassified;

  const GarmentClassificationDiagnostic({required this.index,
    this.categoryRaw, this.categoryCanonical, this.subcategoryRaw,
    this.subcategoryCanonical, required this.roleResolved,
    required this.availableForOutfit, this.reasonIfUnclassified});

  Map<String, Object?> toSafeMap() => {
    'index': index,
    'categoryRaw': categoryRaw,
    'categoryCanonical': categoryCanonical,
    if (subcategoryRaw != null) 'subcategoryRaw': subcategoryRaw,
    if (subcategoryCanonical != null) 'subcategoryCanonical': subcategoryCanonical,
    'roleResolved': roleResolved.name,
    'availableForOutfit': availableForOutfit,
    if (reasonIfUnclassified != null) 'reasonIfUnclassified': reasonIfUnclassified,
  };
}

enum OutfitCompleteness { incomplete, acceptable, recommended }

enum ThermalVerdict { ideal, tooWarm, tooLight, rainInsufficient, missingOuterLayer, excessiveInsulation }

class OutfitThermalAssessment {
  final double score;
  final ThermalVerdict verdict;
  final double accumulatedInsulation;
  final double accumulatedBreathability;
  final List<String> reasons;
  const OutfitThermalAssessment({required this.score, required this.verdict,
    required this.accumulatedInsulation, required this.accumulatedBreathability,
    required this.reasons});
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
    final tracker = _GenerationPhaseTracker();
    try {
      return _generate(request, tracker);
    } catch (error) {
      if (error is OutfitGenerationException) rethrow;
      throw OutfitGenerationException(phase: tracker.phase,
        exceptionType: error.runtimeType.toString(),
        garmentsCount: tracker.garmentsCount);
    }
  }

  OutfitGenerationResult _generate(OutfitGenerationRequest request,
      _GenerationPhaseTracker tracker) {
    final stopwatch = Stopwatch()..start();
    final wardrobe = request.wardrobe.toList(growable: false);
    tracker.garmentsCount = wardrobe.length;
    final classifications = <GarmentClassificationDiagnostic>[
      for (var index = 0; index < wardrobe.length; index++)
        classificationFor(wardrobe[index], index: index + 1),
    ];
    final availableCategories = classifications
        .where((item) => item.availableForOutfit)
        .map((item) => item.roleResolved).toSet();
    final recognizedByRole = <OutfitCategory, int>{};
    for (final item in classifications.where((item) => item.availableForOutfit)) {
      final role = item.roleResolved;
      recognizedByRole[role] = (recognizedByRole[role] ?? 0) + 1;
    }
    final unclassifiedCount = recognizedByRole[OutfitCategory.otherLayer] ?? 0;
    final topsRecognized = classifications.where((item) =>
      item.roleResolved == OutfitCategory.top).length;
    final topsEligible = classifications.where((item) =>
      item.roleResolved == OutfitCategory.top && item.availableForOutfit).length;
    OutfitGenerationResult failure(OutfitGenerationFailure reason) {
      final diagnostic = OutfitGenerationDiagnostic(garmentCount: wardrobe.length,
        categories: Set.unmodifiable(availableCategories), candidateCount: 0, producedCount: 0,
        rejectedCount: 0, failure: reason, contextLoadDuration: request.contextLoadDuration,
        generationDuration: stopwatch.elapsed,
        recognizedByRole: Map<OutfitCategory, int>.unmodifiable(recognizedByRole),
        unclassifiedCount: unclassifiedCount, topsRecognized: topsRecognized,
        topsEligible: topsEligible,
        topsRejectedBeforeGeneration: topsRecognized - topsEligible,
        classifications: List.unmodifiable(classifications));
      final message = diagnostic.userReason;
      return OutfitGenerationResult._(
        const [], diagnostic, message == null ? const [] : [message]);
    }
    if (wardrobe.isEmpty) { return failure(OutfitGenerationFailure.emptyWardrobe); }
    if (!availableCategories.contains(OutfitCategory.top)) { return failure(OutfitGenerationFailure.missingTop); }
    if (!availableCategories.contains(OutfitCategory.bottom)) { return failure(OutfitGenerationFailure.missingBottom); }
    if (request.proposalCount == 0) {
      return OutfitGenerationResult._(const [],
        OutfitGenerationDiagnostic(garmentCount: wardrobe.length, categories: Set.unmodifiable(availableCategories),
          candidateCount: 0, producedCount: 0, rejectedCount: 0,
          contextLoadDuration: request.contextLoadDuration, generationDuration: stopwatch.elapsed,
          recognizedByRole: Map<OutfitCategory, int>.unmodifiable(recognizedByRole), unclassifiedCount: unclassifiedCount,
          topsRecognized: topsRecognized, topsEligible: topsEligible,
          topsRejectedBeforeGeneration: topsRecognized - topsEligible,
          classifications: List.unmodifiable(classifications)));
    }

    // Rank each category once. This bounds work to O(n log n), rather than
    // enumerating the Cartesian product (which does not scale to large closets).
    tracker.phase = OutfitGenerationPhase.candidateConstruction;
    final pools = <OutfitCategory, List<Garment>>{};
    for (final category in OutfitCategory.values) {
      final items = wardrobe.where((item) => categoryFor(item) == category);
      tracker.phase = OutfitGenerationPhase.recommendation;
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

    tracker.phase = OutfitGenerationPhase.proposalConstruction;
    final generated = <Outfit>[];
    final signatures = <String>{};
    // Rotating offsets create alternatives without allowing one category with
    // many similar garments to monopolise all proposals.
    for (var offset = 0; offset < request.proposalCount * 3 && generated.length < request.proposalCount; offset++) {
      final selected = <OutfitCategory, List<Garment>>{};
      for (final category in OutfitCategory.values) {
        final pool = pools[category];
        if (pool == null || pool.isEmpty) { continue; }
        selected[category] = [pool[offset % pool.length]];
      }
      final ids = selected.values.expand((items) => items).map((item) => item.id).toList()..sort();
      if (ids.isEmpty || !signatures.add(ids.join('|'))) { continue; }
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
    tracker.phase = OutfitGenerationPhase.diagnosticSerialization;
    return OutfitGenerationResult._(List.unmodifiable(scored), OutfitGenerationDiagnostic(
      garmentCount: wardrobe.length, categories: Set.unmodifiable(availableCategories),
      candidateCount: generated.length, producedCount: scored.length,
      rejectedCount: generated.length - scored.length,
      failure: scored.isEmpty ? OutfitGenerationFailure.incompatibleCombinations : null,
      contextLoadDuration: request.contextLoadDuration,
      generationDuration: stopwatch.elapsed,
      recognizedByRole: Map<OutfitCategory, int>.unmodifiable(recognizedByRole),
      unclassifiedCount: unclassifiedCount, topsRecognized: topsRecognized,
      topsEligible: topsEligible,
      topsRejectedBeforeGeneration: topsRecognized - topsEligible,
      classifications: List.unmodifiable(classifications)), List.unmodifiable(messages));
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
    final thermalAssessment = evaluateThermal(items, request.context);
    final thermal = thermalAssessment?.score ?? average('température');
    final layering = average('superposition');
    final formality = average('formalité');
    final diversity = (items.length / 5).clamp(0, 1).toDouble();
    final rotation = items.isEmpty
        ? 0.0
        : items.map((item) => 1 / (1 + item.wearCount)).reduce((a, b) => a + b) / items.length;
    final score = style * .25 + thermal * .20 + layering * .15 + formality * .15 +
        diversity * .10 + rotation * .15;
    final reasons = <String>[
      ...?thermalAssessment?.reasons,
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
    if (reasons.isEmpty) { reasons.add('Meilleur équilibre disponible dans le dressing actuel.'); }
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

  /// Unique decision point for thermal suitability, shared by every caller
  /// including Daily. No garment temperature range is consulted.
  OutfitThermalAssessment? evaluateThermal(List<Garment> items, RecommendationContext context) {
    final apparent = context.weather?.apparentTemperature;
    if (apparent == null || items.isEmpty) { return null; }
    final profiles = items.map(_thermal).toList(growable: false);
    double insulationOf(InsulationLevel value) => const [.25, .55, 1.0, 1.7, 2.5][value.index];
    double breathabilityOf(BreathabilityLevel value) => const [.25, .6, 1.0][value.index];
    final insulation = profiles.fold<double>(0, (sum, p) => sum + insulationOf(p.insulation));
    final breathability = profiles.fold<double>(0, (sum, p) => sum + breathabilityOf(p.breathability)) / profiles.length;
    final hasOuter = profiles.any((p) => p.primaryRole == LayerRole.outer);
    final hasMid = profiles.any((p) => p.primaryRole == LayerRole.mid);
    final activity = (context.metadata['activityLevel'] as num?)?.toDouble() ?? 0;
    final evening = context.metadata['momentOfDay'] == 'evening' ? .2 : 0;
    final target = ((22 - apparent) / 6 + evening - activity * .45).clamp(.25, 5).toDouble();
    final difference = insulation - target;
    var score = (1 - difference.abs() / 3).clamp(0, 1).toDouble();
    var verdict = difference > 1.6 ? ThermalVerdict.excessiveInsulation
        : difference > .7 ? ThermalVerdict.tooWarm
        : difference < -1 ? ThermalVerdict.tooLight : ThermalVerdict.ideal;
    final reasons = <String>[];
    if (hasMid) { reasons.add('La couche intermédiaire apporte l’isolation nécessaire.'); }
    if (hasOuter && (context.weather?.windSpeed ?? 0) >= 15 &&
        profiles.any((p) => p.primaryRole == LayerRole.outer && p.windProtection != WeatherProtection.none)) {
      reasons.add('La couche extérieure protège du vent.');
    }
    if (context.weather?.isRaining == true && !profiles.any((p) =>
        p.primaryRole == LayerRole.outer && p.rainProtection == WeatherProtection.resistant)) {
      verdict = ThermalVerdict.rainInsufficient; score = score.clamp(0, .4).toDouble();
      reasons.add('La pluie n’est pas suffisamment couverte par la couche extérieure.');
    } else if (context.weather?.isRaining == true) {
      reasons.add('La couche extérieure assure la protection contre la pluie.');
    }
    if ((context.weather?.windSpeed ?? 0) >= 20 && !hasOuter) {
      verdict = ThermalVerdict.missingOuterLayer; score = score.clamp(0, .5).toDouble();
      reasons.add('Cette tenue manque d’une couche extérieure contre le vent.');
    }
    if ((context.weather?.humidity ?? 0) >= 75 && apparent >= 20 && breathability < .65) {
      score = (score - .2).clamp(0, 1).toDouble(); reasons.add('La respirabilité cumulée est faible pour cette forte humidité.');
    }
    if (verdict == ThermalVerdict.tooWarm) { reasons.add('Cette tenue est trop chaude pour la température ressentie.'); }
    if (verdict == ThermalVerdict.excessiveInsulation) { reasons.add('L’isolation cumulée est excessive.'); }
    if (verdict == ThermalVerdict.tooLight) { reasons.add('Cette tenue est trop légère : une couche isolante est nécessaire.'); }
    if (verdict == ThermalVerdict.ideal && reasons.isEmpty) { reasons.add('L’isolation et la respirabilité cumulées sont adaptées.'); }
    return OutfitThermalAssessment(score: score, verdict: verdict,
      accumulatedInsulation: insulation, accumulatedBreathability: breathability,
      reasons: List.unmodifiable(reasons));
  }

  static OutfitCompleteness validateOutfit(Outfit outfit) {
    final count = outfit.allGarments.length;
    if (count <= 1) { return OutfitCompleteness.incomplete; }
    if (count == 2) { return OutfitCompleteness.acceptable; }
    return OutfitCompleteness.recommended;
  }

  static ThermalProfile _thermal(Garment item) => item.thermalProfile ?? _outfitFallbackThermalProfile;

  static OutfitCategory categoryFor(Garment garment) {
    return classificationFor(garment).roleResolved;
  }

  static GarmentClassificationDiagnostic classificationFor(Garment garment,
      {int index = 1}) {
    // Persisted taxonomy fields are the source of truth. User-controlled name
    // and thermal/layer metadata must not silently change a garment's role.
    final normalized = GarmentNormalizer.normalizeType(category: garment.category,
      subcategory: garment.sousCategorie, preciseType: garment.typePrecis);
    final category = _taxonomyKey(normalized.category ?? garment.category);
    final subcategory = _taxonomyKey(normalized.subcategory ?? normalized.preciseType);
    final role = _roleForTaxonomy(category) ?? _roleForTaxonomy(subcategory) ??
        OutfitCategory.otherLayer;
    final missing = _taxonomyKey(garment.category) == null &&
        _taxonomyKey(garment.sousCategorie) == null &&
        _taxonomyKey(garment.typePrecis) == null;
    return GarmentClassificationDiagnostic(index: index,
      categoryRaw: _diagnosticValue(garment.category),
      categoryCanonical: category,
      subcategoryRaw: _diagnosticValue(garment.sousCategorie ?? garment.typePrecis),
      subcategoryCanonical: subcategory, roleResolved: role,
      // Garment currently has no lifecycle/availability flag. Consequently the
      // candidate set is exactly the classified wardrobe set.
      availableForOutfit: true,
      reasonIfUnclassified: role == OutfitCategory.otherLayer
          ? (missing ? 'missingCategory' : 'unrecognizedTaxonomy') : null);
  }

  static String? _diagnosticValue(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _taxonomyKey(String? value) {
    final raw = value?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    return raw.replaceAll(RegExp(r'[\s_-]+'), '-');
  }

  static OutfitCategory? _roleForTaxonomy(String? value) => switch (value) {
    'haut' || 'hauts' || 'top' || 'tops' || 'chemise' || 'chemises' ||
    'shirt' || 'shirts' || 't-shirt' || 't-shirts' || 'tshirt' || 'tshirts' ||
    'tee-shirt' || 'polo' || 'polos' || 'polo-shirt' || 'pull' || 'pulls' ||
    'sweater' || 'sweatshirt' || 'hoodie' || 'cardigan' || 'blouse' => OutfitCategory.top,
    'bas' || 'bottom' || 'bottoms' || 'pantalon' || 'pantalons' || 'pants' ||
    'trousers' || 'pantalon-habille' || 'jean' || 'jeans' || 'chino' ||
    'jupe' || 'jupes' || 'short' || 'shorts' => OutfitCategory.bottom,
    'chaussure' || 'chaussures' || 'shoe' || 'shoes' || 'sneaker' ||
    'sneakers' || 'basket' || 'baskets' || 'botte' || 'bottes' || 'boot' ||
    'boots' || 'sandale' || 'sandales' => OutfitCategory.shoes,
    'manteau' || 'manteaux' || 'coat' || 'coats' || 'parka' || 'doudoune' => OutfitCategory.coat,
    'veste' || 'vestes' || 'jacket' || 'jackets' || 'blazer' || 'trench' ||
    'outer' || 'outerwear' => OutfitCategory.jacket,
    'sac' || 'sacs' || 'bag' || 'bags' => OutfitCategory.bag,
    'bijou' || 'bijoux' || 'collier' || 'bracelet' || 'jewelry' => OutfitCategory.jewelry,
    'accessoire' || 'accessoires' || 'accessory' || 'accessories' => OutfitCategory.accessory,
    _ => null,
  };

  static String _signature(Outfit value) {
    final ids = value.allGarments.map((item) => item.id).toList()..sort();
    return ids.join('|');
  }
  static Map<OutfitCategory, List<Garment>> _freeze(Map<OutfitCategory, List<Garment>> source) =>
      Map.unmodifiable(source.map((key, value) => MapEntry(key, List.unmodifiable(value))));
}

class _GenerationPhaseTracker {
  OutfitGenerationPhase phase = OutfitGenerationPhase.roleClassification;
  int garmentsCount = 0;
}

final _outfitFallbackThermalProfile = ThermalProfile(
  insulation: InsulationLevel.low,
  thickness: ThicknessLevel.medium,
  breathability: BreathabilityLevel.medium,
  windProtection: WeatherProtection.none,
  rainProtection: WeatherProtection.none,
  primaryRole: LayerRole.mid,
  inputFingerprint: 'outfit-fallback',
  calculatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  confidence: .3,
);
