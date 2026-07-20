import 'outfit_candidate.dart';
import 'outfit_recommendation_request.dart';
import 'outfit_recommendation_result.dart';

typedef OutfitCandidateSource = Future<List<OutfitCandidate>> Function();
typedef RecommendationClock = DateTime Function();

class OutfitRecommendationEngine {
  final OutfitCandidateSource _candidateSource;
  final RecommendationClock _clock;
  final int maximumCandidates;
  final Duration recentWearWindow;

  OutfitRecommendationEngine({
    required OutfitCandidateSource candidateSource,
    RecommendationClock clock = DateTime.now,
    this.maximumCandidates = 12,
    this.recentWearWindow = const Duration(days: 2),
  }) : _candidateSource = candidateSource,
       _clock = clock,
       assert(maximumCandidates >= 0),
       assert(!recentWearWindow.isNegative);

  Future<OutfitRecommendationResult> recommend(
    OutfitRecommendationRequest request,
  ) async {
    final now = _clock();
    final candidates =
        (await _candidateSource())
            .where((candidate) => candidate.isAvailable)
            .where((candidate) => _matchesCategory(candidate, request))
            .where((candidate) => _matchesSeason(candidate, request.season))
            .where((candidate) => !_wasWornRecently(candidate, now))
            .toList();

    candidates.sort(
      (left, right) =>
          _score(right, request, now).compareTo(_score(left, request, now)),
    );
    return OutfitRecommendationResult(
      request: request,
      candidates: candidates.take(maximumCandidates),
    );
  }

  bool _matchesCategory(
    OutfitCandidate candidate,
    OutfitRecommendationRequest request,
  ) {
    final requested = request.requestedCategory;
    return requested == null ||
        _normalize(candidate.category).contains(_normalize(requested));
  }

  bool _matchesSeason(OutfitCandidate candidate, String? requestedSeason) {
    final season = _normalize(candidate.season ?? '');
    if (season.isEmpty || season.contains('toute')) return true;
    return requestedSeason == null ||
        season.contains(_normalize(requestedSeason));
  }

  bool _wasWornRecently(OutfitCandidate candidate, DateTime now) {
    final lastWorn = candidate.lastWorn;
    return lastWorn != null && now.difference(lastWorn) < recentWearWindow;
  }

  int _score(
    OutfitCandidate candidate,
    OutfitRecommendationRequest request,
    DateTime now,
  ) {
    var score = 100 - candidate.wearCount.clamp(0, 100).toInt();
    if (candidate.lastWorn == null) score += 40;
    if (candidate.lastWorn != null) {
      score += now.difference(candidate.lastWorn!).inDays.clamp(0, 60).toInt();
    }
    final category = _normalize(candidate.category);
    if (request.weather?.isCold ?? false) {
      if (['manteau', 'veste', 'pull', 'pantalon'].any(category.contains)) {
        score += 50;
      }
    }
    if (request.weather?.isHot ?? false) {
      if (['short', 'robe', 't shirt', 'haut'].any(category.contains)) {
        score += 50;
      }
    }
    return score;
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
