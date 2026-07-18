import '../../calendar/calendar_context_builder.dart';

class AssistantContext {
  final CalendarContext? calendar;
  final AssistantWeather? weather;
  final AssistantStatistics statistics;
  final AssistantHistory history;
  final AssistantDate date;

  const AssistantContext({
    this.calendar,
    required this.weather,
    required this.statistics,
    required this.history,
    required this.date,
  });
}

class AssistantWeather {
  final double temperature;
  final String condition;
  final String city;

  const AssistantWeather({
    required this.temperature,
    required this.condition,
    required this.city,
  });
}

class AssistantStatistics {
  final int garmentCount;
  final int outfitCount;
  final int recordedWearCount;

  const AssistantStatistics({
    required this.garmentCount,
    required this.outfitCount,
    required this.recordedWearCount,
  });
}

class AssistantHistory {
  final WornOutfit? lastWornOutfit;
  final List<WornGarment> recentlyWornGarments;

  const AssistantHistory({
    this.lastWornOutfit,
    this.recentlyWornGarments = const [],
  });
}

class WornOutfit {
  final String id;
  final String name;
  final DateTime wornAt;

  const WornOutfit({
    required this.id,
    required this.name,
    required this.wornAt,
  });
}

class WornGarment {
  final String id;
  final String name;
  final DateTime wornAt;

  const WornGarment({
    required this.id,
    required this.name,
    required this.wornAt,
  });
}

class AssistantDate {
  final DateTime value;
  final String day;
  final String time;
  final String season;

  const AssistantDate({
    required this.value,
    required this.day,
    required this.time,
    required this.season,
  });
}
