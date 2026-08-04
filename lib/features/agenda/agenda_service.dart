import '../../core/ai_context/wardrobe_ai_context_service.dart';
import '../../core/outfit_generation/outfit_generation_engine.dart';
import '../../core/recommendation/recommendation_context.dart';
import '../../data/database_service.dart';
import '../../models/outfit.dart';
import '../../weather/models/weather_data.dart';
import '../../weather/services/weather_service.dart';
import '../calendar/calendar_event.dart';
import '../calendar/calendar_service.dart';
import 'agenda_models.dart';

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

  AgendaService({required this.database, required this.calendarService,
    required this.aiContextService, this.weatherService,
    this.outfitGenerationEngine = const OutfitGenerationEngine(),
    this.proposalSelector = const DefaultAgendaProposalSelector(),
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
    // build() deliberately reloads database garments on every proposal. Never
    // substitute saved-outfit garments: they may predate a recent edit.
    final wardrobe = (await aiContextService.build()).garments;
    final event = await _optionalEvent(date);
    final weather = await _optionalWeather();
    final context = _recommendationContext(date, event, weather);
    final result = outfitGenerationEngine.generate(OutfitGenerationRequest(
      wardrobe: wardrobe,
      context: context,
      preferences: _recommendationPreferences(preferences),
      proposalCount: 3,
    ));
    final proposal = proposalSelector.select(date: date, result: result,
      previous: previous, preferences: preferences);
    if (proposal == null) return null;
    final choice = _withAgendaId(proposal.outfit, date);
    await _ensureStored(choice);
    final now = clock();
    final value = PlannedOutfit(id: 'plan-${_day(date).millisecondsSinceEpoch}', date: _day(date),
      outfitId: choice.id, outfit: choice, origin: PlanningOrigin.automatic,
      strategy: preferences.strategy, status: PlannedOutfitStatus.proposed,
      justification: proposal.reasons.join(' '), weather: weather, event: event,
      createdAt: now, updatedAt: now);
    await database.savePlannedOutfit(value);
    return value;
  }

  Future<List<PlannedOutfit>> proposePeriod(DateTime from, int days,
      AgendaPreferences preferences, {List<PlannedOutfit> existing = const []}) async {
    final generated = <PlannedOutfit>[];
    final history = [...existing]..sort((a, b) => a.date.compareTo(b.date));
    for (var offset = 0; offset < days; offset++) {
      final date = _day(from).add(Duration(days: offset));
      if (history.any((item) => _sameDay(item.date, date))) continue;
      try {
        final value = await proposeDay(date, preferences, previous: history);
        if (value != null) { generated.add(value); history.add(value); }
      } catch (_) {
        // Days are isolated so one optional provider cannot erase other plans.
      }
    }
    return List.unmodifiable(generated);
  }

  RecommendationContext _recommendationContext(DateTime date, CalendarEvent? event,
      WeatherData? weather) => RecommendationContext(
    occasion: event?.formality.label,
    weather: weather == null ? null : RecommendationWeather(
      temperature: weather.temperature, condition: weather.description,
      windSpeed: weather.windSpeed,
      isRaining: weather.weatherCode >= 51 && weather.weatherCode <= 82),
    metadata: {'planner': 'agenda', 'date': _day(date).toIso8601String()},
  );

  static RecommendationPreferences _recommendationPreferences(AgendaPreferences value) =>
      const RecommendationPreferences();

  Future<void> _ensureStored(Outfit outfit) async {
    if (await database.getOutfitById(outfit.id) == null) await database.createOutfit(outfit);
    for (final garment in outfit.allGarments) await database.addGarmentToOutfit(outfit.id, garment.id);
  }

  Future<CalendarEvent?> _optionalEvent(DateTime date) async {
    try { final events = await calendarService.getTodayEvents(day: date); return events.firstOrNull; } catch (_) { return null; }
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
  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}

extension<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
