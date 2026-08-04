class GarmentNormalizer {
  const GarmentNormalizer._();

  static const _canonical = <String, String>{
    'bleu nuit': 'Bleu marine',
    'dark blue': 'Bleu marine',
    'navy blue': 'Bleu marine',
    'slim fit': 'Slim',
    'business casual': 'Business casual',
  };

  static String? value(String? input) {
    final trimmed = input?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return _canonical[trimmed.toLowerCase()] ?? trimmed;
  }

  static List<String> values(Iterable<String>? input) {
    final result = <String>[];
    final seen = <String>{};
    for (final item in input ?? const <String>[]) {
      final normalized = value(item);
      if (normalized != null && seen.add(normalized.toLowerCase())) {
        result.add(normalized);
      }
    }
    return List.unmodifiable(result);
  }

  static double? confidence(double? input) =>
      input == null ? null : input.clamp(0.0, 1.0);

  /// Reconciles all type signals without restricting AI values to a catalogue.
  /// An explicit subcategory always wins over inferred text.
  static GarmentTypeNormalization normalizeType({String? name, String? category,
    String? subcategory, String? preciseType}) {
    final explicit = value(subcategory) ?? value(preciseType);
    final evidence = [explicit, preciseType, name, category]
        .whereType<String>().join(' ').toLowerCase();
    String? inferredSubcategory, inferredCategory;
    for (final rule in _typeRules) {
      if (rule.tokens.any(evidence.contains)) {
        inferredSubcategory = rule.subcategory;
        inferredCategory = rule.category;
        break;
      }
    }
    return GarmentTypeNormalization(
      category: inferredCategory ?? value(category),
      subcategory: explicit ?? inferredSubcategory,
      preciseType: value(preciseType) ?? explicit ?? inferredSubcategory,
    );
  }

  static const _typeRules = <_GarmentTypeRule>[
    _GarmentTypeRule(['trench'], 'Vestes', 'Trench'),
    _GarmentTypeRule(['polo'], 'Hauts', 'Polo'),
  ];
}

class GarmentTypeNormalization {
  final String? category, subcategory, preciseType;
  const GarmentTypeNormalization({this.category, this.subcategory, this.preciseType});
}

class _GarmentTypeRule {
  final List<String> tokens;
  final String category, subcategory;
  const _GarmentTypeRule(this.tokens, this.category, this.subcategory);
}
