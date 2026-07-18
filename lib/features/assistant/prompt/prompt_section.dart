import '../../calendar/calendar_event.dart';
import '../context/assistant_context.dart';

/// A self-contained piece of the prompt.
abstract interface class PromptSection {
  String get title;

  /// Returns no content when this section is not relevant to [context].
  String? build(AssistantContext context);
}

class SystemPromptSection implements PromptSection {
  static const instructions = [
    'Tu es WardrobeGPT.',
    'Tu es un conseiller vestimentaire intelligent.',
    'Tu privilégies les recommandations utiles.',
    'Tu expliques toujours tes choix.',
    "N'invente jamais d'informations absentes du contexte.",
  ];

  const SystemPromptSection();

  @override
  String get title => 'SYSTÈME';

  @override
  String build(AssistantContext context) => instructions.join('\n');
}

class WeatherPromptSection implements PromptSection {
  const WeatherPromptSection();

  @override
  String get title => 'MÉTÉO';

  @override
  String? build(AssistantContext context) {
    final weather = context.weather;
    if (weather == null) return null;
    final temperature =
        weather.temperature == weather.temperature.roundToDouble()
            ? weather.temperature.toInt().toString()
            : weather.temperature.toStringAsFixed(1);
    return 'Ville : ${weather.city}\n'
        'Température : $temperature°C\n'
        'Condition : ${weather.condition}';
  }
}

class CalendarPromptSection implements PromptSection {
  const CalendarPromptSection();

  @override
  String get title => 'CONTEXTE CALENDRIER';

  @override
  String? build(AssistantContext context) {
    final calendar = context.calendar;
    if (calendar == null) return null;
    final event = calendar.event;
    return 'Événement : ${event.title}\n'
        'Date : ${event.startsAt.toIso8601String()}\n'
        'Lieu : ${event.location ?? 'non précisé'}\n'
        'Formalité : ${event.formality.label}';
  }
}

class WardrobePromptSection implements PromptSection {
  const WardrobePromptSection();

  @override
  String get title => 'GARDE-ROBE';

  @override
  String build(AssistantContext context) =>
      'Nombre de vêtements : ${context.statistics.garmentCount}\n'
      'Nombre de tenues : ${context.statistics.outfitCount}';
}

class StatisticsPromptSection implements PromptSection {
  const StatisticsPromptSection();

  @override
  String get title => 'STATISTIQUES';

  @override
  String build(AssistantContext context) =>
      'Utilisations enregistrées : ${context.statistics.recordedWearCount}';
}

/// Extension point for future wear frequency and forgotten-garment insights.
class HistoryPromptSection implements PromptSection {
  const HistoryPromptSection();

  @override
  String get title => 'HISTORIQUE';

  @override
  String? build(AssistantContext context) => null;
}

class DatePromptSection implements PromptSection {
  const DatePromptSection();

  @override
  String get title => 'DATE';

  @override
  String build(AssistantContext context) =>
      'Jour : ${context.date.day}\n'
      'Heure : ${context.date.time}\n'
      'Saison : ${context.date.season}';
}
