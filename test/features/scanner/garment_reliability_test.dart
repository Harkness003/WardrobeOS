import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:wardrobeos/features/scanner/ai/garment_analysis_mapper.dart';
import 'package:wardrobeos/features/scanner/ai/garment_analysis_result.dart';
import 'package:wardrobeos/features/scanner/ai/garment_analysis_validator.dart';
import 'package:wardrobeos/features/scanner/ai/garment_confidence.dart';
import 'package:wardrobeos/features/scanner/ai/garment_image_processing.dart';
import 'package:wardrobeos/features/scanner/ai/normalization/garment_value_normalizer.dart';

void main() {
  group('image locale', () {
    const validator = GarmentImageValidator();
    test('rejette une image vide ou invalide', () {
      expect(validator.validateBytes(Uint8List(0)).isValid, isFalse);
      expect(validator.validateBytes(Uint8List.fromList([1, 2, 3]), mimeType: 'image/jpeg').isValid, isFalse);
    });
    test('accepte et conserve une petite image', () {
      final source = Uint8List.fromList(img.encodeJpg(img.Image(width: 400, height: 300)));
      expect(validator.validateBytes(source).isValid, isTrue);
      final prepared = const GarmentImagePreprocessor().prepareBytes(source);
      expect(prepared.wasResized, isFalse);
      expect(prepared.width, 400);
      expect(source.length, prepared.originalSizeBytes);
    });
    test('redimensionne sans toucher aux octets source', () {
      final source = Uint8List.fromList(img.encodeJpg(img.Image(width: 2200, height: 1100)));
      final before = Uint8List.fromList(source);
      final prepared = const GarmentImagePreprocessor(maxDimension: 1600).prepareBytes(source);
      expect(prepared.width, 1600);
      expect(prepared.wasResized, isTrue);
      expect(source, orderedEquals(before));
    });
  });

  test('normalise accents, synonymes et doublons', () {
    final colors = WardrobeNormalizers.colors(['Bleu marine', 'Écru']);
    expect(colors.normalize(' DARK BLUE '), 'Bleu marine');
    expect(colors.normalize('cream'), 'Écru');
    expect(colors.normalize('inconnu'), isNull);
    expect(colors.normalizeList(['navy', 'bleu nuit']), ['Bleu marine']);
  });

  test('valide et filtre les valeurs inconnues', () {
    final validator = GarmentAnalysisValidator(
      categoryNormalizer: WardrobeNormalizers.categories(['Hauts', 'Chemises']),
      colorNormalizer: WardrobeNormalizers.colors(['Bleu marine']),
      materialNormalizer: WardrobeNormalizers.materials(['Coton']),
      seasonNormalizer: const GarmentValueNormalizer(['Hiver']),
    );
    final result = validator.validate(const GarmentAnalysisResult(isUsableImage: true, category: 'shirt', primaryColor: 'navy', material: 'plastique magique', season: 'Hiver', globalConfidence: 1.2));
    expect(result.analysis.category, 'Chemises');
    expect(result.analysis.primaryColor, 'Bleu marine');
    expect(result.analysis.material, isNull);
    expect(result.rejectedFields, contains('material'));
    expect(result.analysis.globalConfidence, 1);
  });

  test('mapper préserve le manuel et ignore une faible confiance', () {
    const mapper = GarmentAnalysisMapper(categories: ['Hauts'], colors: ['Bleu'], materials: ['Coton'], seasons: ['Hiver']);
    const current = GarmentFormValues(name: 'Mon nom', category: '', color: '', material: '', season: '', brand: '');
    final mapped = mapper.map(const GarmentAnalysisResult(isUsableImage: true, suggestedName: 'IA', category: 'Hauts', primaryColor: 'Bleu', material: 'Coton', season: 'Hiver', globalConfidence: .9, fieldConfidences: {'category': .9, 'primaryColor': .4, 'material': .9, 'season': .7, 'suggestedName': .9}), current: current);
    expect(mapped.name, 'Mon nom');
    expect(mapped.category, 'Hauts');
    expect(mapped.color, isEmpty);
    expect(mapped.material, 'Coton');
    expect(GarmentConfidence.label(.6), 'Confiance moyenne');
  });
}
