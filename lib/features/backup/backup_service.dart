import 'dart:convert';
import 'dart:io';

import '../../data/database_service.dart';
import 'backup_file.dart';

abstract interface class BackupRepository {
  Future<Map<String, List<Map<String, Object?>>>> exportData();
  Future<void> restoreData(Map<String, List<Map<String, Object?>>> data);
}

class DatabaseBackupRepository implements BackupRepository {
  final DatabaseService databaseService;
  const DatabaseBackupRepository(this.databaseService);

  @override
  Future<Map<String, List<Map<String, Object?>>>> exportData() =>
      databaseService.exportBackupData();

  @override
  Future<void> restoreData(Map<String, List<Map<String, Object?>>> data) =>
      databaseService.restoreBackupData(data);
}

class BackupService {
  final BackupRepository repository;
  final DateTime Function() now;

  BackupService({required this.repository, DateTime Function()? now})
    : now = now ?? DateTime.now;

  Future<BackupFile> createBackup() async {
    final data = await repository.exportData();
    final garments = data['garments'] ?? const [];
    final images = <Map<String, Object?>>[];
    final exportedGarments = <Map<String, Object?>>[];

    for (final garment in garments) {
      final exported = Map<String, Object?>.from(garment);
      final path = garment['image_path'] as String?;
      exported['image_path'] = null;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        try {
          if (await file.exists()) {
            final reference = 'garment:${garment['id']}';
            images.add({
              'reference': reference,
              'fileName': file.uri.pathSegments.last,
              'data': base64Encode(await file.readAsBytes()),
            });
            exported['image_reference'] = reference;
          }
        } on FileSystemException {
          // The garment remains usable even when its image cannot be read.
        }
      }
      exportedGarments.add(exported);
    }

    return BackupFile(
      version: BackupFile.currentVersion,
      createdAt: now(),
      garments: exportedGarments,
      images: images,
      outfits: data['outfits'] ?? const [],
      outfitItems: data['outfitItems'] ?? const [],
      wishlist: data['wishlist'] ?? const [],
      wearHistory: data['wearHistory'] ?? const [],
    );
  }

  Future<void> writeBackup(BackupFile backup, String path) =>
      File(path).writeAsString(backup.encode(), flush: true);
}
