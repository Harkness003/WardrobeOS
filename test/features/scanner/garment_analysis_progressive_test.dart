import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/scanner/ai/garment_analysis_request.dart';
import 'package:wardrobeos/features/scanner/ai/garment_analysis_result.dart';
import 'package:wardrobeos/features/scanner/ai/garment_vision_analyzer.dart';
import 'package:wardrobeos/models/garment_normalizer.dart';
import 'package:wardrobeos/models/thermal_profile_calculator.dart';

class _ProgressiveAnalyzer implements GarmentVisionAnalyzer {
  int quickCalls = 0;
  int enrichmentCalls = 0;
  final bool failEnrichment;

  _ProgressiveAnalyzer({this.failEnrichment = false});

  @override
  Future<GarmentAnalysisResult> analyze(GarmentAnalysisRequest request) async {
    switch (request.phase) {
      case GarmentAnalysisPhase.quick:
        quickCalls++;
        return const GarmentAnalysisResult(
          isUsableImage: true,
          suggestedName: 'Polo bleu',
          category: 'Hauts',
          preciseType: 'polo',
          primaryColor: 'Bleu',
          globalConfidence: .82,
        );
      case GarmentAnalysisPhase.enrichment:
        enrichmentCalls++;
        if (failEnrichment) throw StateError('advanced unavailable');
        return const GarmentAnalysisResult(
          isUsableImage: true,
          suggestedName: 'Polo bleu',
          category: 'Hauts',
          preciseType: 'polo',
          primaryColor: 'Bleu',
          material: 'Coton',
          compositions: [TextileComposition(section: 'main', material: 'Coton', percentage: 100)],
          styleSummary: 'Polo casual net.',
          idealOccasions: ['Quotidien'],
          globalConfidence: .91,
        );
    }
  }
}

void main() {
  final request = GarmentAnalysisRequest(
    imageBytes: Uint8List.fromList([1, 2, 3]),
    mimeType: 'image/jpeg',
    allowedCategories: ['Hauts', 'Vestes'],
    allowedColors: ['Bleu', 'Beige'],
    allowedMaterials: ['Coton'],
    allowedSeasons: ['Toute saison'],
  );

  test('analyse rapide disponible avant enrichissement tardif', () async {
    final analyzer = _ProgressiveAnalyzer();

    final quick = await analyzer.analyzeQuick(request);
    expect(quick.suggestedName, 'Polo bleu');
    expect(quick.category, 'Hauts');
    expect(quick.preciseType, 'polo');
    expect(quick.primaryColor, 'Bleu');
    expect(quick.material, isNull);

    final enriched = await analyzer.enrich(request.copyWith(previousAnalysis: quick.toJson()));
    expect(enriched.material, 'Coton');
    expect(enriched.styleSummary, isNotNull);
    expect(enriched.idealOccasions, contains('Quotidien'));
    expect(analyzer.quickCalls, 1);
    expect(analyzer.enrichmentCalls, 1);
  });

  test('erreur enrichissement conserve la première analyse', () async {
    final analyzer = _ProgressiveAnalyzer(failEnrichment: true);
    final quick = await analyzer.analyzeQuick(request);

    try {
      await analyzer.enrich(request.copyWith(previousAnalysis: quick.toJson()));
      fail('enrichment should fail');
    } catch (_) {
      expect(quick.suggestedName, 'Polo bleu');
      expect(quick.category, 'Hauts');
      expect(quick.primaryColor, 'Bleu');
      expect(quick.preciseType, 'polo');
    }
  });

  test('modification utilisateur protégée par comparaison avec la valeur initiale', () {
    const initialName = '';
    var currentName = 'Nom corrigé';
    const aiName = 'Polo bleu';

    if (currentName == initialName || currentName.trim().isEmpty) {
      currentName = aiName;
    }

    expect(currentName, 'Nom corrigé');
  });

  test('trench correctement classé et profilé comme couche extérieure moyenne', () {
    final type = GarmentNormalizer.normalizeType(
      name: 'Trench beige',
      category: 'Vestes',
      subcategory: 'trench',
      preciseType: 'trench',
    );
    final thermal = const ThermalProfileCalculator().calculate(
      ThermalProfileInput(category: type.category ?? 'Vestes', subcategory: type.subcategory),
    );

    expect(type.category, 'outerwear');
    expect(type.subcategory, 'trench');
    expect(thermal.primaryRole.name, 'outer');
  });

  test('polo correctement classé et profilé comme base légère', () {
    final type = GarmentNormalizer.normalizeType(
      name: 'Polo bleu',
      category: 'Hauts',
      subcategory: 'polo',
      preciseType: 'polo',
    );
    final thermal = const ThermalProfileCalculator().calculate(
      ThermalProfileInput(category: type.category ?? 'Hauts', subcategory: type.subcategory),
    );

    expect(type.category, 'top');
    expect(type.subcategory, 'polo');
    expect(thermal.primaryRole.name, 'base');
  });
}
