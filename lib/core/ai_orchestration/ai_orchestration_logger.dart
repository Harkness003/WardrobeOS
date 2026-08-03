import 'dart:developer' as developer;

abstract interface class AiOrchestrationLogger {
  void engineDecision({required String operationId, required String engineId, required String decision, required String reason, Object? error});
}

class DeveloperAiOrchestrationLogger implements AiOrchestrationLogger {
  const DeveloperAiOrchestrationLogger();

  @override
  void engineDecision({required String operationId, required String engineId, required String decision, required String reason, Object? error}) {
    developer.log(
      'operation=$operationId engine=$engineId decision=$decision reason=$reason',
      name: 'wardrobeos.ai_orchestrator',
      error: error,
    );
  }
}
