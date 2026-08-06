import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../../data/database_service.dart';
import '../../models/garment_photo.dart';
import 'backup_file.dart';
import '../../core/diagnostics/diagnostic_service.dart';

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
    final stopwatch = Stopwatch()..start();
    final data = await repository.exportData();
    final photos = <String, List<int>>{};
    final warnings = <String>[];
    var missingPhotoCount = 0;
    final garmentsWithMissingPhotos = <String>{};
    var normalizedPhotoCount = 0;
    final garmentsWithNormalizedPhotos = <String>{};
    final garments = (data['garments'] ?? const []).map((source) => Map<String, Object?>.from(source)).toList();
    for (final garment in garments) {
      final garmentId = garment['id']?.toString() ?? 'inconnu';
      final garmentLabel = _garmentLabel(garment);
      final List<GarmentPhoto> garmentPhotos;
      try {
        garmentPhotos = GarmentPhoto.decodeStrict(garment['photos']);
      } on FormatException catch (error) {
        throw BackupFormatException('Photos canoniques invalides pour le vêtement $garmentLabel : ${error.message}.');
      }
      final normalized = GarmentPhotoNormalizer.normalize(garmentPhotos);
      if (normalized.changed) {
        normalizedPhotoCount += normalized.removedEmptyPaths + normalized.repairedEmptyIds + normalized.removedDuplicateIds +
          normalized.removedDuplicatePaths + normalized.demotedPrimaryCount + (normalized.promotedPrimary ? 1 : 0);
        garmentsWithNormalizedPhotos.add(garmentId);
      }
      final archivedPhotos = <GarmentPhoto>[];
      for (final photo in normalized.photos) {
        final path = photo.path;
        try {
          final file = File(path);
          if (!await file.exists()) {
            missingPhotoCount++;
            garmentsWithMissingPhotos.add(garmentId);
            continue;
          }
          final name = 'photos/$garmentId/${photo.id}_${p.basename(path)}';
          if (photos.containsKey(name)) {
            throw BackupFormatException('Référence de photo dupliquée pour le vêtement $garmentLabel : $name.');
          }
          photos[name] = await file.readAsBytes();
          archivedPhotos.add(GarmentPhoto(id: photo.id, path: name, type: photo.type,
            createdAt: photo.createdAt, semanticType: photo.semanticType));
        } on FileSystemException catch (error) {
          throw BackupFormatException('Photo illisible pour le vêtement $garmentLabel : $path (${error.message}).');
        }
      }
      garment['photos'] = GarmentPhoto.encode(archivedPhotos);
    }
    if (missingPhotoCount > 0) {
      warnings.add('Sauvegarde créée avec $missingPhotoCount photo${missingPhotoCount == 1 ? '' : 's'} manquante${missingPhotoCount == 1 ? '' : 's'} sur ${garmentsWithMissingPhotos.length} vêtement${garmentsWithMissingPhotos.length == 1 ? '' : 's'}.');
    }
    if (normalizedPhotoCount > 0) {
      warnings.add('$normalizedPhotoCount entrée${normalizedPhotoCount == 1 ? '' : 's'} photo incomplète${normalizedPhotoCount == 1 ? '' : 's'} ou dupliquée${normalizedPhotoCount == 1 ? '' : 's'} normalisée${normalizedPhotoCount == 1 ? '' : 's'} sur ${garmentsWithNormalizedPhotos.length} vêtement${garmentsWithNormalizedPhotos.length == 1 ? '' : 's'}.');
    }
    data['garments'] = garments;
    final counts = {for (final entry in data.entries) entry.key: entry.value.length};
    final result = BackupArchive(manifest: BackupManifest(appVersion: appVersion,
      schemaVersion: BackupManifest.currentSchemaVersion, createdAt: now(),
      garmentCount: garments.length, photoCount: photos.length, content: counts),
      sections: data, photos: photos, warnings: warnings);
    DiagnosticService.instance.publish(module: DiagnosticModule.backup,
      level: warnings.isEmpty ? DiagnosticLevel.success : DiagnosticLevel.warning,
      state: 'Archive préparée', summary: 'Sauvegarde créée', source: 'BackupService',
      duration: stopwatch.elapsed, warning: warnings.isEmpty ? null : warnings.join(' '),
      details: {'vêtements': garments.length, 'tailleArchiveOctets': encodeBackup(result).length},
      pipeline: [
        const DiagnosticStep('Base locale'),
        DiagnosticStep('Collecte', detail: '${garments.length} vêtements'),
        DiagnosticStep('Archive', duration: stopwatch.elapsed),
      ]);
    return result;
  }

  String _garmentLabel(Map<String, Object?> garment) {
    final id = garment['id']?.toString() ?? 'inconnu';
    final name = garment['name']?.toString().trim();
    return name == null || name.isEmpty ? id : '$name ($id)';
  }

  List<int> encodeBackup(BackupArchive backup) {
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
    return ZipEncoder().encode(archive);
  }

  Future<BackupManifest> writeBackup(BackupArchive backup, String path) async {
    final zip = encodeBackup(backup);
    await File(path).writeAsBytes(zip, flush: true);
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      throw const FileSystemException('Backup file was not created');
    }
    return backup.manifest;
  }
}
