import 'dart:convert';

enum ThermalLevel { veryLight, light, moderate, warm, veryWarm }
enum BreathabilityLevel { low, medium, high }
enum WeatherProtection { none, limited, resistant }
enum LayerRole { base, mid, outer }

/// Versioned, explainable thermal description. Seasons are deliberately absent:
/// they remain a legacy display/filter concern, not an estimation input.
class ThermalProfile {
  static const currentModelVersion = 1;

  final double standaloneMinC;
  final double standaloneMaxC;
  final double layeredMinC;
  final double layeredMaxC;
  final ThermalLevel level;
  final BreathabilityLevel breathability;
  final WeatherProtection windProtection;
  final WeatherProtection rainCompatibility;
  final LayerRole primaryRole;
  final List<LayerRole> acceptsUnder;
  final List<LayerRole> acceptsOver;
  final int modelVersion;
  final String inputFingerprint;
  final DateTime calculatedAt;
  final double confidence;
  final Map<String, Object?> extensions;

  const ThermalProfile({
    required this.standaloneMinC,
    required this.standaloneMaxC,
    required this.layeredMinC,
    required this.layeredMaxC,
    required this.level,
    required this.breathability,
    required this.windProtection,
    required this.rainCompatibility,
    required this.primaryRole,
    this.acceptsUnder = const [],
    this.acceptsOver = const [],
    this.modelVersion = currentModelVersion,
    required this.inputFingerprint,
    required this.calculatedAt,
    this.confidence = .65,
    this.extensions = const {},
  }) : assert(standaloneMinC <= standaloneMaxC),
       assert(layeredMinC <= layeredMaxC),
       assert(confidence >= 0 && confidence <= 1);

  bool isCurrentFor(String fingerprint) =>
      modelVersion == currentModelVersion && inputFingerprint == fingerprint;

  Map<String, Object?> toJson() => {
    'standaloneMinC': standaloneMinC,
    'standaloneMaxC': standaloneMaxC,
    'layeredMinC': layeredMinC,
    'layeredMaxC': layeredMaxC,
    'level': level.name,
    'breathability': breathability.name,
    'windProtection': windProtection.name,
    'rainCompatibility': rainCompatibility.name,
    'primaryRole': primaryRole.name,
    'acceptsUnder': acceptsUnder.map((value) => value.name).toList(),
    'acceptsOver': acceptsOver.map((value) => value.name).toList(),
    'modelVersion': modelVersion,
    'inputFingerprint': inputFingerprint,
    'calculatedAt': calculatedAt.toIso8601String(),
    'confidence': confidence,
    'extensions': extensions,
  };

  String encode() => jsonEncode(toJson());

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
      double number(String key) => (map[key] as num).toDouble();
      return ThermalProfile(
        standaloneMinC: number('standaloneMinC'),
        standaloneMaxC: number('standaloneMaxC'),
        layeredMinC: number('layeredMinC'),
        layeredMaxC: number('layeredMaxC'),
        level: enumValue(ThermalLevel.values, 'level', ThermalLevel.moderate),
        breathability: enumValue(BreathabilityLevel.values, 'breathability', BreathabilityLevel.medium),
        windProtection: enumValue(WeatherProtection.values, 'windProtection', WeatherProtection.none),
        rainCompatibility: enumValue(WeatherProtection.values, 'rainCompatibility', WeatherProtection.none),
        primaryRole: enumValue(LayerRole.values, 'primaryRole', LayerRole.mid),
        acceptsUnder: roles('acceptsUnder'),
        acceptsOver: roles('acceptsOver'),
        modelVersion: (map['modelVersion'] as num?)?.toInt() ?? 1,
        inputFingerprint: map['inputFingerprint'] as String? ?? 'unknown',
        calculatedAt: DateTime.tryParse(map['calculatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        confidence: (map['confidence'] as num?)?.toDouble() ?? .5,
        extensions: map['extensions'] is Map ? Map<String, Object?>.from(map['extensions'] as Map) : const {},
      );
    } catch (_) {
      return null;
    }
  }

  /// Allows pre-sprint records to be consumed until they are next edited.
  factory ThermalProfile.fromLegacy({double? minimum, double? maximum, bool? rain, String? layerType}) {
    final min = minimum ?? 12;
    final max = maximum ?? min + 8;
    final safeMax = max < min ? min : max;
    final role = layerType?.toLowerCase().contains('ext') == true
        ? LayerRole.outer
        : layerType?.toLowerCase().contains('base') == true ? LayerRole.base : LayerRole.mid;
    return ThermalProfile(
      standaloneMinC: min,
      standaloneMaxC: safeMax,
      layeredMinC: min - 4,
      layeredMaxC: safeMax - 2,
      level: ThermalLevel.moderate,
      breathability: BreathabilityLevel.medium,
      windProtection: WeatherProtection.none,
      rainCompatibility: rain == true ? WeatherProtection.limited : WeatherProtection.none,
      primaryRole: role,
      acceptsUnder: role == LayerRole.base ? const [] : const [LayerRole.base],
      acceptsOver: role == LayerRole.outer ? const [] : const [LayerRole.mid, LayerRole.outer],
      inputFingerprint: 'legacy',
      calculatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      confidence: .3,
      extensions: const {'source': 'legacy-adapter'},
    );
  }
}
