import 'garment_analysis_result.dart';
import 'garment_confidence.dart';

class GarmentFormValues {
  final String name;
  final String category;
  final String color;
  final String material;
  final String season;
  final String brand;

  const GarmentFormValues({
    required this.name,
    required this.category,
    required this.color,
    required this.material,
    required this.season,
    required this.brand,
  });
}

class GarmentAnalysisMapper {
  final List<String> categories;
  final List<String> colors;
  final List<String> materials;
  final List<String> seasons;

  const GarmentAnalysisMapper({
    required this.categories,
    required this.colors,
    required this.materials,
    required this.seasons,
  });

  GarmentFormValues map(
    GarmentAnalysisResult result, {
    required GarmentFormValues current,
  }) {
    return GarmentFormValues(
      name: _prefer(current.name, _allowed(result, 'suggestedName', result.suggestedName)),
      category:
          current.category.trim().isNotEmpty
              ? current.category
              : _canonical(_allowed(result, 'category', result.category), categories) ?? '',
      color: _prefer(current.color, _canonical(_allowed(result, 'primaryColor', result.primaryColor), colors)),
      material: _prefer(
        current.material,
        _canonical(_allowed(result, 'material', result.material), materials),
      ),
      season:
          current.season.trim().isNotEmpty
              ? current.season
              : _canonical(_allowed(result, 'season', result.season), seasons) ?? '',
      brand: _prefer(current.brand, _allowed(result, 'visibleBrand', result.visibleBrand)),
    );
  }

  String? _allowed(GarmentAnalysisResult result, String field, String? value) {
    final confidence = result.fieldConfidences[field] ?? result.globalConfidence;
    return GarmentConfidence.canApply(field, confidence) ? value : null;
  }

  String _prefer(String current, String? suggestion) =>
      current.trim().isNotEmpty ? current : (suggestion?.trim() ?? '');

  String? _canonical(String? value, List<String> allowed) {
    if (value == null) return null;
    final normalized = _normalize(value);
    for (final candidate in allowed) {
      if (_normalize(candidate) == normalized) return candidate;
    }
    return null;
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u');
}
