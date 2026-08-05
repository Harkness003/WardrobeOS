import 'garment_analysis_request.dart';
import 'garment_analysis_result.dart';

abstract interface class GarmentVisionAnalyzer {
  Future<GarmentAnalysisResult> analyze(GarmentAnalysisRequest request);

  Future<GarmentAnalysisResult> analyzeQuick(GarmentAnalysisRequest request) =>
      analyze(request.copyWith(phase: GarmentAnalysisPhase.quick));

  Future<GarmentAnalysisResult> enrich(GarmentAnalysisRequest request) =>
      analyze(request.copyWith(phase: GarmentAnalysisPhase.enrichment));
}
