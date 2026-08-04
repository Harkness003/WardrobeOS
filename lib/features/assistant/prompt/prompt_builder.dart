import 'dart:convert';

import '../context/assistant_context.dart';
import '../tools/assistant_tool_context_builder.dart';
import '../recommendation/outfit_recommendation_result.dart';
import 'prompt_composer.dart';
import 'prompt_section.dart';

class PromptBuilder {
  final PromptComposer composer;
  final List<PromptSection> sections;

  PromptBuilder({PromptComposer? composer, List<PromptSection>? sections})
    : composer = composer ?? const PromptComposer(),
      sections = List.unmodifiable(sections ?? _defaultSections);

  String build(
    AssistantContext context, {
    AssistantToolContext toolContext = const {},
    OutfitRecommendationResult? recommendation,
  }) {
    var prompt = composer.compose(context, sections);
    const encoder = JsonEncoder.withIndent('  ');
    if (toolContext.isNotEmpty) {
      prompt =
          '$prompt\n\n### DONNÉES MÉTIER STRUCTURÉES\n'
          '${encoder.convert(toolContext)}';
    }
    if (recommendation != null) {
      final request = recommendation.request;
      final composedOutfit = recommendation.outfit;
      prompt =
          '$prompt\n\n### RECOMMANDATION TENUE\n'
          'Demande utilisateur : ${request.originalMessage}\n'
          'Contexte météo : ${encoder.convert(request.weather?.toMap())}\n'
          'Vêtements candidats : '
          '${encoder.convert(recommendation.candidates.map((item) => item.toMap()).toList())}\n'
          'Meilleure composition calculée : ${encoder.convert(composedOutfit == null ? null : {
            'vêtements': composedOutfit.allGarments.map((item) => {'id': item.id, 'nom': item.name}).toList(),
            'justifications': composedOutfit.justification,
          })}\n'
          'Construis le nombre de tenues demandé uniquement avec les identifiants '
          'de la GARDE-ROBE actuelle. Appuie-toi sur la composition calculée, puis '
          'sur les candidats classés pour des variantes cohérentes. Explique chaque '
          'tenue brièvement. Si peu de catégories sont disponibles, propose une '
          'composition partielle utile et signale simplement cette limite.';
    }
    return prompt;
  }

  static const List<PromptSection> _defaultSections = [
    SystemPromptSection(),
    PersonalizationPromptSection(),
    CalendarPromptSection(),
    WeatherPromptSection(),
    WardrobePromptSection(),
    StatisticsPromptSection(),
    HistoryPromptSection(),
    DatePromptSection(),
  ];
}
