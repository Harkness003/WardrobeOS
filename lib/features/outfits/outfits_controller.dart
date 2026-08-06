import 'package:flutter/foundation.dart';

import '../../data/database_service.dart';
import '../../models/garment.dart';
import '../../models/outfit.dart';
import '../../core/outfit_generation/outfit_generation_engine.dart';
import '../../core/ai_context/wardrobe_ai_context_service.dart';

typedef WardrobeLoader = Future<List<Garment>> Function();

class OutfitsController extends ChangeNotifier {
  static const int neverWornScore = 100000;
  final DatabaseService _database;
  final OutfitGenerationEngine _generationEngine;
  final WardrobeLoader _wardrobeLoader;
  final WardrobeAiContextService? _aiContextService;

  OutfitsController({DatabaseService? database, OutfitGenerationEngine? generationEngine,
    WardrobeLoader? wardrobeLoader, WardrobeAiContextService? aiContextService})
    : _database = database ?? DatabaseService.instance,
      _generationEngine = generationEngine ?? const OutfitGenerationEngine(),
      _wardrobeLoader = wardrobeLoader ?? (() => (database ?? DatabaseService.instance).getGarments()),
      _aiContextService = aiContextService;

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
    generating = true;
    error = null;
    _notifyListenersIfActive();
    try {
      final context = await _aiContextService?.build();
      final wardrobe = context?.garments ?? await _wardrobeLoader();
      final result = _generationEngine.generate(OutfitGenerationRequest(
        wardrobe: wardrobe, proposalCount: 3,
        contextLoadDuration: context?.loadDuration ?? Duration.zero,
      ));
      proposals = result.proposals;
      generationDiagnostic = result.diagnostic;
      generationMessage = result.diagnostic.userReason;
    } catch (exception) {
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
    loading = true;
    error = null;
    _notifyListenersIfActive();
    try {
      outfits = await _database.getAllOutfits();
      final entries = await Future.wait(
        outfits.map(
          (outfit) async => MapEntry(
            outfit.id,
            await _database.getGarmentsInOutfit(outfit.id),
          ),
        ),
      );
      garmentsByOutfit
        ..clear()
        ..addEntries(entries);
    } catch (exception) {
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
