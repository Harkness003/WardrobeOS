import 'dart:convert';

class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);
  @override
  String toString() => message;
}

/// Public metadata stored in `manifest.json`, so an archive can be inspected
/// and confirmed without modifying application data.
class BackupManifest {
  static const formatName = 'WardrobeOS Backup';
  static const currentSchemaVersion = 4;
  final String appVersion;
  final int schemaVersion;
  final DateTime createdAt;
  final int garmentCount;
  final int photoCount;
  final Map<String, int> content;
  final Map<String, String> checksums;

  const BackupManifest({required this.appVersion, required this.schemaVersion,
    required this.createdAt, required this.garmentCount, required this.photoCount,
    required this.content, this.checksums = const {}});

  Map<String, Object?> toJson() => {
    'format': formatName, 'appVersion': appVersion,
    'schemaVersion': schemaVersion, 'createdAt': createdAt.toUtc().toIso8601String(),
    'garmentCount': garmentCount, 'photoCount': photoCount,
    'content': content, 'checksums': checksums,
  };

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    final schema = json['schemaVersion'];
    final date = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (json['format'] != formatName || schema is! int || date == null ||
        json['appVersion'] is! String || json['content'] is! Map ||
        json['checksums'] is! Map) {
      throw const BackupFormatException('Le manifeste WardrobeOS est invalide.');
    }
    if (schema != currentSchemaVersion) {
      throw BackupFormatException('Schéma $schema non pris en charge (requis : ${BackupManifest.currentSchemaVersion}).');
    }
    Map<String, int> counts(Object? value) => value is Map
        ? value.map((k, v) => MapEntry(k.toString(), v is int ? v : 0)) : {};
    Map<String, String> hashes(Object? value) => value is Map
        ? value.map((k, v) => MapEntry(k.toString(), v.toString())) : {};
    final content = counts(json['content']);
    final checksums = hashes(json['checksums']);
    if (checksums.isEmpty) {
      throw const BackupFormatException('Le manifeste ne contient aucun contrôle d’intégrité.');
    }
    return BackupManifest(appVersion: json['appVersion'] as String,
      schemaVersion: schema, createdAt: date,
      garmentCount: json['garmentCount'] as int? ?? 0,
      photoCount: json['photoCount'] as int? ?? 0,
      content: content, checksums: checksums);
  }
}

class BackupArchive {
  final BackupManifest manifest;
  final Map<String, List<Map<String, Object?>>> sections;
  final Map<String, List<int>> photos;
  final List<String> warnings;
  const BackupArchive({required this.manifest, required this.sections, required this.photos,
    this.warnings = const []});
}

List<Map<String, Object?>> decodeRows(List<int> bytes, String section) {
  try {
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! List) throw const FormatException();
    return value.map((row) {
      if (row is! Map) throw const FormatException();
      return row.map<String, Object?>((k, v) => MapEntry(k.toString(), v));
    }).toList(growable: false);
  } catch (_) {
    throw BackupFormatException('La section « $section » est corrompue.');
  }
}
