import '../../core/recommendation/recommendation_context.dart';
import '../../core/recommendation/recommendation_engine.dart';
import '../../core/wardrobe_intelligence/wardrobe_intelligence_engine.dart';
import '../../models/garment.dart';
import '../../weather/models/weather_data.dart';
import '../../weather/services/weather_service.dart';
import '../assistant/memory/memory_service.dart';
import '../assistant/memory/personal_goal.dart';
import '../assistant/services/assistant_service.dart';
import 'daily_brief_models.dart';
import '../../core/ai_context/wardrobe_ai_context_service.dart';

/// Adapts the existing intelligence, recommendation, memory and GPT services
/// into presentation-ready cards. Widgets never calculate recommendations.
class DailyBriefService {
  static const maxVisibleCards = 5;

  final WeatherService weatherService;
  final MemoryService memoryService;
  final AssistantService assistantService;
  final RecommendationEngine recommendationEngine;
  final WardrobeIntelligenceEngine intelligenceEngine;
  final DateTime Function() _clock;
  final WardrobeAiContextService? aiContextService;

  DailyBriefService({
    required this.weatherService,
    required this.memoryService,
    required this.assistantService,
    this.recommendationEngine = const RecommendationEngine(),
    WardrobeIntelligenceEngine? intelligenceEngine,
    DateTime Function()? clock,
    this.aiContextService,
  }) : intelligenceEngine = intelligenceEngine ?? WardrobeIntelligenceEngine(),
       _clock = clock ?? DateTime.now;

  Future<DailyBrief> build([Iterable<Garment> wardrobe = const []]) async {
    final liveContext = await aiContextService?.build();
    final garments = liveContext?.garments ?? List<Garment>.unmodifiable(wardrobe);
    final weather = await _optionalWeather();
    final memory = liveContext?.personalization ?? await memoryService.loadSnapshot();
    final report = intelligenceEngine.analyze(garments);
    final recommendation = recommendationEngine.recommend(
      wardrobe: garments,
      context: RecommendationContext(
        season: _season(_clock()),
        weather: weather == null
            ? null
            : RecommendationWeather(
                temperature: weather.temperature,
                isRaining: _isRaining(weather),
                condition: weather.description,
                windSpeed: weather.windSpeed,
              ),
      ),
      alternativeCount: 8,
    );
    final proposals = <DailyOutfitBrief>[];
    for (var start = 0; start < recommendation.choices.length; start += 3) {
      final choices = recommendation.choices.skip(start).take(3).toList();
      if (choices.isEmpty) continue;
      proposals.add(DailyOutfitBrief(
        garments: choices.map((choice) => choice.garment).toList(growable: false),
        explanation: choices.first.explanation,
        confidence: (choices.fold<int>(0, (sum, item) => sum + item.score) / choices.length).round(),
      ));
    }

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
      final dayIndex = _clock().difference(DateTime(_clock().year)).inDays;
      cards.add(DailyBriefCard(
        type: DailyBriefCardType.observation,
        priority: 2,
        data: report.insights[dayIndex % report.insights.length].message,
      ));
    }
    final advice = await _stylistAdvice();
    if (advice != null) {
      cards.add(DailyBriefCard(type: DailyBriefCardType.stylist, priority: 3, data: advice));
    }
    final care = _careMessage(garments);
    if (care != null) {
      cards.add(DailyBriefCard(type: DailyBriefCardType.care, priority: 4, data: care));
    }
    final goal = memory.goals.where((item) => item.status == PersonalGoalStatus.active).firstOrNull;
    if (goal != null && proposals.isNotEmpty) {
      cards.add(DailyBriefCard(
        type: DailyBriefCardType.goal,
        priority: 5,
        data: DailyGoalBrief(title: goal.title, contribution: 'La sélection du jour privilégie des pièces cohérentes avec tes préférences et te permet d’avancer vers cet objectif.'),
      ));
    }
    cards.sort((a, b) => a.priority.compareTo(b.priority));
    return DailyBrief(generatedAt: _clock(), cards: List.unmodifiable(cards.take(maxVisibleCards)), outfitProposals: List.unmodifiable(proposals));
  }

  Future<WeatherData?> _optionalWeather() async {
    try { return await weatherService.getCurrentWeather(); } catch (_) { return null; }
  }

  Future<String?> _stylistAdvice() async {
    final value = await assistantService.generateMessage(
      userMessage: 'Donne mon conseil de styliste personnalisé du jour en 3 phrases maximum.',
    );
    final clean = value.trim();
    if (clean.isEmpty || clean.startsWith('WardrobeGPT est temporairement')) return null;
    return clean.split(RegExp(r'(?<=[.!?])\s+')).take(3).join(' ');
  }

  static bool _isRaining(WeatherData value) => value.weatherCode >= 51 && value.weatherCode <= 82;
  static String _weatherImpact(WeatherData value) {
    if (_isRaining(value)) return 'Privilégie une couche imperméable et des chaussures qui supportent la pluie.';
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
    12 || 1 || 2 => 'Hiver',
    3 || 4 || 5 => 'Printemps',
    6 || 7 || 8 => 'Été',
    _ => 'Automne',
  };
}
