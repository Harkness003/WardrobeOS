import '../../models/garment.dart';

class RecommendationCriterionScore {
  final String criterion;
  final double score;
  final double weight;

  const RecommendationCriterionScore({
    required this.criterion,
    required this.score,
    required this.weight,
  });
}

class RankedGarmentRecommendation {
  final Garment garment;
  final int score;
  final String explanation;
  final List<RecommendationCriterionScore> details;

  RankedGarmentRecommendation({
    required this.garment,
    required this.score,
    required this.explanation,
    required Iterable<RecommendationCriterionScore> details,
  }) : details = List.unmodifiable(details),
       assert(score >= 0 && score <= 100),
       assert(explanation != '');
}

/// Le premier élément est le meilleur choix, les suivants ses alternatives
/// triées. Même une liste vide conserve une explication exploitable par l'appelant.
class RecommendationResult {
  final List<RankedGarmentRecommendation> choices;
  final String explanation;

  RecommendationResult({
    required Iterable<RankedGarmentRecommendation> choices,
    required this.explanation,
  }) : choices = List.unmodifiable(choices),
       assert(explanation != '');

  RankedGarmentRecommendation? get bestChoice =>
      choices.isEmpty ? null : choices.first;

  List<RankedGarmentRecommendation> get alternatives =>
      choices.length < 2 ? const [] : List.unmodifiable(choices.skip(1));
}
