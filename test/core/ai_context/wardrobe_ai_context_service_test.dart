import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/ai_context/ai_context.dart';
import 'package:wardrobeos/core/ai_context/ai_reanalysis_policy.dart';
import 'package:wardrobeos/core/ai_context/wardrobe_ai_context_service.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/style_analysis.dart';
import 'package:wardrobeos/models/thermal_profile.dart';

Garment garment(String name) => Garment(
  id: 'stable-id',
  name: name,
  category: 'Hauts',
  sousCategorie: 'T-shirt',
  couleurPrincipale: 'Bleu',
  matierePrincipale: 'Coton',
  styleAnalysis: StyleAnalysis(
    inputFingerprint: 'style-fixture',
    suggestedRegister: 'casual',
    suggestedSecondaryStyles: const ['minimalist'],
    calculatedAt: DateTime(2026),
  ),
  thermalProfile: ThermalProfile(
    standaloneMinC: 16,
    standaloneMaxC: 28,
    layeredMinC: 12,
    layeredMaxC: 24,
    level: ThermalLevel.light,
    breathability: BreathabilityLevel.high,
    windProtection: WeatherProtection.none,
    rainCompatibility: WeatherProtection.none,
    primaryRole: LayerRole.base,
    inputFingerprint: 'thermal-fixture',
    calculatedAt: DateTime(2026),
  ),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('relit la source à chaque construction et conserve l’identifiant', () async {
    var name = 'Avant';
    var calls = 0;
    final service = WardrobeAiContextService(
      loadCurrentGarments: () async {
        calls++;
        return [garment(name)];
      },
      clock: () => DateTime.utc(2026, 8, 4),
    );

    final before = await service.build();
    name = 'Après correction';
    final after = await service.build();

    expect(calls, 2);
    expect(before.garments.single.name, 'Avant');
    expect(after.garments.single.name, 'Après correction');
    expect(after.aiGarments.single.id, 'stable-id');
    expect(after.toMap()['wardrobeSource'], 'live_database');
  });

  test('étiquette séparément saisie, analyse et calcul', () async {
    final context = AiGarmentContext.fromGarment(garment('T-shirt bleu'));

    expect(context.fields['name']?.source, AiDataSource.user);
    expect(context.fields['thermalProfile']?.source, AiDataSource.calculated);
    expect(context.fields['styleRegister']?.source, AiDataSource.aiAnalysis);
    expect(context.fields['styleCharacteristics']?.source,
        AiDataSource.aiAnalysis);
    expect(context.fields['subcategory']?.source, AiDataSource.user);
  });

  test('une réanalyse protège une correction postérieure', () {
    final decision = const AiReanalysisPolicy().compare(
      baseline: const {'color': 'Bleu', 'material': 'Coton'},
      current: const {'color': 'Vert', 'material': 'Coton'},
      suggested: const {'color': 'Rouge', 'material': 'Lin'},
    );

    expect(decision.protectedUserValues, {'color': 'Vert'});
    expect(decision.applicable, {'material': 'Lin'});
  });
}
