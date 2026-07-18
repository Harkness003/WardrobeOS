import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/context/assistant_context_builder.dart';
import 'package:wardrobeos/features/outfits/outfits_controller.dart';
import 'package:wardrobeos/features/wardrobe/wardrobe_controller.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/outfit.dart';
import 'package:wardrobeos/weather/models/weather_data.dart';
import 'package:wardrobeos/weather/services/weather_service.dart';

class _WeatherService implements WeatherService {
  @override
  void clearCache() {}

  @override
  Future<WeatherData> getCurrentWeather({bool forceRefresh = false}) async =>
      WeatherData(
        city: 'Lyon', latitude: 0, longitude: 0, temperature: 22,
        apparentTemperature: 22, humidity: 50, windSpeed: 4,
        windDirection: 0, weatherCode: 0, description: 'Ensoleillé',
        measuredAt: DateTime(2026),
      );
}

void main() {
  test('agrège météo, contrôleurs, historique et date', () async {
    final wardrobe = WardrobeController()
      ..loading = false
      ..garments = [
        Garment(
          id: 'g1', name: 'Chemise', category: 'Haut', wearCount: 3,
          lastWorn: DateTime(2026, 7, 13), createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
    final outfits = OutfitsController()
      ..loading = false
      ..outfits = [
        Outfit(
          id: 'o1', name: 'Bureau', timesWorn: 2,
          lastWorn: DateTime(2026, 7, 12), createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

    final context = await AssistantContextBuilder(
      weatherService: _WeatherService(),
      wardrobeController: wardrobe,
      outfitsController: outfits,
      clock: () => DateTime(2026, 7, 14, 9, 5),
    ).build();

    expect(context.weather!.city, 'Lyon');
    expect(context.statistics.garmentCount, 1);
    expect(context.statistics.outfitCount, 1);
    expect(context.statistics.recordedWearCount, 3);
    expect(context.history.lastWornOutfit?.name, 'Bureau');
    expect(context.history.recentlyWornGarments.single.name, 'Chemise');
    expect(context.date.day, 'mardi');
    expect(context.date.time, '09:05');
    expect(context.date.season, 'été');
  });
}
