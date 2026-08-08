import 'package:flutter/foundation.dart';

import '../../data/database_service.dart';
import '../../models/garment.dart';
import '../../models/outfit.dart';
import '../../core/outfit_generation/outfit_generation_engine.dart';
import '../../core/ai_context/wardrobe_ai_context_service.dart';
import '../../core/diagnostics/diagnostic_service.dart';

typedef WardrobeLoader = Future<List<Garment>> Function();
typedef StoredOutfitsLoader = Future<StoredOutfitReadResult> Function();
typedef OutfitGarmentsLoader = Future<List<Garment>> Function(String outfitId);
typedef MissingGarmentReferencesLoader = Future<int> Function();

class OutfitsController extends ChangeNotifier {
  static const int neverWornScore = 100000;
  final DatabaseService _database;
  final OutfitGenerationEngine _generationEngine;
  final WardrobeLoader _wardrobeLoader;
  final WardrobeAiContextService? _aiContextService;
  final StoredOutfitsLoader _storedOutfitsLoader;
  final OutfitGarmentsLoader _outfitGarmentsLoader;
  final MissingGarmentReferencesLoader _missingReferencesLoader;

  OutfitsController({DatabaseService? database, OutfitGenerationEngine? generationEngine,
    WardrobeLoader? wardrobeLoader, WardrobeAiContextService? aiContextService,
    StoredOutfitsLoader? storedOutfitsLoader,
    OutfitGarmentsLoader? outfitGarmentsLoader,
    MissingGarmentReferencesLoader? missingReferencesLoader})
    : _database = database ?? DatabaseService.instance,
      _generationEngine = generationEngine ?? const OutfitGenerationEngine(),
      _wardrobeLoader = wardrobeLoader ?? (() => (database ?? DatabaseService.instance).getGarments()),
      _aiContextService = aiContextService,
      _storedOutfitsLoader = storedOutfitsLoader ??
          (database ?? DatabaseService.instance).getAllOutfitsSafely,
      _outfitGarmentsLoader = outfitGarmentsLoader ??
          (database ?? DatabaseService.instance).getGarmentsInOutfit,
      _missingReferencesLoader = missingReferencesLoader ??
          (database ?? DatabaseService.instance).countMissingGarmentReferences;

  List<Outfit> outfits = [];
  final Map<String, List<Garment>> garmentsByOutfit = {};
  bool loading = true;
  Object? error;
  List<OutfitGenerationProposal> proposals = const [];
  bool generating = false;
  bool _disposed = false;
  OutfitGenerationDiagnostic? generationDiagnostic;
  String? generationMessage;

  Future<void> generate() async {
    final stopwatch = Stopwatch()..start();
    final diagnostics = DiagnosticService.instance;
    final correlationId = diagnostics.newCorrelationId('outfits-generate');
    diagnostics.publish(module: DiagnosticModule.outfits, level: AppDiagnosticLevel.info,
      state: 'Démarré', summary: 'Génération demandée', source: 'OutfitsController.generate',
      correlationId: correlationId);
    generating = true;
    error = null;
    _notifyListenersIfActive();
    try {
      final context = await _aiContextService?.build(correlationId: correlationId);
      final wardrobe = context?.garments ?? await _wardrobeLoader();
      final result = _generationEngine.generate(OutfitGenerationRequest(
        wardrobe: wardrobe, proposalCount: 3,
        contextLoadDuration: context?.loadDuration ?? Duration.zero,
      ));
      proposals = result.proposals;
      generationDiagnostic = result.diagnostic;
      generationMessage = result.diagnostic.userReason;
      diagnostics.publish(module: DiagnosticModule.outfits,
        level: proposals.isEmpty ? AppDiagnosticLevel.warning : AppDiagnosticLevel.success,
        state: proposals.isEmpty ? 'Sans proposition' : 'Prêt',
        summary: '${proposals.length} proposition(s)', source: 'OutfitsController.generate',
        correlationId: correlationId, duration: stopwatch.elapsed,
        reason: proposals.isEmpty ? result.diagnostic.userReason : null,
        details: {'garments': wardrobe.length, 'proposals': proposals.length,
          'pipeline': 'generate'}, pipeline: [
          DiagnosticStep('wardrobeContext', duration: context?.loadDuration ?? Duration.zero),
          const DiagnosticStep('outfitGeneration'),
          DiagnosticStep('result', level: proposals.isEmpty ? AppDiagnosticLevel.warning : AppDiagnosticLevel.success),
        ]);
    } catch (exception) {
      final engineError = exception is OutfitGenerationException ? exception : null;
      diagnostics.publish(module: DiagnosticModule.outfits, level: AppDiagnosticLevel.error,
        state: 'Échec', summary: 'Génération interrompue', source: 'OutfitsController.generate',
        correlationId: correlationId, duration: stopwatch.elapsed,
        reason: 'outfitGenerationFailure', details: {
          'exceptionType': engineError?.exceptionType ?? exception.runtimeType.toString(),
          if (engineError?.technicalTypeMessage != null)
            'technicalTypeMessage': engineError!.technicalTypeMessage,
          'phase': engineError?.phase.name ?? 'candidateConstruction',
          'garmentsCount': engineError?.garmentsCount ?? 0,
          'pipeline': 'generate',
        });
      error = exception;
    } finally {
      generating = false;
      _notifyListenersIfActive();
    }
  }

  Future<void> saveProposal(OutfitGenerationProposal proposal) async {
    await create(proposal.outfit, proposal.outfit.allGarments.map((item) => item.id));
  }

  Future<void> load() async {
    final stopwatch = Stopwatch()..start();
    final diagnostics = DiagnosticService.instance;
    final correlationId = diagnostics.newCorrelationId('outfits-load');
    diagnostics.publish(module: DiagnosticModule.outfits, level: AppDiagnosticLevel.info,
      state: 'Démarré', summary: 'Chargement des tenues demandé', source: 'OutfitsController.load',
      correlationId: correlationId, details: const {'pipeline': 'load'});
    loading = true;
    error = null;
    _notifyListenersIfActive();
    try {
      final stored = await _storedOutfitsLoader();
      outfits = stored.outfits;
      final entries = <MapEntry<String, List<Garment>>>[];
      var itemDecodeErrors = 0;
      for (final outfit in outfits) {
        try {
          entries.add(MapEntry(
            outfit.id,
            await _outfitGarmentsLoader(outfit.id),
          ));
        } on Object {
          // Keep the saved outfit visible and preserve its database links. A
          // corrupt linked garment must not take down the complete list.
          entries.add(MapEntry(outfit.id, const []));
          itemDecodeErrors++;
        }
      }
      final missingGarments = await _missingReferencesLoader();
      garmentsByOutfit
        ..clear()
        ..addEntries(entries);
      final itemCount = entries.fold<int>(0, (sum, entry) => sum + entry.value.length);
      final issueCount = stored.decodeErrors + itemDecodeErrors + missingGarments;
      diagnostics.publish(module: DiagnosticModule.outfits,
        level: issueCount == 0 ? AppDiagnosticLevel.success : AppDiagnosticLevel.warning,
        state: issueCount == 0 ? 'Prêt' : 'Partiel',
        summary: issueCount == 0
            ? '${outfits.length} tenue(s) chargée(s)'
            : '${outfits.length} tenue(s) chargée(s), données incompatibles conservées',
        source: 'OutfitsController.load',
        correlationId: correlationId, duration: stopwatch.elapsed,
        details: {'pipeline': 'load', 'outfits': outfits.length, 'items': itemCount,
          'missingGarments': missingGarments,
          'decodeErrors': stored.decodeErrors + itemDecodeErrors},
        reason: issueCount == 0 ? null : 'storedOutfitPartialOrInvalid');
    } catch (exception) {
      diagnostics.publish(module: DiagnosticModule.outfits, level: AppDiagnosticLevel.error,
        state: 'Échec', summary: 'Chargement des tenues interrompu', source: 'OutfitsController.load',
        correlationId: correlationId, duration: stopwatch.elapsed,
        reason: 'storedOutfitReadOrDecodeFailure',
        details: {'pipeline': 'load', 'technical': exception.runtimeType.toString()});
      error = exception;
    } finally {
      loading = false;
      _notifyListenersIfActive();
    }
  }

  Future<void> create(Outfit outfit, Iterable<String> garmentIds) async {
    await _database.createOutfit(outfit);
    for (final garmentId in garmentIds) {
      await _database.addGarmentToOutfit(outfit.id, garmentId);
    }
    await load();
  }

  Future<void> update(
    Outfit outfit,
    Set<String> originalGarmentIds,
    Set<String> garmentIds,
  ) async {
    await _database.updateOutfit(outfit);
    for (final id in garmentIds.difference(originalGarmentIds)) {
      await _database.addGarmentToOutfit(outfit.id, id);
    }
    for (final id in originalGarmentIds.difference(garmentIds)) {
      await _database.removeGarmentFromOutfit(outfit.id, id);
    }
    await load();
  }

  Future<void> delete(Outfit outfit) async {
    await _database.deleteOutfit(outfit.id);
    await load();
  }

  Future<bool> recordWear(Outfit outfit) async {
    final recorded = await _database.recordOutfitWear(outfit.id);
    if (recorded) await load();
    return recorded;
  }

  void _notifyListenersIfActive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
