import '../models/assistant_context.dart';
import '../models/assistant_request.dart';

typedef PromptSection =
    String? Function(AssistantRequest request, AssistantContext context);

class PromptBuilder {
  final List<PromptSection> sections;

  PromptBuilder({List<PromptSection>? sections})
    : sections = sections ?? _defaultSections;

  String build(AssistantRequest request, AssistantContext context) {
    return sections
        .map((section) => section(request, context))
        .whereType<String>()
        .where((section) => section.trim().isNotEmpty)
        .join('\n\n');
  }

  static final List<PromptSection> _defaultSections = [
    (request, context) =>
        '## Demande\n'
        '${request.message.isEmpty ? "Prépare le conseil du jour." : request.message}',
    (request, context) =>
        context.weather == null ? null : '## Météo\n${context.weather}',
    (request, context) =>
        context.wardrobe.isEmpty
            ? null
            : '## Garde-robe\n${context.wardrobe.join('\n')}',
    (request, context) =>
        request.constraints.isEmpty
            ? null
            : '## Contraintes\n${request.constraints}',
    (request, context) =>
        context.wearHistory.isEmpty
            ? null
            : '## Historique\n${context.wearHistory.join('\n')}',
  ];
}
