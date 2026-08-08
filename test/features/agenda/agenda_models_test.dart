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
    const rule = AgendaRule(type: AgendaRuleType.maximumCategoryDays, parameters: {
      'category': 'bottom', 'days': 3,
    });
    final restored = AgendaRule.fromJson(rule.toJson());
    expect(restored.type, rule.type);
    expect(restored.parameters['days'], 3);
  });

  test('préférences Agenda persistent et relisent tous les réglages', () {
    const source = AgendaPreferences(strategy: PlanningStrategy.custom,
      allowCompleteOutfitReuse: false, maximumConsecutiveDays: 5,
      varietyLevel: AgendaVarietyLevel.high, workDays: {1, 3},
      customRules: [AgendaRule(type: AgendaRuleType.refreshCategory,
        parameters: {'category': 'top'})]);
    final restored = AgendaPreferences.fromJson(source.toJson());
    expect(restored.strategy, PlanningStrategy.custom);
    expect(restored.allowCompleteOutfitReuse, isFalse);
    expect(restored.maximumConsecutiveDays, 5);
    expect(restored.varietyLevel, AgendaVarietyLevel.high);
    expect(restored.workDays, {1, 3});
    expect(restored.customRules.single.type, AgendaRuleType.refreshCategory);
  });

  test('ancien payload de préférences conserve les valeurs équilibrées', () {
    final restored = AgendaPreferences.fromJson(const {});
    expect(restored.strategy, PlanningStrategy.rotation);
    expect(restored.varietyLevel, AgendaVarietyLevel.balanced);
    expect(restored.dailyRefreshCategories, contains(OutfitCategory.top));
  });

  test('jours travaillés relit une liste de nombres', () {
    final restored = AgendaPreferences.fromJson(const {
      'workDays': <int>[DateTime.monday, DateTime.wednesday],
    });

    expect(restored.workDays, {DateTime.monday, DateTime.wednesday});
  });

  test('jours travaillés ignore les éléments dynamiques invalides', () {
    final restored = AgendaPreferences.fromJson(const {
      'workDays': <Object?>[DateTime.monday, 'top', null, DateTime.friday],
    });

    expect(restored.workDays, {DateTime.monday, DateTime.friday});
  });

  test('jours travaillés utilise la valeur par défaut si absent ou null', () {
    final absent = AgendaPreferences.fromJson(const {});
    final withNull = AgendaPreferences.fromJson(const {'workDays': null});

    expect(absent.workDays, const AgendaPreferences().workDays);
    expect(withNull.workDays, const AgendaPreferences().workDays);
  });

  test('jours travaillés utilise la valeur par défaut pour un mauvais type', () {
    final restored = AgendaPreferences.fromJson(const {'workDays': 'top'});

    expect(restored.workDays, const AgendaPreferences().workDays);
  });

  test('un échec Agenda distingue phase, résultat métier et index', () {
    final failure = AgendaDayFailure(
      dayIndex: 3,
      date: DateTime(2026, 8, 5),
      phase: AgendaDayPhase.proposalSelection,
      result: AgendaDayResult.businessUnavailable,
      reason: 'missingBottom',
    );

    expect(failure.dayIndex, 3);
    expect(failure.phase, AgendaDayPhase.proposalSelection);
    expect(failure.result, AgendaDayResult.businessUnavailable);
    expect(failure.technicalType, isNull);
  });
}
