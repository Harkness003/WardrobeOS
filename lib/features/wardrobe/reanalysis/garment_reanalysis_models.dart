import '../../../models/garment.dart';
import '../../../models/garment_photo.dart';
import '../../scanner/ai/analysis_foundations.dart';

enum GarmentReanalysisType { complete, composition, style, thermal, category }

class GarmentReanalysisVersions {
  final String aiModel;
  final String pipeline;
  final String styleTaxonomy;
  final String thermalEngine;
  const GarmentReanalysisVersions({required this.aiModel, required this.pipeline, required this.styleTaxonomy, required this.thermalEngine});
}

class GarmentReanalysisChange {
  final String field;
  final Object? oldAnalysis;
  final Object? currentValue;
  final Object? proposedValue;
  final bool conflict;
  const GarmentReanalysisChange({required this.field, this.oldAnalysis, this.currentValue, this.proposedValue, required this.conflict});
}

class GarmentReanalysisProposal {
  final Garment garment;
  final GarmentReanalysisType type;
  final List<GarmentPhoto> photos;
  final GarmentAnalysisSnapshot snapshot;
  final List<GarmentReanalysisChange> changes;
  const GarmentReanalysisProposal({required this.garment, required this.type, required this.photos, required this.snapshot, required this.changes});
  Iterable<GarmentReanalysisChange> get nonConflicting => changes.where((change) => !change.conflict);
}

enum ReanalysisStaleReason { legacy, pipeline, model, styleTaxonomy, thermalEngine, photos }

class ReanalysisCandidatePolicy {
  const ReanalysisCandidatePolicy();
  Set<ReanalysisStaleReason> reasons(Garment garment, GarmentReanalysisVersions versions) {
    final snapshot = garment.currentAnalysis;
    if (snapshot == null || garment.aiAnalysisVersion == null) return {ReanalysisStaleReason.legacy};
    final reasons = <ReanalysisStaleReason>{};
    if (snapshot.pipelineVersion != versions.pipeline) reasons.add(ReanalysisStaleReason.pipeline);
    if (snapshot.version != versions.aiModel) reasons.add(ReanalysisStaleReason.model);
    if (snapshot.values['_styleTaxonomyVersion'] != versions.styleTaxonomy) reasons.add(ReanalysisStaleReason.styleTaxonomy);
    if (snapshot.values['_thermalEngineVersion'] != versions.thermalEngine) reasons.add(ReanalysisStaleReason.thermalEngine);
    final recorded = snapshot.photoIds.toSet();
    if (garment.effectivePhotos.any((photo) => !recorded.contains(photo.id))) reasons.add(ReanalysisStaleReason.photos);
    return reasons;
  }
}
