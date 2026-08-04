import 'dart:convert';

/// Persisted input/output pair used by a future comparison UI.
class GarmentAnalysisSnapshot {
  final String version;
  final String pipelineVersion;
  final DateTime analyzedAt;
  final String reanalysisType;
  final List<String> photoIds;
  final Map<String, Object?> values;

  const GarmentAnalysisSnapshot({required this.version, this.pipelineVersion = 'legacy', required this.analyzedAt, this.reanalysisType = 'complete', this.photoIds = const [], required this.values});
  Map<String, Object?> toJson() => {'version': version, 'pipelineVersion': pipelineVersion, 'analyzedAt': analyzedAt.toIso8601String(), 'reanalysisType': reanalysisType, 'photoIds': photoIds, 'values': values};
  factory GarmentAnalysisSnapshot.fromJson(Map<String, Object?> json) => GarmentAnalysisSnapshot(
    version: json['version']?.toString() ?? 'legacy',
    pipelineVersion: json['pipelineVersion']?.toString() ?? 'legacy',
    analyzedAt: DateTime.tryParse(json['analyzedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    reanalysisType: json['reanalysisType']?.toString() ?? 'complete',
    photoIds: (json['photoIds'] as List?)?.map((value) => value.toString()).toList() ?? const [],
    values: (json['values'] as Map?)?.cast<String, Object?>() ?? const {},
  );
  static String? encode(GarmentAnalysisSnapshot? value) => value == null ? null : jsonEncode(value.toJson());
  static GarmentAnalysisSnapshot? decode(Object? value) {
    if (value is! String || value.isEmpty) return null;
    try { return GarmentAnalysisSnapshot.fromJson((jsonDecode(value) as Map).cast<String, Object?>()); } catch (_) { return null; }
  }
}

/// Keeps user-owned fields when applying a later AI enrichment.
class AnalysisMergePolicy {
  const AnalysisMergePolicy();
  Map<String, Object?> merge({required Map<String, Object?> current, required Map<String, Object?> analysis, required Set<String> userModifiedFields}) => {
    ...current,
    for (final entry in analysis.entries)
      if (!userModifiedFields.contains(entry.key)) entry.key: entry.value,
  };
}

/// Headless concurrency primitive for scanner/enrichment flows. A photo or a
/// user edit arriving during a slow request is retained for the next merge.
class AnalysisSession {
  final List<String> _photoPaths = [];
  final Set<String> _userModifiedFields = {};
  int _revision = 0;

  List<String> get photoPaths => List.unmodifiable(_photoPaths);
  Set<String> get userModifiedFields => Set.unmodifiable(_userModifiedFields);
  int get revision => _revision;

  void addPhoto(String path) {
    if (_photoPaths.contains(path)) return;
    _photoPaths.add(path);
    _revision++;
  }

  void markUserModified(String field) {
    _userModifiedFields.add(field);
    _revision++;
  }

  /// Returns false when new input arrived while [operation] was pending.
  Future<bool> run(Future<void> Function(List<String> photos) operation) async {
    final startRevision = _revision;
    await operation(List.unmodifiable(_photoPaths));
    return startRevision == _revision;
  }
}
