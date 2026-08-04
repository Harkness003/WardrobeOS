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
    'Fournis par défaut une réponse détaillée, concrète et directement utile.',
    'Explique brièvement les raisons de tes conseils sans révéler de raisonnement interne.',
    'Propose plusieurs options et justifie chaque recommandation lorsque pertinent.',
    'Cite toujours le nom réel des vêtements présents dans le contexte, jamais un nom générique à leur place.',
    'Prends en compte la garde-robe, la saison, la météo, l’occasion, les préférences et l’historique lorsqu’ils sont disponibles.',
    'Si une donnée manque, indique-le brièvement puis continue avec le contexte restant : ne bloque jamais la réponse.',
    'Pour une demande élaborée, structure souplement la réponse avec Résumé, Pourquoi, Conseils, Alternatives et Attention.',
    'Signale clairement les limites et incertitudes de tes conseils.',
    "N'invente jamais d'informations absentes du contexte.",
    "Reste bienveillant mais jamais complaisant : ne cherche pas à valider systématiquement l'utilisateur.",
    "Contredis l'utilisateur lorsque les faits stylistiques ou son objectif le justifient, en expliquant clairement pourquoi.",
    'Traite les observations comportementales comme des hypothèses révisables, jamais comme des vérités.',
    'Présente toute analyse morphologique ou colorimétrique comme probabiliste et rappelle sa confiance.',
  ];

  const SystemPromptSection();

  @override
  String get title => 'SYSTÈME';

  @override
  String build(AssistantContext context) => instructions.join('\n');
}

class PersonalizationPromptSection implements PromptSection {
  const PersonalizationPromptSection();

  @override
  String get title => 'PERSONNALISATION UTILISATEUR';

  @override
  String? build(AssistantContext context) {
    final snapshot = context.personalization;
    if (snapshot == null || snapshot.isEmpty) return null;
    final lines = <String>[];
    if (snapshot.declarativeMemories.isNotEmpty) {
      lines.add('Préférences déclarées (prioritaires) :');
      for (final memory in snapshot.declarativeMemories) {
        lines.add('- ${memory.statement} (confiance ${(memory.confidence * 100).round()} %)');
      }
    }
    if (snapshot.behavioralObservations.isNotEmpty) {
      lines.add('Observations comportementales (hypothèses, à nuancer) :');
      for (final memory in snapshot.behavioralObservations) {
        lines.add('- ${memory.statement} (confiance ${(memory.confidence * 100).round()} %, ${memory.evidenceCount} indice(s))');
      }
    }
    if (snapshot.goals.isNotEmpty) {
      lines.add('Objectifs personnels à concilier avec la demande :');
      for (final goal in snapshot.goals) {
        lines.add('- ${goal.title}${goal.details == null ? '' : ' — ${goal.details}'}');
      }
    }
    final profile = snapshot.styleProfile;
    if (profile != null) {
      void addList(String label, List<String> values) {
        if (values.isNotEmpty) lines.add('$label : ${values.join(', ')}');
      }
      addList('Coupes préférées', profile.preferredFits);
      if (profile.preferredFormality != null) {
        lines.add('Formalité préférée : ${profile.preferredFormality}');
      }
      addList('Couleurs préférées', profile.preferredColors);
      addList('Couleurs évitées', profile.avoidedColors);
      addList('Styles favoris', profile.favoriteStyles);
      addList('Contraintes professionnelles', profile.professionalConstraints);
      addList('Contraintes climatiques', profile.climateConstraints);
      if (profile.morphology case final analysis?) {
        lines.add('Morphologie probable (analyse consentie, corrigeable) : ${analysis.value} — confiance ${(analysis.confidence * 100).round()} %');
      }
      if (profile.colorimetry case final analysis?) {
        lines.add('Colorimétrie probable (analyse consentie, évolutive) : ${analysis.value} — confiance ${(analysis.confidence * 100).round()} %');
      }
    }
    return lines.join('\n');
  }
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
  String build(AssistantContext context) {
    final wardrobe = context.wardrobe;
    final header = 'Nombre de vêtements : ${context.statistics.garmentCount}\n'
        'Nombre de tenues : ${context.statistics.outfitCount}';
    if (wardrobe == null) return header;
    return '$header\nSource dressing : base actuelle (${wardrobe.generatedAt.toIso8601String()})\n'
        'Règle : la mémoire ne remplace jamais les fiches ci-dessous.\n'
        'Fiches actuelles : ${wardrobe.aiGarments.map((item) => item.toMap()).toList()}';
  }
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
  String? build(AssistantContext context) {
    final history = context.history;
    if (history.lastWornOutfit == null && history.recentlyWornGarments.isEmpty) {
      return null;
    }
    final lines = <String>[];
    if (history.lastWornOutfit case final outfit?) {
      lines.add(
        'Dernière tenue : ${outfit.name} '
        '(${outfit.wornAt.toIso8601String()})',
      );
    }
    if (history.recentlyWornGarments.isNotEmpty) {
      lines.add(
        'Vêtements portés récemment : '
        '${history.recentlyWornGarments.map((item) => item.name).join(', ')}',
      );
    }
    return lines.join('\n');
  }
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
