import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/scanner/ai/garment_analysis_result.dart';
import 'package:wardrobeos/features/scanner/conversation/requested_photo.dart';
import 'package:wardrobeos/features/scanner/decision/scanner_decision_engine.dart';

void main() {
  const engine = ScannerDecisionEngine();

  test('recalcule une confiance globale pondérée par champ', () {
    const result = GarmentAnalysisResult(
      isUsableImage: true,
      category: 'Hauts',
      primaryColor: 'Bleu',
      material: 'Coton',
      globalConfidence: .99,
      fieldConfidences: {'category': 1, 'primaryColor': .8, 'material': .5},
    );

    final decision = engine.evaluate(result);

    expect(decision.globalConfidence, closeTo(.771, .001));
    expect(decision.globalConfidence, isNot(result.globalConfidence));
  });

  test('explique les incertitudes sans considérer une valeur comme fiable', () {
    const result = GarmentAnalysisResult(
      isUsableImage: true,
      category: 'Vestes',
      primaryColor: 'Noir',
      material: 'Laine',
      globalConfidence: .9,
      fieldConfidences: {'category': .95, 'primaryColor': .95, 'material': .4},
    );

    final decision = engine.evaluate(result);

    expect(decision.missingInformation, contains('matière'));
    expect(decision.explanations, contains('Je ne peux pas confirmer la matière.'));
    expect(decision.canFinishAutomatically, isFalse);
  });

  test('privilégie la matière au logo pour le gain de confiance', () {
    const result = GarmentAnalysisResult(
      isUsableImage: true,
      category: 'Vestes',
      primaryColor: 'Noir',
      globalConfidence: .9,
      fieldConfidences: {
        'category': .95,
        'primaryColor': .95,
        'material': .2,
        'visibleBrand': .1,
      },
    );

    final decision = engine.evaluate(result);

    expect(decision.requestedPhoto?.type, RequestedPhotoType.compositionLabel);
    expect(decision.requestedPhoto?.targetFields, ['material']);
    expect(decision.requestedPhoto?.reason, contains('composition'));
  });

  test('ne demande aucune photo qui ne peut pas améliorer la décision', () {
    const result = GarmentAnalysisResult(
      isUsableImage: true,
      category: 'Hauts',
      primaryColor: 'Bleu',
      preciseType: 'T-shirt',
      material: 'Coton',
      styleSummary: 'Casual',
      season: 'Été',
      globalConfidence: .9,
      fieldConfidences: {
        'category': .9,
        'primaryColor': .9,
        'preciseType': .9,
        'material': .9,
        'style': .9,
        'season': .9,
      },
      needsMorePhotos: true,
      requestedPhoto: RequestedPhoto(
        type: RequestedPhotoType.logo,
        instruction: 'Photographiez le logo.',
        reason: 'Lire la marque.',
        targetFields: ['category'],
      ),
    );

    final decision = engine.evaluate(result);

    expect(decision.canFinishAutomatically, isTrue);
    expect(decision.requestedPhoto, isNull);
  });
}
