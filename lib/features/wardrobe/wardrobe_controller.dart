import 'package:flutter/foundation.dart';
import '../../data/database_service.dart';
import '../../data/image_storage_service.dart';
import '../../models/garment.dart';

class WardrobeController extends ChangeNotifier {
  final DatabaseService _db;
  WardrobeController({DatabaseService? database}) : _db = database ?? DatabaseService.instance;

  List<Garment> garments = [];
  bool loading = true;
  String search = '';
  String category = 'Tout';
  bool favoritesOnly = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    garments = await _db.getGarments(search: search, category: category, favoritesOnly: favoritesOnly);
    loading = false;
    notifyListeners();
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

  Future<void> delete(Garment garment) async {
    await _db.deleteGarment(garment.id);
    await ImageStorageService.remove(garment.imagePath);
    await load();
  }
}
