import '../../models/garment.dart';
import '../../weather/models/weather_data.dart';

enum DailyBriefCardType { outfit, weather, observation, stylist, care, goal }

class DailyBriefCard<T> {
  final DailyBriefCardType type;
  final int priority;
  final T data;

  const DailyBriefCard({required this.type, required this.priority, required this.data});
}

class DailyOutfitBrief {
  final List<Garment> garments;
  final String explanation;
  final int confidence;

  const DailyOutfitBrief({
    required this.garments,
    required this.explanation,
    required this.confidence,
  });
}

class DailyWeatherBrief {
  final WeatherData weather;
  final String impact;
  final bool isRaining;

  const DailyWeatherBrief({
    required this.weather,
    required this.impact,
    required this.isRaining,
  });
}

class DailyGoalBrief {
  final String title;
  final String contribution;

  const DailyGoalBrief({required this.title, required this.contribution});
}

class DailyBrief {
  final DateTime generatedAt;
  final List<DailyBriefCard<Object>> cards;
  final List<DailyOutfitBrief> outfitProposals;

  const DailyBrief({
    required this.generatedAt,
    required this.cards,
    required this.outfitProposals,
  });
}
