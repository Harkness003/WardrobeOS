import '../builders/context_builder.dart';
import '../builders/prompt_builder.dart';
import '../models/assistant_request.dart';
import '../models/assistant_response.dart';

class WardrobeGptService {
  final ContextBuilder contextBuilder;
  final PromptBuilder promptBuilder;

  WardrobeGptService({
    ContextBuilder? contextBuilder,
    PromptBuilder? promptBuilder,
  }) : contextBuilder = contextBuilder ?? const ContextBuilder(),
       promptBuilder = promptBuilder ?? PromptBuilder();

  Future<AssistantResponse> generate(AssistantRequest request) async {
    final context = await contextBuilder.build(request);
    // Le prompt est déjà assemblé pour permettre le branchement futur d'un LLM.
    promptBuilder.build(request, context);

    final weather = context.weather ?? '23°C';
    return AssistantResponse(
      message:
          'Bonjour 👋\n\nAujourd’hui il fait $weather.\n\nJe prépare mes recommandations.',
    );
  }
}
