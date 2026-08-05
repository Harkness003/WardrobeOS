import '../../models/garment.dart';
import 'recommendation_context.dart';

/// Secondary rotation rule used after canonical style, occasion, weather and
/// thermal matching. It only soft-penalizes high frequency or recent wear and
/// is not a standalone historical suggestion engine.
abstract interface class RecommendationRotationPolicy {
  double scoreAdjustment(Garment garment, RecommendationContext context);
}

class NoRecommendationRotation implements RecommendationRotationPolicy {
  const NoRecommendationRotation();

  @override
  double scoreAdjustment(Garment garment, RecommendationContext context) => 0;
}

class WardrobeRotationPolicy implements RecommendationRotationPolicy {
  const WardrobeRotationPolicy();

  @override
  double scoreAdjustment(Garment garment, RecommendationContext context) {
    final frequencyPenalty = (garment.wearCount.clamp(0, 20) / 20) * .18;
    final lastWorn = garment.lastWorn;
    if (lastWorn == null) return .12 - frequencyPenalty;
    final days = DateTime.now().difference(lastWorn).inDays.clamp(0, 30);
    final recencyBonus = (days / 30) * .12;
    return recencyBonus - frequencyPenalty;
  }
}
