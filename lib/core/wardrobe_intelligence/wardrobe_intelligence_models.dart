import '../../models/garment.dart';

enum WardrobeInsightType { dominant, gap, duplicate, imbalance, usage }

enum WardrobeInsightSeverity { info, recommendation, warning }

/// A machine-readable observation that consumers may render in their own way.
class WardrobeInsight {
  final String code;
  final WardrobeInsightType type;
  final WardrobeInsightSeverity severity;
  final String title;
  final String message;
  final Map<String, Object?> evidence;
  final List<String> garmentIds;

  const WardrobeInsight({
    required this.code,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.evidence = const {},
    this.garmentIds = const [],
  });
}

class WardrobeDistribution {
  final int knownCount;
  final int unknownCount;
  final Map<String, int> counts;

  const WardrobeDistribution({
    required this.knownCount,
    required this.unknownCount,
    required this.counts,
  });

  double shareOf(String value) => knownCount == 0
      ? 0
      : (counts[value] ?? 0) / knownCount;
}

class WardrobeDuplicateGroup {
  final String role;
  final List<Garment> garments;

  const WardrobeDuplicateGroup({required this.role, required this.garments});
}

class WardrobeGap {
  final String code;
  final String label;
  final String explanation;
  final double impact;
  final Map<String, Object?> evidence;

  const WardrobeGap({
    required this.code,
    required this.label,
    required this.explanation,
    required this.impact,
    this.evidence = const {},
  });
}

class WardrobeBalanceComponent {
  final String code;
  final String label;
  final double score;
  final double weight;
  final String explanation;

  const WardrobeBalanceComponent({
    required this.code,
    required this.label,
    required this.score,
    required this.weight,
    required this.explanation,
  });
}

class WardrobeBalanceScore {
  final double value;
  final List<WardrobeBalanceComponent> components;

  const WardrobeBalanceScore({required this.value, required this.components});
}

/// Immutable result shared by assistants, recommendations and future features.
class WardrobeIntelligenceReport {
  final DateTime generatedAt;
  final int garmentCount;
  final WardrobeDistribution categories;
  final WardrobeDistribution colors;
  final WardrobeDistribution styles;
  final WardrobeDistribution seasons;
  final WardrobeDistribution materials;
  final List<Garment> underusedGarments;
  final List<WardrobeDuplicateGroup> duplicateGroups;
  final List<WardrobeGap> gaps;
  final WardrobeBalanceScore balance;
  final List<WardrobeInsight> insights;

  const WardrobeIntelligenceReport({
    required this.generatedAt,
    required this.garmentCount,
    required this.categories,
    required this.colors,
    required this.styles,
    required this.seasons,
    required this.materials,
    required this.underusedGarments,
    required this.duplicateGroups,
    required this.gaps,
    required this.balance,
    required this.insights,
  });
}
