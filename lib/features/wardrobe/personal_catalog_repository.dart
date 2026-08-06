import '../../data/database_service.dart';
import '../../models/garment_normalizer.dart';

enum PersonalCatalogField { subcategory, brand, material, color }

/// The single persistence gateway for values learned from users or AI.
class PersonalCatalogRepository {
  final DatabaseService _database;
  PersonalCatalogRepository({DatabaseService? database})
      : _database = database ?? DatabaseService.instance;

  Future<List<String>> values(PersonalCatalogField field) =>
      _database.getPersonalCatalogValues(field.name);

  Future<bool> learn(PersonalCatalogField field, String? raw) async {
    final value = field == PersonalCatalogField.brand
        ? GarmentNormalizer.brand(raw)
        : GarmentNormalizer.classification(raw);
    if (!_isUseful(value)) return false;
    return _database.addPersonalCatalogValue(field.name, value!);
  }

  bool _isUseful(String? value) {
    if (value == null || value.length > 60 || value.split(' ').length > 6) return false;
    final key = value.toLowerCase();
    return !RegExp(r'^(null|n/?a|unknown|inconnu|autre|json|error|erreur)$').hasMatch(key) &&
        !key.contains('{') && !key.contains('}');
  }
}
