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
    final used = previous.map((plan) => _signature(plan.outfit)).whereType<String>().toSet();
    return result.proposals.where((proposal) => !used.contains(_signature(proposal.outfit))).firstOrNull
        ?? result.proposals.first;
  }

  static String? _signature(Outfit? outfit) {
    if (outfit == null) return null;
    final ids = outfit.allGarments.map((garment) => garment.id).toList()..sort();
    return ids.join('|');
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

  Future<void> remove(PlannedOutfit value) => database.deletePlannedOutfit(value.id);
  Future<PlannedOutfit> confirm(PlannedOutfit value) => _setStatus(value, PlannedOutfitStatus.confirmed);

  Future<PlannedOutfit> markWorn(PlannedOutfit value) async {
    if (value.wearRecordedAt != null || value.status == PlannedOutfitStatus.worn) return value;
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
      {List<PlannedOutfit> previous = const []}) async {
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
      AgendaPreferences preferences, {List<PlannedOutfit> existing = const []}) async {
    final generated = <PlannedOutfit>[];
    final failures = <AgendaDayFailure>[];
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
        final result = outfitGenerationEngine.generate(OutfitGenerationRequest(
          wardrobe: wardrobe, context: _recommendationContext(date, events, weather),
          preferences: _recommendationPreferences(preferences), proposalCount: 3));
        phase = AgendaDayPhase.proposalSelection;
        final proposal = proposalSelector.select(date: date, result: result, previous: history, preferences: preferences);
        if (proposal == null) {
          failures.add(AgendaDayFailure(dayIndex: offset + 1, date: date,
            phase: phase, result: AgendaDayResult.businessUnavailable,
            reason: result.diagnostic.failure?.name ?? 'noCompleteOutfit'));
          _publishDayFailure(offset, date, failures.last);
          continue;
        }
        phase = AgendaDayPhase.plannedOutfitConstruction;
        final value = await _saveProposal(date, preferences, proposal, weather, events.firstOrNull,
          calendarAvailable: calendar.available,
          beforePersistence: () => phase = AgendaDayPhase.persistOutfit);
        generated.add(value);
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
          databaseConstraint: persistenceError?.constraint);
        failures.add(failure);
        _publishDayFailure(offset, date, failure,
          enginePhase: engineError?.phase.name);
      }
    }
    lastReport = AgendaGenerationReport(generated: List.unmodifiable(generated),
      failures: List.unmodifiable(failures), calendarAvailable: calendarAvailable);
    return List.unmodifiable(generated);
  }

  RecommendationContext _recommendationContext(DateTime date, List<CalendarEvent> events,
      WeatherData? weather) => calendarEventContextMapper.map(
    date: date,
    events: events,
    weather: weather == null ? null : RecommendationWeather(
      temperature: weather.temperature, condition: weather.description,
      windSpeed: weather.windSpeed,
      isRaining: weather.weatherCode >= 51 && weather.weatherCode <= 82),
  );

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
      {required bool calendarAvailable, void Function()? beforePersistence}) async {
    final choice = _withAgendaId(proposal.outfit, date);
    final now = clock();
    final value = PlannedOutfit(id: 'plan-${_day(date).millisecondsSinceEpoch}', date: _day(date),
      outfitId: choice.id, outfit: choice, origin: PlanningOrigin.automatic,
      strategy: preferences.strategy, status: PlannedOutfitStatus.proposed,
      justification: _justification(proposal, calendarAvailable: calendarAvailable), weather: weather, event: event,
      createdAt: now, updatedAt: now);
    beforePersistence?.call();
    await database.persistAgendaProposal(choice, value);
    return value;
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
  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}

extension<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
