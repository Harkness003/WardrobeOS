class RecommendationWeather {
  final double? temperature;
  final bool? isRaining;
  final String? condition;
  final double? windSpeed;
  final int? humidity;

  const RecommendationWeather({
    this.temperature,
    this.isRaining,
    this.condition,
    this.windSpeed,
    this.humidity,
  });

  double? get apparentTemperature {
    if (temperature == null) return null;
    final windPenalty = (windSpeed ?? 0) >= 30 ? 3.0 : (windSpeed ?? 0) >= 15 ? 1.5 : 0.0;
    final rainPenalty = isRaining == true ? 1.5 : 0.0;
    final humidityPenalty = (humidity ?? 0) >= 80 && temperature! <= 18 ? 1.0 : 0.0;
    return temperature! - windPenalty - rainPenalty - humidityPenalty;
  }
}

/// Contexte indépendant de toute interface, extensible par [metadata] pour les
/// futurs agenda, voyage, packing list, achats et notifications.
class RecommendationContext {
  final String? season;
  final String? occasion;
  final String? desiredStyle;
  final RecommendationWeather? weather;
  final bool isTravel;
  final Map<String, Object?> metadata;

  const RecommendationContext({
    this.season,
    this.occasion,
    this.desiredStyle,
    this.weather,
    this.isTravel = false,
    this.metadata = const {},
  });
}

class RecommendationPreferences {
  final Set<String> preferredStyles;
  final Set<String> preferredColors;
  final Set<String> avoidedMaterials;

  const RecommendationPreferences({
    this.preferredStyles = const {},
    this.preferredColors = const {},
    this.avoidedMaterials = const {},
  });
}

/// Corrections explicites prioritaires sur les informations issues de l'IA.
class GarmentRecommendationCorrection {
  final String garmentId;
  final String? style;
  final String? formality;
  final List<String>? seasons;
  final List<String>? occasions;
  final String? color;
  final String? material;
  final bool? rainCompatible;
  final bool? layerable;

  const GarmentRecommendationCorrection({
    required this.garmentId,
    this.style,
    this.formality,
    this.seasons,
    this.occasions,
    this.color,
    this.material,
    this.rainCompatible,
    this.layerable,
  });
}
