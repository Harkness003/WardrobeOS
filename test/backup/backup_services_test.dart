import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/backup/backup_file.dart';
import 'package:wardrobeos/features/backup/backup_service.dart';
import 'package:wardrobeos/features/backup/restore_service.dart';

void main() {
  group('BackupService', () {
    test('génère un backup versionné avec toutes les sections', () async {
      final repository = _MemoryRepository(_sampleData());
      final service = BackupService(
        repository: repository,
        now: () => DateTime.utc(2026, 7, 18),
      );

      final backup = await service.createBackup();

      expect(backup.version, 1);
      expect(backup.createdAt, DateTime.utc(2026, 7, 18));
      expect(backup.garments.single['id'], 'g1');
      expect(backup.outfits.single['id'], 'o1');
      expect(backup.outfitItems, hasLength(1));
      expect(backup.wearHistory, hasLength(1));
      expect(BackupFile.decode(backup.encode()).version, 1);
    });

    test('génère un backup vide valide', () async {
      final backup = await BackupService(
        repository: _MemoryRepository(_emptyData()),
      ).createBackup();

      expect(backup.garments, isEmpty);
      expect(backup.outfits, isEmpty);
      expect(backup.wearHistory, isEmpty);
      expect(backup.images, isEmpty);
    });
  });

  group('RestoreService', () {
    test('refuse une version inconnue', () {
      expect(
        () => BackupFile.decode('''
          {"version":2,"createdAt":"2026-07-18T00:00:00Z"}
        '''),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('restaure avec succès toutes les relations', () async {
      final source = await BackupService(
        repository: _MemoryRepository(_sampleData()),
      ).createBackup();
      final target = _MemoryRepository(_emptyData());
      final directory = await Directory.systemTemp.createTemp('wardrobe-test');
      addTearDown(() => directory.delete(recursive: true));

      await RestoreService(
        repository: target,
        imageDirectory: () async => directory,
      ).restore(source.encode());

      expect(target.data['garments'], hasLength(1));
      expect(target.data['outfitItems'], hasLength(1));
      expect(target.data['wearHistory'], hasLength(1));
    });

    test('une restauration échouée ne remplace aucune donnée', () async {
      final initial = _sampleData();
      final repository = _MemoryRepository(initial, failRestore: true);
      final backup = await BackupService(
        repository: _MemoryRepository(_emptyData()),
      ).createBackup();

      await expectLater(
        RestoreService(repository: repository).restore(backup.encode()),
        throwsStateError,
      );
      expect(repository.data['garments']!.single['id'], 'g1');
    });
  });
}

Map<String, List<Map<String, Object?>>> _emptyData() => {
  'garments': [],
  'outfits': [],
  'outfitItems': [],
  'wishlist': [],
  'wearHistory': [],
};

Map<String, List<Map<String, Object?>>> _sampleData() => {
  'garments': [
    {
      'id': 'g1',
      'name': 'Chemise',
      'category': 'Hauts',
      'image_path': null,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    },
  ],
  'outfits': [
    {'id': 'o1', 'name': 'Bureau'},
  ],
  'outfitItems': [
    {'outfit_id': 'o1', 'garment_id': 'g1'},
  ],
  'wishlist': [],
  'wearHistory': [
    {'id': 1, 'garment_id': 'g1', 'worn_at': '2026-01-02T00:00:00Z'},
  ],
};

class _MemoryRepository implements BackupRepository {
  Map<String, List<Map<String, Object?>>> data;
  final bool failRestore;

  _MemoryRepository(this.data, {this.failRestore = false});

  @override
  Future<Map<String, List<Map<String, Object?>>>> exportData() async => data;

  @override
  Future<void> restoreData(
    Map<String, List<Map<String, Object?>>> restored,
  ) async {
    if (failRestore) throw StateError('simulated transaction failure');
    data = restored;
  }
}
