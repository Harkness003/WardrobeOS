import 'dart:convert';

import 'garment_analysis_exception.dart';

class GarmentAnalysisResult {
  final bool isUsableImage;
  final String? rejectionReason;
  final String? suggestedName;
  final String? category;
  final String? primaryColor;
  final String? material;
  final String? season;
  final String? visibleBrand;
  final double globalConfidence;
  final double imageQualityConfidence;
  final bool? isBlurry;
  final bool? isTooDark;
  final bool? isOverexposed;
  final bool? garmentIsPartiallyHidden;
  final bool? garmentIsTooSmall;
  final bool? multipleMainGarments;
  final bool? backgroundIsProblematic;
  final List<String> imageQualityWarnings;
  final Map<String, double> fieldConfidences;
  final List<String> warnings;

  const GarmentAnalysisResult({
    required this.isUsableImage,
    this.rejectionReason,
    this.suggestedName,
    this.category,
    this.primaryColor,
    this.material,
    this.season,
    this.visibleBrand,
    required this.globalConfidence,
    this.imageQualityConfidence = 1,
    this.isBlurry,
    this.isTooDark,
    this.isOverexposed,
    this.garmentIsPartiallyHidden,
    this.garmentIsTooSmall,
    this.multipleMainGarments,
    this.backgroundIsProblematic,
    this.imageQualityWarnings = const [],
    this.fieldConfidences = const {},
    this.warnings = const [],
  });

  factory GarmentAnalysisResult.fromJsonString(String source) {
    try {
      final value = jsonDecode(source);
      if (value is! Map<String, dynamic>) throw const FormatException();
      return GarmentAnalysisResult.fromJson(value);
    } on GarmentAnalysisException {
      rethrow;
    } on FormatException {
      throw const GarmentAnalysisException(
        GarmentAnalysisError.invalidJson,
        'La réponse de l’analyse IA est illisible.',
      );
    }
  }

  factory GarmentAnalysisResult.fromJson(Map<String, dynamic> json) {
    if (json['isUsableImage'] is! bool ||
        json['globalConfidence'] is! num) {
      throw const GarmentAnalysisException(
        GarmentAnalysisError.invalidSchema,
        'La réponse de l’analyse IA est incomplète.',
      );
    }
    String? text(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final confidences = <String, double>{};
    final rawConfidences = json['fieldConfidences'];
    if (rawConfidences is Map) {
      for (final entry in rawConfidences.entries) {
        if (entry.key is String && entry.value is num) {
          confidences[entry.key as String] =
              (entry.value as num).toDouble().clamp(0, 1).toDouble();
        }
      }
    }
    List<String> strings(String key) =>
        json[key] is List
            ? (json[key] as List)
                .whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
            : const [];

    return GarmentAnalysisResult(
      isUsableImage: json['isUsableImage'] as bool,
      rejectionReason: text('rejectionReason'),
      suggestedName: text('suggestedName'),
      category: text('category'),
      primaryColor: text('primaryColor'),
      material: text('material'),
      season: text('season'),
      visibleBrand: text('visibleBrand'),
      globalConfidence:
          (json['globalConfidence'] as num).toDouble().clamp(0, 1).toDouble(),
      imageQualityConfidence: json['imageQualityConfidence'] is num
          ? (json['imageQualityConfidence'] as num).toDouble().clamp(0, 1).toDouble()
          : 1,
      isBlurry: json['isBlurry'] as bool?,
      isTooDark: json['isTooDark'] as bool?,
      isOverexposed: json['isOverexposed'] as bool?,
      garmentIsPartiallyHidden: json['garmentIsPartiallyHidden'] as bool?,
      garmentIsTooSmall: json['garmentIsTooSmall'] as bool?,
      multipleMainGarments: json['multipleMainGarments'] as bool?,
      backgroundIsProblematic: json['backgroundIsProblematic'] as bool?,
      imageQualityWarnings: List.unmodifiable(strings('imageQualityWarnings')),
      fieldConfidences: Map.unmodifiable(confidences),
      warnings: List.unmodifiable(strings('warnings')),
    );
  }

  GarmentAnalysisResult copyWith({
    String? category,
    String? primaryColor,
    String? material,
    String? season,
    String? visibleBrand,
    double? globalConfidence,
    Map<String, double>? fieldConfidences,
    List<String>? warnings,
  }) => GarmentAnalysisResult(
    isUsableImage: isUsableImage, rejectionReason: rejectionReason,
    suggestedName: suggestedName, category: category, primaryColor: primaryColor,
    material: material, season: season, visibleBrand: visibleBrand,
    globalConfidence: globalConfidence ?? this.globalConfidence,
    imageQualityConfidence: imageQualityConfidence, isBlurry: isBlurry,
    isTooDark: isTooDark, isOverexposed: isOverexposed,
    garmentIsPartiallyHidden: garmentIsPartiallyHidden,
    garmentIsTooSmall: garmentIsTooSmall,
    multipleMainGarments: multipleMainGarments,
    backgroundIsProblematic: backgroundIsProblematic,
    imageQualityWarnings: imageQualityWarnings,
    fieldConfidences: fieldConfidences ?? this.fieldConfidences,
    warnings: warnings ?? this.warnings,
  );
}
