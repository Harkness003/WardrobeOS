class GarmentScanResult {
  final String suggestedName;
  final String category;
  final String color;
  final String material;
  final String season;
  final double confidence;
  final List<String> labels;
  final String? typePrecis;
  final String? descriptionIA;
  final String? motif;
  final String? stylePrincipal;
  final List<String> saisons;
  final List<String> avertissementsIA;

  const GarmentScanResult({
    required this.suggestedName,
    required this.category,
    required this.color,
    required this.material,
    required this.season,
    required this.confidence,
    required this.labels,
    this.typePrecis,
    this.descriptionIA,
    this.motif,
    this.stylePrincipal,
    this.saisons = const [],
    this.avertissementsIA = const [],
  });
}
