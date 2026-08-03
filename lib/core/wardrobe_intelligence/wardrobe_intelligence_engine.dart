import '../../models/garment.dart';
import '../../models/garment_normalizer.dart';
import 'wardrobe_intelligence_models.dart';
import 'wardrobe_intelligence_rules.dart';

class WardrobeIntelligenceEngine {
  final List<WardrobeGapRule> rules;
  final DateTime Function() _clock;

  WardrobeIntelligenceEngine({
    List<WardrobeGapRule> rules = defaultWardrobeGapRules,
    DateTime Function()? clock,
  }) : rules = List.unmodifiable(rules), _clock = clock ?? DateTime.now;

  WardrobeIntelligenceReport analyze(Iterable<Garment> source) {
    final garments = List<Garment>.unmodifiable(source);
    final categories = _distribution(garments.map((item) => item.category));
    final colors = _distribution(garments.map(
      (item) => item.couleurPrincipale ?? item.color,
    ));
    final styles = _distribution(garments.expand(_styles));
    final seasons = _distribution(garments.expand((item) => item.effectiveSeasons));
    final materials = _distribution(garments.expand(_materials));
    final duplicates = _duplicates(garments);
    final context = WardrobeRuleContext(
      garments: garments,
      categories: categories,
      colors: colors,
      seasons: seasons,
      duplicates: duplicates,
    );
    final gaps = rules.map((rule) => rule.evaluate(context)).whereType<WardrobeGap>().toList(growable: false);
    final underused = _underused(garments);
    final balance = _balance(garments, categories, colors, seasons, gaps, duplicates);
    return WardrobeIntelligenceReport(
      generatedAt: _clock(),
      garmentCount: garments.length,
      categories: categories,
      colors: colors,
      styles: styles,
      seasons: seasons,
      materials: materials,
      underusedGarments: underused,
      duplicateGroups: duplicates,
      gaps: gaps,
      balance: balance,
      insights: _insights(garments, styles, seasons, underused, gaps, duplicates),
    );
  }

  static Iterable<String?> _styles(Garment item) => [
    item.stylePrincipal ?? item.style,
    ...?item.stylesSecondaires,
  ];

  static Iterable<String?> _materials(Garment item) => [
    item.matierePrincipale ?? item.material,
    ...?item.matieresSecondaires,
  ];

  static WardrobeDistribution _distribution(Iterable<String?> values) {
    final counts = <String, int>{};
    var unknown = 0;
    for (final raw in values) {
      final value = GarmentNormalizer.value(raw);
      if (value == null) {
        unknown++;
      } else {
        counts.update(value, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value) != 0
          ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    return WardrobeDistribution(
      knownCount: counts.values.fold(0, (sum, count) => sum + count),
      unknownCount: unknown,
      counts: Map.unmodifiable(Map.fromEntries(sorted)),
    );
  }

  static List<Garment> _underused(List<Garment> garments) {
    if (!garments.any((item) => item.wearCount > 0 || item.lastWorn != null)) return const [];
    final used = garments.where((item) => item.wearCount > 0).map((item) => item.wearCount).toList()..sort();
    final threshold = used.isEmpty ? 0 : used[(used.length - 1) ~/ 4];
    return List.unmodifiable(garments.where((item) => item.wearCount <= threshold));
  }

  static List<WardrobeDuplicateGroup> _duplicates(List<Garment> garments) {
    final groups = <String, List<Garment>>{};
    for (final item in garments) {
      final parts = [item.category, item.sousCategorie, item.typePrecis,
        item.couleurPrincipale ?? item.color, item.stylePrincipal ?? item.style]
          .map(_key).where((value) => value.isNotEmpty).toList();
      if (parts.length < 3) continue;
      groups.putIfAbsent(parts.join('|'), () => []).add(item);
    }
    return List.unmodifiable(groups.entries
        .where((entry) => entry.value.length >= 2)
        .map((entry) => WardrobeDuplicateGroup(
          role: entry.key.replaceAll('|', ' · '),
          garments: List.unmodifiable(entry.value),
        )));
  }

  static WardrobeBalanceScore _balance(
    List<Garment> garments,
    WardrobeDistribution categories,
    WardrobeDistribution colors,
    WardrobeDistribution seasons,
    List<WardrobeGap> gaps,
    List<WardrobeDuplicateGroup> duplicates,
  ) {
    if (garments.isEmpty) return const WardrobeBalanceScore(value: 0, components: []);
    double diversity(WardrobeDistribution value, int target) =>
        (value.counts.length / target).clamp(0, 1);
    final components = <WardrobeBalanceComponent>[
      WardrobeBalanceComponent(code: 'category_diversity', label: 'Diversité des catégories', score: diversity(categories, 6) * 100, weight: .25, explanation: '${categories.counts.length} catégories représentées.'),
      WardrobeBalanceComponent(code: 'color_diversity', label: 'Diversité des couleurs', score: diversity(colors, 5) * 100, weight: .15, explanation: '${colors.counts.length} couleurs représentées.'),
      WardrobeBalanceComponent(code: 'season_coverage', label: 'Couverture saisonnière', score: diversity(seasons, 4) * 100, weight: .25, explanation: '${seasons.counts.length} saisons couvertes sur 4.'),
      WardrobeBalanceComponent(code: 'needs_coverage', label: 'Couverture des besoins', score: (1 - gaps.fold<double>(0, (sum, gap) => sum + gap.impact) / 4).clamp(0, 1) * 100, weight: .25, explanation: '${gaps.length} manque(s) détecté(s).'),
      WardrobeBalanceComponent(code: 'role_redundancy', label: 'Redondance des rôles', score: (1 - duplicates.fold<int>(0, (sum, group) => sum + group.garments.length - 1) / garments.length).clamp(0, 1) * 100, weight: .10, explanation: '${duplicates.length} groupe(s) similaire(s).'),
    ];
    final score = components.fold<double>(0, (sum, item) => sum + item.score * item.weight) /
        components.fold<double>(0, (sum, item) => sum + item.weight);
    return WardrobeBalanceScore(value: double.parse(score.toStringAsFixed(1)), components: List.unmodifiable(components));
  }

  static List<WardrobeInsight> _insights(
    List<Garment> garments,
    WardrobeDistribution styles,
    WardrobeDistribution seasons,
    List<Garment> underused,
    List<WardrobeGap> gaps,
    List<WardrobeDuplicateGroup> duplicates,
  ) {
    final result = <WardrobeInsight>[];
    if (styles.counts.isNotEmpty) {
      final dominant = styles.counts.entries.first;
      if (styles.shareOf(dominant.key) >= .4) result.add(WardrobeInsight(
        code: 'dominant_style', type: WardrobeInsightType.dominant,
        severity: WardrobeInsightSeverity.info, title: 'Style dominant',
        message: 'Votre dressing est principalement ${dominant.key}.',
        evidence: {'style': dominant.key, 'count': dominant.value, 'share': styles.shareOf(dominant.key)},
      ));
    }
    for (final gap in gaps) {
      result.add(WardrobeInsight(code: gap.code, type: WardrobeInsightType.gap,
        severity: gap.impact >= .75 ? WardrobeInsightSeverity.warning : WardrobeInsightSeverity.recommendation,
        title: gap.label, message: gap.explanation, evidence: gap.evidence));
    }
    for (final group in duplicates) {
      result.add(WardrobeInsight(code: 'duplicate_role', type: WardrobeInsightType.duplicate,
        severity: WardrobeInsightSeverity.recommendation, title: 'Rôle en double',
        message: '${group.garments.length} pièces remplissent un rôle très similaire.',
        evidence: {'role': group.role, 'count': group.garments.length},
        garmentIds: group.garments.map((item) => item.id).toList(growable: false)));
    }
    if (underused.isNotEmpty) result.add(WardrobeInsight(
      code: 'underused_items', type: WardrobeInsightType.usage,
      severity: WardrobeInsightSeverity.info, title: 'Pièces peu portées',
      message: '${underused.length} pièce(s) sont peu portées par rapport au dressing.',
      evidence: {'count': underused.length},
      garmentIds: underused.map((item) => item.id).toList(growable: false),
    ));
    final hotWeather = garments.where((item) => item.compatibleChaleur == true).length;
    if (garments.length >= 5 && hotWeather / garments.length < .15) result.add(WardrobeInsight(
      code: 'low_hot_weather_coverage', type: WardrobeInsightType.gap,
      severity: WardrobeInsightSeverity.recommendation, title: 'Fortes chaleurs',
      message: 'Vous disposez de peu de vêtements explicitement adaptés aux fortes chaleurs.',
      evidence: {'count': hotWeather, 'total': garments.length},
    ));
    return List.unmodifiable(result);
  }

  static String _key(String? value) => (value ?? '').trim().toLowerCase();
}
