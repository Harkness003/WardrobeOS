class GarmentScanResult {
  final String suggestedName;
  final String category;
  final String color;
  final String material;
  final String season;
  final double confidence;
  final List<String> labels;

  const GarmentScanResult({
    required this.suggestedName,
    required this.category,
    required this.color,
    required this.material,
    required this.season,
    required this.confidence,
    required this.labels,
  });
}
