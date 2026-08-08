import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database_service.dart';
import '../../../core/diagnostics/diagnostic_service.dart';
import '../../../models/garment.dart';
import '../../../models/garment_normalizer.dart';
import '../../../models/garment_photo.dart';
import '../../../models/thermal_profile_calculator.dart';
import '../../assistant/settings/api_key_storage.dart';
import '../../wardrobe/personal_catalog_repository.dart';
import '../ai/analysis_foundations.dart';
import '../ai/garment_analysis_exception.dart';
import '../ai/garment_analysis_normalizer.dart';
import '../ai/garment_analysis_request.dart';
import '../ai/garment_analysis_result.dart';
import '../ai/garment_analysis_validator.dart';
import '../ai/garment_image_processing.dart';
import '../ai/garment_vision_analyzer.dart';
import '../ai/normalization/garment_value_normalizer.dart';
import '../ai/openai_garment_vision_analyzer.dart';

const importCategories = ['Hauts', 'Chemises', 'Vestes', 'Bas', 'Chaussures', 'Accessoires', 'Autre'];
const importColors = ['Noir', 'Blanc', 'Gris', 'Bleu marine', 'Bleu', 'Beige', 'Marron', 'Camel', 'Vert', 'Kaki', 'Rouge', 'Bordeaux', 'Rose', 'Violet', 'Jaune', 'Orange'];
const importMaterials = ['Coton', 'Laine', 'Lin', 'Soie', 'Denim', 'Cuir', 'Textile', 'Synthétique'];
const importEnrichmentFields = {
  'material', 'compositions', 'thermalPhysicalProperties',
};

enum WardrobeImportStatus { pending, quickAnalysis, enriching, completed, needsReview, failed, cancelled }

enum WardrobeImportEventType { importFinished, needsReview, analysisFailed, enrichmentFinished }

class WardrobeImportEvent {
  final WardrobeImportEventType type;
  final String taskId;
  const WardrobeImportEvent(this.type, this.taskId);
}

class WardrobeImportTask {
  final String id;
  final String photoPath;
  final DateTime capturedAt;
  final WardrobeImportStatus status;
  final int attempt;
  final String? garmentId;
  final GarmentAnalysisResult? quickResult;
  final GarmentAnalysisResult? enrichmentResult;
  final String? userMessage;
  final Map<String, int> timings;

  const WardrobeImportTask({required this.id, required this.photoPath, required this.capturedAt,
    this.status = WardrobeImportStatus.pending, this.attempt = 0, this.garmentId,
    this.quickResult, this.enrichmentResult, this.userMessage, this.timings = const {}});

  WardrobeImportTask copyWith({WardrobeImportStatus? status, int? attempt, String? garmentId,
      GarmentAnalysisResult? quickResult, GarmentAnalysisResult? enrichmentResult,
      String? userMessage, Map<String, int>? timings}) => WardrobeImportTask(
    id: id, photoPath: photoPath, capturedAt: capturedAt, status: status ?? this.status,
    attempt: attempt ?? this.attempt, garmentId: garmentId ?? this.garmentId,
    quickResult: quickResult ?? this.quickResult, enrichmentResult: enrichmentResult ?? this.enrichmentResult,
    userMessage: userMessage, timings: timings ?? this.timings);

  Map<String, Object?> toMap() => {
    'id': id, 'photo_path': photoPath, 'captured_at': capturedAt.toIso8601String(),
    'status': status.name, 'attempt': attempt, 'garment_id': garmentId,
    'quick_result': quickResult == null ? null : jsonEncode(quickResult!.toJson()),
    'enrichment_result': enrichmentResult == null ? null : jsonEncode(enrichmentResult!.toJson()),
    'user_message': userMessage, 'timings': jsonEncode(timings),
    'updated_at': DateTime.now().toIso8601String(),
  };

  factory WardrobeImportTask.fromMap(Map<String, Object?> map) {
    GarmentAnalysisResult? result(Object? raw) => raw == null ? null
        : GarmentAnalysisResult.fromJson((jsonDecode(raw as String) as Map).cast<String, dynamic>());
    return WardrobeImportTask(id: map['id']! as String, photoPath: map['photo_path']! as String,
      capturedAt: DateTime.parse(map['captured_at']! as String),
      status: WardrobeImportStatus.values.byName(map['status']! as String),
      attempt: map['attempt']! as int, garmentId: map['garment_id'] as String?,
      quickResult: result(map['quick_result']), enrichmentResult: result(map['enrichment_result']),
      userMessage: map['user_message'] as String?,
      timings: ((jsonDecode(map['timings']! as String) as Map).cast<String, dynamic>())
          .map((key, value) => MapEntry(key, value as int)));
  }
}

class WardrobeImportMetrics {
  final int successes, failures;
  final Duration average, median, maximum;
  final double garmentsPerMinute;
  const WardrobeImportMetrics({required this.successes, required this.failures, required this.average,
    required this.median, required this.maximum, required this.garmentsPerMinute});
}

/// Persistent, application-scoped coordinator for the existing quick → enrichment pipeline.
/// It resumes while the application is alive or on its next launch; it is not an OS background worker.
class WardrobeImportService extends ChangeNotifier {
  static WardrobeImportService? _instance;
  static WardrobeImportService get instance => _instance ??= WardrobeImportService();

  final DatabaseService database;
  final GarmentVisionAnalyzer analyzer;
  final PersonalCatalogRepository catalog;
  final int maxConcurrency;
  final int maxAttempts;
  final _events = StreamController<WardrobeImportEvent>.broadcast();
  final List<WardrobeImportTask> _tasks = [];
  int _running = 0;
  bool _loaded = false;

  WardrobeImportService({DatabaseService? database, GarmentVisionAnalyzer? analyzer,
      PersonalCatalogRepository? catalog, this.maxConcurrency = 2, this.maxAttempts = 2})
      : database = database ?? DatabaseService.instance,
        analyzer = analyzer ?? OpenAiGarmentVisionAnalyzer(apiKeyStorage: const ApiKeyStorage()),
        catalog = catalog ?? PersonalCatalogRepository(database: database);

  List<WardrobeImportTask> get tasks => List.unmodifiable(_tasks);
  Stream<WardrobeImportEvent> get events => _events.stream;
  int get captured => _tasks.where((task) => task.status != WardrobeImportStatus.cancelled).length;
  int get pending => _tasks.where((task) => task.status == WardrobeImportStatus.pending).length;
  int get analyzing => _tasks.where((task) => task.status == WardrobeImportStatus.quickAnalysis || task.status == WardrobeImportStatus.enriching).length;
  int get completed => _tasks.where((task) => task.status == WardrobeImportStatus.completed).length;
  int get needsReview => _tasks.where((task) => task.status == WardrobeImportStatus.needsReview).length;
  int get failed => _tasks.where((task) => task.status == WardrobeImportStatus.failed).length;

  Future<void> initialize() async {
    if (_loaded) { _pump(); return; }
    _tasks.addAll((await database.getWardrobeImportTasks()).map(WardrobeImportTask.fromMap));
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].status == WardrobeImportStatus.quickAnalysis || _tasks[i].status == WardrobeImportStatus.enriching) {
        _tasks[i] = _tasks[i].copyWith(status: WardrobeImportStatus.pending,
          userMessage: 'Analyse reprise après interruption.');
        await _persist(_tasks[i]);
      }
    }
    _loaded = true;
    notifyListeners();
    _pump();
  }

  Future<WardrobeImportTask> enqueue(String photoPath, {Duration captureDuration = Duration.zero}) async {
    final task = WardrobeImportTask(id: const Uuid().v4(), photoPath: photoPath,
      capturedAt: DateTime.now(), timings: {'capture': captureDuration.inMilliseconds});
    _tasks.add(task);
    await _persist(task);
    notifyListeners();
    _pump();
    return task;
  }

  Future<bool> cancel(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0 || _tasks[index].status != WardrobeImportStatus.pending) { return false; }
    final task = _tasks[index].copyWith(status: WardrobeImportStatus.cancelled);
    _tasks[index] = task;
    await _persist(task);
    await File(task.photoPath).delete().catchError((_) => File(task.photoPath));
    notifyListeners();
    return true;
  }

  Future<void> retry(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0 || _tasks[index].status != WardrobeImportStatus.failed) { return; }
    _tasks[index] = _tasks[index].copyWith(status: WardrobeImportStatus.pending, attempt: 0, userMessage: null);
    await _persist(_tasks[index]);
    notifyListeners();
    _pump();
  }

  void resume() => _pump();

  void _pump() {
    if (!_loaded) { return; }
    while (_running < maxConcurrency) {
      final index = _tasks.indexWhere((task) => task.status == WardrobeImportStatus.pending);
      if (index < 0) { break; }
      _running++;
      final taskId = _tasks[index].id;
      unawaited(_process(_tasks[index]).whenComplete(() {
        _running--;
        _pump();
        if (_running == 0 && pending == 0) {
          _events.add(WardrobeImportEvent(WardrobeImportEventType.importFinished, taskId));
        }
      }));
    }
  }

  Future<void> _process(WardrobeImportTask original) async {
    final total = Stopwatch()..start();
    try {
      var task = await _replace(original.copyWith(status: WardrobeImportStatus.quickAnalysis,
        attempt: original.attempt + 1, userMessage: null));
      final preparation = Stopwatch()..start();
      final validation = await const GarmentImageValidator().validateFile(task.photoPath);
      if (!validation.isValid) throw GarmentAnalysisException(GarmentAnalysisError.rejectedImage,
        validation.rejectionReason ?? 'Cette photo ne permet pas d’identifier un vêtement.');
      final bytes = await File(task.photoPath).readAsBytes();
      final request = GarmentAnalysisRequest(imageBytes: bytes,
        mimeType: GarmentImageValidator.detectMimeType(bytes) ?? 'image/jpeg',
        allowedCategories: importCategories, allowedColors: importColors,
        allowedMaterials: importMaterials,
        allowedSeasons: const <String>[],
        requestedFields: importEnrichmentFields);
      preparation.stop();
      final quickWatch = Stopwatch()..start();
      final quick = _validated(await analyzer.analyzeQuick(request));
      quickWatch.stop();
      if (!quick.isUsableImage || (quick.category == null && quick.preciseType == null)) {
        throw GarmentAnalysisException(GarmentAnalysisError.rejectedImage,
          quick.rejectionReason ?? 'Le vêtement n’est pas suffisamment visible.');
      }
      final creation = Stopwatch()..start();
      final garment = _quickGarment(task, quick);
      await database.insertGarment(garment);
      creation.stop();
      task = await _replace(task.copyWith(status: WardrobeImportStatus.enriching,
        garmentId: garment.id, quickResult: quick, timings: {...task.timings,
          'preparation': preparation.elapsedMilliseconds, 'quick': quickWatch.elapsedMilliseconds,
          'creation': creation.elapsedMilliseconds}));

      final enrichmentWatch = Stopwatch()..start();
      final enriched = _validated(await analyzer.enrich(request.copyWith(
        phase: GarmentAnalysisPhase.enrichment, previousAnalysis: quick.toJson(),
        requestedFields: importEnrichmentFields)));
      enrichmentWatch.stop();
      await _mergeEnrichment(garment.id, quick, enriched);
      total.stop();
      final review = _needsReview(quick);
      await _replace(task.copyWith(status: review ? WardrobeImportStatus.needsReview : WardrobeImportStatus.completed,
        enrichmentResult: enriched, userMessage: review ? 'Vérifiez la catégorie, le type ou la couleur.' : null,
        timings: {...task.timings, 'enrichment': enrichmentWatch.elapsedMilliseconds,
          'total': total.elapsedMilliseconds}));
      _events.add(WardrobeImportEvent(WardrobeImportEventType.enrichmentFinished, task.id));
      if (review) { _events.add(WardrobeImportEvent(WardrobeImportEventType.needsReview, task.id)); }
      DiagnosticService.instance.publish(module: DiagnosticModule.wardrobeImport,
        level: review ? AppDiagnosticLevel.warning : AppDiagnosticLevel.success,
        state: review ? 'À vérifier' : 'Terminé', summary: 'Vêtement importé',
        source: 'WardrobeImportService', duration: total.elapsed,
        warning: review ? 'La catégorie, le type ou la couleur mérite une vérification.' : null,
        details: {'photos': 1, 'quickMs': quickWatch.elapsedMilliseconds,
          'enrichmentMs': enrichmentWatch.elapsedMilliseconds,
          'profilThermique': 'généré'},
        pipeline: [
          DiagnosticStep('Photo', duration: preparation.elapsed),
          DiagnosticStep('Quick', duration: quickWatch.elapsed),
          DiagnosticStep('Création', duration: creation.elapsed),
          DiagnosticStep('Enrichment', duration: enrichmentWatch.elapsed),
          DiagnosticStep('Thermal', level: review ? AppDiagnosticLevel.warning : AppDiagnosticLevel.success),
        ]);
      DiagnosticService.instance.publish(module: DiagnosticModule.scanner,
        level: review ? AppDiagnosticLevel.warning : AppDiagnosticLevel.success,
        state: review ? 'Analyse à confirmer' : 'Analyse terminée',
        summary: 'Photo analysée et profil thermique généré',
        source: 'GarmentVisionAnalyzer', duration: total.elapsed,
        details: {'photos': 1, 'quickMs': quickWatch.elapsedMilliseconds,
          'enrichmentMs': enrichmentWatch.elapsedMilliseconds, 'profilThermique': 'généré'},
        pipeline: [
          DiagnosticStep('Photo', duration: preparation.elapsed),
          DiagnosticStep('Quick', duration: quickWatch.elapsed),
          DiagnosticStep('Enrichment', duration: enrichmentWatch.elapsed),
          const DiagnosticStep('Thermal'),
          DiagnosticStep('Résultat', level: review ? AppDiagnosticLevel.warning : AppDiagnosticLevel.success),
        ]);
    } catch (error) {
      total.stop();
      final current = _tasks.firstWhere((task) => task.id == original.id);
      // Quick already crossed the creation threshold: enrichment is optional
      // and must never turn a usable, visible garment into a failed import.
      if (current.garmentId != null) {
        await _replace(current.copyWith(
          status: WardrobeImportStatus.needsReview,
          userMessage: 'La fiche est créée ; son enrichissement pourra être réessayé.',
          timings: {...current.timings, 'total': total.elapsedMilliseconds},
        ));
        _events.add(WardrobeImportEvent(WardrobeImportEventType.needsReview, current.id));
        return;
      }
      if (_isTransient(error) && current.attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 500 * current.attempt));
        await _replace(current.copyWith(status: WardrobeImportStatus.pending,
          userMessage: 'Connexion indisponible — l’analyse va reprendre.'));
      } else {
        await _replace(current.copyWith(status: WardrobeImportStatus.failed,
          userMessage: _friendly(error), timings: {...current.timings, 'total': total.elapsedMilliseconds}));
        _events.add(WardrobeImportEvent(WardrobeImportEventType.analysisFailed, current.id));
      }
      DiagnosticService.instance.publish(module: DiagnosticModule.wardrobeImport,
        level: AppDiagnosticLevel.error, state: 'Interrompu', summary: 'Import non terminé',
        source: 'WardrobeImportService', duration: total.elapsed,
        reason: _friendly(error), details: {'tentative': current.attempt},
        pipeline: [
          const DiagnosticStep('Photo'),
          DiagnosticStep('Quick / Enrichment', level: AppDiagnosticLevel.error, duration: total.elapsed),
          const DiagnosticStep('Résultat', level: AppDiagnosticLevel.error),
        ]);
      DiagnosticService.instance.publish(module: DiagnosticModule.scanner,
        level: AppDiagnosticLevel.error, state: 'Analyse interrompue',
        summary: 'La photo n’a pas produit de fiche exploitable',
        source: 'GarmentVisionAnalyzer', duration: total.elapsed,
        reason: _friendly(error), pipeline: [
          const DiagnosticStep('Photo'),
          DiagnosticStep('Quick / Enrichment', level: AppDiagnosticLevel.error, duration: total.elapsed),
          const DiagnosticStep('Résultat', level: AppDiagnosticLevel.error),
        ]);
    }
  }

  GarmentAnalysisResult _validated(GarmentAnalysisResult raw) => const GarmentAnalysisNormalizer().normalize(
    GarmentAnalysisValidator(categoryNormalizer: const GarmentValueNormalizer(importCategories),
      colorNormalizer: const GarmentValueNormalizer(importColors),
      materialNormalizer: const GarmentValueNormalizer(importMaterials),
      seasonNormalizer: const GarmentValueNormalizer([])).validate(raw).analysis);

  Garment _quickGarment(WardrobeImportTask task, GarmentAnalysisResult quick) {
    final now = DateTime.now();
    final type = GarmentNormalizer.normalizeType(name: quick.suggestedName,
      category: quick.category, subcategory: quick.preciseType, preciseType: quick.preciseType);
    final category = type.category ?? quick.category ?? 'Autre';
    final color = GarmentNormalizer.classification(quick.primaryColor);
    final brand = GarmentNormalizer.brand(quick.visibleBrand);
    final thermal = const ThermalProfileCalculator().calculate(ThermalProfileInput(
      category: category, subcategory: type.subcategory), calculatedAt: now);
    return Garment(id: const Uuid().v4(),
      name: GarmentNormalizer.value(quick.suggestedName) ?? type.preciseType ?? 'Vêtement à identifier',
      category: category, sousCategorie: type.subcategory, typePrecis: type.preciseType,
      brand: brand, color: color, couleurPrincipale: color, descriptionIA: quick.suggestedName,
      thermalProfile: thermal, confianceGlobale: quick.globalConfidence,
      avertissementsIA: quick.warnings,
      photos: [GarmentPhoto(id: const Uuid().v4(), path: task.photoPath,
        type: GarmentPhotoType.primary, createdAt: now)],
      lastAnalyzedAt: now, aiAnalysisVersion: 'scanner-v1:${OpenAiGarmentVisionAnalyzer.defaultModel}',
      currentAnalysis: GarmentAnalysisSnapshot(version: 'scanner-v1:${OpenAiGarmentVisionAnalyzer.defaultModel}',
        analyzedAt: now, values: quick.toJson().cast<String, Object?>()),
      notes: _needsReview(quick) ? 'Import rapide · à vérifier' : 'Import rapide · validé automatiquement',
      createdAt: now, updatedAt: now);
  }

  Future<void> _mergeEnrichment(String id, GarmentAnalysisResult quick, GarmentAnalysisResult enriched) async {
    final current = await database.getGarmentById(id);
    if (current == null) { return; }
    final protected = current.userModifiedFields;
    final material = protected.contains('material') ? current.material
      : GarmentNormalizer.classification(enriched.material);
    final brand = protected.contains('brand') ? current.brand
      : GarmentNormalizer.brand(enriched.visibleBrand ?? quick.visibleBrand);
    final mergedJson = {...quick.toJson(), ...enriched.toJson(),
      'suggestedName': quick.suggestedName, 'category': quick.category,
      'preciseType': quick.preciseType, 'primaryColor': quick.primaryColor};
    final composition = enriched.compositions.isEmpty ? current.composition
      : enriched.compositions.map((value) => [
          if (value.percentage != null) '${value.percentage!.toStringAsFixed(0)}%',
          value.material,
        ].join(' ')).join(', ');
    final thermalInput = ThermalProfileInput(
      category: current.category,
      subcategory: current.sousCategorie,
      material: material,
      composition: protected.contains('composition') ? current.composition : composition,
      thickness: enriched.thickness,
      lining: enriched.lining,
      fit: protected.contains('fit') ? current.fit : enriched.fit,
      construction: enriched.construction,
      length: protected.contains('longueur') ? current.longueur : enriched.length,
      opening: protected.contains('typeFermeture') ? current.typeFermeture : enriched.opening,
      detectedFeatures: enriched.detectedFeatures,
    );
    final thermal = protected.contains('thermalProfile') ? current.thermalProfile
      : const ThermalProfileCalculator().ensureCurrent(thermalInput, current.thermalProfile);
    final updated = current.copyWith(material: material, matierePrincipale: material,
      brand: brand,
      composition: protected.contains('composition') ? current.composition : composition,
      fit: protected.contains('fit') ? current.fit : enriched.fit,
      longueur: protected.contains('longueur') ? current.longueur : enriched.length,
      typeFermeture: protected.contains('typeFermeture') ? current.typeFermeture : enriched.opening,
      thermalProfile: thermal,
      confianceMatiere: enriched.fieldConfidences['material'],
      lastAnalyzedAt: DateTime.now(), updatedAt: DateTime.now(),
      currentAnalysis: GarmentAnalysisSnapshot(version: 'scanner-v1:${OpenAiGarmentVisionAnalyzer.defaultModel}',
        analyzedAt: DateTime.now(), values: mergedJson.cast<String, Object?>()));
    await database.updateGarment(updated);
    await Future.wait([
      catalog.learn(PersonalCatalogField.subcategory, updated.sousCategorie),
      catalog.learn(PersonalCatalogField.brand, updated.brand),
      catalog.learn(PersonalCatalogField.material, updated.material),
      catalog.learn(PersonalCatalogField.color, updated.color),
    ]);
  }

  bool _needsReview(GarmentAnalysisResult value) {
    double confidence(String field) => value.fieldConfidences[field] ?? value.globalConfidence;
    return value.warnings.isNotEmpty || value.category == null ||
      confidence('category') < .75 || (value.preciseType != null && confidence('preciseType') < .65) ||
      (value.primaryColor == null || confidence('primaryColor') < .65);
  }

  bool _isTransient(Object error) => error is GarmentAnalysisException &&
    {GarmentAnalysisError.network, GarmentAnalysisError.timeout,
      GarmentAnalysisError.quotaExceeded}.contains(error.error);

  String _friendly(Object error) => error is GarmentAnalysisException &&
      error.error == GarmentAnalysisError.rejectedImage
    ? 'Photo inexploitable — reprenez-la en cadrant un seul vêtement.'
    : 'Analyse indisponible pour le moment. Vous pourrez réessayer.';

  Future<WardrobeImportTask> _replace(WardrobeImportTask task) async {
    final index = _tasks.indexWhere((value) => value.id == task.id);
    if (index >= 0) { _tasks[index] = task; }
    await _persist(task);
    notifyListeners();
    return task;
  }

  Future<void> _persist(WardrobeImportTask task) => database.putWardrobeImportTask(task.toMap());

  WardrobeImportMetrics get metrics {
    final finished = _tasks.where((task) => task.status == WardrobeImportStatus.completed ||
      task.status == WardrobeImportStatus.needsReview || task.status == WardrobeImportStatus.failed).toList();
    final values = finished.map((task) => task.timings['total'] ?? 0).toList()..sort();
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return WardrobeImportMetrics(successes: completed + needsReview, failures: failed,
      average: Duration(milliseconds: values.isEmpty ? 0 : total ~/ values.length),
      median: Duration(milliseconds: values.isEmpty ? 0 : values[values.length ~/ 2]),
      maximum: Duration(milliseconds: values.isEmpty ? 0 : values.last),
      garmentsPerMinute: total == 0 ? 0 : (completed + needsReview) * 60000 / total);
  }
}
