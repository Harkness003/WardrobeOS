import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/agenda/agenda_models.dart';
import 'package:wardrobeos/features/agenda/agenda_rule_evaluator.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/outfit.dart';

void main() {
  final day = DateTime(2026, 8, 4);
  Garment garment(String id, String category) => Garment(id: id, name: id,
    category: category, createdAt: day, updatedAt: day);
  Outfit outfit(String id, {String top = 'top-a', String bottom = 'bottom-a',
      String shoes = 'shoes-a'}) => Outfit(id: id, name: id,
    createdAt: day, updatedAt: day, garments: {
      OutfitCategory.top: [garment(top, 'Hauts')],
      OutfitCategory.bottom: [garment(bottom, 'Pantalons')],
      OutfitCategory.shoes: [garment(shoes, 'Chaussures')],
    });
  PlannedOutfit plan(Outfit value) => PlannedOutfit(id: 'plan-${value.id}',
    date: day.subtract(const Duration(days: 1)), outfitId: value.id,
    outfit: value, createdAt: day, updatedAt: day);

  test('un verrou opposé à refresh produit un conflit anonyme', () {
    const rule = AgendaRule(type: AgendaRuleType.refreshCategory,
      parameters: {'category': 'bottom'});
    final conflicts = const AgendaRuleConflictDetector().detect(
      rules: const [rule], lockedCategories: const {OutfitCategory.bottom});
    expect(conflicts, hasLength(1));
    expect(conflicts.single.reason, 'conflictingAgendaRules');
    expect(conflicts.single.ruleTypes, {AgendaRuleType.refreshCategory});
  });

  test('un maximum opposé à une conservation verrouillée est conflictuel', () {
    const rule = AgendaRule(type: AgendaRuleType.maximumCategoryDays,
      parameters: {'category': 'bottom', 'days': 1});
    final conflicts = const AgendaRuleConflictDetector().detect(
      rules: const [rule], lockedCategories: const {OutfitCategory.bottom},
      lockedConsecutiveDays: 2);
    expect(conflicts, hasLength(1));
    expect(conflicts.single.reason, 'conflictingAgendaRules');
  });

  test('une chaussure unique est unsatisfied et non conflicting', () {
    final previous = outfit('a');
    final values = const AgendaRuleEvaluator().evaluate(date: day,
      rules: const [AgendaRule(type: AgendaRuleType.refreshCategory,
        parameters: {'category': 'shoes'})],
      previous: [plan(previous)], selected: outfit('b'));
    expect(values.single.status, AgendaRuleEvaluationStatus.unsatisfied);
    expect(values.single.reason, 'noValidAlternative');
  });

  test('refresh et alternate sont évaluées sur la tenue sélectionnée', () {
    final previous = outfit('a');
    final selected = outfit('b', top: 'top-b', shoes: 'shoes-b');
    final values = const AgendaRuleEvaluator().evaluate(date: day, rules: const [
      AgendaRule(type: AgendaRuleType.refreshCategory,
        parameters: {'category': 'top'}),
      AgendaRule(type: AgendaRuleType.alternateCategory,
        parameters: {'category': 'shoes'}),
    ], previous: [plan(previous)], selected: selected);
    expect(values.map((value) => value.status), everyElement(
      AgendaRuleEvaluationStatus.satisfied));
  });

  test('les maximums catégorie et tenue partagent les séries réelles', () {
    final repeated = outfit('a');
    final history = [plan(repeated), plan(repeated)];
    final values = const AgendaRuleEvaluator().evaluate(date: day, rules: const [
      AgendaRule(type: AgendaRuleType.maximumCategoryDays,
        parameters: {'category': 'bottom', 'days': 2}),
      AgendaRule(type: AgendaRuleType.maximumFullOutfitDays,
        parameters: {'days': 2}),
    ], previous: history, selected: repeated);
    expect(values.map((value) => value.status), everyElement(
      AgendaRuleEvaluationStatus.unsatisfied));
  });

  test('premier jour est notApplicable et non artificiellement satisfait', () {
    final values = const AgendaRuleEvaluator().evaluate(date: day,
      rules: const [AgendaRule(type: AgendaRuleType.maximumFullOutfitDays)],
      previous: const [], selected: outfit('a'));
    expect(values.single.status, AgendaRuleEvaluationStatus.notApplicable);
  });
}
