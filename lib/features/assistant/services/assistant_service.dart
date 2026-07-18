import '../context/assistant_context.dart';
import '../context/assistant_context_builder.dart';
import '../prompt/prompt_builder.dart';

class AssistantService {
  final AssistantContextBuilder _contextBuilder;
  final PromptBuilder _promptBuilder;

  AssistantService({
    required AssistantContextBuilder contextBuilder,
    PromptBuilder? promptBuilder,
  }) : _contextBuilder = contextBuilder,
       _promptBuilder = promptBuilder ?? PromptBuilder();

  Future<AssistantContext> buildContext() => _contextBuilder.build();

  Future<String> generatePrompt() async =>
      _promptBuilder.build(await buildContext());

  Future<String> generateMessage() => generatePrompt();
}
