import 'dart:convert';

import 'thermal_profile.dart';

class ThermalProfileInput {
  final String category;
  final String? subcategory, composition, material, thickness, lining, fit, construction, length, opening;
  final List<String> detectedFeatures;
  const ThermalProfileInput({required this.category, this.subcategory, this.composition,
    this.material, this.thickness, this.lining, this.fit, this.construction, this.length,
    this.opening, this.detectedFeatures = const []});

  String get evidence => [category, subcategory, composition, material, thickness, lining,
    fit, construction, length, opening, ...detectedFeatures].whereType<String>().join(' ').toLowerCase();
  String get fingerprint {
    final values = [category, subcategory, composition, material, thickness, lining, fit,
      construction, length, opening, ...detectedFeatures.toList()..sort()]
        .map((value) => value?.trim().toLowerCase()).toList();
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(jsonEncode(values))) {
      hash = ((hash ^ byte) * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}

class ThermalProfileCalculator {
  const ThermalProfileCalculator();

  ThermalProfile calculate(ThermalProfileInput input, {DateTime? calculatedAt}) {
    final text = _normalize(input.evidence);
    final rule = _ruleFor(input.category.toLowerCase(), input.subcategory?.toLowerCase() ?? '', text);
    final material = _materialEffects(text);
    final insulation = _shiftInsulation(rule.insulation, material.insulationShift);
    final breathability = material.breathability ?? rule.breathability;
    final evidenceCount = [input.subcategory, input.composition, input.material, input.thickness,
      input.lining, input.fit, input.construction, input.length, input.opening]
        .where((value) => value?.trim().isNotEmpty == true).length + input.detectedFeatures.length;
    return ThermalProfile(
      insulation: insulation,
      thickness: _has(text, r'epais|matelasse|double') ? ThicknessLevel.thick : rule.thickness,
      breathability: breathability,
      windProtection: _has(text, r'coupe.?vent|membrane|gabardine') ? WeatherProtection.resistant : rule.wind,
      rainProtection: _has(text, r'impermeable|gore.?tex|enduit|waterproof') ? WeatherProtection.resistant : rule.rain,
      moistureResistance: material.moisture,
      dryingSpeed: material.drying,
      primaryRole: rule.role,
      coverage: _has(text, r'long|manteau|parka|trench') ? CoverageLevel.high : rule.coverage,
      weight: insulation.index >= InsulationLevel.high.index ? GarmentWeight.heavy : rule.weight,
      opening: _has(text, r'zip|bouton|fermeture') ? OpeningType.partial : rule.opening,
      acceptsUnder: rule.role == LayerRole.base ? const [] : rule.role == LayerRole.mid ? const [LayerRole.base] : const [LayerRole.base, LayerRole.mid],
      acceptsOver: rule.role == LayerRole.outer ? const [] : rule.role == LayerRole.mid ? const [LayerRole.outer] : const [LayerRole.mid, LayerRole.outer],
      inputFingerprint: input.fingerprint,
      calculatedAt: calculatedAt ?? DateTime.now().toUtc(),
      confidence: (.5 + evidenceCount * .055).clamp(.5, .9).toDouble(),
      extensions: {'estimator': 'physical-garment-v3', 'matchedRule': rule.name},
    );
  }

  ThermalProfile ensureCurrent(ThermalProfileInput input, ThermalProfile? current, {DateTime? calculatedAt}) =>
      current?.isCurrentFor(input.fingerprint) == true ? current! : calculate(input, calculatedAt: calculatedAt);

  _PhysicalRule _ruleFor(String category, String subcategory, String text) {
    // Category and normalized subtype select construction first; words only
    // refine material/finish below instead of being the sole classifier.
    final type = '$category $subcategory';
    if (_has(type, r'doudoune|parka') || _has(text, r'down jacket|puffer|duvet')) return _rules['doudoune']!;
    if (_has(type, r'manteau') && _has(text, r'laine|wool|caban')) return _rules['manteau-laine']!;
    if (_has(type, r'impermeable') || _has(text, r'raincoat')) return _rules['impermeable']!;
    if (_has(type, r'trench')) return _rules['trench']!;
    if (_has(type, r'blazer|veste de costume')) return _rules['blazer']!;
    if (_has(type, r'pull|cardigan|sweat')) return _rules['pull']!;
    if (_has(type, r'chemise|blouse')) return _rules['chemise']!;
    if (_has(type, r't-shirt|tee-shirt|debardeur|polo')) return _rules['tshirt']!;
    if (_has(category, r'veste|outerwear')) return _rules['veste']!;
    return _rules['fallback']!;
  }

  _MaterialEffects _materialEffects(String text) {
    if (_has(text, r'laine|merinos|cachemire|wool')) return const _MaterialEffects(1, BreathabilityLevel.medium, WeatherProtection.limited, DryingSpeed.slow);
    if (_has(text, r'lin|linen')) return const _MaterialEffects(-1, BreathabilityLevel.high, WeatherProtection.none, DryingSpeed.fast);
    if (_has(text, r'nylon|polyester|synthetique')) return const _MaterialEffects(0, BreathabilityLevel.medium, WeatherProtection.resistant, DryingSpeed.fast);
    if (_has(text, r'cuir|leather')) return const _MaterialEffects(0, BreathabilityLevel.low, WeatherProtection.resistant, DryingSpeed.slow);
    return const _MaterialEffects(0, null, WeatherProtection.limited, DryingSpeed.medium);
  }

  InsulationLevel _shiftInsulation(InsulationLevel value, int shift) =>
      InsulationLevel.values[(value.index + shift).clamp(0, InsulationLevel.values.length - 1)];
  bool _has(String value, String expression) => RegExp(expression, caseSensitive: false).hasMatch(value);
  String _normalize(String value) => value.replaceAll(RegExp(r'[àáâä]'), 'a').replaceAll(RegExp(r'[éèêë]'), 'e');
}

class _MaterialEffects {
  final int insulationShift;
  final BreathabilityLevel? breathability;
  final WeatherProtection moisture;
  final DryingSpeed drying;
  const _MaterialEffects(this.insulationShift, this.breathability, this.moisture, this.drying);
}

class _PhysicalRule {
  final String name;
  final InsulationLevel insulation;
  final ThicknessLevel thickness;
  final LayerRole role;
  final BreathabilityLevel breathability;
  final WeatherProtection wind, rain;
  final CoverageLevel coverage;
  final GarmentWeight weight;
  final OpeningType opening;
  const _PhysicalRule(this.name, this.insulation, this.thickness, this.role, this.breathability,
      this.wind, this.rain, this.coverage, this.weight, this.opening);
}

const _rules = <String, _PhysicalRule>{
  'doudoune': _PhysicalRule('doudoune', InsulationLevel.veryHigh, ThicknessLevel.veryThick, LayerRole.outer, BreathabilityLevel.low, WeatherProtection.resistant, WeatherProtection.limited, CoverageLevel.high, GarmentWeight.heavy, OpeningType.closed),
  'manteau-laine': _PhysicalRule('manteau-laine', InsulationLevel.high, ThicknessLevel.thick, LayerRole.outer, BreathabilityLevel.low, WeatherProtection.resistant, WeatherProtection.limited, CoverageLevel.high, GarmentWeight.heavy, OpeningType.partial),
  'impermeable': _PhysicalRule('impermeable', InsulationLevel.veryLow, ThicknessLevel.light, LayerRole.outer, BreathabilityLevel.low, WeatherProtection.resistant, WeatherProtection.resistant, CoverageLevel.high, GarmentWeight.light, OpeningType.closed),
  'trench': _PhysicalRule('trench', InsulationLevel.low, ThicknessLevel.medium, LayerRole.outer, BreathabilityLevel.medium, WeatherProtection.resistant, WeatherProtection.resistant, CoverageLevel.high, GarmentWeight.medium, OpeningType.partial),
  'blazer': _PhysicalRule('blazer', InsulationLevel.low, ThicknessLevel.medium, LayerRole.outer, BreathabilityLevel.medium, WeatherProtection.limited, WeatherProtection.none, CoverageLevel.medium, GarmentWeight.medium, OpeningType.open),
  'veste': _PhysicalRule('veste', InsulationLevel.medium, ThicknessLevel.medium, LayerRole.outer, BreathabilityLevel.medium, WeatherProtection.limited, WeatherProtection.limited, CoverageLevel.medium, GarmentWeight.medium, OpeningType.partial),
  'pull': _PhysicalRule('pull', InsulationLevel.medium, ThicknessLevel.medium, LayerRole.mid, BreathabilityLevel.medium, WeatherProtection.none, WeatherProtection.none, CoverageLevel.medium, GarmentWeight.medium, OpeningType.closed),
  'chemise': _PhysicalRule('chemise', InsulationLevel.veryLow, ThicknessLevel.light, LayerRole.base, BreathabilityLevel.high, WeatherProtection.none, WeatherProtection.none, CoverageLevel.medium, GarmentWeight.light, OpeningType.partial),
  'tshirt': _PhysicalRule('tshirt', InsulationLevel.veryLow, ThicknessLevel.light, LayerRole.base, BreathabilityLevel.high, WeatherProtection.none, WeatherProtection.none, CoverageLevel.low, GarmentWeight.light, OpeningType.closed),
  'fallback': _PhysicalRule('fallback', InsulationLevel.low, ThicknessLevel.medium, LayerRole.mid, BreathabilityLevel.medium, WeatherProtection.none, WeatherProtection.none, CoverageLevel.medium, GarmentWeight.medium, OpeningType.closed),
};
