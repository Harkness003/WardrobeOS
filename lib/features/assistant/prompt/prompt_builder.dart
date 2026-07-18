import 'dart:convert';

import '../context/assistant_context.dart';
import '../tools/assistant_tool_context_builder.dart';
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
  }) {
    final prompt = composer.compose(context, sections);
    if (toolContext.isEmpty) return prompt;
    const encoder = JsonEncoder.withIndent('  ');
    return '$prompt\n\n### DONNÉES MÉTIER STRUCTURÉES\n'
        '${encoder.convert(toolContext)}';
  }

  static const List<PromptSection> _defaultSections = [
    SystemPromptSection(),
    WeatherPromptSection(),
    WardrobePromptSection(),
    StatisticsPromptSection(),
    HistoryPromptSection(),
    DatePromptSection(),
  ];
}
