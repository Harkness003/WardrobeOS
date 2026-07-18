import 'package:flutter/foundation.dart';
import '../../data/database_service.dart';
import '../../data/image_storage_service.dart';
import '../../models/garment.dart';
import '../../models/wear_history.dart';

class WardrobeController extends ChangeNotifier {
  final DatabaseService _db;
  WardrobeController({DatabaseService? database})
    : _db = database ?? DatabaseService.instance;

  List<Garment> garments = [];
  bool loading = true;
  Object? error;
  String search = '';
  String category = 'Tout';
  bool favoritesOnly = false;
  String season = '';
  String brand = '';
  String color = '';
  String material = '';
  String style = '';
  String occasion = '';
  bool _disposed = false;

  int get advancedFilterCount =>
      [
        season,
        brand,
        color,
        material,
        style,
        occasion,
      ].where((value) => value.trim().isNotEmpty).length;

  Future<void> load() async {
    loading = true;
    error = null;
    _notifyListenersIfActive();
    try {
      garments = await _db.getGarments(
        search: search,
        category: category,
        favoritesOnly: favoritesOnly,
        season: season,
        brand: brand,
        color: color,
        material: material,
        style: style,
        occasion: occasion,
      );
    } catch (exception) {
      error = exception;
    } finally {
      loading = false;
      _notifyListenersIfActive();
    }
  }

  Future<void> setSearch(String value) async {
    search = value;
    await load();
  }

  Future<void> setCategory(String value) async {
    category = value;
    await load();
  }

  Future<void> toggleFavoritesFilter() async {
    favoritesOnly = !favoritesOnly;
    await load();
  }

  Future<void> applyAdvancedFilters({
    required String season,
    required String brand,
    required String color,
    required String material,
    required String style,
    required String occasion,
  }) async {
    this.season = season.trim();
    this.brand = brand.trim();
    this.color = color.trim();
    this.material = material.trim();
    this.style = style.trim();
    this.occasion = occasion.trim();
    await load();
  }

  Future<void> resetAdvancedFilters() => applyAdvancedFilters(
    season: '',
    brand: '',
    color: '',
    material: '',
    style: '',
    occasion: '',
  );

  Future<void> save(Garment garment, {required bool isNew}) async {
    if (isNew) {
      await _db.insertGarment(garment);
    } else {
      await _db.updateGarment(garment);
    }
    await load();
  }

  /// Inserts a garment without refreshing this controller's local list.
  ///
  /// This is useful for short-lived creation flows whose caller refreshes the
  /// visible wardrobe after the route closes.
  Future<void> insert(Garment garment) => _db.insertGarment(garment);

  Future<void> toggleFavorite(Garment garment) async {
    await _db.updateGarment(
      garment.copyWith(
        isFavorite: !garment.isFavorite,
        updatedAt: DateTime.now(),
      ),
    );
    await load();
  }

  Future<List<WearHistory>> getWearHistory(String garmentId, {int? limit}) {
    return _db.getWearHistory(garmentId, limit: limit);
  }

  Future<WearHistory?> getFirstWear(String garmentId) {
    return _db.getFirstWear(garmentId);
  }

  Future<WearHistory> recordWear(Garment garment, {DateTime? wornAt}) async {
    final wear = await _db.recordWear(garment.id, wornAt: wornAt);
    await load();
    return wear;
  }

  Future<bool> removeLastWear(Garment garment) async {
    final removed = await _db.removeLastWear(garment.id);
    if (removed) await load();
    return removed;
  }

  Future<bool> deleteWear(Garment garment, WearHistory wear) async {
    final wearId = wear.id;
    if (wearId == null) return false;

    final removed = await _db.deleteWear(garment.id, wearId);
    if (removed) await load();
    return removed;
  }

  Future<void> delete(Garment garment) async {
    await _db.deleteGarment(garment.id);
    await ImageStorageService.remove(garment.imagePath);
    await load();
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
