import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/outfit_generation/outfit_generation_engine.dart';
import 'package:wardrobeos/core/recommendation/recommendation_context.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/thermal_profile_calculator.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6);
  const calculator = ThermalProfileCalculator();
  final engine = OutfitGenerationEngine(clock: () => now);
  Garment item(String name, String category, String subtype, {String? material}) => Garment(
    id: name, name: name, category: category, sousCategorie: subtype,
    thermalProfile: calculator.calculate(ThermalProfileInput(
      category: category, subcategory: subtype, material: material), calculatedAt: now),
    createdAt: now, updatedAt: now);
  RecommendationContext weather(double temperature, {bool rain = false,
    double wind = 0, int humidity = 50}) => RecommendationContext(
      weather: RecommendationWeather(temperature: temperature, isRaining: rain,
        windSpeed: wind, humidity: humidity));

  final tshirt = item('T-shirt', 'Hauts', 'T-shirt', material: 'lin');
  final shirt = item('Chemise', 'Chemises', 'Chemise', material: 'coton');
  final pull = item('Pull', 'Hauts', 'Pull', material: 'laine');
  final trench = item('Trench', 'Vestes', 'Trench', material: 'gabardine');
  final blazer = item('Blazer', 'Vestes', 'Blazer', material: 'laine');
  final down = item('Doudoune', 'Vestes', 'Doudoune', material: 'nylon');
  final coat = item('Manteau laine', 'Vestes', 'Manteau', material: 'laine');
  final raincoat = item('Imperméable', 'Vestes', 'Imperméable', material: 'nylon');

  test('T-shirt seul: été adapté, froid trop léger', () {
    expect(engine.evaluateThermal([tshirt], weather(27))!.verdict, ThermalVerdict.ideal);
    expect(engine.evaluateThermal([tshirt], weather(5))!.verdict, ThermalVerdict.tooLight);
  });
  test('T-shirt + pull augmente réellement l’isolation', () {
    final base = engine.evaluateThermal([tshirt], weather(12))!;
    final layered = engine.evaluateThermal([tshirt, pull], weather(12))!;
    expect(layered.accumulatedInsulation, greaterThan(base.accumulatedInsulation));
    expect(layered.reasons.join(' '), contains('intermédiaire'));
  });
  test('pull + trench couvre vent et pluie', () {
    final result = engine.evaluateThermal([pull, trench], weather(10, rain: true, wind: 25))!;
    expect(result.reasons.join(' '), contains('vent'));
    expect(result.reasons.join(' '), contains('pluie'));
  });
  test('chemise + blazer reste une superposition légère et non imperméable', () {
    expect(engine.evaluateThermal([shirt, blazer], weather(18))!.accumulatedInsulation,
      lessThan(engine.evaluateThermal([pull, coat], weather(18))!.accumulatedInsulation));
    expect(engine.evaluateThermal([shirt, blazer], weather(18, rain: true))!.verdict,
      ThermalVerdict.rainInsufficient);
  });
  test('doudoune et manteau laine isolent; doudoune excessive en chaleur', () {
    expect(engine.evaluateThermal([down], weather(25))!.verdict,
      ThermalVerdict.excessiveInsulation);
    expect(engine.evaluateThermal([coat], weather(2))!.score, greaterThan(.5));
  });
  test('imperméable couvre la pluie mais pas seul un hiver sec', () {
    expect(engine.evaluateThermal([raincoat], weather(16, rain: true))!.verdict,
      isNot(ThermalVerdict.rainInsufficient));
    expect(engine.evaluateThermal([raincoat], weather(0))!.verdict, ThermalVerdict.tooLight);
  });
  test('vent sans outer et été humide peu respirant expliquent leur déficit', () {
    expect(engine.evaluateThermal([tshirt, pull], weather(15, wind: 30))!.verdict,
      ThermalVerdict.missingOuterLayer);
    expect(engine.evaluateThermal([down], weather(25, humidity: 90))!.reasons.join(' '),
      contains('humidité'));
  });
}
