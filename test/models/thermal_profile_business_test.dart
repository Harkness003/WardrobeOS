import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/models/thermal_profile.dart';
import 'package:wardrobeos/models/thermal_profile_calculator.dart';

void main() {
  const calculator = ThermalProfileCalculator();

  ThermalProfile profile(String category, String subcategory, {String? material}) =>
      calculator.calculate(ThermalProfileInput(
        category: category,
        subcategory: subcategory,
        material: material,
      ), calculatedAt: DateTime(2026, 8, 5));

  test('grille métier des vêtements thermiques de référence', () {
    expect(profile('top', 'T-shirt coton léger', material: 'coton léger').standaloneMinC, 18);
    expect(profile('top', 'T-shirt coton léger', material: 'coton léger').standaloneMaxC, 30);
    expect(profile('top', 'Polo bleu', material: 'coton piqué').standaloneMinC, 15);
    expect(profile('top', 'Polo bleu', material: 'coton piqué').standaloneMaxC, 28);
    expect(profile('top', 'Chemise légère', material: 'coton fin').standaloneMaxC, 25);
    expect(profile('top', 'Pull laine', material: 'laine').standaloneMinC, 8);
    expect(profile('top', 'Sweat', material: 'molleton').standaloneMaxC, 22);
    expect(profile('outerwear', 'Veste légère').standaloneMinC, 10);
    expect(profile('outerwear', 'Trench beige gabardine').standaloneMaxC, 18);
    expect(profile('outerwear', 'Blazer').standaloneMinC, 15);
    expect(profile('outerwear', 'Manteau laine').standaloneMinC, 0);
    expect(profile('outerwear', 'Doudoune').standaloneMinC, -10);
  });

  test('trench et polo gardent une classification thermique métier distincte', () {
    final trench = profile('outerwear', 'Trench beige gabardine');
    expect(trench.primaryRole, LayerRole.outer);
    expect(trench.windProtection, WeatherProtection.resistant);
    expect(trench.rainCompatibility, WeatherProtection.resistant);
    expect(trench.level, ThermalLevel.moderate);

    final polo = profile('top', 'Polo bleu', material: 'coton piqué');
    expect(polo.primaryRole, LayerRole.base);
    expect(polo.insulation, InsulationLevel.low);
    expect(polo.thickness, ThicknessLevel.light);
  });
}
