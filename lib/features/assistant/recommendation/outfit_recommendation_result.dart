import 'outfit_candidate.dart';
import 'outfit_recommendation_request.dart';
import '../../../core/recommendation/recommendation_result.dart';

class OutfitRecommendationResult {
  final OutfitRecommendationRequest request;
  final List<OutfitCandidate> candidates;
  final RecommendationResult? recommendation;

  OutfitRecommendationResult({
    required this.request,
    required Iterable<OutfitCandidate> candidates,
    this.recommendation,
  }) : candidates = List.unmodifiable(candidates);
}
