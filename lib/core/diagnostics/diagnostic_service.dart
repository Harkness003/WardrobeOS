import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AppDiagnosticLevel { info, warning, error, success }

enum DiagnosticModule {
  scanner('Scanner'),
  wardrobeImport('Import Dressing'),
  daily('Daily'),
  wardrobeGpt('WardrobeGPT'),
  agenda('Agenda'),
  googleCalendar('Google Calendar'),
  weather('Weather'),
  outfits('Tenues'),
  backup('Sauvegarde'),
  database('Base locale');

  const DiagnosticModule(this.label);
  final String label;
}

class DiagnosticStep {
  final String name;
  final AppDiagnosticLevel level;
  final Duration duration;
  final String? detail;

  const DiagnosticStep(this.name, {
    this.level = AppDiagnosticLevel.success,
    this.duration = Duration.zero,
    this.detail,
  });

  Map<String, Object?> toJson() => {
    'name': name,
    'level': level.name.toUpperCase(),
    'durationMs': duration.inMilliseconds,
    if (detail != null) 'detail': detail,
  };
}

class DiagnosticEntry {
  final String id;
  final DiagnosticModule module;
  final AppDiagnosticLevel level;
  final String state;
  final String summary;
  final String? reason;
  final String? warning;
  final DateTime date;
  final Duration duration;
  final String version;
  final String source;
  final Map<String, Object?> details;
  final List<DiagnosticStep> pipeline;

  const DiagnosticEntry({
    required this.id,
    required this.module,
    required this.level,
    required this.state,
    required this.summary,
    required this.date,
    required this.version,
    required this.source,
    this.reason,
    this.warning,
    this.duration = Duration.zero,
    this.details = const {},
    this.pipeline = const [],
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'module': module.label,
    'level': level.name.toUpperCase(),
    'state': state,
    'summary': summary,
    if (reason != null) 'reason': reason,
    if (warning != null) 'warning': warning,
    'date': date.toUtc().toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'version': version,
    'source': source,
    'details': details,
    'pipeline': pipeline.map((step) => step.toJson()).toList(),
  };
}

/// Unique, opt-in business diagnostics bus. Calls return before allocating an
/// entry while disabled, keeping the normal-user cost close to zero.
class DiagnosticService extends ChangeNotifier {
  DiagnosticService._();
  static final DiagnosticService instance = DiagnosticService._();
  static const maxEntriesPerModule = 100;
  static const appVersion = '0.8.0+9';

  bool _enabled = false;
  int _sequence = 0;
  final Map<DiagnosticModule, List<DiagnosticEntry>> _entries = {};

  bool get enabled => _enabled;
  List<DiagnosticEntry> get entries => List.unmodifiable(
    _entries.values.expand((items) => items).toList()
      ..sort((a, b) => b.date.compareTo(a.date)),
  );

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  void publish({
    required DiagnosticModule module,
    required AppDiagnosticLevel level,
    required String state,
    required String summary,
    required String source,
    String? reason,
    String? warning,
    Duration duration = Duration.zero,
    Map<String, Object?> details = const {},
    List<DiagnosticStep> pipeline = const [],
  }) {
    if (!_enabled) return;
    final safeDetails = _sanitizeMap(details);
    final list = _entries.putIfAbsent(module, () => []);
    list.add(DiagnosticEntry(
      id: '${module.name}-${++_sequence}', module: module, level: level,
      state: _sanitizeText(state), summary: _sanitizeText(summary),
      reason: reason == null ? null : _businessReason(reason),
      warning: warning == null ? null : _sanitizeText(warning),
      date: DateTime.now(), duration: duration, version: appVersion,
      source: _sanitizeText(source), details: safeDetails,
      pipeline: pipeline.map((step) => DiagnosticStep(
        _sanitizeText(step.name), level: step.level, duration: step.duration,
        detail: step.detail == null ? null : _sanitizeText(step.detail!),
      )).toList(growable: false),
    ));
    if (list.length > maxEntriesPerModule) {
      list.removeRange(0, list.length - maxEntriesPerModule);
    }
    notifyListeners();
  }

  List<DiagnosticEntry> filtered({
    Set<AppDiagnosticLevel>? levels,
    DiagnosticModule? module,
  }) => entries.where((entry) =>
      (levels == null || levels.contains(entry.level)) &&
      (module == null || entry.module == module)).toList(growable: false);

  void clear([DiagnosticModule? module]) {
    module == null ? _entries.clear() : _entries.remove(module);
    notifyListeners();
  }

  String exportReport({Set<AppDiagnosticLevel>? levels, DiagnosticModule? module}) {
    final report = {
      'reportVersion': 1,
      'applicationVersion': appVersion,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'privacy': 'Photos, chemins, identifiants, prompts, clés et tokens exclus.',
      'diagnostics': filtered(levels: levels, module: module)
          .map((entry) => entry.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(report);
  }

  static const _sensitiveKeys = {
    'token', 'accesstoken', 'refreshtoken', 'authorization', 'apikey', 'api_key',
    'key', 'prompt', 'photo', 'photos', 'photopath', 'path', 'filepath', 'email',
    'accountemail', 'userid', 'account', 'latitude', 'longitude', 'location',
    'description',
  };

  Map<String, Object?> _sanitizeMap(Map<String, Object?> source) => {
    for (final entry in source.entries)
      if (!_sensitiveKeys.contains(entry.key.toLowerCase().replaceAll(RegExp('[^a-z_]'), '')))
        _sanitizeText(entry.key): _sanitizeValue(entry.value),
  };

  Object? _sanitizeValue(Object? value) {
    if (value is Map) return _sanitizeMap(value.cast<String, Object?>());
    if (value is Iterable) return value.map(_sanitizeValue).toList();
    if (value is String) return _sanitizeText(value);
    return value;
  }

  String _businessReason(String value) {
    final safe = _sanitizeText(value);
    if (safe.toLowerCase().contains('exception') || safe.contains('StackTrace')) {
      return 'Le moteur n’a pas terminé son opération. Consultez l’étape en erreur.';
    }
    return safe;
  }

  String _sanitizeText(String value) => value
      .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false), '[MASQUÉ]')
      .replaceAll(RegExp(r'(sk-|AIza)[A-Za-z0-9_-]{10,}'), '[MASQUÉ]')
      .replaceAll(RegExp(r'(/Users/|/home/|/data/user/|[A-Z]:\\)[^\s,;]+'), '[CHEMIN MASQUÉ]');
}
