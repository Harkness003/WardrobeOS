import 'dart:typed_data';

class GarmentAnalysisRequest {
  final Uint8List imageBytes;
  final String mimeType;
  final String? fileName;
  final String language;
  final List<String> allowedCategories;
  final List<String> allowedColors;
  final List<String> allowedMaterials;
  final List<String> allowedSeasons;
  final Map<String, String> existingValues;

  const GarmentAnalysisRequest({
    required this.imageBytes,
    required this.mimeType,
    this.fileName,
    this.language = 'français',
    required this.allowedCategories,
    required this.allowedColors,
    required this.allowedMaterials,
    required this.allowedSeasons,
    this.existingValues = const {},
  });

  GarmentAnalysisRequest copyWith({Uint8List? imageBytes, String? mimeType}) =>
      GarmentAnalysisRequest(imageBytes: imageBytes ?? this.imageBytes, mimeType: mimeType ?? this.mimeType, fileName: fileName, language: language, allowedCategories: allowedCategories, allowedColors: allowedColors, allowedMaterials: allowedMaterials, allowedSeasons: allowedSeasons, existingValues: existingValues);
}
