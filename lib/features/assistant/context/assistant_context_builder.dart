import '../../../weather/models/weather_data.dart';
import '../../../weather/services/weather_service.dart';
import '../../calendar/calendar_context_builder.dart';
import '../../outfits/outfits_controller.dart';
import '../../wardrobe/wardrobe_controller.dart';
import '../memory/memory_service.dart';
import '../memory/personalization_snapshot.dart';
import 'assistant_context.dart';
import '../../../core/ai_context/wardrobe_ai_context_service.dart';

typedef AssistantClock = DateTime Function();

class AssistantContextBuilder {
  final WeatherService _weatherService;
  final WardrobeController _wardrobeController;
  final OutfitsController _outfitsController;
  final AssistantClock _clock;
  final CalendarContextBuilder? _calendarContextBuilder;
  final MemoryService? _memoryService;
  final WardrobeAiContextService? _aiContextService;

  const AssistantContextBuilder({
    required WeatherService weatherService,
    required WardrobeController wardrobeController,
    required OutfitsController outfitsController,
    AssistantClock clock = DateTime.now,
    CalendarContextBuilder? calendarContextBuilder,
    MemoryService? memoryService,
    WardrobeAiContextService? aiContextService,
  }) : _weatherService = weatherService,
       _wardrobeController = wardrobeController,
       _outfitsController = outfitsController,
       _clock = clock,
       _calendarContextBuilder = calendarContextBuilder,
       _memoryService = memoryService,
       _aiContextService = aiContextService;

  Future<AssistantContext> build() async {
    final wardrobeContext = await _aiContextService?.build();
    final weatherFuture = _weatherService.getCurrentWeather();
    final calendarFuture = _calendarContextBuilder?.build().then<CalendarContext?>(
      (value) => value,
    ).catchError((_) => null);
    final personalizationFuture = wardrobeContext != null
        ? Future<PersonalizationSnapshot?>.value(wardrobeContext.personalization)
        : _memoryService?.loadSnapshot()
        .then<PersonalizationSnapshot?>((value) => value)
        .catchError((_) => null);
    if (_wardrobeController.loading) await _wardrobeController.load();
    if (_outfitsController.loading) await _outfitsController.load();
    final weather = await weatherFuture
        .then<WeatherData?>((value) => value)
        .catchError((_) => null);
    final now = _clock();

    final currentGarments = wardrobeContext?.garments ?? _wardrobeController.garments;
    final recentGarments =
        currentGarments
            .where((garment) => garment.lastWorn != null)
            .toList()
          ..sort((a, b) => b.lastWorn!.compareTo(a.lastWorn!));
    final wornOutfits =
        _outfitsController.outfits
            .where((outfit) => outfit.lastWorn != null)
            .toList()
          ..sort((a, b) => b.lastWorn!.compareTo(a.lastWorn!));
    final lastOutfit = wornOutfits.isEmpty ? null : wornOutfits.first;

    return AssistantContext(
      calendar: await calendarFuture,
      personalization: await personalizationFuture,
      weather: weather == null
          ? null
          : AssistantWeather(
            temperature: weather.temperature,
            condition: weather.description,
            city: weather.city,
          ),
      statistics: AssistantStatistics(
        garmentCount: currentGarments.length,
        outfitCount: _outfitsController.outfits.length,
        recordedWearCount: currentGarments.fold(
          0,
          (total, garment) => total + garment.wearCount,
        ),
      ),
      history: AssistantHistory(
        lastWornOutfit:
            lastOutfit == null
                ? null
                : WornOutfit(
                  id: lastOutfit.id,
                  name: lastOutfit.name,
                  wornAt: lastOutfit.lastWorn!,
                ),
        recentlyWornGarments: recentGarments
            .map(
              (garment) => WornGarment(
                id: garment.id,
                name: garment.name,
                wornAt: garment.lastWorn!,
              ),
            )
            .toList(growable: false),
      ),
      date: AssistantDate(
        value: now,
        day: _days[now.weekday - 1],
        time:
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}',
        season: _seasonFor(now),
      ),
      wardrobe: wardrobeContext,
    );
  }

  static const _days = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];

  static String _seasonFor(DateTime date) => switch (date.month) {
    3 || 4 || 5 => 'printemps',
    6 || 7 || 8 => 'été',
    9 || 10 || 11 => 'automne',
    _ => 'hiver',
  };
}
