import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/scanner/ai/garment_analysis_normalizer.dart';
import 'package:wardrobeos/features/scanner/ai/garment_analysis_result.dart';
import 'package:wardrobeos/features/scanner/decision/scanner_decision_engine.dart';

GarmentAnalysisResult analysis({
  String? name,
  String? category,
  String? type,
  String? material,
}) => GarmentAnalysisResult(
  isUsableImage: true,
  suggestedName: name,
  category: category,
  preciseType: type,
  primaryColor: 'Noir',
  material: material,
  globalConfidence: .9,
  fieldConfidences: const {
    'category': .9,
    'primaryColor': .9,
    'preciseType': .3,
  },
);

void main() {
  test('normalizes Pull noir into a coherent category and subtype', () {
    final result = const GarmentAnalysisNormalizer().normalize(
      analysis(name: 'Pull noir', category: 'Autre'),
    );
    expect(result.category, 'Hauts');
    expect(result.preciseType, 'Pull');
  });

  test('retains multiple OCR textile sections and percentages', () {
    final result = GarmentAnalysisResult.fromJson({
      'isUsableImage': true,
      'globalConfidence': .9,
      'compositions': [
        {'section': 'main', 'material': 'Coton', 'percentage': 50, 'source': 'ocr'},
        {'section': 'main', 'material': 'Polyester', 'percentage': 50, 'source': 'ocr'},
        {'section': 'lining', 'material': 'Viscose', 'percentage': 100, 'source': 'ocr'},
      ],
    });
    expect(result.compositions, hasLength(3));
    expect(result.compositions[1].percentage, 50);
    expect(result.toJson()['compositions'], isNotEmpty);
  });

  test('asks for a shoe sole with an explicit reason, not a label', () {
    final decision = const ScannerDecisionEngine().evaluate(
      analysis(name: 'Baskets noires', category: 'Chaussures'),
    );
    expect(decision.requestedPhoto?.type.name, 'sole');
    expect(decision.requestedPhoto?.reason, contains('usure'));
  });
}
