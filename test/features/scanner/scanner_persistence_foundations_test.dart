import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/scanner/ai/analysis_foundations.dart';
import 'package:wardrobeos/features/scanner/ai/normalization/garment_value_normalizer.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/garment_photo.dart';

void main() {
  final now = DateTime.utc(2026, 8, 4);

  test('legacy garment exposes its image as a typed primary photo', () {
    final legacy = Garment.fromMap({
      'id': 'old', 'name': 'Pull', 'category': 'Hauts',
      'image_path': '/images/old.jpg',
      'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
    });
    expect(legacy.effectivePhotos.single.path, '/images/old.jpg');
    expect(legacy.effectivePhotos.single.type, GarmentPhotoType.primary);
  });

  test('several typed photos survive a persistence round trip', () {
    final garment = Garment(
      id: 'g', name: 'Basket', category: 'Chaussures', imagePath: '/p/main.jpg',
      photos: [
        GarmentPhoto(id: '1', path: '/p/main.jpg', type: GarmentPhotoType.primary, createdAt: now),
        GarmentPhoto(id: '2', path: '/p/sole.jpg', type: GarmentPhotoType.sole, createdAt: now),
      ],
      createdAt: now, updatedAt: now,
    );
    final restored = Garment.fromMap(garment.toMap());
    expect(restored.photos.map((photo) => photo.type), [GarmentPhotoType.primary, GarmentPhotoType.sole]);
    expect(restored.photos.map((photo) => photo.path), ['/p/main.jpg', '/p/sole.jpg']);
  });

  test('missing complementary photo data degrades without losing legacy path', () {
    final garment = Garment.fromMap({
      'id': 'g', 'name': 'Veste', 'category': 'Vestes',
      'image_path': '/main.jpg', 'photos': '[broken',
      'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
    });
    expect(garment.effectivePhotos.single.path, '/main.jpg');
  });

  test('analysis version identifies stale records and snapshots round-trip', () {
    final snapshot = GarmentAnalysisSnapshot(version: 'v1', analyzedAt: now, values: const {'category': 'Hauts'});
    final garment = Garment(id: 'g', name: 'Pull', category: 'Hauts', lastAnalyzedAt: now, aiAnalysisVersion: 'v1', currentAnalysis: snapshot, createdAt: now, updatedAt: now);
    final restored = Garment.fromMap(garment.toMap());
    expect(restored.needsAiReanalysis('v2'), isTrue);
    expect(restored.needsAiReanalysis('v1'), isFalse);
    expect(restored.currentAnalysis?.values['category'], 'Hauts');
  });

  test('AI enrichment never overwrites user corrections made while it runs', () {
    final merged = const AnalysisMergePolicy().merge(
      current: const {'category': 'Vestes', 'color': 'Rouge'},
      analysis: const {'category': 'Hauts', 'color': 'Bleu', 'material': 'Coton'},
      userModifiedFields: const {'category', 'color'},
    );
    expect(merged, {'category': 'Vestes', 'color': 'Rouge', 'material': 'Coton'});
  });

  test('a second photo added during a slow analysis remains associated', () async {
    final session = AnalysisSession()..addPhoto('/main.jpg');
    final gate = Future<void>.delayed(const Duration(milliseconds: 10));
    final analysis = session.run((photos) async {
      expect(photos, ['/main.jpg']);
      await gate;
    });
    session.addPhoto('/detail.jpg');
    expect(await analysis, isFalse);
    expect(session.photoPaths, ['/main.jpg', '/detail.jpg']);
  });

  test('failed analysis does not discard session photos or edits', () async {
    final session = AnalysisSession()..addPhoto('/main.jpg');
    session.markUserModified('category');
    await expectLater(session.run((_) => Future<void>.error(StateError('AI failed'))), throwsStateError);
    expect(session.photoPaths, ['/main.jpg']);
    expect(session.userModifiedFields, {'category'});
  });

  test('multilingual catalogue keeps canonical values', () {
    const categories = ['Hauts', 'Chemises', 'Vestes', 'Bas', 'Chaussures'];
    const materials = ['Coton', 'Laine', 'Cuir', 'Lin', 'Soie'];
    expect(WardrobeNormalizers.categories(categories).normalize('chaqueta'), 'Vestes');
    expect(WardrobeNormalizers.categories(categories).normalize('Schuhe'), 'Chaussures');
    expect(WardrobeNormalizers.materials(materials).normalize('Baumwolle'), 'Coton');
  });
}
