import 'package:flutter/foundation.dart';
import '../../data/database_service.dart';
import '../../data/image_storage_service.dart';
import '../../models/garment.dart';
import '../../models/wear_history.dart';

class WardrobeController extends ChangeNotifier {
  final DatabaseService _db;
  WardrobeController({DatabaseService? database}) : _db = database ?? DatabaseService.instance;

  List<Garment> garments = [];
  bool loading = true;
  Object? error;
  String search = '';
  String category = 'Tout';
  bool favoritesOnly = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      garments = await _db.getGarments(
        search: search,
        category: category,
        favoritesOnly: favoritesOnly,
      );
    } catch (exception) {
      error = exception;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setSearch(String value) async { search = value; await load(); }
  Future<void> setCategory(String value) async { category = value; await load(); }
  Future<void> toggleFavoritesFilter() async { favoritesOnly = !favoritesOnly; await load(); }

  Future<void> save(Garment garment, {required bool isNew}) async {
    if (isNew) { await _db.insertGarment(garment); } else { await _db.updateGarment(garment); }
    await load();
  }

  Future<void> toggleFavorite(Garment garment) async {
    await _db.updateGarment(garment.copyWith(isFavorite: !garment.isFavorite, updatedAt: DateTime.now()));
    await load();
  }


  Future<List<WearHistory>> getWearHistory(
    String garmentId, {
    int? limit,
  }) {
    return _db.getWearHistory(garmentId, limit: limit);
  }

  Future<void> recordWear(Garment garment, {DateTime? wornAt}) async {
    await _db.recordWear(garment.id, wornAt: wornAt);
    await load();
  }

  Future<bool> removeLastWear(Garment garment) async {
    final removed = await _db.removeLastWear(garment.id);
    if (removed) await load();
    return removed;
  }

  Future<void> delete(Garment garment) async {
    await _db.deleteGarment(garment.id);
    await ImageStorageService.remove(garment.imagePath);
    await load();
  }
}
