import 'dart:convert';

/// Stable identifiers used by persistence and future style-library screens.
abstract final class StyleTaxonomy {
  static const version = 1;
  static const registers = <String>{
    'casual', 'smart_casual', 'dressy', 'sport', 'technical',
  };
  static const secondaryStyles = <String>{
    'minimalist', 'workwear', 'streetwear', 'preppy', 'vintage', 'rock',
    'outdoor',
  };
  static const characteristics = <String>{
    'understated', 'structured', 'modern', 'retro', 'elegant', 'utility',
  };
}

/// Versioned, explainable stylistic result. AI values and user decisions are
/// deliberately separate: recomputation only replaces the suggestion layer.
class StyleAnalysis {
  static const currentModelVersion = 'style-v1';

  final int taxonomyVersion;
  final String modelVersion;
  final String inputFingerprint;
  final String suggestedRegister;
  final List<String> suggestedSecondaryStyles;
  final List<String> suggestedCharacteristics;
  final String? userRegister;
  final List<String>? userSecondaryStyles;
  final List<String>? userCharacteristics;
  final List<String> evidence;
  final DateTime calculatedAt;
  final bool migratedFromLegacy;

  const StyleAnalysis({
    this.taxonomyVersion = StyleTaxonomy.version,
    this.modelVersion = currentModelVersion,
    required this.inputFingerprint,
    required this.suggestedRegister,
    this.suggestedSecondaryStyles = const [],
    this.suggestedCharacteristics = const [],
    this.userRegister,
    this.userSecondaryStyles,
    this.userCharacteristics,
    this.evidence = const [],
    required this.calculatedAt,
    this.migratedFromLegacy = false,
  });

  String get register => userRegister ?? suggestedRegister;
  List<String> get secondaryStyles =>
      userSecondaryStyles ?? suggestedSecondaryStyles;
  List<String> get characteristics =>
      userCharacteristics ?? suggestedCharacteristics;
  bool get hasUserCorrections => userRegister != null ||
      userSecondaryStyles != null || userCharacteristics != null;

  StyleAnalysis withUserCorrections({String? register,
    List<String>? secondaryStyles, List<String>? characteristics}) =>
      StyleAnalysis(
        taxonomyVersion: taxonomyVersion, modelVersion: modelVersion,
        inputFingerprint: inputFingerprint,
        suggestedRegister: suggestedRegister,
        suggestedSecondaryStyles: suggestedSecondaryStyles,
        suggestedCharacteristics: suggestedCharacteristics,
        userRegister: register ?? userRegister,
        userSecondaryStyles: secondaryStyles ?? userSecondaryStyles,
        userCharacteristics: characteristics ?? userCharacteristics,
        evidence: evidence, calculatedAt: calculatedAt,
        migratedFromLegacy: migratedFromLegacy,
      );

  StyleAnalysis retainCorrectionsFrom(StyleAnalysis? previous) => StyleAnalysis(
    taxonomyVersion: taxonomyVersion, modelVersion: modelVersion,
    inputFingerprint: inputFingerprint, suggestedRegister: suggestedRegister,
    suggestedSecondaryStyles: suggestedSecondaryStyles,
    suggestedCharacteristics: suggestedCharacteristics,
    userRegister: previous?.userRegister,
    userSecondaryStyles: previous?.userSecondaryStyles,
    userCharacteristics: previous?.userCharacteristics,
    evidence: evidence, calculatedAt: calculatedAt,
    migratedFromLegacy: migratedFromLegacy,
  );

  String encode() => jsonEncode({
    'taxonomyVersion': taxonomyVersion, 'modelVersion': modelVersion,
    'inputFingerprint': inputFingerprint,
    'suggestedRegister': suggestedRegister,
    'suggestedSecondaryStyles': suggestedSecondaryStyles,
    'suggestedCharacteristics': suggestedCharacteristics,
    'userRegister': userRegister,
    'userSecondaryStyles': userSecondaryStyles,
    'userCharacteristics': userCharacteristics,
    'evidence': evidence, 'calculatedAt': calculatedAt.toIso8601String(),
    'migratedFromLegacy': migratedFromLegacy,
  });

  static StyleAnalysis? decode(Object? source) {
    if (source is! String || source.isEmpty) return null;
    try {
      final map = jsonDecode(source);
      if (map is! Map) return null;
      List<String> strings(Object? value) => value is List
          ? value.map((e) => e.toString()).toList(growable: false) : const [];
      return StyleAnalysis(
        taxonomyVersion: map['taxonomyVersion'] is int
            ? map['taxonomyVersion'] as int : StyleTaxonomy.version,
        modelVersion: map['modelVersion']?.toString() ?? currentModelVersion,
        inputFingerprint: map['inputFingerprint']?.toString() ?? '',
        suggestedRegister: map['suggestedRegister']?.toString() ?? 'casual',
        suggestedSecondaryStyles: strings(map['suggestedSecondaryStyles']),
        suggestedCharacteristics: strings(map['suggestedCharacteristics']),
        userRegister: map['userRegister']?.toString(),
        userSecondaryStyles: map['userSecondaryStyles'] == null
            ? null : strings(map['userSecondaryStyles']),
        userCharacteristics: map['userCharacteristics'] == null
            ? null : strings(map['userCharacteristics']),
        evidence: strings(map['evidence']),
        calculatedAt: DateTime.tryParse(map['calculatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        migratedFromLegacy: map['migratedFromLegacy'] == true,
      );
    } on FormatException { return null; }
  }
}
