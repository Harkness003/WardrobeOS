import '../context/assistant_context.dart';
import '../intents/intent_result.dart';

class OutfitWeatherConstraints {
  final double? temperature;
  final String? condition;

  const OutfitWeatherConstraints({this.temperature, this.condition});

  bool get isCold => temperature != null && temperature! <= 12;
  bool get isHot => temperature != null && temperature! >= 25;

  Map<String, Object?> toMap() => {
    'température': temperature,
    'condition': condition,
  };
}

class OutfitRecommendationRequest {
  final String userIntent;
  final String originalMessage;
  final DateTime? date;
  final String? occasion;
  final String? desiredStyle;
  final OutfitWeatherConstraints? weather;
  final String? season;
  final String? requestedCategory;
  final Map<String, Object?> metadata;

  const OutfitRecommendationRequest({
    required this.userIntent,
    required this.originalMessage,
    this.date,
    this.occasion,
    this.desiredStyle,
    this.weather,
    this.season,
    this.requestedCategory,
    this.metadata = const {},
  });

  factory OutfitRecommendationRequest.fromIntent(
    IntentResult intent,
    AssistantContext context,
  ) => OutfitRecommendationRequest(
    userIntent: intent.type.name,
    originalMessage: intent.originalText,
    date: context.date.value,
    occasion: intent.parameters['occasion'],
    desiredStyle: intent.parameters['style'],
    weather:
        context.weather == null
            ? null
            : OutfitWeatherConstraints(
              temperature: context.weather!.temperature,
              condition: context.weather!.condition,
            ),
    season: intent.parameters['saison'] ?? context.date.season,
    requestedCategory: intent.parameters['catégorie'],
  );
}
