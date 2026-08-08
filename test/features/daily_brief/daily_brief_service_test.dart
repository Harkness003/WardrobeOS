import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/ai_context/wardrobe_ai_context_service.dart';
import 'package:wardrobeos/core/diagnostics/diagnostic_service.dart';
import 'package:wardrobeos/core/outfit_generation/outfit_generation_engine.dart';
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
    insulation: InsulationLevel.medium,
    breathability: BreathabilityLevel.medium,
    windProtection: WeatherProtection.limited,
    rainProtection: WeatherProtection.none,
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
      wardrobe: [_garment('top', 'Chemise', 'Hauts'), _garment('bottom', 'Jean', 'Pantalons')],
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
    final diagnostics = DiagnosticService.instance
      ..clear()
      ..setEnabled(true);
    final brief = await _service(
      wardrobe: [_garment('top', 'T-shirt', 'Hauts'), _garment('bottom', 'Jean', 'Pantalons')],
      weather: _Weather(() => Future.error(StateError('indisponible'))),
    ).build();

    expect(brief.outfitProposals, isNotEmpty);
    expect(brief.cards.any((card) => card.type == DailyBriefCardType.weather), isFalse);
    expect(brief.state, DailyBriefState.weatherError);
    expect(brief.detail, contains('indisponible'));
    final generations = diagnostics.filtered(module: DiagnosticModule.outfits)
        .where((entry) => entry.source == 'DailyBriefService').toList();
    expect(generations, hasLength(1));
    expect(generations.single.details['phase'], 'phaseInitial');
    diagnostics.setEnabled(false);
  });

  test('sans météo ni calendrier, le dressing suffit à produire Daily', () async {
    final brief = await _service(
      wardrobe: [
        _garment('top', 'T-shirt', 'Hauts'),
        _garment('bottom', 'Jean', 'Pantalons'),
      ],
      weather: _Weather(() => Future.error(StateError('hors ligne'))),
    ).build();

    expect(brief.outfitProposals, isNotEmpty);
    expect(brief.state, DailyBriefState.weatherError);
  });

  test('des préférences illisibles restent un contexte optionnel', () async {
    final diagnostics = DiagnosticService.instance
      ..clear()
      ..setEnabled(true);
    final memory = MemoryService(repository: _FailingMemoryRepository());
    final service = DailyBriefService(
      weatherService: _Weather(() => Future.error(StateError('hors ligne'))),
      memoryService: memory,
      aiContextService: WardrobeAiContextService(
        loadCurrentGarments: () async => [
          _garment('top', 'Chemise', 'Hauts'),
          _garment('bottom', 'Jean', 'Pantalons'),
        ],
        memoryService: memory,
      ),
    );

    final brief = await service.build();

    expect(brief.outfitProposals, isNotEmpty);
    expect(
      diagnostics.filtered(module: DiagnosticModule.wardrobeContext),
      contains(predicate<DiagnosticEntry>(
        (entry) => entry.reason == 'invalidPreferences',
      )),
    );
    expect(
      diagnostics.filtered(module: DiagnosticModule.weather),
      contains(predicate<DiagnosticEntry>(
        (entry) => entry.reason == 'optionalWeatherUnavailable',
      )),
    );
    diagnostics.setEnabled(false);
  });

  test('distingue dressing vide et dressing réduit', () async {
    final empty = await _service(wardrobe: const [], weather: _Weather(() async => _weatherData)).build();
    final reduced = await _service(wardrobe: [_garment('top', 'T-shirt', 'Hauts')],
      weather: _Weather(() async => _weatherData)).build();
    expect(empty.state, DailyBriefState.emptyWardrobe);
    expect(reduced.state, DailyBriefState.insufficientWardrobe);
  });

  test('conserve la ville et les conditions météo résolues', () async {
    final brief = await _service(wardrobe: [
      _garment('top', 'Chemise', 'Hauts'), _garment('bottom', 'Pantalon', 'Pantalons')],
      weather: _Weather(() async => _weatherData)).build();
    final weather = brief.cards.where((card) => card.type == DailyBriefCardType.weather)
      .single.data as DailyWeatherBrief;
    expect(weather.weather.city, 'Paris');
    expect(weather.weather.description, 'Clair');
  });

  test('chaque relance relit le dressing actuel', () async {
    var name = 'Avant modification';
    var reads = 0;
    final context = WardrobeAiContextService(loadCurrentGarments: () async {
      reads++;
      return [_garment('stable', name, 'Hauts'), _garment('bottom', 'Jean', 'Pantalons')];
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
    expect(before.outfitProposals.single.garments.firstWhere((item) => item.id == 'stable').name, 'Avant modification');
    expect(after.outfitProposals.single.garments.firstWhere((item) => item.id == 'stable').name, 'Après modification');
  });

  test('attribue une panne moteur à outfitGenerationFailure après contexte réussi', () async {
    final diagnostics = DiagnosticService.instance
      ..clear()
      ..setEnabled(true);
    final service = DailyBriefService(
      weatherService: _Weather(() => Future.error(StateError('offline'))),
      memoryService: MemoryService(repository: _EmptyMemoryRepository()),
      outfitEngine: const _FailingOutfitEngine(),
      aiContextService: WardrobeAiContextService(loadCurrentGarments: () async => [
        _garment('top', 'Chemise', 'Hauts'),
        _garment('bottom', 'Jean', 'Pantalons'),
      ]),
    );

    await expectLater(service.build(), throwsA(isA<OutfitGenerationException>()));
    final failure = diagnostics.filtered(module: DiagnosticModule.daily)
        .where((entry) => entry.level == AppDiagnosticLevel.error).single;
    expect(failure.reason, 'outfitGenerationFailure');
    expect(failure.reason, isNot('wardrobeContextFailure'));
    expect(failure.details['phase'], 'recommendation');
    expect(failure.details['garmentsCount'], 2);
    expect(failure.details['technicalTypeMessage'],
      "type 'List<dynamic>' is not a subtype of type 'List<Garment>'");
    diagnostics.setEnabled(false);
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

class _FailingMemoryRepository extends _EmptyMemoryRepository {
  @override
  Future<List<UserMemory>> getMemories({UserMemoryKind? kind}) =>
      Future.error(const FormatException('legacy preferences'));
}

class _FailingOutfitEngine extends OutfitGenerationEngine {
  const _FailingOutfitEngine();

  @override
  OutfitGenerationResult generate(OutfitGenerationRequest request) {
    throw OutfitGenerationException(
      phase: OutfitGenerationPhase.recommendation,
      exceptionType: '_TypeError',
      technicalTypeMessage:
          "type 'List<dynamic>' is not a subtype of type 'List<Garment>'",
      garmentsCount: request.wardrobe.length,
    );
  }
}
