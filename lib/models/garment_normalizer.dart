class GarmentNormalizer {
  const GarmentNormalizer._();

  static const _canonical = <String, String>{
    'bleu nuit': 'Bleu marine',
    'dark blue': 'Bleu marine',
    'navy blue': 'Bleu marine',
    'slim fit': 'Slim',
    'business casual': 'Business casual',
  };

  static String? value(String? input) => classification(input);

  /// Normalizes free classification values at the persistence boundary.
  static String? classification(String? input) {
    final trimmed = input?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed == null || trimmed.isEmpty) return null;
    final canonical = _canonical[trimmed.toLowerCase()];
    if (canonical != null) return canonical;
    if (_isAcronym(trimmed)) return trimmed.toUpperCase();
    final lower = trimmed == trimmed.toUpperCase()
        ? trimmed.toLowerCase()
        : '${trimmed[0].toLowerCase()}${trimmed.substring(1)}';
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  /// Brand names keep intentional mixed casing and short acronyms.
  static String? brand(String? input) {
    final compact = input?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact == null || compact.isEmpty) return null;
    if (_isAcronym(compact) || compact != compact.toUpperCase()) return compact;
    return compact.split(' ').map((word) => word.length <= 3
        ? word
        : '${word[0]}${word.substring(1).toLowerCase()}').join(' ');
  }

  /// Composition is whitespace-normalized only: percentages and fibre names
  /// must never be recased automatically.
  static String? composition(String? input) =>
      input?.trim().replaceAll(RegExp(r'\s+'), ' ').nullIfEmpty;

  static bool _isAcronym(String value) =>
      !value.contains(' ') && value.length <= 5 &&
      RegExp(r'^[A-Z0-9&.+-]+$').hasMatch(value);

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

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
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
