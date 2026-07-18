import '../../../weather/services/weather_service.dart';
import '../../calendar/calendar_context_builder.dart';
import '../../outfits/outfits_controller.dart';
import '../../wardrobe/wardrobe_controller.dart';
import 'assistant_context.dart';

typedef AssistantClock = DateTime Function();

class AssistantContextBuilder {
  final WeatherService _weatherService;
  final WardrobeController _wardrobeController;
  final OutfitsController _outfitsController;
  final AssistantClock _clock;
  final CalendarContextBuilder? _calendarContextBuilder;

  const AssistantContextBuilder({
    required WeatherService weatherService,
    required WardrobeController wardrobeController,
    required OutfitsController outfitsController,
    AssistantClock clock = DateTime.now,
    CalendarContextBuilder? calendarContextBuilder,
  }) : _weatherService = weatherService,
       _wardrobeController = wardrobeController,
       _outfitsController = outfitsController,
       _clock = clock,
       _calendarContextBuilder = calendarContextBuilder;

  Future<AssistantContext> build() async {
    final weatherFuture = _weatherService.getCurrentWeather();
    final calendarFuture = _calendarContextBuilder?.build();
    if (_wardrobeController.loading) await _wardrobeController.load();
    if (_outfitsController.loading) await _outfitsController.load();
    final weather = await weatherFuture;
    final now = _clock();

    final recentGarments =
        _wardrobeController.garments
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
      weather: AssistantWeather(
        temperature: weather.temperature,
        condition: weather.description,
        city: weather.city,
      ),
      statistics: AssistantStatistics(
        garmentCount: _wardrobeController.garments.length,
        outfitCount: _outfitsController.outfits.length,
        recordedWearCount: _wardrobeController.garments.fold(
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
