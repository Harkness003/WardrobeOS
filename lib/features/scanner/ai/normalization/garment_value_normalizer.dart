class GarmentValueNormalizer {
  final List<String> canonicalValues;
  final Map<String, String> synonyms;
  const GarmentValueNormalizer(this.canonicalValues, {this.synonyms = const {}});

  String? normalize(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final key = comparisonKey(value);
    final synonym = synonyms[key];
    if (synonym != null && canonicalValues.contains(synonym)) return synonym;
    for (final candidate in canonicalValues) {
      if (comparisonKey(candidate) == key) return candidate;
    }
    return null;
  }

  List<String> normalizeList(Iterable<String>? values) {
    final output = <String>[];
    final seen = <String>{};
    for (final value in values ?? const <String>[]) {
      final normalized = normalize(value);
      if (normalized != null && seen.add(comparisonKey(normalized))) output.add(normalized);
    }
    return List.unmodifiable(output);
  }

  static String comparisonKey(String value) => value
      .trim().toLowerCase().replaceAll(RegExp(r'[-_]+'), ' ').replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp('[éèêë]'), 'e').replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i').replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u').replaceAll('ç', 'c');
}

class WardrobeNormalizers {
  static GarmentValueNormalizer categories(List<String> values) => GarmentValueNormalizer(values, synonyms: const {'shirt': 'Chemises', 'chemise': 'Chemises', 'top': 'Hauts', 'shoe': 'Chaussures', 'shoes': 'Chaussures', 'pants': 'Bas', 'trousers': 'Bas'});
  static GarmentValueNormalizer colors(List<String> values) => GarmentValueNormalizer(values, synonyms: const {'navy': 'Bleu marine', 'navy blue': 'Bleu marine', 'dark blue': 'Bleu marine', 'bleu nuit': 'Bleu marine', 'bleu fonce': 'Bleu marine', 'off white': 'Écru', 'cream': 'Écru', 'ecru': 'Écru'});
  static GarmentValueNormalizer materials(List<String> values) => GarmentValueNormalizer(values, synonyms: const {'cotton': 'Coton', 'wool': 'Laine', 'leather': 'Cuir', 'linen': 'Lin', 'silk': 'Soie'});
  static GarmentValueNormalizer fits(List<String> values) => GarmentValueNormalizer(values, synonyms: const {'slim fit': 'Slim', 'fitted': 'Slim', 'ajuste': 'Slim', 'regular fit': 'Regular', 'loose fit': 'Relaxed'});
  static GarmentValueNormalizer styles(List<String> values) => GarmentValueNormalizer(values, synonyms: const {'business casual': 'Smart casual', 'business-casual': 'Smart casual', 'casual chic': 'Smart casual'});
}
