import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/ai_context/wardrobe_ai_context_service.dart';
import 'package:wardrobeos/features/assistant/memory/memory_repository.dart';
import 'package:wardrobeos/features/assistant/memory/memory_service.dart';
import 'package:wardrobeos/features/assistant/memory/personal_goal.dart';
import 'package:wardrobeos/features/assistant/memory/style_profile.dart';
import 'package:wardrobeos/features/assistant/memory/user_memory.dart';
import 'package:wardrobeos/features/daily_brief/daily_brief_models.dart';
import 'package:wardrobeos/features/daily_brief/daily_brief_service.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/style_analysis.dart';
import 'package:wardrobeos/models/thermal_profile.dart';
import 'package:wardrobeos/weather/models/weather_data.dart';
import 'package:wardrobeos/weather/services/weather_service.dart';

Garment _garment(String id, String name, String category) => Garment(
  id: id,
  name: name,
  category: category,
  couleurPrincipale: 'Bleu',
  matierePrincipale: 'Coton',
  styleAnalysis: StyleAnalysis(
    inputFingerprint: 'style-fixture',
    suggestedRegister: 'casual',
    calculatedAt: DateTime(2026),
  ),
  thermalProfile: ThermalProfile(
    standaloneMinC: 10,
    standaloneMaxC: 25,
    layeredMinC: 6,
    layeredMaxC: 21,
    level: ThermalLevel.moderate,
    breathability: BreathabilityLevel.medium,
    windProtection: WeatherProtection.limited,
    rainCompatibility: WeatherProtection.none,
    primaryRole: LayerRole.mid,
    inputFingerprint: 'thermal-fixture',
    calculatedAt: DateTime(2026),
  ),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('propose une tenue avant la météo puis enrichit le même brief', () async {
    final weather = Completer<WeatherData>();
    final service = _service(
      wardrobe: [_garment('top', 'Chemise', 'Hauts')],
      weather: _Weather(() => weather.future),
    );
    final events = <DailyBrief>[];
    final done = service.watch().listen(events.add).asFuture<void>();

    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    expect(events.single.outfitProposals, isNotEmpty);
    expect(events.single.cards.any((card) => card.type == DailyBriefCardType.weather), isFalse);

    weather.complete(_weatherData);
    await done;
    expect(events, hasLength(2));
    expect(events.last.cards.any((card) => card.type == DailyBriefCardType.weather), isTrue);
  });

  test('une météo absente ne bloque jamais la recommandation', () async {
    final brief = await _service(
      wardrobe: [_garment('top', 'T-shirt', 'Hauts')],
      weather: _Weather(() => Future.error(StateError('indisponible'))),
    ).build();

    expect(brief.outfitProposals, isNotEmpty);
    expect(brief.cards.any((card) => card.type == DailyBriefCardType.weather), isFalse);
  });

  test('chaque relance relit le dressing actuel', () async {
    var name = 'Avant modification';
    var reads = 0;
    final context = WardrobeAiContextService(loadCurrentGarments: () async {
      reads++;
      return [_garment('stable', name, 'Hauts')];
    });
    final service = DailyBriefService(
      weatherService: _Weather(() => Future.error(StateError('offline'))),
      memoryService: MemoryService(repository: _EmptyMemoryRepository()),
      aiContextService: context,
    );

    final before = await service.build();
    name = 'Après modification';
    final after = await service.build();

    expect(reads, 2);
    expect(before.outfitProposals.single.garments.single.name, 'Avant modification');
    expect(after.outfitProposals.single.garments.single.name, 'Après modification');
  });
}

DailyBriefService _service({required List<Garment> wardrobe, required WeatherService weather}) =>
    DailyBriefService(
      weatherService: weather,
      memoryService: MemoryService(repository: _EmptyMemoryRepository()),
      aiContextService: WardrobeAiContextService(loadCurrentGarments: () async => wardrobe),
    );

final _weatherData = WeatherData(
  city: 'Paris', latitude: 0, longitude: 0, temperature: 18,
  apparentTemperature: 18, humidity: 50, windSpeed: 8, windDirection: 0,
  weatherCode: 0, description: 'Clair', measuredAt: DateTime(2026),
);

class _Weather implements WeatherService {
  final Future<WeatherData> Function() loader;
  _Weather(this.loader);
  @override
  Future<WeatherData> getCurrentWeather({bool forceRefresh = false}) => loader();
  @override
  void clearCache() {}
}

class _EmptyMemoryRepository implements MemoryRepository {
  @override Future<void> deleteMemory(String id) async {}
  @override Future<void> deleteGoal(String id) async {}
  @override Future<void> deleteStyleProfile() async {}
  @override Future<List<PersonalGoal>> getGoals() async => [];
  @override Future<List<UserMemoryRevision>> getMemoryHistory(String memoryId) async => [];
  @override Future<List<UserMemory>> getMemories({UserMemoryKind? kind}) async => [];
  @override Future<StyleProfile?> getStyleProfile() async => null;
  @override Future<void> saveGoal(PersonalGoal goal) async {}
  @override Future<void> saveMemory(UserMemory memory, {bool recordRevision = true}) async {}
  @override Future<void> saveStyleProfile(StyleProfile profile) async {}
}
