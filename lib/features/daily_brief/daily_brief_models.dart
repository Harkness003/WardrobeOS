import '../../core/outfit_generation/outfit_generation_engine.dart';
import '../../weather/models/weather_data.dart';

enum DailyBriefCardType { outfit, weather, observation, stylist, care, goal }
enum DailyBriefState { emptyWardrobe, insufficientWardrobe, noProposal, weatherError, available }

class DailyBriefCard<T> {
  final DailyBriefCardType type;
  final int priority;
  final T data;

  const DailyBriefCard({required this.type, required this.priority, required this.data});
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
  final List<OutfitGenerationProposal> outfitProposals;
  final DailyBriefState state;
  final String? detail;

  const DailyBrief({
    required this.generatedAt,
    required this.cards,
    required this.outfitProposals,
    this.state = DailyBriefState.available,
    this.detail,
  });
}
