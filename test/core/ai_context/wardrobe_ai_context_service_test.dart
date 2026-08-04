import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/ai_context/ai_context.dart';
import 'package:wardrobeos/core/ai_context/ai_reanalysis_policy.dart';
import 'package:wardrobeos/core/ai_context/wardrobe_ai_context_service.dart';
import 'package:wardrobeos/models/garment.dart';

Garment garment(String name) => Garment(
  id: 'stable-id',
  name: name,
  category: 'Hauts',
  sousCategorie: 'T-shirt',
  couleurPrincipale: 'Bleu',
  matierePrincipale: 'Coton',
  stylesSecondaires: const ['Casual'],
  temperatureMinimum: 16,
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
    expect(context.fields['temperatureMinimum'], isNull);
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
