enum GarmentConfidenceLevel { low, medium, high }

class GarmentConfidence {
  static const highThreshold = .80;
  static const mediumThreshold = .55;
  static const riskyThreshold = .80;
  static const riskyFields = {'visibleBrand', 'material', 'condition', 'care', 'visibleDefects'};

  const GarmentConfidence._();

  static GarmentConfidenceLevel level(double value) => value >= highThreshold
      ? GarmentConfidenceLevel.high
      : value >= mediumThreshold
          ? GarmentConfidenceLevel.medium
          : GarmentConfidenceLevel.low;

  static bool canApply(String field, double? value) =>
      value != null && value >= (riskyFields.contains(field) ? riskyThreshold : mediumThreshold);

  static String label(double value) => switch (level(value)) {
        GarmentConfidenceLevel.high => 'Confiance élevée',
        GarmentConfidenceLevel.medium => 'Confiance moyenne',
        GarmentConfidenceLevel.low => 'À vérifier',
      };
}
