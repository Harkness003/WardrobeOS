import '../../core/outfit/outfit_engine.dart';
import '../../core/recommendation/recommendation_context.dart';
import '../../data/database_service.dart';
import '../../models/garment.dart';
import '../../models/outfit.dart';
import '../../weather/models/weather_data.dart';
import '../../weather/services/weather_service.dart';
import '../calendar/calendar_event.dart';
import '../calendar/calendar_service.dart';
import 'agenda_models.dart';

typedef AgendaClock = DateTime Function();

class AgendaService {
  final DatabaseService database;
  final OutfitEngine outfitEngine;
  final CalendarService calendarService;
  final WeatherService? weatherService;
  final AgendaClock clock;

  AgendaService({required this.database, required this.calendarService, this.weatherService,
    this.outfitEngine = const OutfitEngine(), this.clock = DateTime.now});

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
    final outfits = await _loadOutfits();
    final wardrobe = await database.getGarments();
    final event = await _optionalEvent(date);
    final weather = await _optionalWeather();
    final context = RecommendationContext(
      occasion: event?.formality.label,
      weather: weather == null ? null : RecommendationWeather(
        temperature: weather.temperature, condition: weather.description),
    );
    Outfit? choice;
    OutfitReuseKind reuse = OutfitReuseKind.none;
    final last = previous.isEmpty ? null : previous.last;
    final repeated = last == null ? 0 : _consecutive(previous, last.outfitId);
    if (preferences.allowCompleteOutfitReuse && last?.outfit != null &&
        (preferences.strategy == PlanningStrategy.minimal || preferences.strategy == PlanningStrategy.professional) &&
        repeated < preferences.maximumConsecutiveDays) {
      choice = last!.outfit;
      reuse = OutfitReuseKind.complete;
    } else if (last?.outfit != null && preferences.strategy == PlanningStrategy.economical) {
      choice = _partialVariant(last!.outfit!, wardrobe, context, preferences);
      reuse = choice == null ? OutfitReuseKind.none : OutfitReuseKind.partial;
    }
    choice ??= _chooseSaved(outfits, previous, preferences, date);
    choice ??= outfitEngine.generateBestOutfit(wardrobe: wardrobe, context: context);
    if (choice == null) return null;
    if (choice.id.startsWith('generated-') || reuse == OutfitReuseKind.partial) {
      choice = _cloneWithId(choice, 'agenda-${date.microsecondsSinceEpoch}');
    }
    await _ensureStored(choice);
    final now = clock();
    final value = PlannedOutfit(id: 'plan-${_day(date).millisecondsSinceEpoch}', date: _day(date),
      outfitId: choice.id, outfit: choice, origin: PlanningOrigin.automatic,
      strategy: preferences.strategy, status: PlannedOutfitStatus.proposed,
      justification: _explanation(preferences.strategy, reuse, weather, event),
      weather: weather, event: event, reuseKind: reuse, createdAt: now, updatedAt: now);
    await database.savePlannedOutfit(value);
    return value;
  }

  Future<List<PlannedOutfit>> proposePeriod(DateTime from, int days, AgendaPreferences preferences) async {
    final generated = <PlannedOutfit>[];
    for (var offset = 0; offset < days; offset++) {
      try {
        final value = await proposeDay(_day(from).add(Duration(days: offset)), preferences, previous: generated);
        if (value != null) generated.add(value);
      } catch (_) {
        // A day is deliberately isolated: saved days and following proposals survive.
      }
    }
    return List.unmodifiable(generated);
  }

  Future<List<Outfit>> _loadOutfits() async {
    final values = await database.getAllOutfits();
    final result = <Outfit>[];
    for (final value in values) {
      final garments = await database.getGarmentsInOutfit(value.id);
      result.add(value.copyWith(garments: _group(garments)));
    }
    return result;
  }

  Outfit? _chooseSaved(List<Outfit> outfits, List<PlannedOutfit> previous,
      AgendaPreferences preferences, DateTime date) {
    if (outfits.isEmpty) return null;
    final used = previous.map((item) => item.outfitId).toSet();
    final ranked = [...outfits]..sort((a, b) {
      if (preferences.strategy == PlanningStrategy.rotation) {
        final ad = a.lastWorn ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.lastWorn ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ad.compareTo(bd);
      }
      if (preferences.strategy == PlanningStrategy.comfort) {
        return (b.favorite ? 1 : 0).compareTo(a.favorite ? 1 : 0);
      }
      if (preferences.strategy == PlanningStrategy.elegance) {
        return (b.score?.styleCoherence.value ?? 0).compareTo(a.score?.styleCoherence.value ?? 0);
      }
      return 0;
    });
    if (preferences.strategy == PlanningStrategy.variety || preferences.varietyLevel >= .7) {
      return ranked.where((item) => !used.contains(item.id)).firstOrNull ?? ranked.first;
    }
    return ranked.first;
  }

  Outfit? _partialVariant(Outfit base, List<Garment> wardrobe,
      RecommendationContext context, AgendaPreferences preferences) {
    final variants = outfitEngine.generateAlternatives(base, wardrobe: wardrobe, context: context, limit: 8);
    for (final variant in variants) {
      final changed = OutfitCategory.values.where((category) =>
        _ids(base.itemsFor(category)).join() != _ids(variant.itemsFor(category)).join()).toSet();
      if (changed.isNotEmpty && changed.every((category) => !preferences.reusableCategories.contains(category))) {
        return variant;
      }
    }
    return variants.firstOrNull;
  }

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

  static int _consecutive(List<PlannedOutfit> values, String id) {
    var count = 0;
    for (final value in values.reversed) { if (value.outfitId != id) break; count++; }
    return count;
  }
  static Set<String> _ids(List<Garment> values) => values.map((item) => item.id).toSet();
  static Map<OutfitCategory, List<Garment>> _group(List<Garment> garments) {
    final result = <OutfitCategory, List<Garment>>{};
    for (final item in garments) { result.putIfAbsent(OutfitEngine.categoryFor(item), () => []).add(item); }
    return result;
  }
  static Outfit _cloneWithId(Outfit source, String id) => Outfit(id: id, name: source.name,
    season: source.season, favorite: source.favorite, createdAt: DateTime.now(), updatedAt: DateTime.now(),
    garments: source.garments, score: source.score, justification: source.justification);
  static String _explanation(PlanningStrategy strategy, OutfitReuseKind reuse,
      WeatherData? weather, CalendarEvent? event) {
    if (reuse == OutfitReuseKind.complete) return 'Tenue identique conservée conformément à vos préférences du mode ${strategy.label.toLowerCase()}.';
    if (reuse == OutfitReuseKind.partial) return 'Certaines pièces réutilisables sont conservées pour limiter les lessives.';
    if (strategy == PlanningStrategy.weather && weather != null) return 'Tenue choisie en priorité pour les conditions météo disponibles.';
    if (strategy == PlanningStrategy.weather) return 'Météo indisponible : proposition fondée sur les informations du dressing.';
    if (event != null) return 'Tenue adaptée à « ${event.title} » et au mode ${strategy.label.toLowerCase()}.';
    return 'Proposition fondée sur le mode ${strategy.label.toLowerCase()}, sans événement imposé.';
  }
  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}

extension<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
