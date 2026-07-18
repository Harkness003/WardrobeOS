import '../context/assistant_context.dart';
import '../context/assistant_context_builder.dart';
import '../prompt/prompt_builder.dart';
import '../ai/llm_provider.dart';
import '../tools/assistant_tool_context_builder.dart';

class AssistantService {
  final AssistantContextBuilder _contextBuilder;
  final PromptBuilder _promptBuilder;
  final LlmProvider _llmProvider;
  final AssistantToolContextBuilder _toolContextBuilder;
  AssistantToolContext _lastToolContext = const {};

  AssistantService({
    required AssistantContextBuilder contextBuilder,
    AssistantToolContextBuilder? toolContextBuilder,
    required LlmProvider llmProvider,
    PromptBuilder? promptBuilder,
  }) : _contextBuilder = contextBuilder,
       _llmProvider = llmProvider,
       _toolContextBuilder =
           toolContextBuilder ?? AssistantToolContextBuilder(tools: const []),
       _promptBuilder = promptBuilder ?? PromptBuilder();

  AssistantToolContext get lastToolContext => _lastToolContext;

  Future<AssistantContext> buildContext() => _contextBuilder.build();

  Future<String> generatePrompt() async {
    final context = await buildContext();
    _lastToolContext = await _toolContextBuilder.build();
    return _promptBuilder.build(context, toolContext: _lastToolContext);
  }

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
