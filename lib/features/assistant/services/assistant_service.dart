import '../context/assistant_context.dart';
import '../context/assistant_context_builder.dart';
import '../prompt/prompt_builder.dart';
import '../ai/llm_provider.dart';
import '../tools/assistant_tool_context_builder.dart';
import '../intents/assistant_intent.dart';
import '../intents/intent_parser.dart';
import '../intents/intent_result.dart';
import '../intents/intent_type.dart';
import '../../../core/outfit_generation/outfit_generation_engine.dart';
import '../../../core/recommendation/recommendation_context.dart';

class AssistantService {
  final AssistantContextBuilder _contextBuilder;
  final PromptBuilder _promptBuilder;
  final LlmProvider _llmProvider;
  final AssistantToolContextBuilder _toolContextBuilder;
  final AssistantIntent _intentParser;
  final OutfitGenerationEngine _outfitEngine;
  AssistantToolContext _lastToolContext = const {};
  IntentResult? _lastIntent;
  List<OutfitGenerationProposal> _lastOutfitProposals = const [];

  AssistantService({
    required AssistantContextBuilder contextBuilder,
    AssistantToolContextBuilder? toolContextBuilder,
    required LlmProvider llmProvider,
    PromptBuilder? promptBuilder,
    AssistantIntent? intentParser,
    OutfitGenerationEngine outfitEngine = const OutfitGenerationEngine(),
  }) : _contextBuilder = contextBuilder,
       _llmProvider = llmProvider,
       _toolContextBuilder =
           toolContextBuilder ?? AssistantToolContextBuilder(tools: const []),
       _intentParser = intentParser ?? const IntentParser(),
       _outfitEngine = outfitEngine,
       _promptBuilder = promptBuilder ?? PromptBuilder();

  AssistantToolContext get lastToolContext => _lastToolContext;
  IntentResult? get lastIntent => _lastIntent;
  List<OutfitGenerationProposal> get lastOutfitProposals => _lastOutfitProposals;

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
    final weather = context.weather;
    final generation = shouldRecommend
        ? _outfitEngine.generate(OutfitGenerationRequest(
            wardrobe: context.wardrobe?.garments ?? const [],
            context: RecommendationContext(
              occasion: _lastIntent!.parameters['occasion'],
              desiredStyle: _lastIntent!.parameters['style'],
              season: _lastIntent!.parameters['saison'],
              weather: weather == null ? null : RecommendationWeather(
                temperature: weather.temperature,
                condition: weather.condition,
                isRaining: _isRain(weather.condition),
              ),
            ),
          ))
        : null;
    _lastOutfitProposals = generation?.proposals ?? const [];
    final prompt = _promptBuilder.build(
      context,
      toolContext: _lastToolContext,
      outfitProposals: _lastOutfitProposals,
      outfitRequest: shouldRecommend ? _lastIntent!.originalText : null,
    );
    if (_lastIntent == null) return prompt;
    return '$prompt\n\n### DEMANDE UTILISATEUR\n'
        'Intention : ${_lastIntent!.type.name}\n'
        'Paramètres : ${_lastIntent!.parameters}\n'
        'Message : ${_lastIntent!.originalText}';
  }

  static bool _isRain(String condition) {
    final value = condition.toLowerCase();
    return value.contains('pluie') || value.contains('averse');
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
