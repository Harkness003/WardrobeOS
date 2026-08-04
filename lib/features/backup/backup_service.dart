import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import '../../data/database_service.dart';
import 'backup_file.dart';

abstract interface class BackupRepository {
  Future<Map<String, List<Map<String, Object?>>>> exportData();
  Future<void> restoreData(Map<String, List<Map<String, Object?>>> data);
}
class DatabaseBackupRepository implements BackupRepository {
  final DatabaseService databaseService;
  const DatabaseBackupRepository(this.databaseService);
  @override Future<Map<String, List<Map<String, Object?>>>> exportData() => databaseService.exportBackupData();
  @override Future<void> restoreData(Map<String, List<Map<String, Object?>>> data) => databaseService.restoreBackupData(data);
}

class BackupService {
  static const appVersion = '0.8.0+9';
  final BackupRepository repository;
  final DateTime Function() now;
  BackupService({required this.repository, DateTime Function()? now}) : now = now ?? DateTime.now;

  Future<BackupArchive> createBackup() async {
    final data = await repository.exportData();
    final photos = <String, List<int>>{};
    final garments = (data['garments'] ?? const []).map((source) => Map<String, Object?>.from(source)).toList();
    for (final garment in garments) {
      final paths = <String>{};
      final main = garment['image_path'] as String?;
      if (main != null && main.isNotEmpty) paths.add(main);
      // `photos` contains the scanner's additional photo descriptors/paths.
      final rawPhotos = garment['photos'];
      if (rawPhotos is String) {
        try { for (final item in jsonDecode(rawPhotos) as List) { if (item is String) paths.add(item); } } catch (_) {}
      }
      final refs = <String>[];
      for (final path in paths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            final name = 'photos/${garment['id']}_${refs.length}_${file.uri.pathSegments.last}';
            photos[name] = await file.readAsBytes(); refs.add(name);
          }
        } on FileSystemException { /* Reported by the photo count difference. */ }
      }
      garment['image_path'] = null; garment['backup_photo_references'] = refs;
    }
    data['garments'] = garments;
    final counts = {for (final entry in data.entries) entry.key: entry.value.length};
    return BackupArchive(manifest: BackupManifest(appVersion: appVersion,
      schemaVersion: BackupManifest.currentSchemaVersion, createdAt: now(),
      garmentCount: garments.length, photoCount: photos.length, content: counts),
      sections: data, photos: photos);
  }

  Future<BackupManifest> writeBackup(BackupArchive backup, String path) async {
    final archive = Archive(); final hashes = <String, String>{};
    for (final entry in backup.sections.entries) {
      final name = 'data/${entry.key}.json'; final bytes = utf8.encode(jsonEncode(entry.value));
      hashes[name] = sha256.convert(bytes).toString(); archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    for (final entry in backup.photos.entries) {
      hashes[entry.key] = sha256.convert(entry.value).toString();
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    final manifest = BackupManifest(appVersion: backup.manifest.appVersion,
      schemaVersion: backup.manifest.schemaVersion, createdAt: backup.manifest.createdAt,
      garmentCount: backup.manifest.garmentCount, photoCount: backup.manifest.photoCount,
      content: backup.manifest.content, checksums: hashes);
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest.toJson()));
    archive.addFile(ArchiveFile('manifest.json', bytes.length, bytes));
    final zip = ZipEncoder().encode(archive);
    await File(path).writeAsBytes(zip, flush: true);
    return manifest;
  }
}
