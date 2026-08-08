import '../../models/outfit.dart';
import 'agenda_models.dart';

/// Detects contradictions before generation. A preference that the current
/// wardrobe cannot fulfil is not a conflict; only an explicit category lock
/// opposed to a same-day change rule is.
class AgendaRuleConflictDetector {
  const AgendaRuleConflictDetector();

  List<AgendaRuleConflict> detect({required List<AgendaRule> rules,
      Set<OutfitCategory> lockedCategories = const {},
      int lockedConsecutiveDays = 1}) {
    final conflicts = <AgendaRuleConflict>[];
    for (final rule in rules.where((item) => item.enabled)) {
      final category = AgendaRuleEvaluator.categoryOf(rule);
      if (category == null || !lockedCategories.contains(category)) continue;
      if (rule.type == AgendaRuleType.refreshCategory ||
          rule.type == AgendaRuleType.alternateCategory) {
        conflicts.add(AgendaRuleConflict(ruleTypes: {rule.type}));
      }
      if (rule.type == AgendaRuleType.maximumCategoryDays &&
          lockedConsecutiveDays > AgendaRuleEvaluator.maximumOf(rule)) {
        conflicts.add(AgendaRuleConflict(ruleTypes: {rule.type}));
      }
    }
    return List.unmodifiable(conflicts);
  }
}

class AgendaRuleEvaluator {
  const AgendaRuleEvaluator();

  List<AgendaRuleEvaluation> evaluate({required DateTime date,
      required List<AgendaRule> rules, required List<PlannedOutfit> previous,
      required Outfit selected, Set<OutfitCategory> lockedCategories = const {}}) {
    return rules.where((rule) => rule.enabled).map((rule) {
      final category = categoryOf(rule);
      if (rule.type != AgendaRuleType.maximumFullOutfitDays && category == null) {
        return AgendaRuleEvaluation(ruleType: rule.type,
          status: AgendaRuleEvaluationStatus.notApplicable,
          reason: 'missingRuleCategory', date: date);
      }
      if (category != null && lockedCategories.contains(category) &&
          (rule.type == AgendaRuleType.refreshCategory ||
           rule.type == AgendaRuleType.alternateCategory ||
           rule.type == AgendaRuleType.maximumCategoryDays &&
             previous.isNotEmpty && previous.last.outfit != null &&
             _categoryRun(previous, category) >= maximumOf(rule))) {
        return AgendaRuleEvaluation(ruleType: rule.type,
          status: AgendaRuleEvaluationStatus.conflicting,
          reason: 'conflictingAgendaRules', date: date);
      }
      if (previous.isEmpty || previous.last.outfit == null) {
        return AgendaRuleEvaluation(ruleType: rule.type,
          status: AgendaRuleEvaluationStatus.notApplicable,
          reason: 'noPreviousPlannedOutfit', date: date);
      }
      final satisfied = switch (rule.type) {
        AgendaRuleType.refreshCategory || AgendaRuleType.alternateCategory =>
          !_sameCategory(previous.last.outfit!, selected, category!),
        AgendaRuleType.maximumCategoryDays =>
          _categoryRun(previous, category!) < maximumOf(rule) ||
            !_sameCategory(previous.last.outfit!, selected, category),
        AgendaRuleType.maximumFullOutfitDays =>
          _outfitRun(previous) < maximumOf(rule) ||
            _signature(previous.last.outfit!) != _signature(selected),
      };
      return AgendaRuleEvaluation(ruleType: rule.type,
        status: satisfied ? AgendaRuleEvaluationStatus.satisfied :
          AgendaRuleEvaluationStatus.unsatisfied,
        reason: satisfied ? 'ruleSatisfied' : 'noValidAlternative', date: date);
    }).toList(growable: false);
  }

  static OutfitCategory? categoryOf(AgendaRule rule) {
    final raw = rule.parameters['category'];
    return OutfitCategory.values.where((value) => value.name == raw).firstOrNull;
  }
  static int maximumOf(AgendaRule rule) {
    final value = (rule.parameters['days'] as num?)?.toInt() ?? 1;
    return value < 1 ? 1 : value > 365 ? 365 : value;
  }
  static bool _sameCategory(Outfit a, Outfit b, OutfitCategory category) {
    final before = a.itemsFor(category).map((item) => item.id).toSet();
    final after = b.itemsFor(category).map((item) => item.id).toSet();
    return before.length == after.length && before.containsAll(after);
  }
  static int _categoryRun(List<PlannedOutfit> history, OutfitCategory category) {
    final last = history.last.outfit!;
    var count = 0;
    for (final plan in history.reversed) {
      if (plan.outfit == null || !_sameCategory(last, plan.outfit!, category)) break;
      count++;
    }
    return count;
  }
  static int _outfitRun(List<PlannedOutfit> history) {
    final last = _signature(history.last.outfit!);
    var count = 0;
    for (final plan in history.reversed) {
      if (plan.outfit == null || _signature(plan.outfit!) != last) break;
      count++;
    }
    return count;
  }
  static String _signature(Outfit outfit) {
    final ids = outfit.allGarments.map((item) => item.id).toList()..sort();
    return ids.join('|');
  }
}

extension<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
