import '../../core/ai_context/wardrobe_ai_context_service.dart';
import '../../core/outfit_generation/outfit_generation_engine.dart';
import '../../core/recommendation/recommendation_context.dart';
import '../../core/recommendation/recommendation_engine.dart';
import '../../core/wardrobe_intelligence/wardrobe_intelligence_engine.dart';
import '../../features/assistant/memory/personalization_snapshot.dart';
import '../../models/garment.dart';
import '../../weather/models/weather_data.dart';
import '../../weather/services/weather_service.dart';
import '../assistant/memory/memory_service.dart';
import '../assistant/memory/personal_goal.dart';
import 'daily_brief_models.dart';

/// Composes the Daily Brief exclusively from the shared AI context and outfit
/// engine. Expensive I/O is performed once and intermediate states are emitted
/// as soon as they are useful to the UI.
class DailyBriefService {
  static const maxVisibleCards = 5;

  final WeatherService weatherService;
  final MemoryService memoryService;
  final RecommendationEngine recommendationEngine;
  final WardrobeIntelligenceEngine intelligenceEngine;
  final OutfitGenerationEngine outfitEngine;
  final DateTime Function() _clock;
  final WardrobeAiContextService? aiContextService;

  DailyBriefService({
    required this.weatherService,
    required this.memoryService,
    Object? assistantService, // Kept source-compatible; Daily no longer calls GPT.
    this.recommendationEngine = const RecommendationEngine(),
    WardrobeIntelligenceEngine? intelligenceEngine,
    OutfitGenerationEngine? outfitEngine,
    DateTime Function()? clock,
    this.aiContextService,
  }) : intelligenceEngine = intelligenceEngine ?? WardrobeIntelligenceEngine(),
       outfitEngine = outfitEngine ??
           OutfitGenerationEngine(recommendationEngine: recommendationEngine),
       _clock = clock ?? DateTime.now;

  /// Emits wardrobe/outfit content first, then weather-enriched content. A
  /// weather failure is data, not an error, and never prevents an outfit.
  Stream<DailyBrief> watch([Iterable<Garment> wardrobe = const []]) async* {
    final weatherFuture = _optionalWeather();
    try {
      final liveContext = await aiContextService?.build();
      final garments = liveContext?.garments ??
          List<Garment>.unmodifiable(wardrobe);
      final memory = liveContext?.personalization ??
          await memoryService.loadSnapshot();

      var brief = _compose(garments, memory, weather: null);
      yield brief;

      final weather = await weatherFuture;
      if (weather != null) {
        brief = _compose(garments, memory, weather: weather);
        yield brief;
      }
    } catch (_) {
      // Stream errors are converted into an explicit UI state by the screen.
      rethrow;
    }
  }

  /// Compatibility API for non-progressive consumers.
  Future<DailyBrief> build([Iterable<Garment> wardrobe = const []]) async {
    DailyBrief? latest;
    await for (final brief in watch(wardrobe)) {
      latest = brief;
    }
    return latest ?? DailyBrief(generatedAt: _clock(), cards: const [], outfitProposals: const []);
  }

  DailyBrief _compose(
    List<Garment> garments,
    PersonalizationSnapshot memory, {
    required WeatherData? weather,
  }) {
    final preferences = _preferences(memory);
    final report = intelligenceEngine.analyze(garments);
    final generation = outfitEngine.generate(OutfitGenerationRequest(
      wardrobe: garments,
      proposalCount: 3,
      preferences: preferences,
      context: RecommendationContext(
        season: _season(_clock()),
        desiredStyle: preferences.preferredStyles.firstOrNull,
        weather: weather == null
            ? null
            : RecommendationWeather(
                temperature: weather.temperature,
                isRaining: _isRaining(weather),
                condition: weather.description,
                windSpeed: weather.windSpeed,
              ),
      ),
    ));
    final proposals = generation.proposals;

    final cards = <DailyBriefCard<Object>>[];
    if (proposals.isNotEmpty) {
      cards.add(DailyBriefCard(type: DailyBriefCardType.outfit, priority: 0, data: proposals.first));
    }
    if (weather != null) {
      cards.add(DailyBriefCard(
        type: DailyBriefCardType.weather,
        priority: 1,
        data: DailyWeatherBrief(weather: weather, impact: _weatherImpact(weather), isRaining: _isRaining(weather)),
      ));
    }
    if (report.insights.isNotEmpty) {
      final now = _clock();
      final dayIndex = now.difference(DateTime(now.year)).inDays;
      cards.add(DailyBriefCard(type: DailyBriefCardType.observation, priority: 2,
        data: report.insights[dayIndex % report.insights.length].message));
    }
    final advice = _localAdvice(proposals, weather);
    if (advice != null) {
      cards.add(DailyBriefCard(type: DailyBriefCardType.stylist, priority: 3, data: advice));
    }
    final care = _careMessage(garments);
    if (care != null) {
      cards.add(DailyBriefCard(type: DailyBriefCardType.care, priority: 4, data: care));
    }
    final goal = memory.goals.where((item) => item.status == PersonalGoalStatus.active).firstOrNull;
    if (goal != null && proposals.isNotEmpty) {
      cards.add(DailyBriefCard(type: DailyBriefCardType.goal, priority: 5,
        data: DailyGoalBrief(title: goal.title,
          contribution: 'Cette sélection tient compte de tes préférences et de la rotation de ton dressing.')));
    }
    cards.sort((a, b) => a.priority.compareTo(b.priority));
    return DailyBrief(generatedAt: _clock(),
      cards: List.unmodifiable(cards.take(maxVisibleCards)),
      outfitProposals: List.unmodifiable(proposals));
  }

  static RecommendationPreferences _preferences(PersonalizationSnapshot snapshot) {
    final profile = snapshot.styleProfile;
    final avoidedMaterials = <String>{};
    for (final memory in [...snapshot.declarativeMemories, ...snapshot.behavioralObservations]) {
      if (memory.confidence < .6) continue;
      final topic = memory.topic.toLowerCase();
      if (topic.contains('mati') && (topic.contains('evit') || topic.contains('avoid'))) {
        avoidedMaterials.add(memory.statement.trim());
      }
    }
    return RecommendationPreferences(
      preferredStyles: {...?profile?.favoriteStyles},
      preferredColors: {...?profile?.preferredColors},
      avoidedMaterials: avoidedMaterials,
    );
  }

  Future<WeatherData?> _optionalWeather() async {
    try { return await weatherService.getCurrentWeather(); } catch (_) { return null; }
  }

  static String? _localAdvice(List<OutfitGenerationProposal> proposals, WeatherData? weather) {
    if (proposals.isEmpty) return null;
    if (weather == null) return 'La tenue reste modulable : ajoute ou retire une couche selon ton ressenti.';
    return _weatherImpact(weather);
  }

  static bool _isRaining(WeatherData value) => value.weatherCode >= 51 && value.weatherCode <= 82;
  static String _weatherImpact(WeatherData value) {
    if (_isRaining(value)) return 'Privilégie une couche imperméable et des chaussures adaptées à la pluie.';
    if (value.windSpeed >= 30) return 'Le vent invite à choisir une couche extérieure bien fermée.';
    if (value.temperature <= 10) return 'Ajoute une couche chaude pour rester confortable.';
    if (value.temperature >= 25) return 'Choisis des matières légères et respirantes.';
    return 'Les conditions sont douces : une superposition légère suffit.';
  }

  static String? _careMessage(List<Garment> garments) {
    for (final item in garments) {
      final condition = '${item.condition ?? ''} ${item.etatVisuel ?? ''} ${item.usureVisible ?? ''}'.toLowerCase();
      if (condition.contains('sale') || condition.contains('tach')) return 'Pense à nettoyer ${item.name} avant sa prochaine sortie.';
      if (condition.contains('us') || condition.contains('abîm')) return '${item.name} mérite un peu d’entretien avant d’être reporté.';
    }
    return null;
  }

  static String _season(DateTime date) => switch (date.month) {
    12 || 1 || 2 => 'Hiver', 3 || 4 || 5 => 'Printemps',
    6 || 7 || 8 => 'Été', _ => 'Automne',
  };
}
