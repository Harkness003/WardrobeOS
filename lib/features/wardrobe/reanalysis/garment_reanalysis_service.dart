import 'dart:typed_data';

import '../../../core/ai_context/ai_reanalysis_policy.dart';
import '../../../models/garment.dart';
import '../../scanner/ai/analysis_foundations.dart';
import '../../scanner/ai/garment_analysis_request.dart';
import '../../scanner/ai/garment_analysis_result.dart';
import '../../scanner/ai/garment_vision_analyzer.dart';
import 'garment_reanalysis_models.dart';

abstract interface class GarmentReanalysisRepository {
  Future<Garment?> findById(String id);
  Future<List<Garment>> findAll();
  Future<void> save(Garment garment);
}

typedef GarmentPhotoLoader = Future<Uint8List> Function(String path);

class GarmentReanalysisService {
  final GarmentReanalysisRepository repository;
  final GarmentVisionAnalyzer analyzer;
  final GarmentPhotoLoader loadPhoto;
  final GarmentReanalysisVersions versions;
  final DateTime Function() now;
  final Set<String> _running = {};
  GarmentReanalysisService({required this.repository, required this.analyzer, required this.loadPhoto, required this.versions, this.now = DateTime.now});

  Future<GarmentReanalysisProposal> propose(String garmentId, GarmentReanalysisType type) async {
    if (!_running.add(garmentId)) throw StateError('Une réanalyse est déjà en cours pour ce vêtement.');
    try {
      final garment = await repository.findById(garmentId);
      if (garment == null) throw StateError('Vêtement introuvable: $garmentId');
      final photos = garment.effectivePhotos;
      if (photos.isEmpty) throw StateError('Aucune photo enregistrée.');
      final bytes = <Uint8List>[];
      for (final photo in photos) { bytes.add(await loadPhoto(photo.path)); }
      final current = _values(garment);
      final result = await analyzer.analyze(GarmentAnalysisRequest(
        imageBytes: bytes.first, mimeType: _mime(photos.first.path), fileName: photos.first.path,
        allowedCategories: const [], allowedColors: const [], allowedMaterials: const [], allowedSeasons: Garment.availableSeasons,
        existingValues: current.map((key, value) => MapEntry(key, value?.toString() ?? '')),
        previousImageBytes: bytes.skip(1).toList(), previousAnalysis: garment.currentAnalysis?.values,
        requestedFields: _fields(type),
      ));
      final suggested = _restrict(_resultValues(result), type);
      final baseline = garment.currentAnalysis?.values ?? current;
      final decision = const AiReanalysisPolicy().compare(baseline: baseline, current: current, suggested: suggested);
      final changes = <GarmentReanalysisChange>[];
      for (final entry in suggested.entries) {
        if (entry.value == current[entry.key]) continue;
        changes.add(GarmentReanalysisChange(field: entry.key, oldAnalysis: baseline[entry.key], currentValue: current[entry.key], proposedValue: entry.value, conflict: decision.protectedUserValues.containsKey(entry.key) || garment.userModifiedFields.contains(entry.key)));
      }
      final at = now();
      return GarmentReanalysisProposal(garment: garment, type: type, photos: photos, changes: changes, snapshot: GarmentAnalysisSnapshot(
        version: versions.aiModel, pipelineVersion: versions.pipeline, analyzedAt: at, reanalysisType: type.name,
        photoIds: photos.map((photo) => photo.id).toList(), values: {...current, ...suggested, '_styleTaxonomyVersion': versions.styleTaxonomy, '_thermalEngineVersion': versions.thermalEngine},
      ));
    } finally { _running.remove(garmentId); }
  }

  Future<void> apply(GarmentReanalysisProposal proposal, Set<String> acceptedFields) async {
    final latest = await repository.findById(proposal.garment.id);
    if (latest == null) throw StateError('Vêtement supprimé pendant la réanalyse.');
    final latestValues = _values(latest);
    final allowed = proposal.changes.where((c) => acceptedFields.contains(c.field) && latestValues[c.field] == c.currentValue).map((c) => c.field).toSet();
    var updated = latest;
    for (final change in proposal.changes.where((c) => allowed.contains(c.field))) { updated = _applyField(updated, change.field, change.proposedValue); }
    await repository.save(updated.copyWith(previousAnalysis: latest.currentAnalysis, currentAnalysis: proposal.snapshot, aiAnalysisVersion: versions.aiModel, lastAnalyzedAt: proposal.snapshot.analyzedAt, updatedAt: now()));
  }

  Map<String, Object?> _values(Garment g) => {'name': g.name, 'category': g.category, 'sousCategorie': g.sousCategorie, 'material': g.material, 'composition': g.composition, 'style': g.style, 'season': g.season, 'temperatureMinimum': g.temperatureMinimum, 'temperatureMaximum': g.temperatureMaximum};
  Map<String, Object?> _resultValues(GarmentAnalysisResult r) => {'name': r.suggestedName, 'category': r.category, 'sousCategorie': r.preciseType, 'material': r.material, 'style': r.styleSummary, 'season': r.season}..removeWhere((_, value) => value == null);
  Map<String, Object?> _restrict(Map<String, Object?> values, GarmentReanalysisType type) { if (type == GarmentReanalysisType.complete) return values; final fields = switch(type) { GarmentReanalysisType.composition => {'material','composition'}, GarmentReanalysisType.style => {'style'}, GarmentReanalysisType.thermal => {'season','temperatureMinimum','temperatureMaximum'}, GarmentReanalysisType.category => {'category','sousCategorie'}, _ => values.keys.toSet() }; return Map.fromEntries(values.entries.where((e) => fields.contains(e.key))); }
  Set<String> _fields(GarmentReanalysisType type) => _restrict({'name': null, 'category': null, 'sousCategorie': null, 'material': null, 'composition': null, 'style': null, 'season': null, 'temperatureMinimum': null, 'temperatureMaximum': null}, type).keys.toSet();
  Garment _applyField(Garment g, String field, Object? value) => switch(field) { 'name' => g.copyWith(name: value.toString()), 'category' => g.copyWith(category: value.toString()), 'sousCategorie' => g.copyWith(sousCategorie: value?.toString()), 'material' => g.copyWith(material: value?.toString()), 'composition' => g.copyWith(composition: value?.toString()), 'style' => g.copyWith(style: value?.toString()), 'season' => g.copyWith(season: value?.toString()), 'temperatureMinimum' => g.copyWith(temperatureMinimum: value as double?), 'temperatureMaximum' => g.copyWith(temperatureMaximum: value as double?), _ => g };
  String _mime(String path) => path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
}
