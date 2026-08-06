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
import '../../core/diagnostics/diagnostic_service.dart';

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
  /// weather failure is an explicit state and never prevents a wardrobe result.
  Stream<DailyBrief> watch([Iterable<Garment> wardrobe = const []]) async* {
    final stopwatch = Stopwatch()..start();
    final weatherFuture = _optionalWeather();
    try {
      final liveContext = await aiContextService?.build();
      final garments = liveContext?.garments ??
          List<Garment>.unmodifiable(wardrobe);
      final memory = liveContext?.personalization ??
          await memoryService.loadSnapshot();

      var brief = _compose(garments, memory, weather: null,
        contextLoadDuration: liveContext?.loadDuration ?? Duration.zero);
      yield brief;

      final weather = await weatherFuture;
      brief = weather.data == null
          ? _compose(garments, memory, weather: null, weatherError: weather.error,
              contextLoadDuration: liveContext?.loadDuration ?? Duration.zero)
          : _compose(garments, memory, weather: weather.data,
              contextLoadDuration: liveContext?.loadDuration ?? Duration.zero);
      yield brief;
      DiagnosticService.instance.publish(module: DiagnosticModule.daily,
        level: brief.state == DailyBriefState.available ? AppDiagnosticLevel.success : AppDiagnosticLevel.warning,
        state: brief.state.name, summary: '${brief.outfitProposals.length} proposition(s)',
        source: 'DailyBriefService', duration: stopwatch.elapsed, reason: brief.detail,
        details: {'vêtements': garments.length, 'cartes': brief.cards.length},
        pipeline: [
          DiagnosticStep('Weather', level: weather.data == null ? AppDiagnosticLevel.warning : AppDiagnosticLevel.success),
          DiagnosticStep('WardrobeContext', duration: liveContext?.loadDuration ?? Duration.zero),
          const DiagnosticStep('Generation'),
          const DiagnosticStep('Recommendation'),
          DiagnosticStep('Résultat', level: brief.outfitProposals.isEmpty ? AppDiagnosticLevel.warning : AppDiagnosticLevel.success),
        ]);
    } catch (_) {
      DiagnosticService.instance.publish(module: DiagnosticModule.daily,
        level: AppDiagnosticLevel.error, state: 'Interrompu', summary: 'Daily non généré',
        source: 'DailyBriefService', duration: stopwatch.elapsed,
        reason: 'Le contexte dressing n’a pas pu être préparé.');
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
    Object? weatherError,
    Duration contextLoadDuration = Duration.zero,
  }) {
    final preferences = _preferences(memory);
    final report = intelligenceEngine.analyze(garments);
    final generation = outfitEngine.generate(OutfitGenerationRequest(
      wardrobe: garments,
      proposalCount: 3,
      preferences: preferences,
      contextLoadDuration: contextLoadDuration,
      context: RecommendationContext(
        desiredStyle: preferences.preferredStyles.firstOrNull,
        weather: weather == null
            ? null
            : RecommendationWeather(
                temperature: weather.temperature,
                isRaining: _isRaining(weather),
                condition: weather.description,
                windSpeed: weather.windSpeed,
                humidity: weather.humidity,
              ),
        metadata: {
          'momentOfDay': _clock().hour >= 18 ? 'evening' : 'day',
          'activityLevel': 0,
        },
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
    final state = garments.isEmpty ? DailyBriefState.emptyWardrobe
        : generation.diagnostic.failure == OutfitGenerationFailure.missingTop ||
              generation.diagnostic.failure == OutfitGenerationFailure.missingBottom
            ? DailyBriefState.insufficientWardrobe
        : proposals.isEmpty ? DailyBriefState.noProposal
        : weatherError != null ? DailyBriefState.weatherError
        : DailyBriefState.available;
    final generationDetail = generation.diagnostic.userReason;
    return DailyBrief(generatedAt: _clock(),
      cards: List.unmodifiable(cards.take(maxVisibleCards)),
      outfitProposals: List.unmodifiable(proposals), state: state,
      detail: generationDetail ?? (weatherError == null ? null : 'Météo indisponible. La tenue est générée sans météo.'));
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

  Future<({WeatherData? data, Object? error})> _optionalWeather() async {
    try { return (data: await weatherService.getCurrentWeather(), error: null); }
    catch (error) { return (data: null, error: error); }
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

}
