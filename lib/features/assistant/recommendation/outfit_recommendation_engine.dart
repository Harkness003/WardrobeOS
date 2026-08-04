import '../../../core/recommendation/recommendation_context.dart';
import '../../../core/recommendation/recommendation_engine.dart';
import '../../../core/outfit/outfit_engine.dart';
import 'outfit_candidate.dart';
import 'outfit_recommendation_request.dart';
import 'outfit_recommendation_result.dart';

typedef OutfitCandidateSource = Future<List<OutfitCandidate>> Function();
typedef RecommendationClock = DateTime Function();

/// Adaptateur historique de l'assistant vers le moteur central.
///
/// Il reste volontairement sans logique de score afin que tous les points
/// d'entrée de l'application utilisent les mêmes règles métier.
class OutfitRecommendationEngine {
  final OutfitCandidateSource _candidateSource;
  final RecommendationEngine _engine;
  final OutfitEngine _outfitEngine;
  final int maximumCandidates;

  OutfitRecommendationEngine({
    required OutfitCandidateSource candidateSource,
    RecommendationClock clock = DateTime.now,
    RecommendationEngine engine = const RecommendationEngine(),
    this.maximumCandidates = 12,
    Duration recentWearWindow = const Duration(days: 2),
  }) : _candidateSource = candidateSource,
       _engine = engine,
       _outfitEngine = OutfitEngine(recommendationEngine: engine),
       assert(maximumCandidates >= 0),
       assert(!recentWearWindow.isNegative);

  Future<OutfitRecommendationResult> recommend(
    OutfitRecommendationRequest request, {
    Iterable<OutfitCandidate>? candidates,
  }) async {
    // AssistantService supplies the garments from the context it has just
    // built. The source remains available for non-assistant callers, but must
    // never create a second, potentially different snapshot during a reply.
    final availableCandidates = (candidates ?? await _candidateSource())
        .where((candidate) => candidate.isAvailable)
        .where(
          (candidate) => request.requestedCategory == null ||
              _normalize(candidate.category).contains(
                _normalize(request.requestedCategory!),
              ),
        )
        .toList();
    final byId = {
      for (final candidate in availableCandidates) candidate.id: candidate,
    };
    final result = _engine.recommend(
      wardrobe: availableCandidates.map((candidate) => candidate.garment),
      context: RecommendationContext(
        season: request.season,
        occasion: request.occasion,
        desiredStyle: request.desiredStyle,
        weather: request.weather == null
            ? null
            : RecommendationWeather(
                temperature: request.weather!.temperature,
                condition: request.weather!.condition,
                isRaining: _isRain(request.weather!.condition),
              ),
        isTravel: _normalize(request.userIntent).contains('voyage'),
        metadata: request.metadata,
      ),
      alternativeCount: maximumCandidates == 0 ? 0 : maximumCandidates - 1,
    );
    return OutfitRecommendationResult(
      request: request,
      candidates: result.choices
          .map((choice) => byId[choice.garment.id])
          .whereType<OutfitCandidate>(),
      recommendation: result,
      outfit: _outfitEngine.generateBestOutfit(
        wardrobe: availableCandidates.map((candidate) => candidate.garment),
        context: RecommendationContext(
          season: request.season,
          occasion: request.occasion,
          desiredStyle: request.desiredStyle,
          weather: request.weather == null
              ? null
              : RecommendationWeather(
                  temperature: request.weather!.temperature,
                  condition: request.weather!.condition,
                  isRaining: _isRain(request.weather!.condition),
                ),
        ),
      ),
    );
  }

  bool _isRain(String? condition) {
    final value = _normalize(condition ?? '');
    return value.contains('pluie') || value.contains('averse');
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c');
}
