import '../../features/assistant/memory/memory_service.dart';
import '../../features/assistant/memory/personalization_snapshot.dart';
import '../../models/garment.dart';
import 'ai_context.dart';

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

  Future<WardrobeAiContext> build() async {
    final stopwatch = Stopwatch()..start();
    final garments = await loadCurrentGarments();
    PersonalizationSnapshot? personalization;
    try {
      personalization = await memoryService?.loadSnapshot();
    } catch (_) {
      // Personalization is optional; current database garments are not.
    }
    return WardrobeAiContext(
      generatedAt: clock(),
      garments: garments,
      personalization: personalization,
      loadDuration: stopwatch.elapsed,
    );
  }
}
