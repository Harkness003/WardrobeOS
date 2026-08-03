import '../../models/garment.dart';
import 'recommendation_context.dart';
import 'recommendation_result.dart';
import 'recommendation_rotation_policy.dart';
import 'recommendation_weights.dart';

class RecommendationEngine {
  final RecommendationWeights weights;
  final RecommendationRotationPolicy rotationPolicy;

  const RecommendationEngine({
    this.weights = const RecommendationWeights(),
    this.rotationPolicy = const NoRecommendationRotation(),
  });

  RecommendationResult recommend({
    required Iterable<Garment> wardrobe,
    Garment? anchor,
    RecommendationContext context = const RecommendationContext(),
    RecommendationPreferences preferences = const RecommendationPreferences(),
    Iterable<GarmentRecommendationCorrection> corrections = const [],
    int alternativeCount = 3,
  }) {
    assert(alternativeCount >= 0);
    final correctionById = {
      for (final correction in corrections) correction.garmentId: correction,
    };
    final ranked = wardrobe
        .where((garment) => garment.id != anchor?.id)
        .map(
          (garment) => _evaluate(
            garment,
            anchor: anchor,
            context: context,
            preferences: preferences,
            correction: correctionById[garment.id],
            anchorCorrection:
                anchor == null ? null : correctionById[anchor.id],
          ),
        )
        .toList()
      ..sort((left, right) {
        final scoreOrder = right.score.compareTo(left.score);
        return scoreOrder != 0
            ? scoreOrder
            : left.garment.name.compareTo(right.garment.name);
      });
    final choices = ranked.take(alternativeCount + 1).toList();
    return RecommendationResult(
      choices: choices,
      explanation: choices.isEmpty
          ? 'Aucun vêtement disponible ne permet de formuler une recommandation.'
          : 'Les choix sont classés selon leur compatibilité stylistique et le contexte disponible.',
    );
  }

  RankedGarmentRecommendation _evaluate(
    Garment garment, {
    required Garment? anchor,
    required RecommendationContext context,
    required RecommendationPreferences preferences,
    required GarmentRecommendationCorrection? correction,
    required GarmentRecommendationCorrection? anchorCorrection,
  }) {
    final candidate = _Profile(garment, correction);
    final base = anchor == null ? null : _Profile(anchor, anchorCorrection);
    final details = <RecommendationCriterionScore>[
      _detail('style', weights.style, _style(candidate, base, context, preferences)),
      _detail('formalité', weights.formality, _same(candidate.formality, base?.formality)),
      _detail('saison', weights.season, _season(candidate, context)),
      _detail('température', weights.temperature, _temperature(candidate, context)),
      _detail('couleurs', weights.color, _color(candidate, base, preferences)),
      _detail('matières', weights.material, _material(candidate, base, preferences)),
      _detail('superposition', weights.layering, _layering(candidate, base)),
      _detail('occasion', weights.occasion, _occasion(candidate, context)),
    ];
    final weighted = details.fold<double>(
      0,
      (sum, detail) => sum + detail.score * detail.weight,
    );
    final raw = weights.total == 0 ? 0 : weighted / weights.total;
    final adjusted = raw + rotationPolicy.scoreAdjustment(garment, context);
    final score = (adjusted * 100).round().clamp(0, 100).toInt();
    return RankedGarmentRecommendation(
      garment: garment,
      score: score,
      explanation: _explain(candidate, base, context, details, score),
      details: details,
    );
  }

  RecommendationCriterionScore _detail(String name, double weight, double score) =>
      RecommendationCriterionScore(criterion: name, score: score, weight: weight);

  double _style(_Profile item, _Profile? anchor, RecommendationContext context,
      RecommendationPreferences preferences) {
    final desired = _normalize(context.desiredStyle);
    if (desired.isNotEmpty) return item.styles.contains(desired) ? 1 : .35;
    if (anchor != null && item.styles.intersection(anchor.styles).isNotEmpty) return 1;
    if (item.styles.any(preferences.preferredStyles.map(_normalize).contains)) return .85;
    return item.styles.isEmpty ? .65 : .55;
  }

  double _same(String? left, String? right) {
    final a = _normalize(left);
    final b = _normalize(right);
    if (a.isEmpty || b.isEmpty) return .65;
    return a == b ? 1 : .3;
  }

  double _season(_Profile item, RecommendationContext context) {
    final season = _normalize(context.season);
    if (season.isEmpty || item.seasons.isEmpty) return .7;
    return item.seasons.contains(season) ? 1 : .15;
  }

  double _temperature(_Profile item, RecommendationContext context) {
    final temperature = context.weather?.temperature;
    if (temperature == null) return .7;
    if (item.minimumTemperature != null && temperature < item.minimumTemperature!) {
      return (1 - (item.minimumTemperature! - temperature) / 15)
          .clamp(0, 1)
          .toDouble();
    }
    if (item.maximumTemperature != null && temperature > item.maximumTemperature!) {
      return (1 - (temperature - item.maximumTemperature!) / 15)
          .clamp(0, 1)
          .toDouble();
    }
    if (context.weather?.isRaining == true && item.rainCompatible == false) return .2;
    return 1;
  }

  double _color(_Profile item, _Profile? anchor, RecommendationPreferences preferences) {
    if (preferences.preferredColors.map(_normalize).contains(item.color)) return 1;
    if (anchor == null || item.color.isEmpty || anchor.color.isEmpty) return .7;
    if (item.compatibleColors.contains(anchor.color) ||
        anchor.compatibleColors.contains(item.color)) return 1;
    if (item.incompatibleColors.contains(anchor.color)) return .15;
    const neutrals = {'noir', 'blanc', 'gris', 'beige', 'marine', 'bleu marine'};
    return neutrals.contains(item.color) || neutrals.contains(anchor.color) ? .9 : .6;
  }

  double _material(_Profile item, _Profile? anchor, RecommendationPreferences preferences) {
    if (preferences.avoidedMaterials.map(_normalize).contains(item.material)) return 0;
    if (anchor == null || item.material.isEmpty || anchor.material.isEmpty) return .7;
    return item.material == anchor.material ? .85 : .75;
  }

  double _layering(_Profile item, _Profile? anchor) {
    if (anchor == null) return item.layerable == false ? .6 : .8;
    if (item.layerType.isEmpty || anchor.layerType.isEmpty) return .65;
    if (item.layerType == anchor.layerType) return .35;
    return item.layerable == false && anchor.layerable == false ? .35 : 1;
  }

  double _occasion(_Profile item, RecommendationContext context) {
    final occasion = _normalize(context.occasion);
    if (occasion.isEmpty || item.occasions.isEmpty) return .7;
    if (item.discouragedOccasions.contains(occasion)) return 0;
    return item.occasions.contains(occasion) ? 1 : .3;
  }

  String _explain(_Profile item, _Profile? anchor, RecommendationContext context,
      List<RecommendationCriterionScore> details, int score) {
    final temperature = context.weather?.temperature;
    if (temperature != null && item.maximumTemperature != null &&
        temperature > item.maximumTemperature! + 5) {
      return '${item.garment.name} est déconseillé car la température prévue dépasse largement sa plage idéale.';
    }
    if (context.weather?.isRaining == true && item.rainCompatible == false) {
      return '${item.garment.name} est peu conseillé sous la pluie car il n’est pas déclaré compatible.';
    }
    final best = details.reduce((a, b) => a.score > b.score ? a : b);
    if (anchor != null && item.styles.intersection(anchor.styles).isNotEmpty) {
      final style = item.styles.intersection(anchor.styles).first;
      return '${item.garment.name} fonctionne avec ${anchor.garment.name} : ils partagent le registre ${_label(style)} (score $score %).';
    }
    return '${item.garment.name} obtient $score % grâce principalement à sa compatibilité ${best.criterion} avec le contexte disponible.';
  }

  static String _normalize(String? value) => (value ?? '')
      .trim().toLowerCase()
      .replaceAll(RegExp(r'[àáâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  static String _label(String value) => value
      .split(' ')
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class _Profile {
  final Garment garment;
  final GarmentRecommendationCorrection? correction;
  _Profile(this.garment, this.correction);

  Set<String> get styles => {
    correction?.style,
    if (correction?.style == null) garment.stylePrincipal,
    if (correction?.style == null) garment.style,
    if (correction?.style == null) ...?garment.stylesSecondaires,
  }.map(RecommendationEngine._normalize).where((value) => value.isNotEmpty).toSet();
  String? get formality => correction?.formality ?? garment.niveauFormalite;
  Set<String> get seasons => (correction?.seasons ?? garment.effectiveSeasons)
      .map(RecommendationEngine._normalize).toSet();
  Set<String> get occasions => (correction?.occasions ?? garment.effectiveOccasions)
      .map(RecommendationEngine._normalize).toSet();
  String get color => RecommendationEngine._normalize(
      correction?.color ?? garment.couleurPrincipale ?? garment.color);
  String get material => RecommendationEngine._normalize(
      correction?.material ?? garment.matierePrincipale ?? garment.material);
  Set<String> get compatibleColors => (garment.couleursCompatibles ?? const [])
      .map(RecommendationEngine._normalize).toSet();
  Set<String> get incompatibleColors => (garment.couleursMoinsAdaptees ?? const [])
      .map(RecommendationEngine._normalize).toSet();
  Set<String> get discouragedOccasions => (garment.occasionsDeconseillees ?? const [])
      .map(RecommendationEngine._normalize).toSet();
  double? get minimumTemperature => correction?.minimumTemperature ?? garment.temperatureMinimum;
  double? get maximumTemperature => correction?.maximumTemperature ?? garment.temperatureMaximum;
  bool? get rainCompatible => correction?.rainCompatible ?? garment.compatiblePluie;
  bool? get layerable => correction?.layerable ?? garment.superposable;
  String get layerType => RecommendationEngine._normalize(garment.layerType);
}
