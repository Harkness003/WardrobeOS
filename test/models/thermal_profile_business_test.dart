import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/models/thermal_profile.dart';
import 'package:wardrobeos/models/thermal_profile_calculator.dart';

void main() {
  const calculator = ThermalProfileCalculator();
  ThermalProfile profile(String category, String subtype, {String? material}) => calculator.calculate(
    ThermalProfileInput(category: category, subcategory: subtype, material: material),
    calculatedAt: DateTime(2026, 8, 5));

  test('les références produisent des propriétés physiques distinctes', () {
    expect(profile('top', 'T-shirt', material: 'lin').breathability, BreathabilityLevel.high);
    expect(profile('top', 'Pull', material: 'laine').insulation, InsulationLevel.high);
    expect(profile('outerwear', 'Doudoune').insulation, InsulationLevel.veryHigh);
    expect(profile('outerwear', 'Manteau', material: 'laine').coverage, CoverageLevel.high);
    expect(profile('outerwear', 'Imperméable').rainProtection, WeatherProtection.resistant);
    expect(profile('outerwear', 'Trench').windProtection, WeatherProtection.resistant);
    expect(profile('outerwear', 'Blazer').opening, OpeningType.open);
  });
}
