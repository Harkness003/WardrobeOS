import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/scanner/ai/analysis_foundations.dart';
import 'package:wardrobeos/features/wardrobe/reanalysis/garment_reanalysis_models.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/garment_photo.dart';

Garment garment({GarmentAnalysisSnapshot? snapshot, String? version, List<GarmentPhoto> photos = const []}) => Garment(
  id: 'g1', name: 'Pull', category: 'Hauts', photos: photos, aiAnalysisVersion: version,
  currentAnalysis: snapshot, createdAt: DateTime(2025), updatedAt: DateTime(2025),
);

void main() {
  const versions = GarmentReanalysisVersions(aiModel: 'model-2', pipeline: 'pipeline-2', styleTaxonomy: 'styles-2', thermalEngine: 'thermal-2');
  const policy = ReanalysisCandidatePolicy();

  test('une ancienne fiche sans version est candidate', () {
    expect(policy.reasons(garment(), versions), {ReanalysisStaleReason.legacy});
  });

  test('les versions et nouvelles photos invalident uniquement les bons moteurs', () {
    final photo = GarmentPhoto(id: 'p2', path: '/detail.jpg', type: GarmentPhotoType.detail, createdAt: DateTime(2025));
    final snapshot = GarmentAnalysisSnapshot(version: 'model-1', pipelineVersion: 'pipeline-1', analyzedAt: DateTime(2025), photoIds: const ['p1'], values: const {'_styleTaxonomyVersion': 'styles-1', '_thermalEngineVersion': 'thermal-1'});
    expect(policy.reasons(garment(snapshot: snapshot, version: 'model-1', photos: [photo]), versions), containsAll(ReanalysisStaleReason.values.where((reason) => reason != ReanalysisStaleReason.legacy)));
  });

  test('un snapshot versionné conserve type, pipeline et photos', () {
    final snapshot = GarmentAnalysisSnapshot(version: 'model-2', pipelineVersion: 'pipeline-2', analyzedAt: DateTime(2025), reanalysisType: 'style', photoIds: const ['main', 'other'], values: const {'style': 'minimaliste'});
    final restored = GarmentAnalysisSnapshot.fromJson(snapshot.toJson());
    expect(restored.pipelineVersion, 'pipeline-2');
    expect(restored.reanalysisType, 'style');
    expect(restored.photoIds, ['main', 'other']);
  });
}
