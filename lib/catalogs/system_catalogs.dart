import '../l10n/app_localizations.dart';

class CatalogItem {
  const CatalogItem(this.id, {this.legacyIds = const []});
  final String id;
  final List<String> legacyIds;
}

/// Canonical system catalogues. Only these IDs cross persistence, AI and
/// business-engine boundaries; labels are resolved at the UI boundary.
abstract final class SystemCatalogs {
  static const categories = [
    CatalogItem('tops', legacyIds: ['Hauts']),
    CatalogItem('shirts', legacyIds: ['Chemises']),
    CatalogItem('jackets', legacyIds: ['Vestes']),
    CatalogItem('bottoms', legacyIds: ['Bas']),
    CatalogItem('shoes', legacyIds: ['Chaussures']),
    CatalogItem('accessories', legacyIds: ['Accessoires']),
    CatalogItem('other', legacyIds: ['Autre']),
  ];
  static const materials = [
    CatalogItem('cotton', legacyIds: ['Coton']), CatalogItem('wool', legacyIds: ['Laine']),
    CatalogItem('merino_wool', legacyIds: ['Mérinos']), CatalogItem('cashmere', legacyIds: ['Cachemire']),
    CatalogItem('linen', legacyIds: ['Lin']), CatalogItem('polyester', legacyIds: ['Polyester']),
    CatalogItem('viscose', legacyIds: ['Viscose']), CatalogItem('denim', legacyIds: ['Denim']),
    CatalogItem('leather', legacyIds: ['Cuir']), CatalogItem('suede', legacyIds: ['Daim']),
    CatalogItem('nylon', legacyIds: ['Nylon']), CatalogItem('silk', legacyIds: ['Soie']),
    CatalogItem('blend', legacyIds: ['Mélange']), CatalogItem('other', legacyIds: ['Autre...']),
  ];
  static const colors = [
    CatalogItem('black', legacyIds: ['Noir']), CatalogItem('white', legacyIds: ['Blanc']),
    CatalogItem('dark_blue', legacyIds: ['Bleu marine', 'Marine']), CatalogItem('blue', legacyIds: ['Bleu']),
    CatalogItem('beige', legacyIds: ['Beige']), CatalogItem('brown', legacyIds: ['Marron']),
    CatalogItem('grey', legacyIds: ['Gris']), CatalogItem('red', legacyIds: ['Rouge']),
    CatalogItem('green', legacyIds: ['Vert']),
  ];

  static String canonicalId(Iterable<CatalogItem> catalog, String value) {
    final normalized = _normalize(value);
    return catalog.firstWhere(
      (item) => _normalize(item.id) == normalized || item.legacyIds.any((legacy) => _normalize(legacy) == normalized),
      orElse: () => CatalogItem(value),
    ).id;
  }

  static String label(AppLocalizations l10n, String catalog, CatalogItem item) =>
      l10n.catalogEntry(catalog, item.id)['name'] as String? ?? item.id;

  static String _normalize(String value) => value.trim().toLowerCase().replaceAll('_', ' ');
}
