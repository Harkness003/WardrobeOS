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
import '../../../core/diagnostics/diagnostic_service.dart';

class AssistantService {
  final AssistantContextBuilder _contextBuilder;
  final PromptBuilder _promptBuilder;
  final LlmProvider _llmProvider;
  final AssistantToolContextBuilder _toolContextBuilder;
  final AssistantIntent _intentParser;
  final OutfitGenerationEngine _outfitEngine;
  final String Function() _languageCode;
  AssistantToolContext _lastToolContext = const {};
  IntentResult? _lastIntent;
  List<OutfitGenerationProposal> _lastOutfitProposals = const [];
  OutfitGenerationDiagnostic? _lastGenerationDiagnostic;

  AssistantService({
    required AssistantContextBuilder contextBuilder,
    AssistantToolContextBuilder? toolContextBuilder,
    required LlmProvider llmProvider,
    PromptBuilder? promptBuilder,
    AssistantIntent? intentParser,
    OutfitGenerationEngine outfitEngine = const OutfitGenerationEngine(),
    String Function()? languageCode,
  }) : _contextBuilder = contextBuilder,
       _llmProvider = llmProvider,
       _toolContextBuilder =
           toolContextBuilder ?? AssistantToolContextBuilder(tools: const []),
       _intentParser = intentParser ?? const IntentParser(),
       _outfitEngine = outfitEngine,
       _languageCode = languageCode ?? (() => 'fr'),
       _promptBuilder = promptBuilder ?? PromptBuilder();

  AssistantToolContext get lastToolContext => _lastToolContext;
  IntentResult? get lastIntent => _lastIntent;
  List<OutfitGenerationProposal> get lastOutfitProposals => _lastOutfitProposals;
  OutfitGenerationDiagnostic? get lastGenerationDiagnostic => _lastGenerationDiagnostic;

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
            contextLoadDuration: context.wardrobe?.loadDuration ?? Duration.zero,
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
    _lastGenerationDiagnostic = generation?.diagnostic;
    final prompt = _promptBuilder.build(
      context,
      languageCode: _languageCode(),
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

  String _ensureUsefulResponse(String response) {
    final trimmed = response.trim();
    final completion = _qualityCompletion(trimmed);
    return completion == null ? trimmed : '$trimmed$completion';
  }

  String? _qualityCompletion(String response) {
    final text = response.trim();
    if (text.isEmpty) {
      return 'Je n’ai pas encore assez d’éléments pour répondre correctement. Reformule ta demande ou précise l’occasion, la météo ou le niveau de style attendu.';
    }
    final intent = _lastIntent?.type;
    final asksAdvice = intent != null && {
      AssistantIntentType.dailyOutfit,
      AssistantIntentType.weatherOutfit,
      AssistantIntentType.eventOutfit,
      AssistantIntentType.forgottenGarments,
      AssistantIntentType.wardrobeAnalysis,
    }.contains(intent);
    if (!asksAdvice) return null;

    final words = RegExp(r"\S+").allMatches(text).length;
    final hasReason = RegExp(r'\b(car|parce que|puisque|raison|adapt|cohérent|température|météo|style|therm)', caseSensitive: false).hasMatch(text);
    final hasAlternative = RegExp(r'\b(alternative|option|sinon|autre|variante)\b', caseSensitive: false).hasMatch(text);
    final needsSupport = words < 28 || !hasReason;
    if (!needsSupport) return null;

    final buffer = StringBuffer('\n\nPourquoi : je m’appuie sur les vêtements disponibles dans ton dressing');
    final proposals = _lastOutfitProposals;
    if (proposals.isNotEmpty) {
      final first = proposals.first;
      if (first.reasons.isNotEmpty) {
        buffer.write(', notamment ${first.reasons.take(2).join(' et ').toLowerCase()}');
      }
      final names = first.garments.map((item) => item.name).where((name) => name.trim().isNotEmpty).take(4).join(', ');
      if (names.isNotEmpty) buffer.write('. Proposition concrète : $names');
      if (!hasAlternative && proposals.length > 1) {
        final altNames = proposals[1].garments.map((item) => item.name).where((name) => name.trim().isNotEmpty).take(4).join(', ');
        if (altNames.isNotEmpty) buffer.write('. Alternative : $altNames');
      }
    } else {
      buffer.write(', tes préférences connues et le contexte météo ou agenda disponible');
    }
    buffer.write('.');
    return buffer.toString();
  }

  Stream<String> generateMessageStream({String? userMessage}) async* {
    final stopwatch = Stopwatch()..start();
    try {
      final prompt = await generatePrompt(userMessage: userMessage);
      if (_lastIntent != null && _lastGenerationDiagnostic?.failure != null) {
        yield _outfitFailureResponse(_lastGenerationDiagnostic!.failure!);
        return;
      }
      if (_llmProvider case final StreamingLlmProvider provider) {
        final chunks = <String>[];
        await for (final chunk in provider.generateStream(prompt)) {
          chunks.add(chunk);
          yield chunk;
        }
        final completion = _qualityCompletion(chunks.join());
        if (completion != null) yield completion;
      } else {
        yield _ensureUsefulResponse(await _llmProvider.generate(prompt));
      }
      DiagnosticService.instance.publish(module: DiagnosticModule.wardrobeGpt,
        level: AppDiagnosticLevel.success, state: 'Réponse générée', summary: 'Demande traitée',
        source: 'AssistantService', duration: stopwatch.elapsed,
        details: {'intention': _lastIntent?.type.name ?? 'conversation',
          'tenuesGénérées': _lastOutfitProposals.length},
        pipeline: [
          const DiagnosticStep('Intention'),
          const DiagnosticStep('WardrobeContext'),
          DiagnosticStep('OutfitGeneration', level: _lastGenerationDiagnostic?.failure == null
            ? AppDiagnosticLevel.success : AppDiagnosticLevel.warning),
          DiagnosticStep('Résultat', duration: stopwatch.elapsed),
        ]);
    } on LlmException catch (error) {
      DiagnosticService.instance.publish(module: DiagnosticModule.wardrobeGpt,
        level: AppDiagnosticLevel.error, state: 'Indisponible', summary: 'Réponse non générée',
        source: 'AssistantService', duration: stopwatch.elapsed,
        reason: error.message);
      yield error.message;
    } catch (_) {
      DiagnosticService.instance.publish(module: DiagnosticModule.wardrobeGpt,
        level: AppDiagnosticLevel.error, state: 'Indisponible', summary: 'Réponse non générée',
        source: 'AssistantService', duration: stopwatch.elapsed,
        reason: 'Le contexte ou le fournisseur de réponse n’a pas terminé.');
      yield 'WardrobeGPT est temporairement indisponible. Réessayez.';
    }
  }

  static String _outfitFailureResponse(OutfitGenerationFailure failure) => switch (failure) {
    OutfitGenerationFailure.emptyWardrobe =>
      'Je ne peux pas encore créer une tenue complète : ton dressing est vide. Ajoute au moins un haut et un bas.',
    OutfitGenerationFailure.missingTop =>
      'Je ne peux pas encore créer une tenue complète : aucun haut compatible n’est enregistré. Ajoute un haut puis réessaie.',
    OutfitGenerationFailure.missingBottom =>
      'Je ne peux pas encore créer une tenue complète : ton dressing contient des hauts, mais aucun bas compatible n’est enregistré.',
    OutfitGenerationFailure.incompatibleCombinations =>
      'Je ne peux pas composer une tenue complète avec ces pièces : toutes les combinaisons disponibles sont incompatibles. Ajoute un haut ou un bas différent.',
  };
}
