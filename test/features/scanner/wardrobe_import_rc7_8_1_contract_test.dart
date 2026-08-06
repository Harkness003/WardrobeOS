import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RC7.8.1 integration contracts', () {
    test('SQLite migration stays monotone and creates imports on both paths', () {
      final source = File('lib/data/database_service.dart').readAsStringSync();
      expect(source, contains('version: 2'));
      expect(source, contains('if (oldVersion < 2)'));
      expect(RegExp(r'_createWardrobeImportTable\(db\)').allMatches(source).length,
        greaterThanOrEqualTo(2));
      expect(source, contains('CREATE TABLE IF NOT EXISTS wardrobe_import_tasks'));
    });

    test('bulk schema contains no abandoned or secondary fields', () {
      final source = File('lib/features/scanner/ai/openai_garment_vision_analyzer.dart')
        .readAsStringSync();
      final start = source.indexOf('static const _essentialEnrichmentSchema');
      final end = source.indexOf('static const _schema', start + 1);
      final schema = source.substring(start, end);
      expect(schema, contains("'detectedFeatures'"));
      expect(schema, isNot(contains("'season'")));
      expect(schema, isNot(contains("'idealOccasions'")));
      expect(schema, isNot(contains("'styleSummary'")));
      expect(schema, isNot(contains("'requestedPhoto'")));
    });

    test('ImagePicker boundary returns null without creating import work', () {
      final capture = File('lib/features/scanner/capture/garment_capture.dart').readAsStringSync();
      final screen = File('lib/features/scanner/wardrobe_import_screen.dart').readAsStringSync();
      expect(capture, contains('Future<String?> capture()'));
      expect(screen, contains('if (photoPath == null) return;'));
      expect(screen.indexOf('if (photoPath == null) return;'),
        lessThan(screen.indexOf('service.enqueue')));
      expect(screen, contains('capturing || !capture.isInitialized ? null : _capture'));
    });
  });
}
