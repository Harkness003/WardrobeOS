import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import '../scanner/ai/analysis_foundations.dart';
import '../../core/ai_context/ai_reanalysis_policy.dart';
import '../../data/database_service.dart';
import '../../models/garment.dart';
import '../scanner/ai/garment_analysis_exception.dart';
import '../scanner/ai/garment_analysis_request.dart';
import '../scanner/ai/garment_analysis_result.dart';
import '../scanner/ai/garment_image_processing.dart';
import '../scanner/ai/garment_vision_analyzer.dart';

enum AiReanalysisStep { idle, preparing, analyzing, comparing, completed }
enum AiReanalysisScope { all, old, style, thermal, composition }

class AiReanalysisDifference {
  final String field;
  final Object? currentValue;
  final Object? suggestedValue;
  final bool userConflict;

  const AiReanalysisDifference({
    required this.field,
    required this.currentValue,
    required this.suggestedValue,
    required this.userConflict,
  });
}

class AiReanalysisPreview {
  final Garment garment;
  final GarmentAnalysisResult analysis;
  final List<AiReanalysisDifference> differences;

  const AiReanalysisPreview(this.garment, this.analysis, this.differences);
}

class AiReanalysisReport {
  final int successes;
  final int failures;
  final Duration duration;
  final List<String> errors;

  const AiReanalysisReport(this.successes, this.failures, this.duration, this.errors);
}

/// UI-facing coordinator. Analysis, three-way comparison and persistence stay
/// delegated to the existing analyzer, policy, snapshots and database.
class AiReanalysisController extends ChangeNotifier {
  static const analysisVersion = 'scanner-v1';
  static const _categories = ['Hauts', 'Chemises', 'Vestes', 'Bas', 'Chaussures', 'Accessoires', 'Autre'];
  static const _colors = ['Noir', 'Blanc', 'Gris', 'Bleu', 'Marron', 'Beige', 'Vert', 'Rouge', 'Rose', 'Violet', 'Jaune', 'Orange'];
  static const _materials = ['Coton', 'Laine', 'Lin', 'Soie', 'Polyester', 'Cuir', 'Denim', 'Cachemire', 'Viscose', 'Autre'];
  static const _seasons = ['Printemps', 'Été', 'Automne', 'Hiver', 'Toute saison'];

  final DatabaseService database;
  final GarmentVisionAnalyzer analyzer;
  final AiReanalysisPolicy policy;
  bool _busy = false;
  AiReanalysisStep step = AiReanalysisStep.idle;
  AiReanalysisReport? lastReport;

  AiReanalysisController({
    required this.database,
    required this.analyzer,
    this.policy = const AiReanalysisPolicy(),
  });

  bool get busy => _busy;

  Future<AiReanalysisPreview> prepare(Garment garment) async {
    if (_busy) throw const GarmentAnalysisException(GarmentAnalysisError.invalidSchema, 'Une analyse est déjà en cours.');
    _busy = true;
    step = AiReanalysisStep.preparing;
    notifyListeners();
    try {
      final photos = garment.effectivePhotos;
      if (photos.isEmpty) {
        throw const GarmentAnalysisException(GarmentAnalysisError.missingImage, 'Ajoute au moins une photo avant de réanalyser cette fiche.');
      }
      final bytes = <Uint8List>[];
      for (final photo in photos) {
        final file = File(photo.path);
        if (await file.exists()) bytes.add(await file.readAsBytes());
      }
      if (bytes.isEmpty) {
        throw const GarmentAnalysisException(GarmentAnalysisError.missingImage, 'Les photos de cette fiche sont introuvables.');
      }
      step = AiReanalysisStep.analyzing;
      notifyListeners();
      final result = await analyzer.analyze(GarmentAnalysisRequest(
        imageBytes: bytes.first,
        mimeType: GarmentImageValidator.detectMimeType(bytes.first) ?? 'image/jpeg',
        allowedCategories: _categories,
        allowedColors: _colors,
        allowedMaterials: _materials,
        allowedSeasons: _seasons,
        existingValues: _stringValues(_currentValues(garment)),
        previousImageBytes: bytes.skip(1).toList(growable: false),
        previousAnalysis: garment.currentAnalysis?.values,
      ));
      if (!result.isUsableImage) {
        throw GarmentAnalysisException(GarmentAnalysisError.rejectedImage, result.rejectionReason ?? 'Les photos ne permettent pas une nouvelle analyse.');
      }
      step = AiReanalysisStep.comparing;
      notifyListeners();
      final current = _currentValues(garment);
      final suggested = _suggestedValues(result);
      final baseline = _snapshotValues(garment.currentAnalysis?.values ?? const {});
      final decision = policy.compare(baseline: baseline, current: current, suggested: suggested);
      final differences = <AiReanalysisDifference>[];
      for (final entry in suggested.entries) {
        if (_equal(entry.value, current[entry.key])) continue;
        differences.add(AiReanalysisDifference(
          field: entry.key,
          currentValue: current[entry.key],
          suggestedValue: entry.value,
          userConflict: decision.protectedUserValues.containsKey(entry.key) || garment.userModifiedFields.contains(entry.key),
        ));
      }
      return AiReanalysisPreview(garment, result, differences);
    } catch (_) {
      _finish(AiReanalysisStep.idle);
      rethrow;
    }
  }

  Future<Garment> apply(AiReanalysisPreview preview, Set<String> accepted) async {
    try {
      final values = _suggestedValues(preview.analysis);
      var updated = _applyValues(preview.garment, {for (final key in accepted) key: values[key]});
      final now = DateTime.now();
      updated = updated.copyWith(
        previousAnalysis: preview.garment.currentAnalysis,
        currentAnalysis: GarmentAnalysisSnapshot(version: analysisVersion, analyzedAt: now, values: preview.analysis.toJson().cast<String, Object?>()),
        lastAnalyzedAt: now,
        aiAnalysisVersion: analysisVersion,
        updatedAt: now,
      );
      await database.updateGarment(updated);
      _finish(AiReanalysisStep.completed);
      return updated;
    } catch (_) {
      _finish(AiReanalysisStep.idle);
      rethrow;
    }
  }

  void cancel() => _finish(AiReanalysisStep.idle);

  Future<(int, int)> estimate(AiReanalysisScope scope) async {
    final garments = await database.getGarments();
    final selected = _select(garments, scope);
    return (selected.length, selected.fold<int>(0, (sum, item) => sum + (item.effectivePhotos.isEmpty ? 0 : 1)));
  }

  Future<AiReanalysisReport> runGlobal(AiReanalysisScope scope) async {
    if (_busy) throw StateError('Une analyse est déjà en cours.');
    final watch = Stopwatch()..start();
    var successes = 0;
    final errors = <String>[];
    final selected = _select(await database.getGarments(), scope);
    for (final garment in selected) {
      try {
        final preview = await prepare(garment);
        final scopeFields = switch (scope) {
          AiReanalysisScope.style => const {'style'},
          AiReanalysisScope.composition => const {'composition', 'material'},
          AiReanalysisScope.thermal => const <String>{},
          _ => const {'name', 'category', 'color', 'material', 'season', 'brand', 'composition', 'style'},
        };
        final allowed = preview.differences
            .where((item) => !item.userConflict && scopeFields.contains(item.field))
            .map((item) => item.field)
            .toSet();
        await apply(preview, allowed);
        successes++;
      } catch (error) {
        errors.add('${garment.name} : ${_message(error)}');
      }
    }
    watch.stop();
    lastReport = AiReanalysisReport(successes, errors.length, watch.elapsed, List.unmodifiable(errors));
    notifyListeners();
    return lastReport!;
  }

  List<Garment> _select(List<Garment> garments, AiReanalysisScope scope) => switch (scope) {
    AiReanalysisScope.old => garments.where((item) => item.needsAiReanalysis(analysisVersion)).toList(),
    _ => garments,
  };

  void _finish(AiReanalysisStep value) {
    step = value;
    _busy = false;
    notifyListeners();
  }

  static String _message(Object error) => error is GarmentAnalysisException ? error.message : 'Analyse impossible';
  static bool _equal(Object? a, Object? b) => a.toString() == b.toString();
  static Map<String, String> _stringValues(Map<String, Object?> values) => {for (final e in values.entries) if (e.value != null) e.key: e.value.toString()};
  static Map<String, Object?> _currentValues(Garment g) => {'name': g.name, 'category': g.category, 'color': g.color, 'material': g.material, 'season': g.season, 'brand': g.brand, 'composition': g.composition, 'style': g.resumeStylistique};
  static Map<String, Object?> _snapshotValues(Map<String, Object?> raw) => {'name': raw['suggestedName'], 'category': raw['category'], 'color': raw['primaryColor'], 'material': raw['material'], 'season': raw['season'], 'brand': raw['visibleBrand'], 'composition': _composition(raw['compositions']), 'style': raw['styleSummary']};
  static Map<String, Object?> _suggestedValues(GarmentAnalysisResult r) => {'name': r.suggestedName, 'category': r.category, 'color': r.primaryColor, 'material': r.material, 'season': r.season, 'brand': r.visibleBrand, 'composition': r.compositions.map((e) => '${e.material}${e.percentage == null ? '' : ' ${e.percentage!.round()} %'}').join(', '), 'style': r.styleSummary}..removeWhere((_, value) => value == null || value == '');
  static Object? _composition(Object? value) => value is List ? value.map((e) => e is Map ? '${e['material']}${e['percentage'] == null ? '' : ' ${(e['percentage'] as num).round()} %'}' : '$e').join(', ') : value;

  static Garment _applyValues(Garment g, Map<String, Object?> v) => g.copyWith(
    name: v['name'] as String?, category: v['category'] as String?, color: v['color'] as String?,
    couleurPrincipale: v['color'] as String?, material: v['material'] as String?, matierePrincipale: v['material'] as String?,
    season: v['season'] as String?, brand: v['brand'] as String?, composition: v['composition'] as String?,
    resumeStylistique: v['style'] as String?,
  );
}
