enum AiEngineState { success, error, skipped, upToDate, pending }

class AiEngineRequest {
  final String operationId;
  final Object? input;
  final Set<String> changedFields;
  final Set<String> requestedEngines;
  final String? cacheFingerprint;
  final Map<String, Object?> metadata;

  AiEngineRequest({
    required this.operationId,
    this.input,
    Iterable<String> changedFields = const [],
    Iterable<String> requestedEngines = const [],
    this.cacheFingerprint,
    Map<String, Object?> metadata = const {},
  }) : changedFields = Set.unmodifiable(changedFields),
       requestedEngines = Set.unmodifiable(requestedEngines),
       metadata = Map.unmodifiable(metadata);
}

class AiEngineContext {
  final AiEngineRequest request;
  final Map<String, AiEngineResult> dependencies;

  AiEngineContext({required this.request, required Map<String, AiEngineResult> dependencies})
    : dependencies = Map.unmodifiable(dependencies);

  T? resultOf<T>(String engineId) {
    final value = dependencies[engineId]?.value;
    return value is T ? value : null;
  }
}

class AiEngineResult {
  final String engineId;
  final AiEngineState state;
  final Object? value;
  final String reason;
  final Object? error;
  final Duration duration;

  const AiEngineResult({
    required this.engineId,
    required this.state,
    required this.reason,
    this.value,
    this.error,
    this.duration = Duration.zero,
  });

  bool get hasUsableValue =>
      (state == AiEngineState.success || state == AiEngineState.upToDate) && value != null;
}

abstract interface class AiEngine {
  String get id;
  Set<String> get dependencies;

  /// Input fields that invalidate this engine. An empty set means that the
  /// engine only runs when explicitly requested or pulled in as a dependency.
  Set<String> get invalidatedBy;
  Future<Object?> execute(AiEngineContext context);
}

typedef AiEngineCallback = Future<Object?> Function(AiEngineContext context);

/// Small adapter used to register existing services without coupling them to
/// the orchestrator or to one another.
class CallbackAiEngine implements AiEngine {
  @override
  final String id;
  @override
  final Set<String> dependencies;
  @override
  final Set<String> invalidatedBy;
  final AiEngineCallback _callback;

  CallbackAiEngine({
    required this.id,
    required AiEngineCallback execute,
    Iterable<String> dependencies = const [],
    Iterable<String> invalidatedBy = const [],
  }) : _callback = execute,
       dependencies = Set.unmodifiable(dependencies),
       invalidatedBy = Set.unmodifiable(invalidatedBy);

  @override
  Future<Object?> execute(AiEngineContext context) => _callback(context);
}
