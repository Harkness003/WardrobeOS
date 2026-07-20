import 'garment_analysis_request.dart';
import 'garment_analysis_result.dart';

abstract interface class GarmentVisionAnalyzer {
  Future<GarmentAnalysisResult> analyze(GarmentAnalysisRequest request);
}
