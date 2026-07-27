import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/scanner/ai/garment_analysis_result.dart';
import 'package:wardrobeos/features/scanner/conversation/requested_photo.dart';
import 'package:wardrobeos/features/scanner/conversation/scan_conversation.dart';

void main() {
  const policy = ScanConversationPolicy();

  test('a reliable first photo completes without another request', () {
    const result = GarmentAnalysisResult(
      isUsableImage: true,
      category: 'Hauts',
      primaryColor: 'Bleu',
      material: 'Coton',
      preciseType: 'T-shirt',
      styleSummary: 'Casual',
      globalConfidence: .9,
      fieldConfidences: {
        'category': .95,
        'primaryColor': .9,
        'material': .86,
        'preciseType': .9,
        'style': .8,
      },
    );

    final decision = policy.evaluate(result);

    expect(decision.canFinishAutomatically, isTrue);
    expect(decision.requestedPhoto, isNull);
  });

  test('keeps one useful contextual request when material is uncertain', () {
    const result = GarmentAnalysisResult(
      isUsableImage: true,
      category: 'Hauts',
      primaryColor: 'Bleu',
      material: 'Coton',
      globalConfidence: .68,
      fieldConfidences: {
        'category': .9,
        'primaryColor': .9,
        'material': .4,
      },
      needsMorePhotos: true,
      requestedPhoto: RequestedPhoto(
        type: RequestedPhotoType.compositionLabel,
        instruction: 'Photographie l’étiquette de composition.',
        reason: 'La matière ne peut pas être confirmée visuellement.',
        targetFields: ['material'],
      ),
    );

    final decision = policy.evaluate(result);

    expect(decision.canFinishAutomatically, isFalse);
    expect(decision.requestedPhoto?.type, RequestedPhotoType.compositionLabel);
    expect(
      decision.progress.singleWhere((item) => item.field == 'material').confirmed,
      isFalse,
    );
  });

  test('rejects a photo request that cannot improve an uncertain field', () {
    const result = GarmentAnalysisResult(
      isUsableImage: true,
      category: 'Hauts',
      primaryColor: 'Bleu',
      globalConfidence: .8,
      fieldConfidences: {'category': .9, 'primaryColor': .9},
      needsMorePhotos: true,
      requestedPhoto: RequestedPhoto(
        type: RequestedPhotoType.logo,
        instruction: 'Photographie le logo.',
        reason: 'Pour lire la marque.',
        targetFields: ['category'],
      ),
    );

    final decision = policy.evaluate(result);

    expect(decision.canFinishAutomatically, isTrue);
    expect(decision.requestedPhoto, isNull);
  });
}
