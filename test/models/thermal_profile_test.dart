import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/thermal_profile.dart';
import 'package:wardrobeos/models/thermal_profile_calculator.dart';

void main() {
  const calculator = ThermalProfileCalculator();

  test('uses garment evidence rather than seasons and keeps ranges prudent', () {
    const input = ThermalProfileInput(
      category: 'Vestes',
      subcategory: 'Parka',
      material: 'Nylon',
      composition: '80 % laine, doublure polyester',
      thickness: 'épais',
      lining: 'matelassée',
      fit: 'ample',
      detectedFeatures: ['déperlant', 'capuche'],
    );
    final profile = calculator.calculate(input, calculatedAt: DateTime.utc(2026));

    expect(profile.primaryRole, LayerRole.outer);
    expect(profile.level, ThermalLevel.veryWarm);
    expect(profile.rainCompatibility, WeatherProtection.resistant);
    expect(profile.standaloneMaxC - profile.standaloneMinC, lessThanOrEqualTo(8));
    expect(profile.layeredMinC, lessThan(profile.standaloneMinC));
    expect(profile.acceptsUnder, containsAll([LayerRole.base, LayerRole.mid]));
  });

  test('important input changes invalidate and recalculate without a scan', () {
    const cotton = ThermalProfileInput(category: 'Hauts', subcategory: 'Pull', material: 'Coton');
    const wool = ThermalProfileInput(category: 'Hauts', subcategory: 'Pull', material: 'Laine épaisse');
    final first = calculator.calculate(cotton, calculatedAt: DateTime.utc(2026));
    final unchanged = calculator.ensureCurrent(cotton, first, calculatedAt: DateTime.utc(2027));
    final updated = calculator.ensureCurrent(wool, first, calculatedAt: DateTime.utc(2027));

    expect(identical(unchanged, first), isTrue);
    expect(updated.inputFingerprint, isNot(first.inputFingerprint));
    expect(updated.standaloneMaxC, lessThan(first.standaloneMaxC));
  });

  test('profile round-trips and legacy records remain readable', () {
    final profile = calculator.calculate(
      const ThermalProfileInput(category: 'Chemises', material: 'Lin'),
      calculatedAt: DateTime.utc(2026),
    );
    expect(ThermalProfile.decode(profile.encode())?.toJson(), profile.toJson());

    final legacy = Garment.fromMap({
      'id': 'legacy',
      'name': 'Ancienne veste',
      'category': 'Vestes',
      'season': 'Hiver',
      'temperature_minimum': 5,
      'temperature_maximum': 13,
      'compatible_pluie': 1,
      'created_at': '2025-01-01T00:00:00Z',
      'updated_at': '2025-01-01T00:00:00Z',
    });
    expect(legacy.effectiveSeasons, ['Hiver']);
    expect(legacy.effectiveThermalProfile.extensions['source'], 'legacy-adapter');
    expect(legacy.effectiveThermalProfile.standaloneMinC, 5);
  });
}
