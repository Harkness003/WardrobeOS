import '../../core/ai_context/wardrobe_ai_context_service.dart';
import '../../core/outfit_generation/outfit_generation_engine.dart';
import '../../core/recommendation/recommendation_context.dart';
import '../../data/database_service.dart';
import '../../models/outfit.dart';
import '../../models/garment.dart';
import '../../weather/models/weather_data.dart';
import '../../weather/services/weather_service.dart';
import '../calendar/calendar_event.dart';
import '../calendar/calendar_event_context_mapper.dart';
import '../calendar/calendar_service.dart';
import 'agenda_models.dart';
import 'agenda_rule_evaluator.dart';
import '../../core/diagnostics/diagnostic_service.dart';

typedef AgendaClock = DateTime Function();

/// Selection policy kept separate from generation so future work/weekend/travel
/// planners can select among central-engine proposals without duplicating it.
abstract interface class AgendaProposalSelector {
  OutfitGenerationProposal? select({
    required DateTime date,
    required OutfitGenerationResult result,
    required List<PlannedOutfit> previous,
    required AgendaPreferences preferences,
  });
}

class DefaultAgendaProposalSelector implements AgendaProposalSelector {
  const DefaultAgendaProposalSelector();

  @override
  OutfitGenerationProposal? select({required DateTime date,
      required OutfitGenerationResult result, required List<PlannedOutfit> previous,
      required AgendaPreferences preferences}) {
    if (result.proposals.isEmpty) return null;
    final prior = previous.isEmpty ? null : previous.last.outfit;
    final used = previous.map((plan) => _signature(plan.outfit)).whereType<String>().toSet();
    double agendaScore(OutfitGenerationProposal proposal) {
      final overlap = _overlap(prior, proposal.outfit);
      final repeated = used.contains(_signature(proposal.outfit));
      final strategyScore = switch (preferences.strategy) {
        PlanningStrategy.minimal => proposal.score + overlap * .35,
        PlanningStrategy.economical => proposal.score + _reusableOverlap(prior, proposal.outfit, preferences) * .25,
        PlanningStrategy.rotation => proposal.score,
        PlanningStrategy.variety => proposal.score - overlap * _varietyWeight(preferences.varietyLevel),
        PlanningStrategy.elegance => proposal.score * 1.25,
        PlanningStrategy.comfort => proposal.score + proposal.outfit.allGarments.where((g) => g.isFavorite).length * .04,
        PlanningStrategy.weather => proposal.score,
        PlanningStrategy.professional || PlanningStrategy.custom => proposal.score - (repeated ? .03 : 0),
      };
      // Custom rules are strong selection preferences, but deliberately remain
      // non-blocking for small wardrobes.
      var customScore = 0.0;
      for (final rule in preferences.customRules.where((item) => item.enabled)) {
        if (rule.type == AgendaRuleType.maximumFullOutfitDays) {
          final maximum = (rule.parameters['days'] as num?)?.toInt() ?? 1;
          if (_consecutiveOutfit(previous) >= maximum) {
            customScore += repeated ? -1 : 1;
          }
          continue;
        }
        final category = _ruleCategory(rule);
        if (category == null || prior == null) continue;
        final same = _sameCategoryItems(prior, proposal.outfit, category);
        switch (rule.type) {
          case AgendaRuleType.refreshCategory:
          case AgendaRuleType.alternateCategory:
            customScore += same ? -.8 : .8;
          case AgendaRuleType.maximumCategoryDays:
            final maximum = (rule.parameters['days'] as num?)?.toInt() ?? 1;
            if (_consecutiveCategory(previous, category) >= maximum) {
              customScore += same ? -1 : 1;
            }
          case AgendaRuleType.maximumFullOutfitDays:
            break;
        }
      }
      return strategyScore + customScore;
    }
    final ranked = [...result.proposals]..sort((a, b) => agendaScore(b).compareTo(agendaScore(a)));
    return ranked.first;
  }

  static String? _signature(Outfit? outfit) {
    if (outfit == null) return null;
    final ids = outfit.allGarments.map((garment) => garment.id).toList()..sort();
    return ids.join('|');
  }
  static double _overlap(Outfit? a, Outfit b) {
    if (a == null || b.allGarments.isEmpty) return 0;
    final ids = a.allGarments.map((item) => item.id).toSet();
    return b.allGarments.where((item) => ids.contains(item.id)).length / b.allGarments.length;
  }
  static double _reusableOverlap(Outfit? a, Outfit b, AgendaPreferences preferences) {
    if (a == null) return 0;
    final reusable = preferences.reusableCategories.expand(a.itemsFor).map((item) => item.id).toSet();
    final candidates = preferences.reusableCategories.expand(b.itemsFor).toList();
    return candidates.isEmpty ? 0 : candidates.where((item) => reusable.contains(item.id)).length / candidates.length;
  }
  static double _varietyWeight(AgendaVarietyLevel value) => switch (value) {
    AgendaVarietyLevel.low => .08, AgendaVarietyLevel.balanced => .18, AgendaVarietyLevel.high => .30,
  };
  static OutfitCategory? _ruleCategory(AgendaRule rule) {
    final raw = rule.parameters['category'];
    return OutfitCategory.values.where((item) => item.name == raw).firstOrNull;
  }
  static bool _sameCategoryItems(Outfit a, Outfit b, OutfitCategory category) {
    final before = a.itemsFor(category).map((item) => item.id).toSet();
    final after = b.itemsFor(category).map((item) => item.id).toSet();
    return before.length == after.length && before.containsAll(after);
  }
  static int _consecutiveCategory(List<PlannedOutfit> history, OutfitCategory category) {
    if (history.isEmpty || history.last.outfit == null) return 0;
    final last = history.last.outfit!;
    var count = 0;
    for (final plan in history.reversed) {
      if (plan.outfit == null || !_sameCategoryItems(last, plan.outfit!, category)) break;
      count++;
    }
    return count;
  }
  static int _consecutiveOutfit(List<PlannedOutfit> history) {
    if (history.isEmpty) return 0;
    final signature = _signature(history.last.outfit);
    var count = 0;
    for (final plan in history.reversed) {
      if (_signature(plan.outfit) != signature) break;
      count++;
    }
    return count;
  }
}

class AgendaService {
  final DatabaseService database;
  final OutfitGenerationEngine outfitGenerationEngine;
  final AgendaProposalSelector proposalSelector;
  final CalendarService calendarService;
  final WeatherService? weatherService;
  final AgendaClock clock;
  final WardrobeAiContextService aiContextService;
  final CalendarEventContextMapper calendarEventContextMapper;
  AgendaGenerationReport lastReport = const AgendaGenerationReport();

  AgendaService({required this.database, required this.calendarService,
    required this.aiContextService, this.weatherService,
    this.outfitGenerationEngine = const OutfitGenerationEngine(),
    this.proposalSelector = const DefaultAgendaProposalSelector(),
    this.calendarEventContextMapper = const CalendarEventContextMapper(),
    this.clock = DateTime.now});

  Future<List<PlannedOutfit>> loadPeriod(DateTime from, DateTime to) =>
      database.getPlannedOutfits(_day(from), _day(to));
  Future<AgendaPreferences> loadPreferences() => database.getAgendaPreferences();
  Future<void> savePreferences(AgendaPreferences value) => database.saveAgendaPreferences(value);

  Future<PlannedOutfit> plan({required DateTime date, required Outfit outfit,
    PlanningStrategy strategy = PlanningStrategy.rotation,
    PlanningOrigin origin = PlanningOrigin.manual, String justification = 'Tenue choisie par vous.'}) async {
    await _ensureStored(outfit);
    final now = clock();
    final value = PlannedOutfit(id: 'plan-${_day(date).millisecondsSinceEpoch}', date: _day(date),
      outfitId: outfit.id, outfit: outfit, origin: origin, strategy: strategy,
      status: origin == PlanningOrigin.manual ? PlannedOutfitStatus.confirmed : PlannedOutfitStatus.proposed,
      justification: justification, createdAt: now, updatedAt: now);
    await database.savePlannedOutfit(value);
    return value;
  }

  Future<PlannedOutfit> replace(PlannedOutfit current, Outfit replacement,
      {OutfitReuseKind reuseKind = OutfitReuseKind.none, String? justification}) async {
    await _ensureStored(replacement);
    final changed = current.copyWith(outfit: replacement, outfitId: replacement.id,
      status: PlannedOutfitStatus.proposed, reuseKind: reuseKind,
      justification: justification ?? 'Tenue remplacée selon votre choix.', updatedAt: clock());
    await database.savePlannedOutfit(changed);
    return changed;
  }

  /// Regenerates one day through the canonical engine while retaining every
  /// category except [category]. Passing null changes the complete outfit.
  Future<PlannedOutfit?> changePlannedOutfit(PlannedOutfit current,
      {OutfitCategory? category}) async {
    final existing = current.outfit;
    if (existing == null) return null;
    final wardrobe = (await aiContextService.build()).garments;
    final calendar = await _events(current.date);
    final weather = await _optionalWeather();
    final events = calendar.available ? calendar.events : const <CalendarEvent>[];
    final locked = category == null
        ? const <Garment>{}
        : existing.allGarments
            .where((item) => !_matchesReplacementCategory(item, category))
            .toSet();
    final lockedCategories = locked
        .map(OutfitGenerationEngine.categoryFor).toSet();
    final result = outfitGenerationEngine.generate(OutfitGenerationRequest(
      wardrobe: wardrobe,
      context: _recommendationContext(current.date, events, weather),
      preferences: _recommendationPreferences(
        (await loadPreferences())),
      proposalCount: 5,
      lockedGarments: locked,
      lockedCategories: lockedCategories,
      replaceCategory: category,
      excludedOutfitSignatures: {_outfitSignature(existing)},
      excludedGarmentIds: category == null ? const {} : existing.allGarments
        .where((item) => _matchesReplacementCategory(item, category))
        .map((item) => item.id).toSet(),
    ));
    if (result.proposals.isEmpty) return null;
    final proposal = result.proposals.first;
    final replacement = _withAgendaId(proposal.outfit, current.date);
    return replace(current, replacement,
      reuseKind: _reuseKind(existing, replacement),
      justification: _justification(proposal,
        calendarAvailable: calendar.available));
  }

  Future<void> remove(PlannedOutfit value) => database.deletePlannedOutfit(value.id);
  Future<PlannedOutfit> confirm(PlannedOutfit value) => _setStatus(value, PlannedOutfitStatus.confirmed);

  Future<PlannedOutfit> markWorn(PlannedOutfit value) async {
    if (value.wearRecordedAt != null || value.status == PlannedOutfitStatus.worn) return value;
    // Re-read the durable guard: callers may retry with the original stale
    // PlannedOutfit instance after the first request already committed.
    final persisted = (await database.getPlannedOutfits(
      _day(value.date), _day(value.date).add(const Duration(days: 1))))
      .where((plan) => plan.id == value.id).firstOrNull;
    if (persisted?.wearRecordedAt != null ||
        persisted?.status == PlannedOutfitStatus.worn) {
      return persisted!;
    }
    final wornAt = value.date.isAfter(clock()) ? clock() : value.date;
    final recorded = await database.recordOutfitWear(value.outfitId, wornAt: wornAt);
    if (!recorded) throw StateError('La tenue ne contient plus de vêtements disponibles.');
    final updated = value.copyWith(status: PlannedOutfitStatus.worn,
      wearRecordedAt: clock(), updatedAt: clock());
    await database.savePlannedOutfit(updated);
    return updated;
  }

  Future<PlannedOutfit> _setStatus(PlannedOutfit value, PlannedOutfitStatus status) async {
    final updated = value.copyWith(status: status, updatedAt: clock());
    await database.savePlannedOutfit(updated);
    return updated;
  }

  Future<PlannedOutfit?> proposeDay(DateTime date, AgendaPreferences preferences,
      {List<PlannedOutfit> previous = const [], PlannedOutfit? excluding}) async {
    final diagnostics = DiagnosticService.instance;
    final correlationId = diagnostics.newCorrelationId('agenda-day');
    diagnostics.publish(module: DiagnosticModule.agenda, level: AppDiagnosticLevel.info,
      state: 'Demandée', summary: 'Génération quotidienne demandée',
      source: 'AgendaService.proposeDay', correlationId: correlationId,
      details: {'date': _day(date).toIso8601String()});
    // build() deliberately reloads database garments on every proposal. Never
    // substitute saved-outfit garments: they may predate a recent edit.
    final wardrobe = (await aiContextService.build()).garments;
    final calendar = await _events(date);
    final weather = await _optionalWeather();
    final events = calendar.available ? calendar.events : const <CalendarEvent>[];
    final conflict = _eventConflict(events);
    if (conflict != null) throw StateError(conflict);
    final context = _recommendationContext(date, events, weather);
    final result = outfitGenerationEngine.generate(OutfitGenerationRequest(
      wardrobe: wardrobe,
      context: context,
      preferences: _recommendationPreferences(preferences),
      proposalCount: 3,
      excludedOutfitSignatures: {
        if (excluding?.outfit case final outfit?) _outfitSignature(outfit),
      },
    ));
    final proposal = proposalSelector.select(date: date, result: result,
      previous: previous, preferences: preferences);
    if (proposal == null) {
      diagnostics.publish(module: DiagnosticModule.outfits, level: AppDiagnosticLevel.warning,
        state: 'Impossible', summary: 'Aucune tenue complète compatible avec le dressing',
        source: 'AgendaService.proposeDay', correlationId: correlationId,
        reason: 'noCompleteOutfit');
      return null;
    }
    final choice = _withAgendaId(proposal.outfit, date);
    final now = clock();
    final value = PlannedOutfit(id: 'plan-${_day(date).millisecondsSinceEpoch}', date: _day(date),
      outfitId: choice.id, outfit: choice, origin: PlanningOrigin.automatic,
      strategy: preferences.strategy, status: PlannedOutfitStatus.proposed,
      justification: _justification(proposal, calendarAvailable: calendar.available), weather: weather, event: events.firstOrNull,
      createdAt: now, updatedAt: now);
    await database.persistAgendaProposal(choice, value);
    diagnostics.publish(module: DiagnosticModule.outfits, level: AppDiagnosticLevel.success,
      state: 'Générée', summary: 'Proposition quotidienne générée',
      source: 'AgendaService.proposeDay', correlationId: correlationId,
      details: {'calendarApplied': events.isNotEmpty, 'weatherApplied': weather != null});
    return value;
  }

  Future<List<PlannedOutfit>> proposePeriod(DateTime from, int days,
      AgendaPreferences preferences, {List<PlannedOutfit> existing = const [],
      Set<OutfitCategory> lockedCategories = const {}}) async {
    final generated = <PlannedOutfit>[];
    final failures = <AgendaDayFailure>[];
    final evaluations = <AgendaRuleEvaluation>[];
    final conflicts = const AgendaRuleConflictDetector().detect(
      rules: preferences.customRules, lockedCategories: lockedCategories,
      lockedConsecutiveDays: days);
    if (conflicts.isNotEmpty) {
      final date = _day(from);
      failures.add(AgendaDayFailure(dayIndex: 1, date: date,
        phase: AgendaDayPhase.proposalSelection,
        result: AgendaDayResult.businessUnavailable,
        reason: 'conflictingAgendaRules'));
      for (final conflict in conflicts) {
        for (final type in conflict.ruleTypes) {
          evaluations.add(AgendaRuleEvaluation(ruleType: type,
            status: AgendaRuleEvaluationStatus.conflicting,
            reason: conflict.reason, date: date));
        }
      }
      lastReport = AgendaGenerationReport(failures: List.unmodifiable(failures),
        customRulesActive: preferences.customRules.where((r) => r.enabled).length,
        ruleConflict: true, conflictCount: conflicts.length,
        ruleEvaluations: List.unmodifiable(evaluations));
      return const [];
    }
    var calendarAvailable = true;
    final history = [...existing]..sort((a, b) => a.date.compareTo(b.date));
    // One immutable wardrobe snapshot and one weather request per generation.
    final wardrobe = (await aiContextService.build()).garments;
    final weather = await _optionalWeather();
    for (var offset = 0; offset < days; offset++) {
      final date = _day(from).add(Duration(days: offset));
      if (history.any((item) => _sameDay(item.date, date))) continue;
      var phase = AgendaDayPhase.agendaContext;
      try {
        final calendar = await _events(date);
        calendarAvailable = calendarAvailable && calendar.available;
        final events = calendar.available ? calendar.events : const <CalendarEvent>[];
        final conflict = _eventConflict(events);
        if (conflict != null) {
          failures.add(AgendaDayFailure(dayIndex: offset + 1, date: date,
            phase: AgendaDayPhase.agendaContext,
            result: AgendaDayResult.businessUnavailable,
            reason: 'incompatibleEventContexts'));
          _publishDayFailure(offset, date, failures.last);
          continue;
        }
        phase = AgendaDayPhase.outfitGeneration;
        final context = _recommendationContext(date, events, weather, preferences: preferences);
        final result = outfitGenerationEngine.generate(OutfitGenerationRequest(
          wardrobe: wardrobe, context: context,
          preferences: _recommendationPreferences(preferences), proposalCount: 3));
        phase = AgendaDayPhase.proposalSelection;
        final reusable = _completeReuse(history, preferences);
        final proposal = reusable == null
          ? proposalSelector.select(date: date, result: result, previous: history, preferences: preferences)
          : OutfitGenerationProposal(outfit: reusable,
              score: reusable.score?.overallConfidence.value ?? 1,
              reasons: const ['Tenue maintenue conformément au mode Minimal.']);
        if (proposal == null) {
          failures.add(AgendaDayFailure(dayIndex: offset + 1, date: date,
            phase: phase, result: AgendaDayResult.businessUnavailable,
            reason: result.diagnostic.failure?.name ?? 'noCompleteOutfit'));
          _publishDayFailure(offset, date, failures.last);
          continue;
        }
        phase = AgendaDayPhase.plannedOutfitConstruction;
        final value = await _saveProposal(date, preferences, proposal, weather, events.firstOrNull,
          reuseKind: reusable == null ? _reuseKind(history.isEmpty ? null : history.last.outfit, proposal.outfit) : OutfitReuseKind.complete,
          calendarAvailable: calendar.available,
          beforePersistence: () => phase = AgendaDayPhase.persistOutfit);
        generated.add(value);
        evaluations.addAll(const AgendaRuleEvaluator().evaluate(date: date,
          rules: preferences.customRules, previous: history,
          selected: proposal.outfit, lockedCategories: lockedCategories));
        history.add(value);
      } catch (error) {
        final engineError = error is OutfitGenerationException ? error : null;
        final persistenceError = error is AgendaPersistenceException ? error : null;
        phase = persistenceError?.phase ?? phase;
        final failure = AgendaDayFailure(dayIndex: offset + 1, date: date,
          phase: phase, result: AgendaDayResult.technicalFailure,
          reason: _technicalReason(phase, error),
          technicalType: engineError?.exceptionType ??
            persistenceError?.technicalType ?? error.runtimeType.toString(),
          databaseTable: persistenceError?.table,
          databaseConstraint: persistenceError?.constraint,
          foreignKeyTarget: persistenceError?.foreignKeyTarget,
          outfitExists: persistenceError?.outfitExists,
          selectedGarments: persistenceError?.selectedGarments,
          existingGarments: persistenceError?.existingGarments,
          missingGarments: persistenceError?.missingGarments);
        failures.add(failure);
        _publishDayFailure(offset, date, failure,
          enginePhase: engineError?.phase.name);
      }
    }
    final activeRules = preferences.customRules.where((rule) => rule.enabled).length;
    final fullReuse = generated.where((item) => item.reuseKind == OutfitReuseKind.complete).length;
    final partialReuse = generated.where((item) => item.reuseKind == OutfitReuseKind.partial ||
      item.reuseKind == OutfitReuseKind.variant).length;
    final uniqueGarments = generated.expand((item) => item.outfit?.allGarments ?? const <Garment>[])
      .map((item) => item.id).toSet().length;
    lastReport = AgendaGenerationReport(generated: List.unmodifiable(generated),
      failures: List.unmodifiable(failures), calendarAvailable: calendarAvailable,
      fullReuse: fullReuse, partialReuse: partialReuse,
      newOutfits: generated.length - fullReuse - partialReuse,
      uniqueGarments: uniqueGarments, customRulesActive: activeRules,
      rulesSatisfied: evaluations.where((item) => item.status == AgendaRuleEvaluationStatus.satisfied).length,
      rulesUnsatisfied: evaluations.where((item) => item.status == AgendaRuleEvaluationStatus.unsatisfied).length,
      rulesNotApplicable: evaluations.where((item) => item.status == AgendaRuleEvaluationStatus.notApplicable).length,
      ruleConflict: evaluations.any((item) => item.status == AgendaRuleEvaluationStatus.conflicting),
      conflictCount: conflicts.length,
      ruleEvaluations: List.unmodifiable(evaluations));
    return List.unmodifiable(generated);
  }

  RecommendationContext _recommendationContext(DateTime date, List<CalendarEvent> events,
      WeatherData? weather, {AgendaPreferences? preferences}) {
    final mapped = calendarEventContextMapper.map(
    date: date,
    events: events,
    weather: weather == null ? null : RecommendationWeather(
      temperature: weather.temperature, condition: weather.description,
      windSpeed: weather.windSpeed,
      isRaining: weather.weatherCode >= 51 && weather.weatherCode <= 82),
    );
    if (preferences?.strategy != PlanningStrategy.professional || !preferences!.workDays.contains(date.weekday)) return mapped;
    return RecommendationContext(season: mapped.season, occasion: 'travail', desiredStyle: mapped.desiredStyle,
      weather: mapped.weather, metadata: {...mapped.metadata, 'agendaWorkDay': true});
  }

  static RecommendationPreferences _recommendationPreferences(AgendaPreferences value) =>
      const RecommendationPreferences();

  Future<void> _ensureStored(Outfit outfit) async {
    if (await database.getOutfitById(outfit.id) == null) await database.createOutfit(outfit);
    final garments = List<Garment>.from(outfit.allGarments, growable: false);
    for (final garment in garments) {
      await database.addGarmentToOutfit(outfit.id, garment.id);
    }
  }

  Future<({bool available, List<CalendarEvent> events})> _events(DateTime date) async {
    try { return (events: await calendarService.getTodayEvents(day: date),
      available: calendarService is! CalendarAvailability ||
          (calendarService as CalendarAvailability).isCalendarAvailable); }
    catch (_) { return (events: const <CalendarEvent>[], available: false); }
  }
  Future<WeatherData?> _optionalWeather() async {
    try { return await weatherService?.getCurrentWeather(); } catch (_) { return null; }
  }

  Outfit _withAgendaId(Outfit source, DateTime date) {
    final now = clock();
    return Outfit(id: 'agenda-${_day(date).millisecondsSinceEpoch}-${now.microsecondsSinceEpoch}',
      name: source.name, season: source.season, favorite: source.favorite,
      createdAt: now, updatedAt: now, garments: source.garments,
      score: source.score, justification: source.justification);
  }
  Future<PlannedOutfit> _saveProposal(DateTime date, AgendaPreferences preferences,
      OutfitGenerationProposal proposal, WeatherData? weather, CalendarEvent? event,
      {required bool calendarAvailable, OutfitReuseKind reuseKind = OutfitReuseKind.none,
      void Function()? beforePersistence}) async {
    final choice = _withAgendaId(proposal.outfit, date);
    final now = clock();
    final value = PlannedOutfit(id: 'plan-${_day(date).millisecondsSinceEpoch}', date: _day(date),
      outfitId: choice.id, outfit: choice, origin: PlanningOrigin.automatic,
      strategy: preferences.strategy, status: PlannedOutfitStatus.proposed,
      justification: _justification(proposal, calendarAvailable: calendarAvailable), weather: weather, event: event,
      reuseKind: reuseKind,
      createdAt: now, updatedAt: now);
    beforePersistence?.call();
    await database.persistAgendaProposal(choice, value);
    return value;
  }

  static Outfit? _completeReuse(List<PlannedOutfit> history, AgendaPreferences preferences) {
    if (preferences.strategy != PlanningStrategy.minimal || !preferences.allowCompleteOutfitReuse || history.isEmpty) return null;
    final active = preferences.customRules.where((rule) => rule.enabled);
    if (active.any((rule) => rule.type == AgendaRuleType.refreshCategory ||
        rule.type == AgendaRuleType.alternateCategory)) {
      return null;
    }
    for (final rule in active.where((rule) => rule.type == AgendaRuleType.maximumCategoryDays)) {
      final category = DefaultAgendaProposalSelector._ruleCategory(rule);
      final maximum = (rule.parameters['days'] as num?)?.toInt() ?? 1;
      if (category != null &&
          DefaultAgendaProposalSelector._consecutiveCategory(history, category) >= maximum) {
        return null;
      }
    }
    final last = history.last.outfit;
    if (last == null) return null;
    final signature = DefaultAgendaProposalSelector._signature(last);
    var consecutive = 0;
    for (final plan in history.reversed) {
      if (DefaultAgendaProposalSelector._signature(plan.outfit) != signature) break;
      consecutive++;
    }
    final customMaximums = preferences.customRules.where((rule) => rule.enabled &&
      rule.type == AgendaRuleType.maximumFullOutfitDays)
      .map((rule) => (rule.parameters['days'] as num?)?.toInt())
      .whereType<int>();
    final maximum = customMaximums.isEmpty ? preferences.maximumConsecutiveDays
      : customMaximums.reduce((a, b) => a < b ? a : b);
    return consecutive < maximum ? last : null;
  }
  static OutfitReuseKind _reuseKind(Outfit? previous, Outfit current) {
    if (previous == null) return OutfitReuseKind.none;
    final before = previous.allGarments.map((item) => item.id).toSet();
    final after = current.allGarments.map((item) => item.id).toSet();
    if (before.length == after.length && before.containsAll(after)) return OutfitReuseKind.complete;
    final shared = before.intersection(after).length;
    if (shared == 0) return OutfitReuseKind.none;
    return shared >= after.length - 1 ? OutfitReuseKind.variant : OutfitReuseKind.partial;
  }

  static String _technicalReason(AgendaDayPhase phase, Object error) {
    if (error is AgendaPersistenceException) return error.reason;
    if (error is OutfitGenerationException) return 'outfitGenerationFailure';
    return switch (phase) {
      AgendaDayPhase.agendaContext => 'agendaContextFailure',
      AgendaDayPhase.outfitGeneration => 'outfitGenerationFailure',
      AgendaDayPhase.proposalSelection => 'proposalSelectionFailure',
      AgendaDayPhase.plannedOutfitConstruction => 'mappingFailure',
      AgendaDayPhase.persistOutfit ||
      AgendaDayPhase.persistOutfitItems ||
      AgendaDayPhase.persistPlannedOutfit => 'databaseWriteFailure',
    };
  }

  static void _publishDayFailure(int offset, DateTime date,
      AgendaDayFailure failure, {String? enginePhase}) {
    DiagnosticService.instance.publish(module: DiagnosticModule.agenda,
      level: failure.result == AgendaDayResult.businessUnavailable
        ? AppDiagnosticLevel.warning : AppDiagnosticLevel.error,
      state: failure.result == AgendaDayResult.businessUnavailable
        ? 'Impossible' : 'Échec',
      summary: 'Journée Agenda non planifiée',
      source: 'AgendaService.proposePeriod', reason: failure.reason,
      details: {
        'dayIndex': offset + 1,
        'date': _day(date).toIso8601String(),
        'phase': failure.phase.name,
        'result': failure.result.name,
        if (failure.technicalType != null) 'technicalType': failure.technicalType,
        if (failure.databaseTable != null) 'databaseTable': failure.databaseTable,
        if (failure.databaseConstraint != null)
          'databaseConstraint': failure.databaseConstraint,
        if (failure.foreignKeyTarget != null)
          'foreignKeyTarget': failure.foreignKeyTarget,
        if (failure.outfitExists != null) 'outfitExists': failure.outfitExists,
        if (failure.selectedGarments != null)
          'selectedGarments': failure.selectedGarments,
        if (failure.existingGarments != null)
          'existingGarments': failure.existingGarments,
        if (failure.missingGarments != null)
          'missingGarments': failure.missingGarments,
        if (enginePhase != null) 'enginePhase': enginePhase,
      });
  }
  static String _justification(OutfitGenerationProposal proposal, {required bool calendarAvailable}) {
    final reasons = proposal.reasons.join(' ');
    if (calendarAvailable) return reasons;
    return [
      'Calendrier indisponible, proposition générée sans contexte événement.',
      if (reasons.trim().isNotEmpty) reasons,
    ].join(' ');
  }

  static String? _eventConflict(List<CalendarEvent> events) {
    final formalities = events.map((event) => event.formality).toSet();
    if (formalities.contains(EventFormality.sport) &&
        (formalities.contains(EventFormality.formal) || formalities.contains(EventFormality.business))) {
      return 'Conflit entre un événement sportif et un événement formel : aucune tenue unique cohérente.';
    }
    return null;
  }
  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static String _outfitSignature(Outfit outfit) {
    final ids = outfit.allGarments.map((item) => item.id).toList()..sort();
    return ids.join('|');
  }
  static bool _matchesReplacementCategory(Garment item, OutfitCategory category) {
    final actual = OutfitGenerationEngine.categoryFor(item);
    if (category == OutfitCategory.jacket || category == OutfitCategory.coat) {
      return actual == OutfitCategory.jacket || actual == OutfitCategory.coat;
    }
    return actual == category;
  }
  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}

extension<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
