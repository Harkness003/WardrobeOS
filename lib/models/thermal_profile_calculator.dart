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
    final text = _normalize(input.evidence);
    final rule = _ruleFor(text);
    final evidenceCount = [input.subcategory, input.composition, input.material, input.thickness,
      input.lining, input.fit].where((value) => value?.trim().isNotEmpty == true).length + input.detectedFeatures.length;

    return ThermalProfile(
      standaloneMinC: rule.min,
      standaloneMaxC: rule.max,
      layeredMinC: rule.min - rule.layerGain,
      layeredMaxC: rule.max - (rule.role == LayerRole.base ? 1 : 2),
      level: rule.level,
      insulation: rule.insulation,
      thickness: rule.thickness,
      thermalContributionC: rule.contribution,
      breathability: rule.breathability,
      windProtection: rule.wind,
      rainCompatibility: rule.rain,
      primaryRole: rule.role,
      acceptsUnder: rule.role == LayerRole.base ? const [] : rule.role == LayerRole.mid ? const [LayerRole.base] : const [LayerRole.base, LayerRole.mid],
      acceptsOver: rule.role == LayerRole.outer ? const [] : rule.role == LayerRole.mid ? const [LayerRole.outer] : const [LayerRole.mid, LayerRole.outer],
      inputFingerprint: input.fingerprint,
      calculatedAt: calculatedAt ?? DateTime.now().toUtc(),
      confidence: (.55 + evidenceCount * .06).clamp(.55, .9).toDouble(),
      extensions: {'estimator': 'deterministic-thermal-business-v2', 'matchedRule': rule.name, 'personalAdjustmentReady': true},
    );
  }

  ThermalProfile ensureCurrent(ThermalProfileInput input, ThermalProfile? current, {DateTime? calculatedAt}) =>
      current?.isCurrentFor(input.fingerprint) == true ? current! : calculate(input, calculatedAt: calculatedAt);

  _ThermalRule _ruleFor(String text) {
    if (_has(text, r'doudoune|down jacket|puffer|duvet|parka')) return const _ThermalRule('doudoune', -10, 8, ThermalLevel.veryWarm, InsulationLevel.veryHigh, ThicknessLevel.veryThick, LayerRole.outer, BreathabilityLevel.low, WeatherProtection.resistant, WeatherProtection.limited, 13, 9);
    if (_has(text, r'manteau.*laine|laine.*manteau|overcoat|caban')) return const _ThermalRule('manteau-laine', 0, 12, ThermalLevel.veryWarm, InsulationLevel.high, ThicknessLevel.thick, LayerRole.outer, BreathabilityLevel.low, WeatherProtection.resistant, WeatherProtection.limited, 11, 8);
    if (_has(text, r'trench|gabardine')) return const _ThermalRule('trench', 8, 18, ThermalLevel.moderate, InsulationLevel.medium, ThicknessLevel.medium, LayerRole.outer, BreathabilityLevel.medium, WeatherProtection.resistant, WeatherProtection.resistant, 7, 5);
    if (_has(text, r'blazer|veste de costume')) return const _ThermalRule('blazer', 15, 22, ThermalLevel.light, InsulationLevel.low, ThicknessLevel.medium, LayerRole.outer, BreathabilityLevel.medium, WeatherProtection.limited, WeatherProtection.none, 4, 3);
    if (_has(text, r'surchemise|bomber|veste|blouson')) return const _ThermalRule('veste-legere', 10, 20, ThermalLevel.moderate, InsulationLevel.medium, ThicknessLevel.medium, LayerRole.outer, BreathabilityLevel.medium, WeatherProtection.limited, WeatherProtection.limited, 6, 4);
    if (_has(text, r'sweat|hoodie|molleton')) return const _ThermalRule('sweat', 10, 22, ThermalLevel.warm, InsulationLevel.medium, ThicknessLevel.thick, LayerRole.mid, BreathabilityLevel.medium, WeatherProtection.none, WeatherProtection.none, 6, 5);
    if (_has(text, r'pull|laine|merinos|cachemire')) return const _ThermalRule('pull-laine', 8, 20, ThermalLevel.warm, InsulationLevel.medium, ThicknessLevel.medium, LayerRole.mid, BreathabilityLevel.medium, WeatherProtection.none, WeatherProtection.none, 6, 5);
    if (_has(text, r'polo')) return const _ThermalRule('polo', 15, 28, ThermalLevel.light, InsulationLevel.low, ThicknessLevel.light, LayerRole.base, BreathabilityLevel.high, WeatherProtection.none, WeatherProtection.none, 2, 2);
    if (_has(text, r'chemise')) return const _ThermalRule('chemise-legere', 15, 25, ThermalLevel.light, InsulationLevel.low, ThicknessLevel.light, LayerRole.base, BreathabilityLevel.high, WeatherProtection.none, WeatherProtection.none, 2, 2);
    if (_has(text, r't-shirt|tee-shirt|debardeur')) return const _ThermalRule('t-shirt', 18, 30, ThermalLevel.veryLight, InsulationLevel.veryLow, ThicknessLevel.light, LayerRole.base, BreathabilityLevel.high, WeatherProtection.none, WeatherProtection.none, 1.5, 2);
    return const _ThermalRule('fallback-modere', 12, 24, ThermalLevel.moderate, InsulationLevel.medium, ThicknessLevel.medium, LayerRole.mid, BreathabilityLevel.medium, WeatherProtection.none, WeatherProtection.none, 5, 4);
  }

  bool _has(String value, String expression) => RegExp(expression, caseSensitive: false).hasMatch(value);
  String _normalize(String value) => value.replaceAll(RegExp(r'[àáâä]'), 'a').replaceAll(RegExp(r'[éèêë]'), 'e');
}

class _ThermalRule {
  final String name; final double min; final double max; final ThermalLevel level; final InsulationLevel insulation; final ThicknessLevel thickness; final LayerRole role; final BreathabilityLevel breathability; final WeatherProtection wind; final WeatherProtection rain; final double contribution; final double layerGain;
  const _ThermalRule(this.name, this.min, this.max, this.level, this.insulation, this.thickness, this.role, this.breathability, this.wind, this.rain, this.contribution, this.layerGain);
}
