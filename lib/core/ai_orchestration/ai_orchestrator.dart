import 'ai_engine.dart';
import 'ai_orchestration_cache.dart';
import 'ai_orchestration_logger.dart';

class AiOrchestrationResult {
  final String operationId;
  final Map<String, AiEngineResult> engines;

  AiOrchestrationResult({required this.operationId, required Map<String, AiEngineResult> engines})
    : engines = Map.unmodifiable(engines);

  bool get hasErrors => engines.values.any((result) => result.state == AiEngineState.error);
  Iterable<Object?> get usableValues => engines.values.where((result) => result.hasUsableValue).map((result) => result.value);
  AiEngineResult? operator [](String engineId) => engines[engineId];
}

class AiOrchestrator {
  final Map<String, AiEngine> _engines;
  final AiOrchestrationCache _cache;
  final AiOrchestrationLogger _logger;
  final DateTime Function() _clock;

  AiOrchestrator({
    required Iterable<AiEngine> engines,
    AiOrchestrationCache? cache,
    AiOrchestrationLogger logger = const DeveloperAiOrchestrationLogger(),
    DateTime Function()? clock,
  }) : _engines = _indexAndValidate(engines),
       _cache = cache ?? MemoryAiOrchestrationCache(),
       _logger = logger,
       _clock = clock ?? DateTime.now;

  Future<AiOrchestrationResult> execute(AiEngineRequest request) async {
    final selected = _selectEngines(request);
    final ordered = _topologicalOrder();
    final results = <String, AiEngineResult>{};

    for (final engine in ordered) {
      if (!selected.contains(engine.id)) {
        results[engine.id] = _decision(request, engine.id, AiEngineState.skipped, 'Aucun champ modifié ni résultat demandé ne nécessite ce moteur.');
        continue;
      }

      final unavailable = engine.dependencies
          .map((id) => results[id])
          .whereType<AiEngineResult>()
          .where((result) => selected.contains(result.engineId) && !result.hasUsableValue)
          .map((result) => result.engineId)
          .toList(growable: false);
      if (unavailable.isNotEmpty) {
        results[engine.id] = _decision(request, engine.id, AiEngineState.pending, 'Dépendances sans résultat exploitable : ${unavailable.join(', ')}.');
        continue;
      }

      final cacheKey = _cacheKey(request, engine.id);
      final cached = cacheKey == null ? null : await _cache.read(cacheKey);
      if (cached != null) {
        results[engine.id] = _decision(request, engine.id, AiEngineState.upToDate, 'Résultat réutilisé depuis le cache.', value: cached.value);
        continue;
      }

      final stopwatch = Stopwatch()..start();
      try {
        final value = await engine.execute(AiEngineContext(request: request, dependencies: {for (final id in engine.dependencies) id: results[id]!}));
        stopwatch.stop();
        final result = AiEngineResult(engineId: engine.id, state: AiEngineState.success, value: value, reason: 'Moteur exécuté.', duration: stopwatch.elapsed);
        results[engine.id] = result;
        _log(request, result);
        if (cacheKey != null) await _cache.write(cacheKey, AiOrchestrationCacheEntry(value: value, storedAt: _clock()));
      } catch (error) {
        stopwatch.stop();
        results[engine.id] = _decision(request, engine.id, AiEngineState.error, 'Échec isolé du moteur ; le pipeline poursuit les étapes indépendantes.', error: error, duration: stopwatch.elapsed);
      }
    }
    return AiOrchestrationResult(operationId: request.operationId, engines: results);
  }

  Set<String> _selectEngines(AiEngineRequest request) {
    final selected = <String>{...request.requestedEngines};
    void includeDependencies(String id) {
      final engine = _engines[id];
      if (engine == null) throw ArgumentError.value(id, 'requestedEngines', 'Moteur inconnu');
      for (final dependency in engine.dependencies) {
        if (selected.add(dependency)) includeDependencies(dependency);
      }
    }
    for (final id in selected.toList()) { includeDependencies(id); }
    // Field invalidations select only affected engines. Their predecessors are
    // ordering constraints, not mandatory re-computations: the request can
    // carry the already persisted garment data produced by an earlier stage.
    for (final engine in _engines.values) {
      if (engine.invalidatedBy.any(request.changedFields.contains)) selected.add(engine.id);
    }
    return selected;
  }

  String? _cacheKey(AiEngineRequest request, String engineId) =>
      request.cacheFingerprint == null ? null : '$engineId:${request.cacheFingerprint}';

  AiEngineResult _decision(AiEngineRequest request, String id, AiEngineState state, String reason, {Object? value, Object? error, Duration duration = Duration.zero}) {
    final result = AiEngineResult(engineId: id, state: state, reason: reason, value: value, error: error, duration: duration);
    _log(request, result);
    return result;
  }

  void _log(AiEngineRequest request, AiEngineResult result) => _logger.engineDecision(operationId: request.operationId, engineId: result.engineId, decision: result.state.name, reason: result.reason, error: result.error);

  List<AiEngine> _topologicalOrder() {
    final ordered = <AiEngine>[];
    final visited = <String>{};
    void visit(String id) {
      if (!visited.add(id)) return;
      final engine = _engines[id]!;
      for (final dependency in engine.dependencies) { visit(dependency); }
      ordered.add(engine);
    }
    for (final id in _engines.keys) { visit(id); }
    return ordered;
  }

  static Map<String, AiEngine> _indexAndValidate(Iterable<AiEngine> source) {
    final engines = <String, AiEngine>{};
    for (final engine in source) {
      if (engine.id.trim().isEmpty || engines.containsKey(engine.id)) throw ArgumentError('Chaque moteur doit avoir un identifiant unique et non vide.');
      engines[engine.id] = engine;
    }
    for (final engine in engines.values) {
      for (final dependency in engine.dependencies) {
        if (!engines.containsKey(dependency)) throw ArgumentError('Dépendance inconnue "$dependency" pour "${engine.id}".');
      }
    }
    final visiting = <String>{};
    final visited = <String>{};
    void visit(String id) {
      if (visited.contains(id)) return;
      if (!visiting.add(id)) throw ArgumentError('Cycle détecté dans le pipeline autour de "$id".');
      for (final dependency in engines[id]!.dependencies) { visit(dependency); }
      visiting.remove(id);
      visited.add(id);
    }
    for (final id in engines.keys) { visit(id); }
    return Map.unmodifiable(engines);
  }
}
