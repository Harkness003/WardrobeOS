import 'assistant_intent.dart';
import 'intent_result.dart';
import 'intent_type.dart';

class IntentParser implements AssistantIntent {
  const IntentParser();

  @override
  IntentResult parse(String userMessage) {
    final text = _normalize(userMessage);
    final parameters = <String, String>{};
    final type = _detectType(text);

    _extractDate(text, parameters);
    if (type == AssistantIntentType.eventOutfit) {
      _extractOccasion(text, parameters);
    }
    _extractSeason(text, parameters);
    _extractStyle(text, parameters);

    return IntentResult(
      type: type,
      originalText: userMessage,
      parameters: parameters,
    );
  }

  AssistantIntentType _detectType(String text) {
    if (_containsAny(text, ['meteo', 'temps qu il fait', 'temperature'])) {
      return AssistantIntentType.weatherOutfit;
    }
    if (_containsAny(text, [
      'mariage', 'restaurant', 'evenement', 'soiree', 'entretien',
      'anniversaire', 'ceremonie',
    ])) {
      return AssistantIntentType.eventOutfit;
    }
    if (_containsAny(text, [
      'porte peu', 'porte jamais', 'ne porte plus', 'vetements oublies',
    ])) {
      return AssistantIntentType.forgottenGarments;
    }
    if (_containsAny(text, ['analyse mon dressing', 'analyse ma garde robe'])) {
      return AssistantIntentType.wardrobeAnalysis;
    }
    if (_containsAny(text, [
      'devrais je acheter', 'quoi acheter', 'conseil achat', 'shopping',
    ])) {
      return AssistantIntentType.shoppingAdvice;
    }
    if (_containsAny(text, [
      'aujourd hui', 'tenue du jour', 'que mettre', 'comment m habiller',
    ])) {
      return AssistantIntentType.dailyOutfit;
    }
    return AssistantIntentType.generalQuestion;
  }

  void _extractDate(String text, Map<String, String> parameters) {
    const dates = [
      'aujourd hui', 'demain', 'lundi', 'mardi', 'mercredi', 'jeudi',
      'vendredi', 'samedi', 'dimanche',
    ];
    for (final date in dates) {
      if (text.contains(date)) {
        parameters['date'] = date == 'aujourd hui' ? "aujourd'hui" : date;
        return;
      }
    }
  }

  void _extractOccasion(String text, Map<String, String> parameters) {
    const occasions = [
      'mariage', 'restaurant', 'soiree', 'entretien', 'anniversaire',
      'ceremonie',
    ];
    for (final occasion in occasions) {
      if (text.contains(occasion)) {
        parameters['occasion'] = occasion == 'soiree' ? 'soirée' : occasion;
        return;
      }
    }
    if (text.contains('evenement')) parameters['occasion'] = 'événement';
  }

  void _extractSeason(String text, Map<String, String> parameters) {
    const seasons = ['printemps', 'ete', 'automne', 'hiver'];
    for (final season in seasons) {
      if (text.contains(season)) {
        parameters['saison'] = season == 'ete' ? 'été' : season;
        return;
      }
    }
  }

  void _extractStyle(String text, Map<String, String> parameters) {
    const styles = ['casual', 'chic', 'elegant', 'sportif', 'minimaliste'];
    for (final style in styles) {
      if (text.contains(style)) {
        parameters['style'] = style == 'elegant' ? 'élégant' : style;
        return;
      }
    }
  }

  bool _containsAny(String text, List<String> expressions) =>
      expressions.any(text.contains);

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r"[^a-z0-9 ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
