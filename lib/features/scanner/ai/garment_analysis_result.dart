import 'dart:convert';

import 'garment_analysis_exception.dart';
import '../conversation/requested_photo.dart';

class GarmentAnalysisResult {
  final bool isUsableImage;
  final String? rejectionReason;
  final String? suggestedName;
  final String? category;
  final String? preciseType;
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

  const GarmentAnalysisResult({
    required this.isUsableImage,
    this.rejectionReason,
    this.suggestedName,
    this.category,
    this.preciseType,
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
      isUsableImage: json['isUsableImage'] as bool,
      rejectionReason: text('rejectionReason'),
      suggestedName: text('suggestedName'),
      category: text('category'),
      preciseType: text('preciseType'),
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
    'requestedPhoto': requestedPhoto == null ? null : {
      'type': requestedPhoto!.type.name,
      'instruction': requestedPhoto!.instruction,
      'reason': requestedPhoto!.reason,
      'targetFields': requestedPhoto!.targetFields,
    },
  };

  GarmentAnalysisResult copyWith({
    String? category,
    String? preciseType,
    String? primaryColor,
    String? material,
    String? season,
    String? visibleBrand,
    double? globalConfidence,
    Map<String, double>? fieldConfidences,
    List<String>? warnings,
  }) => GarmentAnalysisResult(
    isUsableImage: isUsableImage, rejectionReason: rejectionReason,
    suggestedName: suggestedName, category: category,
    preciseType: preciseType ?? this.preciseType,
    primaryColor: primaryColor,
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
