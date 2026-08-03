import '../../models/garment.dart';
import 'recommendation_context.dart';

/// Point d'extension pour l'historique, la fréquence et les rotations.
/// Aucun comportement de rotation n'est appliqué dans ce sprint.
abstract interface class RecommendationRotationPolicy {
  double scoreAdjustment(Garment garment, RecommendationContext context);
}

class NoRecommendationRotation implements RecommendationRotationPolicy {
  const NoRecommendationRotation();

  @override
  double scoreAdjustment(Garment garment, RecommendationContext context) => 0;
}
