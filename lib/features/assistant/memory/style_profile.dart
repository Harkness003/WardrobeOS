import 'dart:convert';

class ProbabilisticStyleAnalysis {
  final String value;
  final double confidence;
  final bool userCorrected;
  final DateTime updatedAt;

  const ProbabilisticStyleAnalysis({
    required this.value,
    required this.confidence,
    this.userCorrected = false,
    required this.updatedAt,
  }) : assert(confidence >= 0 && confidence <= 1);

  Map<String, Object?> toJson() => {
    'value': value,
    'confidence': confidence,
    'userCorrected': userCorrected,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ProbabilisticStyleAnalysis.fromJson(Map<String, Object?> json) =>
      ProbabilisticStyleAnalysis(
        value: json['value'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        userCorrected: json['userCorrected'] as bool? ?? false,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// Optional profile data that belongs to the person, not to their wardrobe.
class StyleProfile {
  static const singletonId = 'current_user';

  final String id;
  final List<String> preferredFits;
  final String? preferredFormality;
  final List<String> preferredColors;
  final List<String> avoidedColors;
  final List<String> favoriteStyles;
  final List<String> professionalConstraints;
  final List<String> climateConstraints;
  final bool morphologyConsent;
  final ProbabilisticStyleAnalysis? morphology;
  final bool colorimetryConsent;
  final ProbabilisticStyleAnalysis? colorimetry;
  final DateTime updatedAt;

  const StyleProfile({
    this.id = singletonId,
    this.preferredFits = const [],
    this.preferredFormality,
    this.preferredColors = const [],
    this.avoidedColors = const [],
    this.favoriteStyles = const [],
    this.professionalConstraints = const [],
    this.climateConstraints = const [],
    this.morphologyConsent = false,
    this.morphology,
    this.colorimetryConsent = false,
    this.colorimetry,
    required this.updatedAt,
  }) : assert(morphologyConsent || morphology == null),
       assert(colorimetryConsent || colorimetry == null);

  Map<String, Object?> toMap() => {
    'id': id,
    'preferred_fits': jsonEncode(preferredFits),
    'preferred_formality': preferredFormality,
    'preferred_colors': jsonEncode(preferredColors),
    'avoided_colors': jsonEncode(avoidedColors),
    'favorite_styles': jsonEncode(favoriteStyles),
    'professional_constraints': jsonEncode(professionalConstraints),
    'climate_constraints': jsonEncode(climateConstraints),
    'morphology_consent': morphologyConsent ? 1 : 0,
    'morphology': morphology == null ? null : jsonEncode(morphology!.toJson()),
    'colorimetry_consent': colorimetryConsent ? 1 : 0,
    'colorimetry': colorimetry == null ? null : jsonEncode(colorimetry!.toJson()),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory StyleProfile.fromMap(Map<String, Object?> map) {
    List<String> list(String key) => (jsonDecode(map[key] as String? ?? '[]') as List)
        .map((value) => value.toString()).toList(growable: false);
    ProbabilisticStyleAnalysis? analysis(String key) {
      final value = map[key] as String?;
      if (value == null) return null;
      return ProbabilisticStyleAnalysis.fromJson(
        (jsonDecode(value) as Map).cast<String, Object?>(),
      );
    }
    return StyleProfile(
      id: map['id'] as String,
      preferredFits: list('preferred_fits'),
      preferredFormality: map['preferred_formality'] as String?,
      preferredColors: list('preferred_colors'),
      avoidedColors: list('avoided_colors'),
      favoriteStyles: list('favorite_styles'),
      professionalConstraints: list('professional_constraints'),
      climateConstraints: list('climate_constraints'),
      morphologyConsent: map['morphology_consent'] == 1,
      morphology: analysis('morphology'),
      colorimetryConsent: map['colorimetry_consent'] == 1,
      colorimetry: analysis('colorimetry'),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
