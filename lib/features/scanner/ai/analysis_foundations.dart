import 'dart:convert';

/// Persisted input/output pair used by a future comparison UI.
class GarmentAnalysisSnapshot {
  final String version;
  final DateTime analyzedAt;
  final Map<String, Object?> values;

  const GarmentAnalysisSnapshot({required this.version, required this.analyzedAt, required this.values});
  Map<String, Object?> toJson() => {'version': version, 'analyzedAt': analyzedAt.toIso8601String(), 'values': values};
  factory GarmentAnalysisSnapshot.fromJson(Map<String, Object?> json) => GarmentAnalysisSnapshot(
    version: json['version']?.toString() ?? 'legacy',
    analyzedAt: DateTime.tryParse(json['analyzedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
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
