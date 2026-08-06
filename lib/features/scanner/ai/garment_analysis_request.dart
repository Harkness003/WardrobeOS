import 'dart:typed_data';

enum GarmentAnalysisPhase { quick, enrichment }

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
  final List<Uint8List> previousImageBytes;
  final Map<String, Object?>? previousAnalysis;
  final Set<String> requestedFields;
  final GarmentAnalysisPhase phase;

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
    this.previousImageBytes = const [],
    this.previousAnalysis,
    this.requestedFields = const {},
    this.phase = GarmentAnalysisPhase.enrichment,
  });

  GarmentAnalysisRequest copyWith({Uint8List? imageBytes, String? mimeType, List<Uint8List>? previousImageBytes, Map<String, Object?>? previousAnalysis, Set<String>? requestedFields, GarmentAnalysisPhase? phase}) =>
      GarmentAnalysisRequest(imageBytes: imageBytes ?? this.imageBytes, mimeType: mimeType ?? this.mimeType, fileName: fileName, language: language, allowedCategories: allowedCategories, allowedColors: allowedColors, allowedMaterials: allowedMaterials, allowedSeasons: allowedSeasons, existingValues: existingValues, previousImageBytes: previousImageBytes ?? this.previousImageBytes, previousAnalysis: previousAnalysis ?? this.previousAnalysis, requestedFields: requestedFields ?? this.requestedFields, phase: phase ?? this.phase);
}
