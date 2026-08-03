import 'ai_engine.dart';
import 'ai_orchestrator.dart';
import 'ai_orchestration_cache.dart';
import 'ai_orchestration_logger.dart';

abstract final class WardrobeAiEngineIds {
  static const scanner = 'scanner';
  static const fusion = 'fusion';
  static const styleAnalysis = 'style_analysis';
  static const wardrobeIntelligence = 'wardrobe_intelligence';
  static const recommendation = 'recommendation';
  static const wardrobeGpt = 'wardrobe_gpt';
}

/// Composition root for the standard pipeline. Callbacks adapt the existing
/// services; this class deliberately owns neither their implementations nor
/// their business rules.
AiOrchestrator createWardrobeAiOrchestrator({
  required Map<String, AiEngineCallback> callbacks,
  AiOrchestrationCache? cache,
  AiOrchestrationLogger logger = const DeveloperAiOrchestrationLogger(),
}) {
  AiEngineCallback callback(String id) {
    final value = callbacks[id];
    if (value == null) throw ArgumentError('Callback manquant pour le moteur "$id".');
    return value;
  }

  CallbackAiEngine engine(String id, {Iterable<String> dependencies = const [], Iterable<String> fields = const []}) =>
      CallbackAiEngine(id: id, execute: callback(id), dependencies: dependencies, invalidatedBy: fields);

  return AiOrchestrator(
    cache: cache,
    logger: logger,
    engines: [
      engine(WardrobeAiEngineIds.scanner, fields: const ['photo']),
      engine(WardrobeAiEngineIds.fusion, dependencies: const [WardrobeAiEngineIds.scanner], fields: const ['photo']),
      engine(WardrobeAiEngineIds.styleAnalysis, dependencies: const [WardrobeAiEngineIds.fusion], fields: const ['photo', 'category', 'color', 'material', 'style']),
      engine(WardrobeAiEngineIds.wardrobeIntelligence, dependencies: const [WardrobeAiEngineIds.styleAnalysis], fields: const ['photo', 'category', 'color', 'material', 'style', 'season', 'wear_history']),
      engine(WardrobeAiEngineIds.recommendation, dependencies: const [WardrobeAiEngineIds.wardrobeIntelligence], fields: const ['photo', 'category', 'color', 'material', 'style', 'season', 'wear_history', 'occasion', 'weather']),
      engine(WardrobeAiEngineIds.wardrobeGpt, dependencies: const [WardrobeAiEngineIds.recommendation], fields: const ['photo', 'category', 'color', 'material', 'style', 'season', 'wear_history', 'occasion', 'weather']),
    ],
  );
}
