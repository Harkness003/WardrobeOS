import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/agenda/agenda_models.dart';
import 'package:wardrobeos/models/outfit.dart';

void main() {
  test('anciennes données utilisent des valeurs compatibles par défaut', () {
    final value = PlannedOutfit.fromMap({
      'id': 'legacy', 'planned_date': '2026-08-03T00:00:00.000',
      'outfit_id': 'outfit-1', 'created_at': '2026-08-01T10:00:00.000',
      'updated_at': '2026-08-01T10:00:00.000',
    });
    expect(value.origin, PlanningOrigin.manual);
    expect(value.strategy, PlanningStrategy.rotation);
    expect(value.status, PlannedOutfitStatus.proposed);
    expect(value.reuseKind, OutfitReuseKind.none);
  });

  test('toutes les stratégies demandées restent centralisées', () {
    expect(PlanningStrategy.values, containsAll(<PlanningStrategy>[
      PlanningStrategy.minimal, PlanningStrategy.economical,
      PlanningStrategy.rotation, PlanningStrategy.variety,
      PlanningStrategy.elegance, PlanningStrategy.comfort,
      PlanningStrategy.weather, PlanningStrategy.professional,
      PlanningStrategy.custom,
    ]));
  });

  test('mode minimal autorise explicitement cinq jours consécutifs', () {
    const value = AgendaPreferences(strategy: PlanningStrategy.minimal,
      allowCompleteOutfitReuse: true, maximumConsecutiveDays: 5);
    expect(value.allowCompleteOutfitReuse, isTrue);
    expect(value.maximumConsecutiveDays, 5);
  });

  test('mode économique configure une réutilisation partielle sûre', () {
    const value = AgendaPreferences(strategy: PlanningStrategy.economical);
    expect(value.reusableCategories, containsAll(<OutfitCategory>[
      OutfitCategory.bottom, OutfitCategory.jacket,
      OutfitCategory.coat, OutfitCategory.shoes,
    ]));
    expect(value.dailyRefreshCategories, contains(OutfitCategory.top));
  });

  test('règle personnalisée conserve des paramètres extensibles', () {
    const rule = AgendaRule(type: 'maximum_category_days', parameters: {
      'category': 'bottom', 'days': 3,
    });
    final restored = AgendaRule.fromJson(rule.toJson());
    expect(restored.type, rule.type);
    expect(restored.parameters['days'], 3);
  });
}
