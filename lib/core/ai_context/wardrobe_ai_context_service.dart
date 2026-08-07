import '../../features/assistant/memory/memory_service.dart';
import '../../features/assistant/memory/personalization_snapshot.dart';
import '../../models/garment.dart';
import 'ai_context.dart';
import '../diagnostics/diagnostic_service.dart';

typedef CurrentGarmentsLoader = Future<List<Garment>> Function();

/// Single entry point for wardrobe data consumed by AI features.
///
/// No snapshot is cached: every [build] invokes [loadCurrentGarments]. Memory
/// is loaded independently and can personalize advice, but is never merged into
/// garment records.
class WardrobeAiContextService {
  final CurrentGarmentsLoader loadCurrentGarments;
  final MemoryService? memoryService;
  final DateTime Function() clock;

  const WardrobeAiContextService({
    required this.loadCurrentGarments,
    this.memoryService,
    this.clock = DateTime.now,
  });

  Future<WardrobeAiContext> build({String? correlationId}) async {
    final stopwatch = Stopwatch()..start();
    final diagnostics = DiagnosticService.instance;
    correlationId ??= diagnostics.newCorrelationId('wardrobe-context');
    diagnostics.publish(module: DiagnosticModule.wardrobeContext,
      level: AppDiagnosticLevel.info, state: 'Démarré', summary: 'Lecture du dressing demandée',
      source: 'WardrobeAiContextService', correlationId: correlationId,
      pipeline: const [DiagnosticStep('databaseRead', level: AppDiagnosticLevel.info)]);
    late final List<Garment> garments;
    try {
      garments = await loadCurrentGarments();
      diagnostics.publish(module: DiagnosticModule.wardrobeContext,
        level: AppDiagnosticLevel.info, state: 'Décodé', summary: '${garments.length} vêtement(s) valide(s)',
        source: 'WardrobeAiContextService', correlationId: correlationId,
        duration: stopwatch.elapsed, details: {'rowsRead': garments.length, 'validGarments': garments.length},
        pipeline: [DiagnosticStep('databaseRead', duration: stopwatch.elapsed),
          const DiagnosticStep('rowToGarment'), const DiagnosticStep('styleAnalysisDecode'),
          const DiagnosticStep('thermalProfileDecode')]);
    } catch (error) {
      diagnostics.publish(module: DiagnosticModule.wardrobeContext,
        level: AppDiagnosticLevel.error, state: 'Échec', summary: 'Lecture ou décodage du dressing interrompu',
        source: 'WardrobeAiContextService', correlationId: correlationId,
        duration: stopwatch.elapsed, reason: 'wardrobeDatabaseOrDecodeFailure',
        details: {'technical': error.runtimeType.toString(), 'decodedGarments': 0},
        pipeline: [DiagnosticStep('databaseRead', level: AppDiagnosticLevel.error,
          duration: stopwatch.elapsed, detail: error.runtimeType.toString())]);
      rethrow;
    }
    PersonalizationSnapshot? personalization;
    try {
      personalization = await memoryService?.loadSnapshot();
    } catch (error) {
      // Personalization is optional; current database garments are not.
      diagnostics.publish(module: DiagnosticModule.wardrobeContext,
        level: AppDiagnosticLevel.warning, state: 'Dégradé', summary: 'Préférences indisponibles',
        source: 'WardrobeAiContextService', correlationId: correlationId,
        reason: 'invalidPreferences', details: {'technical': error.runtimeType.toString()});
    }
    final result = WardrobeAiContext(
      generatedAt: clock(),
      garments: garments,
      personalization: personalization,
      loadDuration: stopwatch.elapsed,
    );
    diagnostics.publish(module: DiagnosticModule.wardrobeContext,
      level: AppDiagnosticLevel.success, state: 'Prêt', summary: 'Contexte dressing prêt',
      source: 'WardrobeAiContextService', correlationId: correlationId,
      duration: stopwatch.elapsed, details: {'garments': garments.length,
        'preferencesAvailable': personalization != null});
    return result;
  }
}
