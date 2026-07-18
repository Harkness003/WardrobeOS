import '../context/assistant_context.dart';
import '../context/assistant_context_builder.dart';
import '../prompt/prompt_builder.dart';
import '../ai/llm_provider.dart';

class AssistantService {
  final AssistantContextBuilder _contextBuilder;
  final PromptBuilder _promptBuilder;
  final LlmProvider _llmProvider;

  AssistantService({
    required AssistantContextBuilder contextBuilder,
    required LlmProvider llmProvider,
    PromptBuilder? promptBuilder,
  }) : _contextBuilder = contextBuilder,
       _llmProvider = llmProvider,
       _promptBuilder = promptBuilder ?? PromptBuilder();

  Future<AssistantContext> buildContext() => _contextBuilder.build();

  Future<String> generatePrompt() async =>
      _promptBuilder.build(await buildContext());

  Future<String> generateMessage() async {
    try {
      return await _llmProvider.generate(await generatePrompt());
    } on LlmException catch (error) {
      return error.message;
    } catch (_) {
      return 'WardrobeGPT est temporairement indisponible. Réessayez.';
    }
  }
}
