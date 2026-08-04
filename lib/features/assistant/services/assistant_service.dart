import '../context/assistant_context.dart';
import '../context/assistant_context_builder.dart';
import '../prompt/prompt_builder.dart';
import '../ai/llm_provider.dart';
import '../tools/assistant_tool_context_builder.dart';
import '../intents/assistant_intent.dart';
import '../intents/intent_parser.dart';
import '../intents/intent_result.dart';
import '../intents/intent_type.dart';
import '../recommendation/outfit_candidate.dart';
import '../recommendation/outfit_recommendation_engine.dart';
import '../recommendation/outfit_recommendation_request.dart';

class AssistantService {
  final AssistantContextBuilder _contextBuilder;
  final PromptBuilder _promptBuilder;
  final LlmProvider _llmProvider;
  final AssistantToolContextBuilder _toolContextBuilder;
  final AssistantIntent _intentParser;
  final OutfitRecommendationEngine? _recommendationEngine;
  AssistantToolContext _lastToolContext = const {};
  IntentResult? _lastIntent;
  List<OutfitCandidate> _lastRecommendationCandidates = const [];

  AssistantService({
    required AssistantContextBuilder contextBuilder,
    AssistantToolContextBuilder? toolContextBuilder,
    required LlmProvider llmProvider,
    PromptBuilder? promptBuilder,
    AssistantIntent? intentParser,
    OutfitRecommendationEngine? recommendationEngine,
  }) : _contextBuilder = contextBuilder,
       _llmProvider = llmProvider,
       _toolContextBuilder =
           toolContextBuilder ?? AssistantToolContextBuilder(tools: const []),
       _intentParser = intentParser ?? const IntentParser(),
       _recommendationEngine = recommendationEngine,
       _promptBuilder = promptBuilder ?? PromptBuilder();

  AssistantToolContext get lastToolContext => _lastToolContext;
  IntentResult? get lastIntent => _lastIntent;
  List<OutfitCandidate> get lastRecommendationCandidates =>
      _lastRecommendationCandidates;

  Future<AssistantContext> buildContext() => _contextBuilder.build();

  Future<String> generatePrompt({String? userMessage}) async {
    _lastIntent = userMessage == null ? null : _intentParser.parse(userMessage);
    final context = await buildContext();
    _lastToolContext = await _toolContextBuilder.build(
      calendar: context.calendar,
    );
    final shouldRecommend =
        _lastIntent != null &&
        {
          AssistantIntentType.dailyOutfit,
          AssistantIntentType.weatherOutfit,
          AssistantIntentType.eventOutfit,
          AssistantIntentType.forgottenGarments,
        }.contains(_lastIntent!.type);
    final recommendation =
        shouldRecommend && _recommendationEngine != null
            ? await _recommendationEngine.recommend(
              OutfitRecommendationRequest.fromIntent(_lastIntent!, context),
              candidates: context.wardrobe?.garments
                  .map(OutfitCandidate.fromGarment),
            )
            : null;
    _lastRecommendationCandidates = recommendation?.candidates ?? const [];
    final prompt = _promptBuilder.build(
      context,
      toolContext: _lastToolContext,
      recommendation: recommendation,
    );
    if (_lastIntent == null) return prompt;
    return '$prompt\n\n### DEMANDE UTILISATEUR\n'
        'Intention : ${_lastIntent!.type.name}\n'
        'Paramètres : ${_lastIntent!.parameters}\n'
        'Message : ${_lastIntent!.originalText}';
  }

  Future<String> generateMessage({String? userMessage}) async {
    final chunks = <String>[];
    await for (final chunk in generateMessageStream(userMessage: userMessage)) {
      chunks.add(chunk);
    }
    return chunks.join();
  }

  Stream<String> generateMessageStream({String? userMessage}) async* {
    try {
      final prompt = await generatePrompt(userMessage: userMessage);
      if (_llmProvider case final StreamingLlmProvider provider) {
        yield* provider.generateStream(prompt);
      } else {
        yield await _llmProvider.generate(prompt);
      }
    } on LlmException catch (error) {
      yield error.message;
    } catch (_) {
      yield 'WardrobeGPT est temporairement indisponible. Réessayez.';
    }
  }
}
