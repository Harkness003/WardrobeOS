import 'dart:convert';

import '../context/assistant_context.dart';
import '../tools/assistant_tool_context_builder.dart';
import '../../../core/outfit_generation/outfit_generation_engine.dart';
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
    String languageCode = 'fr',
    AssistantToolContext toolContext = const {},
    List<OutfitGenerationProposal> outfitProposals = const [],
    String? outfitRequest,
  }) {
    var prompt = composer.compose(context, sections);
    prompt = '$prompt\n\n### LANGUE DE RÉPONSE\n'
        'Réponds dans la langue de l’application (code BCP-47 : $languageCode). '
        'Les valeurs de catalogue présentes dans le contexte sont des identifiants canoniques : '
        'conserve-les pour raisonner et ne les remplace jamais dans les données structurées.';
    const encoder = JsonEncoder.withIndent('  ');
    if (toolContext.isNotEmpty) {
      prompt =
          '$prompt\n\n### DONNÉES MÉTIER STRUCTURÉES\n'
          '${encoder.convert(toolContext)}';
    }
    if (outfitProposals.isNotEmpty) {
      prompt =
          '$prompt\n\n### RECOMMANDATION TENUE\n'
          'Demande utilisateur : $outfitRequest\n'
          'Propositions calculées : ${encoder.convert(outfitProposals.map((proposal) => {
            'vêtements': proposal.garments.map((item) => {'id': item.id, 'nom': item.name}).toList(),
            'score': proposal.score,
            'raisons': proposal.reasons,
            'contraintesRespectées': proposal.respectedConstraints,
          }).toList())}\n'
          "Explique et conseille à partir de ces propositions uniquement. Ne sélectionne, "
          "ne remplace et n'invente aucun vêtement. Pour toute explication thermique, "
          "reprends uniquement les raisons calculées fournies, sans les compléter.";
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
