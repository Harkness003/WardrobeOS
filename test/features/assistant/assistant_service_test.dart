import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/context/assistant_context_builder.dart';
import 'package:wardrobeos/features/assistant/services/assistant_service.dart';
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
        apparentTemperature: 22, humidity: 0, windSpeed: 0, windDirection: 0,
        weatherCode: 0, description: 'Clair', measuredAt: DateTime(2026),
      );
}

void main() {
  test('génère un prompt à partir du contexte', () async {
    final wardrobe = WardrobeController()
      ..loading = false
      ..garments = List.generate(
        2,
        (index) => Garment(
          id: '$index', name: 'Vêtement $index', category: 'Haut',
          createdAt: DateTime(2026), updatedAt: DateTime(2026),
        ),
      );
    final outfits = OutfitsController()
      ..loading = false
      ..outfits = [
        Outfit(
          id: 'o1', name: 'Tenue', createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
    final service = AssistantService(
      contextBuilder: AssistantContextBuilder(
        weatherService: _WeatherService(), wardrobeController: wardrobe,
        outfitsController: outfits,
        clock: () => DateTime(2026, 7, 14),
      ),
    );

    final message = await service.generatePrompt();

    expect(message, contains('Jour : mardi'));
    expect(message, contains('Température : 22°C'));
    expect(message, contains('Ville : Lyon'));
    expect(message, contains('Nombre de vêtements : 2'));
    expect(message, contains('Nombre de tenues : 1'));
  });
}
