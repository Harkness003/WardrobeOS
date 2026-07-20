import 'garment_analysis_result.dart';
import 'normalization/garment_value_normalizer.dart';

class GarmentAnalysisValidationResult {
  final GarmentAnalysisResult analysis;
  final List<String> warnings;
  final Set<String> rejectedFields;
  final List<String> corrections;
  const GarmentAnalysisValidationResult({required this.analysis, required this.warnings, required this.rejectedFields, required this.corrections});
}

class GarmentAnalysisValidator {
  final GarmentValueNormalizer categoryNormalizer;
  final GarmentValueNormalizer colorNormalizer;
  final GarmentValueNormalizer materialNormalizer;
  final GarmentValueNormalizer seasonNormalizer;

  const GarmentAnalysisValidator({required this.categoryNormalizer, required this.colorNormalizer, required this.materialNormalizer, required this.seasonNormalizer});

  GarmentAnalysisValidationResult validate(GarmentAnalysisResult source) {
    final rejected = <String>{};
    final corrections = <String>[];
    String? checked(String field, String? value, GarmentValueNormalizer normalizer) {
      if (value == null || value.trim().isEmpty) return null;
      final normalized = normalizer.normalize(value);
      if (normalized == null) { rejected.add(field); return null; }
      if (normalized != value.trim()) corrections.add('$field normalisé en « $normalized »');
      return normalized;
    }
    final confidences = <String, double>{};
    for (final entry in source.fieldConfidences.entries) {
      final clamped = entry.value.clamp(0, 1).toDouble();
      confidences[entry.key] = clamped;
      if (clamped != entry.value) corrections.add('${entry.key}: confiance ramenée entre 0 et 1');
    }
    final warnings = <String>{...source.warnings, ...source.imageQualityWarnings};
    if (rejected.isNotEmpty) warnings.add('Certaines valeurs inconnues ont été ignorées.');
    final cleaned = source.copyWith(
      category: checked('category', source.category, categoryNormalizer),
      primaryColor: checked('primaryColor', source.primaryColor, colorNormalizer),
      material: checked('material', source.material, materialNormalizer),
      season: checked('season', source.season, seasonNormalizer),
      visibleBrand: source.visibleBrand?.trim().isEmpty == true ? null : source.visibleBrand,
      globalConfidence: source.globalConfidence.clamp(0, 1).toDouble(),
      fieldConfidences: Map.unmodifiable(confidences),
      warnings: List.unmodifiable(warnings),
    );
    return GarmentAnalysisValidationResult(analysis: cleaned, warnings: List.unmodifiable(warnings), rejectedFields: Set.unmodifiable(rejected), corrections: List.unmodifiable(corrections));
  }
}
