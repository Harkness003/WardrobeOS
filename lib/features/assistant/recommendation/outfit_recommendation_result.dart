import 'outfit_candidate.dart';
import 'outfit_recommendation_request.dart';
import '../../../core/recommendation/recommendation_result.dart';
import '../../../models/outfit.dart';

class OutfitRecommendationResult {
  final OutfitRecommendationRequest request;
  final List<OutfitCandidate> candidates;
  final RecommendationResult? recommendation;
  final Outfit? outfit;

  OutfitRecommendationResult({
    required this.request,
    required Iterable<OutfitCandidate> candidates,
    this.recommendation,
    this.outfit,
  }) : candidates = List.unmodifiable(candidates);
}
