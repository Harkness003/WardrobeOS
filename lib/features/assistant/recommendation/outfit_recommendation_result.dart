import 'outfit_candidate.dart';
import 'outfit_recommendation_request.dart';

class OutfitRecommendationResult {
  final OutfitRecommendationRequest request;
  final List<OutfitCandidate> candidates;

  OutfitRecommendationResult({
    required this.request,
    required Iterable<OutfitCandidate> candidates,
  }) : candidates = List.unmodifiable(candidates);
}
