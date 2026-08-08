import '../../core/ai_context/wardrobe_ai_context_service.dart';
import '../../core/outfit_generation/outfit_generation_engine.dart';
import '../../core/recommendation/recommendation_context.dart';
import '../../core/recommendation/recommendation_engine.dart';
import '../../core/wardrobe_intelligence/wardrobe_intelligence_engine.dart';
import '../../features/assistant/memory/personalization_snapshot.dart';
import '../../models/garment.dart';
import '../../models/outfit.dart';
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
    final diagnostics = DiagnosticService.instance;
    final correlationId = diagnostics.newCorrelationId('daily');
    diagnostics.publish(module: DiagnosticModule.daily, level: AppDiagnosticLevel.info,
      state: 'Démarré', summary: 'Préparation du Daily demandée', source: 'DailyBriefService',
      correlationId: correlationId, pipeline: const [DiagnosticStep('dailyStarted', level: AppDiagnosticLevel.info)]);
    final weatherFuture = _optionalWeather();
    try {
      final liveContext = await aiContextService?.build(correlationId: correlationId);
      final garments = liveContext?.garments ??
          List<Garment>.unmodifiable(wardrobe);
      // WardrobeAiContextService already treats personalization as optional.
      // Do not retry the same failed optional read here: that used to turn a
      // preferences failure into a fatal Daily failure after the dressing had
      // successfully loaded.
      final memory = aiContextService == null
          ? await _optionalMemory(correlationId)
          : liveContext?.personalization ?? const PersonalizationSnapshot();

      var brief = _compose(garments, memory, weather: null,
        phase: 'phaseInitial',
        correlationId: correlationId,
        contextLoadDuration: liveContext?.loadDuration ?? Duration.zero);
      yield brief;

      final weather = await weatherFuture;
      brief = weather.data == null
          ? DailyBrief(generatedAt: brief.generatedAt, cards: brief.cards,
              outfitProposals: brief.outfitProposals,
              state: brief.state == DailyBriefState.available
                  ? DailyBriefState.weatherError : brief.state,
              detail: brief.detail ?? 'Météo indisponible. La tenue est générée sans météo.')
          : _compose(garments, memory, weather: weather.data,
              phase: 'phaseWeatherEnriched',
              correlationId: correlationId,
              contextLoadDuration: liveContext?.loadDuration ?? Duration.zero);
      yield brief;
      diagnostics.publish(
        module: DiagnosticModule.weather,
        level: weather.data == null
            ? AppDiagnosticLevel.warning
            : AppDiagnosticLevel.success,
        state: weather.data == null ? 'Indisponible' : 'Prêt',
        summary: weather.data == null
            ? 'Daily continue sans météo'
            : 'Contexte météo ajouté au Daily',
        source: 'DailyBriefService',
        correlationId: correlationId,
        reason: weather.data == null ? 'optionalWeatherUnavailable' : null,
        details: weather.data == null
            ? {'technical': weather.error.runtimeType.toString()}
            : const {},
      );
      DiagnosticService.instance.publish(module: DiagnosticModule.daily,
        level: brief.state == DailyBriefState.available ? AppDiagnosticLevel.success : AppDiagnosticLevel.warning,
        state: brief.state.name, summary: '${brief.outfitProposals.length} proposition(s)',
        source: 'DailyBriefService', duration: stopwatch.elapsed, reason: brief.detail,
        correlationId: correlationId,
        details: {'vêtements': garments.length, 'cartes': brief.cards.length},
        pipeline: [
          DiagnosticStep('Weather', level: weather.data == null ? AppDiagnosticLevel.warning : AppDiagnosticLevel.success),
          DiagnosticStep('WardrobeContext', duration: liveContext?.loadDuration ?? Duration.zero),
          const DiagnosticStep('Generation'),
          const DiagnosticStep('Recommendation'),
          DiagnosticStep('Résultat', level: brief.outfitProposals.isEmpty ? AppDiagnosticLevel.warning : AppDiagnosticLevel.success),
        ]);
    } catch (error) {
      DiagnosticService.instance.publish(module: DiagnosticModule.daily,
        level: AppDiagnosticLevel.error, state: 'Interrompu', summary: 'Daily non généré',
        source: 'DailyBriefService', duration: stopwatch.elapsed,
        correlationId: correlationId, reason: 'wardrobeContextFailure',
        details: {'technical': error.runtimeType.toString()},
        pipeline: [DiagnosticStep('wardrobeContext', level: AppDiagnosticLevel.error,
          duration: stopwatch.elapsed, detail: error.runtimeType.toString())]);
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
    required String phase,
    Object? weatherError,
    String? correlationId,
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
    DiagnosticService.instance.publish(
      module: DiagnosticModule.outfits,
      level: proposals.isEmpty
          ? AppDiagnosticLevel.warning
          : AppDiagnosticLevel.success,
      state: proposals.isEmpty ? 'Impossible' : 'Générée',
      summary: proposals.isEmpty
          ? generation.diagnostic.userReason ?? 'Aucune combinaison valide'
          : 'Tenue Daily générée par le moteur partagé',
      source: 'DailyBriefService',
      correlationId: correlationId,
      reason: generation.diagnostic.failure?.name,
      duration: generation.diagnostic.generationDuration,
      details: {
        'phase': phase,
        'garments': generation.diagnostic.garmentCount,
        'candidates': generation.diagnostic.candidateCount,
        'proposals': generation.diagnostic.producedCount,
        'rejected': generation.diagnostic.rejectedCount,
        'topsRecognized': generation.diagnostic.recognizedByRole[OutfitCategory.top] ?? 0,
        'bottomsRecognized': generation.diagnostic.recognizedByRole[OutfitCategory.bottom] ?? 0,
        'shoesRecognized': generation.diagnostic.recognizedByRole[OutfitCategory.shoes] ?? 0,
        'outerwearRecognized':
            (generation.diagnostic.recognizedByRole[OutfitCategory.jacket] ?? 0) +
            (generation.diagnostic.recognizedByRole[OutfitCategory.coat] ?? 0),
        'unclassified': generation.diagnostic.unclassifiedCount,
      },
      pipeline: [
        DiagnosticStep(
          'outfitGeneration',
          level: proposals.isEmpty
              ? AppDiagnosticLevel.warning
              : AppDiagnosticLevel.success,
          duration: generation.diagnostic.generationDuration,
        ),
      ],
    );

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

  Future<PersonalizationSnapshot> _optionalMemory(String? correlationId) async {
    try {
      return await memoryService.loadSnapshot();
    } catch (error) {
      DiagnosticService.instance.publish(
        module: DiagnosticModule.wardrobeContext,
        level: AppDiagnosticLevel.warning,
        state: 'Dégradé',
        summary: 'Daily continue sans préférences',
        source: 'DailyBriefService',
        correlationId: correlationId,
        reason: 'optionalPreferencesUnavailable',
        details: {'technical': error.runtimeType.toString()},
      );
      return const PersonalizationSnapshot();
    }
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
