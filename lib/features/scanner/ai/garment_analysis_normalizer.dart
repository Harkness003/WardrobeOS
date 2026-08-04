import 'garment_analysis_result.dart';

/// Enforces coherence between the free-form AI name, category and subtype.
class GarmentAnalysisNormalizer {
  const GarmentAnalysisNormalizer();

  static const _types = <String, (String, String)>{
    'pull': ('Hauts', 'Pull'),
    'sweat': ('Hauts', 'Sweat'),
    'cardigan': ('Hauts', 'Cardigan'),
    't-shirt': ('Hauts', 'T-shirt'),
    'polo': ('Hauts', 'Polo'),
    'chemise': ('Chemises', 'Chemise casual'),
    'blouse': ('Chemises', 'Blouse'),
    'manteau': ('Vestes', 'Manteau'),
    'parka': ('Vestes', 'Parka'),
    'doudoune': ('Vestes', 'Doudoune'),
    'blazer': ('Vestes', 'Blazer'),
    'jean': ('Bas', 'Jean'),
    'pantalon': ('Bas', 'Pantalon'),
    'short': ('Bas', 'Short'),
    'jupe': ('Bas', 'Jupe'),
    'baskets': ('Chaussures', 'Baskets'),
    'boots': ('Chaussures', 'Boots'),
    'sandales': ('Chaussures', 'Sandales'),
  };

  GarmentAnalysisResult normalize(GarmentAnalysisResult source) {
    final evidence = '${source.preciseType ?? ''} ${source.suggestedName ?? ''}'.toLowerCase();
    for (final entry in _types.entries) {
      if (RegExp('(^|[^a-zà-ÿ])${RegExp.escape(entry.key)}([^a-zà-ÿ]|\$)', caseSensitive: false).hasMatch(evidence)) {
        return source.copyWith(category: entry.value.$1, preciseType: entry.value.$2);
      }
    }
    return source;
  }
}
