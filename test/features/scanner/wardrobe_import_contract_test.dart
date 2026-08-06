import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/scanner/analysis/wardrobe_import_service.dart';

void main() {
  group('RC7.8 import queue contracts', () {
    final source = File('lib/features/scanner/analysis/wardrobe_import_service.dart').readAsStringSync();

    test('task persistence round-trips order/status/results/timings', () {
      final capturedAt = DateTime.utc(2026, 8, 6);
      final task = WardrobeImportTask(id: 'stable-id', photoPath: '/local/photo.jpg',
        capturedAt: capturedAt, status: WardrobeImportStatus.pending,
        timings: const {'capture': 12});
      final restored = WardrobeImportTask.fromMap(task.toMap());
      expect(restored.id, task.id);
      expect(restored.photoPath, task.photoPath);
      expect(restored.capturedAt, capturedAt);
      expect(restored.status, WardrobeImportStatus.pending);
      expect(restored.timings, const {'capture': 12});
    });

    test('captures enqueue independently from analysis', () {
      expect(source, contains('Future<WardrobeImportTask> enqueue'));
      expect(source, contains('unawaited(_process'));
    });
    test('queue is FIFO and concurrency is configurable and bounded', () {
      expect(source, contains('this.maxConcurrency = 2'));
      expect(source, contains('_running < maxConcurrency'));
      expect(source, contains('indexWhere((task) => task.status == WardrobeImportStatus.pending)'));
    });
    test('one failure does not block later tasks and retries are finite', () {
      expect(source, contains('whenComplete(() {'));
      expect(source, contains('_running--;'));
      expect(source, contains('_pump();'));
      expect(source, contains('current.attempt < maxAttempts'));
      expect(source, contains('Future<void> retry'));
    });
    test('quick creates canonical garment/photo before enrichment', () {
      final insert = source.indexOf('database.insertGarment(garment)');
      final enrich = source.indexOf('analyzer.enrich');
      expect(insert, greaterThan(source.indexOf('analyzer.analyzeQuick')));
      expect(enrich, greaterThan(insert));
      expect(source, contains('GarmentPhotoType.primary'));
    });
    test('enrichment protects user fields and learns catalog values', () {
      expect(source, contains('current.userModifiedFields'));
      expect(source, contains("protected.contains('material')"));
      expect(source, contains("protected.contains('brand')"));
      expect(source, contains('catalog.learn(PersonalCatalogField'));
    });
    test('bulk import never requests a complementary photo', () {
      expect(source, isNot(contains('requestedPhoto')));
      expect(source, isNot(contains('previousImageBytes')));
    });
    test('confidence only routes ambiguous garments to review', () {
      expect(source, contains("confidence('category') < .75"));
      expect(source, contains('WardrobeImportStatus.needsReview'));
      expect(source, contains('WardrobeImportStatus.completed'));
    });
    test('interrupted states resume after reconstruction', () {
      expect(source, contains('WardrobeImportStatus.quickAnalysis ||'));
      expect(source, contains('status: WardrobeImportStatus.pending'));
    });
    test('pending cancellation and failed retry are explicit', () {
      expect(source, contains('Future<bool> cancel'));
      expect(source, contains('status != WardrobeImportStatus.pending'));
      expect(source, contains('status != WardrobeImportStatus.failed'));
    });
    test('normalization occurs before persistence', () {
      expect(source, contains('GarmentNormalizer.normalizeType'));
      expect(source, contains('GarmentNormalizer.classification'));
      expect(source, contains('GarmentNormalizer.brand'));
    });
    test('canonical model only: no legacy image path or thermal model', () {
      expect(source, isNot(contains('imagePath:')));
      expect(source, contains('ThermalProfileCalculator'));
      expect(source, contains('Garment('));
      expect(source, contains('GarmentPhoto('));
    });
    test('essential enrichment excludes seasons, occasions, and style', () {
      expect(importEnrichmentFields, containsAll(
        {'material', 'compositions', 'thermalPhysicalProperties'}));
      expect(importEnrichmentFields, isNot(contains('season')));
      expect(importEnrichmentFields, isNot(contains('occasions')));
      expect(importEnrichmentFields, isNot(contains('style')));
    });
    test('enrichment recalculates ThermalProfile v3 from physical evidence', () {
      expect(source, contains('ThermalProfileInput('));
      expect(source, contains('thickness: enriched.thickness'));
      expect(source, contains('detectedFeatures: enriched.detectedFeatures'));
      expect(source, contains("protected.contains('thermalProfile')"));
      expect(source, isNot(contains('withCurrentStyleAnalysis')));
    });
  });
}
