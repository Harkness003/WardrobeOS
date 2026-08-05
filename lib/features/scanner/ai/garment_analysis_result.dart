import 'dart:convert';

import 'garment_analysis_exception.dart';
import '../conversation/requested_photo.dart';

/// Read-only projection used by Expert UI without duplicating parsing or
/// confidence fallback rules in widgets.
class ReliabilitySummary {
  final double? overallConfidence;
  final Map<String, double> fieldConfidences;
  final Map<String, String> fieldStatuses;
  final Map<String, String> fieldSources;
  final Map<String, String> fieldExplanations;

  const ReliabilitySummary({
    this.overallConfidence,
    this.fieldConfidences = const {},
    this.fieldStatuses = const {},
    this.fieldSources = const {},
    this.fieldExplanations = const {},
  });

  bool get hasDetails =>
      overallConfidence != null ||
      fieldConfidences.isNotEmpty ||
      fieldStatuses.isNotEmpty ||
      fieldSources.isNotEmpty ||
      fieldExplanations.isNotEmpty;
}

class GarmentAnalysisResult {
  final bool isUsableImage;
  final String? rejectionReason;
  final String? suggestedName;
  final String? category;
  final String? preciseType;
  final String? primaryColor;
  final String? material;
  final List<TextileComposition> compositions;
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
  /// Optional expert diagnostics. They stay nullable so historical analyses
  /// and partial provider responses never have to invent evidence.
  final Map<String, String>? fieldStatuses;
  final Map<String, String>? fieldSources;
  final Map<String, Object?>? fieldMetadata;
  final double? overallConfidence;
  final Map<String, Object?>? analysisMetadata;
  final Map<String, String>? fieldExplanations;
  final List<String> warnings;
  final String? styleSummary;
  final List<String> styleStrengths;
  final List<String> styleWeaknesses;
  final List<String> styleAdvice;
  final List<String> compatibleColors;
  final List<String> lessSuitableColors;
  final List<String> compatibleBottoms;
  final List<String> compatibleShoes;
  final List<String> idealOccasions;
  final List<String> discouragedOccasions;
  final String? versatilityExplanation;
  final String? styleVerdict;
  final List<String> analysisLimitations;
  final bool needsMorePhotos;
  final RequestedPhoto? requestedPhoto;

  ReliabilitySummary get reliabilitySummary => ReliabilitySummary(
    overallConfidence: overallConfidence,
    fieldConfidences: fieldConfidences,
    fieldStatuses: fieldStatuses ?? const {},
    fieldSources: fieldSources ?? const {},
    fieldExplanations: fieldExplanations ?? const {},
  );

  const GarmentAnalysisResult({
    required this.isUsableImage,
    this.rejectionReason,
    this.suggestedName,
    this.category,
    this.preciseType,
    this.primaryColor,
    this.material,
    this.compositions = const [],
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
    this.fieldStatuses,
    this.fieldSources,
    this.fieldMetadata,
    this.overallConfidence,
    this.analysisMetadata,
    this.fieldExplanations,
    this.warnings = const [],
    this.styleSummary,
    this.styleStrengths = const [],
    this.styleWeaknesses = const [],
    this.styleAdvice = const [],
    this.compatibleColors = const [],
    this.lessSuitableColors = const [],
    this.compatibleBottoms = const [],
    this.compatibleShoes = const [],
    this.idealOccasions = const [],
    this.discouragedOccasions = const [],
    this.versatilityExplanation,
    this.styleVerdict,
    this.analysisLimitations = const [],
    this.needsMorePhotos = false,
    this.requestedPhoto,
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
    } else if (rawConfidences is List) {
      for (final entry in rawConfidences.whereType<Map>()) {
        final field = entry['field'];
        final confidence = entry['confidence'];
        if (field is String && confidence is num) {
          confidences[field] = confidence.toDouble().clamp(0, 1).toDouble();
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
    Map<String, String>? stringMap(String key) {
      final value = json[key];
      if (value is! Map) return null;
      final result = <String, String>{};
      for (final entry in value.entries) {
        if (entry.key is String && entry.value is String) {
          final text = (entry.value as String).trim();
          if (text.isNotEmpty) result[entry.key as String] = text;
        }
      }
      return result.isEmpty ? null : Map.unmodifiable(result);
    }

    Map<String, Object?>? objectMap(String key) {
      final value = json[key];
      if (value is! Map) return null;
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is String) result[entry.key as String] = entry.value;
      }
      return result.isEmpty ? null : Map.unmodifiable(result);
    }
    final rawRequest = json['requestedPhoto'];
    RequestedPhoto? requestedPhoto;
    if (rawRequest is Map) {
      final instruction = rawRequest['instruction'];
      final reason = rawRequest['reason'];
      final targets = rawRequest['targetFields'];
      if (instruction is String && instruction.trim().isNotEmpty &&
          reason is String && reason.trim().isNotEmpty) {
        requestedPhoto = RequestedPhoto(
          type: RequestedPhotoType.fromWireValue(
            rawRequest['type'] is String ? rawRequest['type'] as String : null,
          ),
          instruction: instruction.trim(),
          reason: reason.trim(),
          targetFields: targets is List
              ? targets.whereType<String>().toList(growable: false)
              : const [],
        );
      }
    }

    return GarmentAnalysisResult(
      isUsableImage: json['isUsableImage'] is bool
          ? json['isUsableImage'] as bool
          : false,
      rejectionReason: text('rejectionReason'),
      suggestedName: text('suggestedName'),
      category: text('category'),
      preciseType: text('preciseType'),
      primaryColor: text('primaryColor'),
      material: text('material'),
      compositions: TextileComposition.fromJsonList(json['compositions']),
      season: text('season'),
      visibleBrand: text('visibleBrand'),
      globalConfidence: json['globalConfidence'] is num
          ? (json['globalConfidence'] as num).toDouble().clamp(0, 1).toDouble()
          : json['overallConfidence'] is num
              ? (json['overallConfidence'] as num).toDouble().clamp(0, 1).toDouble()
              : 0,
      imageQualityConfidence: json['imageQualityConfidence'] is num
          ? (json['imageQualityConfidence'] as num).toDouble().clamp(0, 1).toDouble()
          : 1,
      isBlurry: json['isBlurry'] is bool ? json['isBlurry'] as bool : null,
      isTooDark: json['isTooDark'] is bool ? json['isTooDark'] as bool : null,
      isOverexposed: json['isOverexposed'] is bool ? json['isOverexposed'] as bool : null,
      garmentIsPartiallyHidden: json['garmentIsPartiallyHidden'] is bool ? json['garmentIsPartiallyHidden'] as bool : null,
      garmentIsTooSmall: json['garmentIsTooSmall'] is bool ? json['garmentIsTooSmall'] as bool : null,
      multipleMainGarments: json['multipleMainGarments'] is bool ? json['multipleMainGarments'] as bool : null,
      backgroundIsProblematic: json['backgroundIsProblematic'] is bool ? json['backgroundIsProblematic'] as bool : null,
      imageQualityWarnings: List.unmodifiable(strings('imageQualityWarnings')),
      fieldConfidences: Map.unmodifiable(confidences),
      fieldStatuses: stringMap('fieldStatuses'),
      fieldSources: stringMap('fieldSources'),
      fieldMetadata: objectMap('fieldMetadata'),
      overallConfidence: json['overallConfidence'] is num
          ? (json['overallConfidence'] as num).toDouble().clamp(0, 1).toDouble()
          : null,
      analysisMetadata: objectMap('analysisMetadata'),
      fieldExplanations: stringMap('fieldExplanations'),
      warnings: List.unmodifiable(strings('warnings')),
      styleSummary: text('styleSummary'),
      styleStrengths: List.unmodifiable(strings('styleStrengths')),
      styleWeaknesses: List.unmodifiable(strings('styleWeaknesses')),
      styleAdvice: List.unmodifiable(strings('styleAdvice')),
      compatibleColors: List.unmodifiable(strings('compatibleColors')),
      lessSuitableColors: List.unmodifiable(strings('lessSuitableColors')),
      compatibleBottoms: List.unmodifiable(strings('compatibleBottoms')),
      compatibleShoes: List.unmodifiable(strings('compatibleShoes')),
      idealOccasions: List.unmodifiable(strings('idealOccasions')),
      discouragedOccasions: List.unmodifiable(strings('discouragedOccasions')),
      versatilityExplanation: text('versatilityExplanation'),
      styleVerdict: text('styleVerdict'),
      analysisLimitations: List.unmodifiable(strings('analysisLimitations')),
      needsMorePhotos: json['needsMorePhotos'] == true,
      requestedPhoto: requestedPhoto,
    );
  }

  Map<String, Object?> toJson() => {
    'isUsableImage': isUsableImage,
    'rejectionReason': rejectionReason,
    'suggestedName': suggestedName,
    'category': category,
    'preciseType': preciseType,
    'primaryColor': primaryColor,
    'material': material,
    'compositions': compositions.map((value) => value.toJson()).toList(),
    'season': season,
    'visibleBrand': visibleBrand,
    'globalConfidence': globalConfidence,
    'imageQualityConfidence': imageQualityConfidence,
    'isBlurry': isBlurry,
    'isTooDark': isTooDark,
    'isOverexposed': isOverexposed,
    'garmentIsPartiallyHidden': garmentIsPartiallyHidden,
    'garmentIsTooSmall': garmentIsTooSmall,
    'multipleMainGarments': multipleMainGarments,
    'backgroundIsProblematic': backgroundIsProblematic,
    'imageQualityWarnings': imageQualityWarnings,
    'fieldConfidences': fieldConfidences,
    'fieldStatuses': fieldStatuses,
    'fieldSources': fieldSources,
    'fieldMetadata': fieldMetadata,
    'overallConfidence': overallConfidence,
    'analysisMetadata': analysisMetadata,
    'fieldExplanations': fieldExplanations,
    'warnings': warnings,
    'styleSummary': styleSummary,
    'styleStrengths': styleStrengths,
    'styleWeaknesses': styleWeaknesses,
    'styleAdvice': styleAdvice,
    'compatibleColors': compatibleColors,
    'lessSuitableColors': lessSuitableColors,
    'compatibleBottoms': compatibleBottoms,
    'compatibleShoes': compatibleShoes,
    'idealOccasions': idealOccasions,
    'discouragedOccasions': discouragedOccasions,
    'versatilityExplanation': versatilityExplanation,
    'styleVerdict': styleVerdict,
    'analysisLimitations': analysisLimitations,
    'needsMorePhotos': needsMorePhotos,
    'requestedPhoto': switch (requestedPhoto) {
      final photo? => {
        'type': photo.type.name,
        'instruction': photo.instruction,
        'reason': photo.reason,
        'targetFields': photo.targetFields,
      },
      null => null,
    },
  };

  GarmentAnalysisResult copyWith({
    String? suggestedName,
    String? category,
    String? preciseType,
    String? primaryColor,
    String? material,
    List<TextileComposition>? compositions,
    String? season,
    String? visibleBrand,
    double? globalConfidence,
    Map<String, double>? fieldConfidences,
    Map<String, String>? fieldStatuses,
    Map<String, String>? fieldSources,
    Map<String, Object?>? fieldMetadata,
    double? overallConfidence,
    Map<String, Object?>? analysisMetadata,
    Map<String, String>? fieldExplanations,
    List<String>? warnings,
  }) => GarmentAnalysisResult(
    isUsableImage: isUsableImage, rejectionReason: rejectionReason,
    suggestedName: suggestedName ?? this.suggestedName, category: category ?? this.category,
    preciseType: preciseType ?? this.preciseType,
    primaryColor: primaryColor ?? this.primaryColor,
    material: material ?? this.material, compositions: compositions ?? this.compositions,
    season: season ?? this.season, visibleBrand: visibleBrand ?? this.visibleBrand,
    globalConfidence: globalConfidence ?? this.globalConfidence,
    imageQualityConfidence: imageQualityConfidence, isBlurry: isBlurry,
    isTooDark: isTooDark, isOverexposed: isOverexposed,
    garmentIsPartiallyHidden: garmentIsPartiallyHidden,
    garmentIsTooSmall: garmentIsTooSmall,
    multipleMainGarments: multipleMainGarments,
    backgroundIsProblematic: backgroundIsProblematic,
    imageQualityWarnings: imageQualityWarnings,
    fieldConfidences: fieldConfidences ?? this.fieldConfidences,
    fieldStatuses: fieldStatuses ?? this.fieldStatuses,
    fieldSources: fieldSources ?? this.fieldSources,
    fieldMetadata: fieldMetadata ?? this.fieldMetadata,
    overallConfidence: overallConfidence ?? this.overallConfidence,
    analysisMetadata: analysisMetadata ?? this.analysisMetadata,
    fieldExplanations: fieldExplanations ?? this.fieldExplanations,
    warnings: warnings ?? this.warnings,
    styleSummary: styleSummary, styleStrengths: styleStrengths,
    styleWeaknesses: styleWeaknesses, styleAdvice: styleAdvice,
    compatibleColors: compatibleColors, lessSuitableColors: lessSuitableColors,
    compatibleBottoms: compatibleBottoms, compatibleShoes: compatibleShoes,
    idealOccasions: idealOccasions,
    discouragedOccasions: discouragedOccasions,
    versatilityExplanation: versatilityExplanation, styleVerdict: styleVerdict,
    analysisLimitations: analysisLimitations,
    needsMorePhotos: needsMorePhotos, requestedPhoto: requestedPhoto,
  );
}

class TextileComposition {
  final String section;
  final String material;
  final double? percentage;
  final String source;

  const TextileComposition({required this.section, required this.material, this.percentage, this.source = 'ocr'});

  static List<TextileComposition> fromJsonList(Object? raw) => raw is List
      ? List.unmodifiable(raw.whereType<Map>().map((item) {
          final percentage = item['percentage'];
          return TextileComposition(
            section: item['section'] is String ? item['section'] as String : 'main',
            material: item['material'] is String ? (item['material'] as String).trim() : '',
            percentage: percentage is num ? percentage.toDouble().clamp(0, 100) : null,
            source: item['source'] == 'visual' ? 'visual' : 'ocr',
          );
        }).where((item) => item.material.isNotEmpty))
      : const [];

  Map<String, Object?> toJson() => {'section': section, 'material': material, 'percentage': percentage, 'source': source};
}
