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
}
