import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/tools/assistant_tool.dart';
import 'package:wardrobeos/features/assistant/tools/assistant_tool_context_builder.dart';
import 'package:wardrobeos/features/assistant/tools/outfit_tool.dart';
import 'package:wardrobeos/features/assistant/tools/statistics_tool.dart';
import 'package:wardrobeos/features/assistant/tools/wardrobe_tool.dart';
import 'package:wardrobeos/features/assistant/tools/weather_tool.dart';
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
        city: 'Paris',
        latitude: 0,
        longitude: 0,
        temperature: 18,
        apparentTemperature: 18,
        humidity: 50,
        windSpeed: 5,
        windDirection: 0,
        weatherCode: 1,
        description: 'Peu nuageux',
        measuredAt: DateTime(2026),
      );
}

class _Tool implements AssistantTool {
  @override
  String get id => 'test';
  @override
  String get description => 'Description';
  @override
  Future<AssistantToolData> getData() async => {'value': 42};
}

void main() {
  final now = DateTime(2026, 7, 18);
  late WardrobeController wardrobe;
  late OutfitsController outfits;

  setUp(() {
    wardrobe =
        WardrobeController()
          ..loading = false
          ..garments = [
            Garment(
              id: 'g1',
              name: 'Chemise',
              category: 'Haut',
              color: 'Bleu',
              wearCount: 3,
              lastWorn: now,
              createdAt: now,
              updatedAt: now,
            ),
            Garment(
              id: 'g2',
              name: 'Jean',
              category: 'Bas',
              color: 'Bleu',
              createdAt: now,
              updatedAt: now,
            ),
          ];
    outfits =
        OutfitsController()
          ..loading = false
          ..outfits = [
            Outfit(
              id: 'o1',
              name: 'Bureau',
              timesWorn: 2,
              lastWorn: now,
              createdAt: now,
              updatedAt: now,
            ),
          ];
  });

  test('chaque outil retourne une structure valide', () async {
    final wardrobeData = await WardrobeTool(controller: wardrobe).getData();
    final outfitData = await OutfitTool(controller: outfits).getData();
    final weatherData =
        await WeatherTool(weatherService: _WeatherService()).getData();
    final statisticsData = await StatisticsTool(controller: wardrobe).getData();

    expect(wardrobeData['totalGarments'], 2);
    expect(wardrobeData['categories'], ['Bas', 'Haut']);
    expect(outfitData['totalOutfits'], 1);
    expect((outfitData['suggestions'] as List), isNotEmpty);
    expect(weatherData, containsPair('city', 'Paris'));
    expect(statisticsData['wearCount'], 3);
    expect((statisticsData['forgotten'] as List), hasLength(1));
  });

  test('assemble les données sous l’identifiant de chaque outil', () async {
    final context = await AssistantToolContextBuilder(tools: [_Tool()]).build();

    expect(context['test']?['description'], 'Description');
    expect(context['test']?['data'], {'value': 42});
  });
}
