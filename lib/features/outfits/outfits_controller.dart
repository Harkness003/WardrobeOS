import 'package:flutter/foundation.dart';

import '../../data/database_service.dart';
import '../../models/garment.dart';
import '../../models/outfit.dart';

class OutfitsController extends ChangeNotifier {
  final DatabaseService _database;

  OutfitsController({DatabaseService? database})
    : _database = database ?? DatabaseService.instance;

  List<Outfit> outfits = [];
  final Map<String, List<Garment>> garmentsByOutfit = {};
  bool loading = true;
  Object? error;
  bool _disposed = false;

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
