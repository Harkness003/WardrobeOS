import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/backup/backup_file.dart';
import 'package:wardrobeos/features/backup/backup_service.dart';
import 'package:wardrobeos/features/backup/restore_service.dart';

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('wardrobe_backup_test'));
  tearDown(() async => temp.delete(recursive: true));

  test('sauvegarde ZIP complète et restauration complète', () async {
    final photo = File('${temp.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    final source = _MemoryRepository(_sampleData(photo.path));
    final service = BackupService(repository: source, now: () => DateTime.utc(2026, 8, 4, 12, 30));
    final path = '${temp.path}/backup.zip';
    final created = await service.createBackup();
    final manifest = await service.writeBackup(created, path);
    expect(manifest.garmentCount, 1); expect(manifest.photoCount, 1);
    final target = _MemoryRepository(_emptyData());
    final restore = RestoreService(repository: target, imageDirectory: () async => temp);
    final inspected = await restore.inspectFile(path);
    expect(inspected.manifest.createdAt, DateTime.utc(2026, 8, 4, 12, 30));
    final report = await restore.restore(inspected);
    expect(report.restored['garments'], 1); expect(target.data['plannedOutfits'], hasLength(1));
    expect(File(target.data['garments']!.single['image_path']! as String).existsSync(), isTrue);
  });

  test('archive incomplète est refusée clairement', () {
    expect(() => RestoreService(repository: _MemoryRepository(_emptyData())).inspect([1,2,3]),
      throwsA(isA<BackupFormatException>()));
  });

  test('ancienne sauvegarde JSON sans sections optionnelles migre progressivement', () {
    final archive = RestoreService(repository: _MemoryRepository(_emptyData())).inspect(
      '''{"version":1,"createdAt":"2025-01-02T03:04:05Z","garments":[],"images":[],"outfits":[],"outfitItems":[],"wishlist":[],"wearHistory":[]}'''.codeUnits);
    expect(archive.manifest.schemaVersion, 1);
    expect(archive.sections['plannedOutfits'], isEmpty);
  });

  test('photo absente n’empêche pas la sauvegarde', () async {
    final backup = await BackupService(repository: _MemoryRepository(_sampleData('/absente.jpg'))).createBackup();
    expect(backup.manifest.photoCount, 0);
  });
}

Map<String, List<Map<String, Object?>>> _emptyData() => {for (final key in RestoreService.sections) key: []};
Map<String, List<Map<String, Object?>>> _sampleData(String? photo) => {
  ..._emptyData(),
  'garments': [{'id':'g1','name':'Chemise','category':'Hauts','image_path':photo,'photos':'[]','created_at':'2026-01-01','updated_at':'2026-01-01'}],
  'outfits': [{'id':'o1','name':'Bureau'}],
  'outfitItems': [{'outfit_id':'o1','garment_id':'g1'}],
  'plannedOutfits': [{'id':'p1','outfit_id':'o1'}],
};
class _MemoryRepository implements BackupRepository {
  Map<String, List<Map<String, Object?>>> data; _MemoryRepository(this.data);
  @override Future<Map<String, List<Map<String, Object?>>>> exportData() async => data;
  @override Future<void> restoreData(Map<String, List<Map<String, Object?>>> restored) async => data = restored;
}
