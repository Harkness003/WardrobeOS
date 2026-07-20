import 'garment_analysis_exception.dart';
import 'garment_analysis_request.dart';
import 'garment_analysis_result.dart';
import 'garment_vision_analyzer.dart';

enum FakeGarmentVisionScenario {
  highConfidence, mediumConfidence, lowConfidence, blurry, tooDark,
  multipleGarments, inconsistent, timeout, networkError, quotaExceeded,
  invalidJson,
}

class FakeGarmentVisionAnalyzer implements GarmentVisionAnalyzer {
  final FakeGarmentVisionScenario scenario;
  final Duration delay;

  const FakeGarmentVisionAnalyzer({
    this.scenario = FakeGarmentVisionScenario.highConfidence,
    this.delay = Duration.zero,
  });

  @override
  Future<GarmentAnalysisResult> analyze(GarmentAnalysisRequest request) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return switch (scenario) {
      FakeGarmentVisionScenario.highConfidence => const GarmentAnalysisResult(
        isUsableImage: true,
        suggestedName: 'Chemise bleue',
        category: 'Chemises',
        primaryColor: 'Bleu',
        material: 'Coton',
        season: 'Toute saison',
        globalConfidence: .91,
        fieldConfidences: {'category': .96, 'primaryColor': .94, 'material': .84},
      ),
      FakeGarmentVisionScenario.mediumConfidence => const GarmentAnalysisResult(isUsableImage: true, category: 'Chemises', primaryColor: 'Bleu', globalConfidence: .67, fieldConfidences: {'category': .72, 'primaryColor': .68}),
      FakeGarmentVisionScenario.lowConfidence => const GarmentAnalysisResult(
        isUsableImage: true,
        category: 'Hauts',
        globalConfidence: .31,
        warnings: ['Vêtement partiellement visible.'],
      ),
      FakeGarmentVisionScenario.blurry => const GarmentAnalysisResult(isUsableImage: true, globalConfidence: .56, imageQualityConfidence: .45, isBlurry: true, imageQualityWarnings: ['La photo semble floue.']),
      FakeGarmentVisionScenario.tooDark => const GarmentAnalysisResult(isUsableImage: true, globalConfidence: .52, imageQualityConfidence: .4, isTooDark: true, imageQualityWarnings: ['La photo est trop sombre.']),
      FakeGarmentVisionScenario.multipleGarments => const GarmentAnalysisResult(isUsableImage: false, rejectionReason: 'Plusieurs vêtements principaux sont indissociables.', globalConfidence: .1, multipleMainGarments: true),
      FakeGarmentVisionScenario.inconsistent => const GarmentAnalysisResult(isUsableImage: true, category: 'Chaussures', material: 'Inconnu', globalConfidence: 1, fieldConfidences: {'material': .2}),
      FakeGarmentVisionScenario.timeout => throw const GarmentAnalysisException(GarmentAnalysisError.timeout, 'L’analyse prend trop de temps. Réessayez.'),
      FakeGarmentVisionScenario.networkError => throw const GarmentAnalysisException(
        GarmentAnalysisError.network,
        'Impossible de joindre OpenAI. Vérifiez votre connexion.',
      ),
      FakeGarmentVisionScenario.quotaExceeded => throw const GarmentAnalysisException(GarmentAnalysisError.quotaExceeded, 'Le quota OpenAI est dépassé.'),
      FakeGarmentVisionScenario.invalidJson => throw const GarmentAnalysisException(GarmentAnalysisError.invalidJson, 'La réponse de l’analyse IA est illisible.'),
    };
  }
}
