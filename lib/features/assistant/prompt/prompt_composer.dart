import '../context/assistant_context.dart';
import 'prompt_section.dart';

class PromptComposer {
  const PromptComposer();

  String compose(AssistantContext context, Iterable<PromptSection> sections) {
    return sections
        .map((section) {
          final content = section.build(context)?.trim();
          if (content == null || content.isEmpty) return null;
          return '## ${section.title}\n$content';
        })
        .whereType<String>()
        .join('\n\n');
  }
}
