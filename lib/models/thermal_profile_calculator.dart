import 'dart:convert';

import 'thermal_profile.dart';

class ThermalProfileInput {
  final String category;
  final String? subcategory;
  final String? composition;
  final String? material;
  final String? thickness;
  final String? lining;
  final String? fit;
  final List<String> detectedFeatures;

  const ThermalProfileInput({required this.category, this.subcategory, this.composition,
    this.material, this.thickness, this.lining, this.fit, this.detectedFeatures = const []});

  String get evidence => [category, subcategory, composition, material, thickness, lining, fit, ...detectedFeatures]
      .whereType<String>().join(' ').toLowerCase();

  String get fingerprint {
    final normalized = [category, subcategory, composition, material, thickness, lining, fit,
      ...detectedFeatures.toList()..sort()].map((value) => value?.trim().toLowerCase()).toList();
    // Stable lightweight fingerprint; no cryptographic property is required.
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(jsonEncode(normalized))) {
      hash = ((hash ^ byte) * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}

class ThermalProfileCalculator {
  const ThermalProfileCalculator();

  ThermalProfile calculate(ThermalProfileInput input, {DateTime? calculatedAt}) {
    final text = input.evidence;
    var warmth = 2;
    if (_has(text, 'lin|soie|léger|fin|mesh')) warmth -= 1;
    if (_has(text, 'laine|mérinos|cachemire|polaire|molleton|duvet|rembour')) warmth += 2;
    if (_has(text, 'épais|double|doubl|matelass|doudoune|parka')) warmth += 1;
    warmth = warmth.clamp(0, 4).toInt();

    final role = _has(text, 'manteau|veste|parka|blouson|imperméable|coupe-vent')
        ? LayerRole.outer
        : _has(text, 't-shirt|débardeur|sous-vêtement|chemise') ? LayerRole.base : LayerRole.mid;
    final center = [27.0, 23.0, 18.0, 12.0, 5.0][warmth];
    // Narrow ranges are intentional: uncertainty lowers confidence, not precision.
    final width = warmth == 0 || warmth == 4 ? 7.0 : 8.0;
    final standaloneMin = center - width / 2;
    final standaloneMax = center + width / 2;
    final layerGain = role == LayerRole.outer ? 6.0 : role == LayerRole.mid ? 5.0 : 3.0;
    final breathable = _has(text, 'lin|coton|mérinos|mesh|respir') && !_has(text, 'enduit|nylon|polyester');
    final wind = _has(text, 'coupe-vent|parka|manteau|cuir|softshell|tissage serré');
    final rain = _has(text, 'imperméable|déperlant|gore-tex|enduit|softshell');
    final evidenceCount = [input.subcategory, input.composition, input.material, input.thickness,
      input.lining, input.fit].where((value) => value?.trim().isNotEmpty == true).length + input.detectedFeatures.length;

    return ThermalProfile(
      standaloneMinC: standaloneMin,
      standaloneMaxC: standaloneMax,
      layeredMinC: standaloneMin - layerGain,
      layeredMaxC: standaloneMax - (role == LayerRole.base ? 1 : 2),
      level: ThermalLevel.values[warmth],
      breathability: breathable ? BreathabilityLevel.high : _has(text, 'enduit|cuir|nylon') ? BreathabilityLevel.low : BreathabilityLevel.medium,
      windProtection: wind ? WeatherProtection.resistant : role == LayerRole.outer ? WeatherProtection.limited : WeatherProtection.none,
      rainCompatibility: rain ? WeatherProtection.resistant : _has(text, 'nylon|polyester|cuir') ? WeatherProtection.limited : WeatherProtection.none,
      primaryRole: role,
      acceptsUnder: role == LayerRole.base ? const [] : role == LayerRole.mid ? const [LayerRole.base] : const [LayerRole.base, LayerRole.mid],
      acceptsOver: role == LayerRole.outer ? const [] : role == LayerRole.mid ? const [LayerRole.outer] : const [LayerRole.mid, LayerRole.outer],
      inputFingerprint: input.fingerprint,
      calculatedAt: calculatedAt ?? DateTime.now().toUtc(),
      confidence: (.45 + evidenceCount * .06).clamp(.45, .87).toDouble(),
      extensions: const {'estimator': 'deterministic-v1', 'personalAdjustmentReady': true},
    );
  }

  ThermalProfile ensureCurrent(ThermalProfileInput input, ThermalProfile? current, {DateTime? calculatedAt}) =>
      current?.isCurrentFor(input.fingerprint) == true ? current! : calculate(input, calculatedAt: calculatedAt);

  bool _has(String value, String expression) => RegExp(expression, caseSensitive: false).hasMatch(value);
}
