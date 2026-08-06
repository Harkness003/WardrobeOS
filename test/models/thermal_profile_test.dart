import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/models/thermal_profile.dart';
import 'package:wardrobeos/models/thermal_profile_calculator.dart';

void main() {
  const calculator = ThermalProfileCalculator();
  test('décrit la construction et les matières sans plage de température', () {
    final profile = calculator.calculate(const ThermalProfileInput(
      category: 'Vestes', subcategory: 'Parka', material: 'Nylon',
      composition: 'laine, doublure polyester', thickness: 'épais',
      construction: 'membrane coupe-vent', detectedFeatures: ['capuche']),
      calculatedAt: DateTime.utc(2026));
    expect(profile.primaryRole, LayerRole.outer);
    expect(profile.insulation, InsulationLevel.veryHigh);
    expect(profile.windProtection, WeatherProtection.resistant);
    expect(profile.dryingSpeed, DryingSpeed.fast);
    expect(profile.acceptsUnder, containsAll([LayerRole.base, LayerRole.mid]));
    expect(profile.toJson(), isNot(contains('standaloneMinC')));
  });

  test('les changements physiques invalident le profil', () {
    const cotton = ThermalProfileInput(category: 'Hauts', subcategory: 'Pull', material: 'Coton');
    const wool = ThermalProfileInput(category: 'Hauts', subcategory: 'Pull', material: 'Laine épaisse');
    final first = calculator.calculate(cotton, calculatedAt: DateTime.utc(2026));
    expect(identical(calculator.ensureCurrent(cotton, first), first), isTrue);
    expect(calculator.ensureCurrent(wool, first).insulation.index, greaterThan(first.insulation.index));
  });

  test('la lecture v2 migre les températures sans les exposer au runtime', () {
    final migrated = ThermalProfile.decode({
      'modelVersion': 2, 'standaloneMinC': -10, 'standaloneMaxC': 8,
      'thermalContributionC': 13, 'primaryRole': 'outer',
    })!;
    expect(migrated.insulation, InsulationLevel.veryHigh);
    expect(migrated.extensions['migratedFromThermalVersion'], 2);
    expect(migrated.toJson(), isNot(contains('standaloneMinC')));
  });
}
