import 'dart:convert';

enum InsulationLevel { veryLow, low, medium, high, veryHigh }
enum ThicknessLevel { light, medium, thick, veryThick }
enum BreathabilityLevel { low, medium, high }
enum WeatherProtection { none, limited, resistant }
enum DryingSpeed { slow, medium, fast }
enum LayerRole { base, mid, outer }
enum CoverageLevel { low, medium, high }
enum GarmentWeight { light, medium, heavy }
enum OpeningType { open, partial, closed }

/// Description physique d'une pièce. Elle ne porte volontairement aucune
/// température : seul l'ensemble porté peut être évalué face à la météo.
class ThermalProfile {
  static const currentModelVersion = 3;

  final InsulationLevel insulation;
  final ThicknessLevel thickness;
  final BreathabilityLevel breathability;
  final WeatherProtection windProtection;
  final WeatherProtection rainProtection;
  final WeatherProtection moistureResistance;
  final DryingSpeed dryingSpeed;
  final LayerRole primaryRole;
  final CoverageLevel coverage;
  final GarmentWeight weight;
  final OpeningType opening;
  final List<LayerRole> acceptsUnder;
  final List<LayerRole> acceptsOver;
  final int modelVersion;
  final String inputFingerprint;
  final DateTime calculatedAt;
  final double confidence;
  final Map<String, Object?> extensions;

  const ThermalProfile({
    this.insulation = InsulationLevel.medium,
    this.thickness = ThicknessLevel.medium,
    required this.breathability,
    required this.windProtection,
    required this.rainProtection,
    this.moistureResistance = WeatherProtection.limited,
    this.dryingSpeed = DryingSpeed.medium,
    required this.primaryRole,
    this.coverage = CoverageLevel.medium,
    this.weight = GarmentWeight.medium,
    this.opening = OpeningType.closed,
    this.acceptsUnder = const [],
    this.acceptsOver = const [],
    this.modelVersion = currentModelVersion,
    required this.inputFingerprint,
    required this.calculatedAt,
    this.confidence = .65,
    this.extensions = const {},
  }) : assert(confidence >= 0 && confidence <= 1);

  /// Compatibility name for persisted/UI callers; it is a physical property.
  WeatherProtection get rainCompatibility => rainProtection;

  bool isCurrentFor(String fingerprint) =>
      modelVersion == currentModelVersion && inputFingerprint == fingerprint;

  Map<String, Object?> toJson() => {
    'insulation': insulation.name,
    'thickness': thickness.name,
    'breathability': breathability.name,
    'windProtection': windProtection.name,
    'rainProtection': rainProtection.name,
    'moistureResistance': moistureResistance.name,
    'dryingSpeed': dryingSpeed.name,
    'primaryRole': primaryRole.name,
    'coverage': coverage.name,
    'weight': weight.name,
    'opening': opening.name,
    'acceptsUnder': acceptsUnder.map((value) => value.name).toList(),
    'acceptsOver': acceptsOver.map((value) => value.name).toList(),
    'modelVersion': modelVersion,
    'inputFingerprint': inputFingerprint,
    'calculatedAt': calculatedAt.toIso8601String(),
    'confidence': confidence,
    'extensions': extensions,
  };

  String encode() => jsonEncode(toJson());

  /// Legacy temperature fields are consumed only here, while migrating v1/v2
  /// records to physical insulation. They never enter runtime decisions.
  static ThermalProfile? decode(Object? source) {
    if (source == null) return null;
    try {
      final value = source is String ? jsonDecode(source) : source;
      if (value is! Map) return null;
      final map = Map<String, Object?>.from(value);
      T enumValue<T extends Enum>(List<T> values, String key, T fallback) =>
          values.where((value) => value.name == map[key]).firstOrNull ?? fallback;
      List<LayerRole> roles(String key) => (map[key] as List? ?? const [])
          .map((item) => LayerRole.values.where((value) => value.name == item).firstOrNull)
          .whereType<LayerRole>().toList(growable: false);
      final legacyContribution = (map['thermalContributionC'] as num?)?.toDouble();
      final migratedInsulation = legacyContribution == null
          ? InsulationLevel.medium
          : legacyContribution >= 11 ? InsulationLevel.veryHigh
          : legacyContribution >= 8 ? InsulationLevel.high
          : legacyContribution >= 4 ? InsulationLevel.medium
          : legacyContribution >= 2 ? InsulationLevel.low : InsulationLevel.veryLow;
      return ThermalProfile(
        insulation: enumValue(InsulationLevel.values, 'insulation', migratedInsulation),
        thickness: enumValue(ThicknessLevel.values, 'thickness', ThicknessLevel.medium),
        breathability: enumValue(BreathabilityLevel.values, 'breathability', BreathabilityLevel.medium),
        windProtection: enumValue(WeatherProtection.values, 'windProtection', WeatherProtection.none),
        rainProtection: enumValue(WeatherProtection.values, 'rainProtection',
            enumValue(WeatherProtection.values, 'rainCompatibility', WeatherProtection.none)),
        moistureResistance: enumValue(WeatherProtection.values, 'moistureResistance', WeatherProtection.limited),
        dryingSpeed: enumValue(DryingSpeed.values, 'dryingSpeed', DryingSpeed.medium),
        primaryRole: enumValue(LayerRole.values, 'primaryRole', LayerRole.mid),
        coverage: enumValue(CoverageLevel.values, 'coverage', CoverageLevel.medium),
        weight: enumValue(GarmentWeight.values, 'weight', GarmentWeight.medium),
        opening: enumValue(OpeningType.values, 'opening', OpeningType.closed),
        acceptsUnder: roles('acceptsUnder'), acceptsOver: roles('acceptsOver'),
        modelVersion: currentModelVersion,
        inputFingerprint: map['inputFingerprint'] as String? ?? 'legacy-migration',
        calculatedAt: DateTime.tryParse(map['calculatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        confidence: (map['confidence'] as num?)?.toDouble() ?? .5,
        extensions: {
          if (map['extensions'] is Map) ...Map<String, Object?>.from(map['extensions'] as Map),
          if ((map['modelVersion'] as num? ?? 1) < currentModelVersion) 'migratedFromThermalVersion': map['modelVersion'] ?? 1,
        },
      );
    } catch (_) { return null; }
  }
}
