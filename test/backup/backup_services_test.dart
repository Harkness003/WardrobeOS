import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/backup/backup_controller.dart';
import 'package:wardrobeos/features/backup/backup_file.dart';
import 'package:wardrobeos/features/backup/backup_service.dart';
import 'package:wardrobeos/features/backup/restore_service.dart';
import 'package:wardrobeos/models/garment_photo.dart';

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('wardrobe_backup_test'));
  tearDown(() async => temp.delete(recursive: true));

  test('sauvegarde et restauration conservent toutes les données canoniques', () async {
    final primary = File('${temp.path}/primary.jpg')..writeAsBytesSync([1, 2, 3]);
    final detail = File('${temp.path}/detail.jpg')..writeAsBytesSync([4, 5, 6]);
    final source = _MemoryRepository(_sampleData(primary.path, detail.path));
    final service = BackupService(repository: source,
      now: () => DateTime.utc(2026, 8, 4, 12, 30));
    final path = '${temp.path}/backup.zip';
    final manifest = await service.writeBackup(await service.createBackup(), path);

    expect(manifest.schemaVersion, BackupManifest.currentSchemaVersion);
    expect(manifest.garmentCount, 1);
    expect(manifest.photoCount, 2);
    final target = _MemoryRepository(_emptyData());
    final restore = RestoreService(repository: target,
      imageDirectory: () async => Directory('${temp.path}/restored'));
    final report = await restore.restore(await restore.inspectFile(path));

    expect(report.warnings, isEmpty);
    expect(target.data['outfits'], hasLength(1));
    expect(target.data['outfitItems'], hasLength(1));
    expect(target.data['plannedOutfits'], hasLength(1));
    expect(target.data['styleProfiles'], hasLength(1));
    final garment = target.data['garments']!.single;
    expect(garment['style_analysis'], contains('style-v1'));
    expect(garment['thermal_profile'], contains('thermal-v1'));
    final photos = GarmentPhoto.decode(garment['photos']);
    expect(photos.map((photo) => photo.id), ['photo-primary', 'photo-detail']);
    expect(photos.map((photo) => photo.type),
      [GarmentPhotoType.primary, GarmentPhotoType.detail]);
    expect(photos.every((photo) => File(photo.path).existsSync()), isTrue);
  });

  test('archive invalide ou incompatible est refusée avant restauration', () {
    final restore = RestoreService(repository: _MemoryRepository(_emptyData()));
    expect(() => restore.inspect([1, 2, 3]), throwsA(isA<BackupFormatException>()));
    expect(() => BackupManifest.fromJson({
      'format': BackupManifest.formatName,
      'appVersion': '0.8.0+9',
      'schemaVersion': BackupManifest.currentSchemaVersion - 1,
      'createdAt': '2026-08-04T12:30:00Z',
      'content': <String, int>{},
      'checksums': <String, String>{'x': 'y'},
    }), throwsA(isA<BackupFormatException>()));
  });

  test('une photo canonique absente fait échouer la sauvegarde', () async {
    final service = BackupService(repository: _MemoryRepository(
      _sampleData('/absente.jpg', null)));
    await expectLater(service.createBackup(), throwsA(isA<BackupFormatException>()));
  });



  test('création de sauvegarde annule proprement sans écriture', () async {
    final repository = _MemoryRepository(_emptyData());
    final picker = _FakeBackupDestinationPicker();
    final controller = BackupController(
      backupService: BackupService(repository: repository),
      restoreService: RestoreService(repository: repository),
      destinationPicker: picker,
    );

    await controller.createBackup();

    expect(picker.calls, 1);
    expect(picker.writtenBytes, isNotEmpty);
    expect(controller.result, 'Sauvegarde annulée.');
    expect(controller.resultIsError, isFalse);
    expect(controller.busy, isFalse);
    controller.dispose();
  });

  test('création de sauvegarde confirme le vrai nom et bloque le double clic', () async {
    final repository = _MemoryRepository(_emptyData());
    final picker = _DelayedBackupDestinationPicker(
      destination: const BackupSaveDestination(
        name: 'WardrobeOS_backup_2026-08-05_10-30.zip',
        location: r'C:\Users\me\WardrobeOS_backup_2026-08-05_10-30.zip',
        confirmed: true,
      ),
    );
    final controller = BackupController(
      backupService: BackupService(repository: repository),
      restoreService: RestoreService(repository: repository),
      destinationPicker: picker,
    );

    final first = controller.createBackup();
    final second = controller.createBackup();
    picker.complete();
    await Future.wait([first, second]);

    expect(picker.calls, 1);
    expect(picker.requestedName, endsWith('.zip'));
    expect(picker.writtenBytes, isNotEmpty);
    expect(controller.result, contains('Sauvegarde créée : WardrobeOS_backup_2026-08-05_10-30.zip'));
    expect(controller.result, contains(r'C:\Users\me\WardrobeOS_backup_2026-08-05_10-30.zip'));
    expect(controller.resultIsError, isFalse);
    controller.dispose();
  });

  test('création de sauvegarde distingue destination invalide et export échoué', () async {
    final repository = _MemoryRepository(_emptyData());
    final controller = BackupController(
      backupService: BackupService(repository: repository),
      restoreService: RestoreService(repository: repository),
      destinationPicker: _FakeBackupDestinationPicker(
        error: const BackupSaveException(BackupSaveFailure.invalidDestination),
      ),
    );

    await controller.createBackup();
    expect(controller.result, 'Impossible d’utiliser l’emplacement sélectionné. Choisis un autre emplacement.');
    expect(controller.resultIsError, isTrue);

    final exportController = BackupController(
      backupService: BackupService(repository: repository),
      restoreService: RestoreService(repository: repository),
      destinationPicker: _FakeBackupDestinationPicker(
        destination: const BackupSaveDestination(name: 'backup.zip', confirmed: false),
      ),
    );
    await exportController.createBackup();
    expect(exportController.result, 'L’archive a été préparée, mais n’a pas pu être enregistrée à l’emplacement choisi.');
    expect(exportController.resultIsError, isTrue);
    controller.dispose();
    exportController.dispose();
  });

  test('création de sauvegarde signale l’échec de création archive avant export', () async {
    final service = BackupService(repository: _MemoryRepository(_sampleData('/absente.jpg', null)));
    final picker = _FakeBackupDestinationPicker(
      destination: const BackupSaveDestination(name: 'backup.zip', confirmed: true),
    );
    final controller = BackupController(
      backupService: service,
      restoreService: RestoreService(repository: _MemoryRepository(_emptyData())),
      destinationPicker: picker,
    );

    await controller.createBackup();

    expect(picker.calls, 0);
    expect(controller.result, 'Impossible de créer l’archive de sauvegarde.');
    expect(controller.resultIsError, isTrue);
    controller.dispose();
  });
  test('la restauration reste explicitement confirmée et rafraîchit les caches', () async {
    var refreshed = false;
    final repository = _MemoryRepository(_emptyData());
    final restore = RestoreService(repository: repository,
      imageDirectory: () async => Directory('${temp.path}/confirmed'));
    final controller = BackupController(
      backupService: BackupService(repository: repository),
      restoreService: restore,
      afterRestore: () async => refreshed = true,
    );
    final archive = BackupArchive(
      manifest: BackupManifest(appVersion: BackupService.appVersion,
        schemaVersion: BackupManifest.currentSchemaVersion,
        createdAt: DateTime.utc(2026), garmentCount: 0, photoCount: 0,
        content: {for (final key in RestoreService.sections) key: 0}),
      sections: _emptyData(), photos: const {},
    );
    controller.pendingRestore = archive;

    expect(repository.restoreCalls, 0);
    await controller.confirmRestore();
    expect(repository.restoreCalls, 1);
    expect(refreshed, isTrue);
    controller.dispose();
  });
}

Map<String, List<Map<String, Object?>>> _emptyData() =>
  {for (final key in RestoreService.sections) key: []};

Map<String, List<Map<String, Object?>>> _sampleData(String primary, String? detail) => {
  ..._emptyData(),
  'garments': [{
    'id': 'g1', 'name': 'Chemise', 'category': 'Hauts',
    'photos': GarmentPhoto.encode([
      GarmentPhoto(id: 'photo-primary', path: primary,
        type: GarmentPhotoType.primary, createdAt: DateTime.utc(2026, 1, 1)),
      if (detail != null) GarmentPhoto(id: 'photo-detail', path: detail,
        type: GarmentPhotoType.detail, createdAt: DateTime.utc(2026, 1, 2),
        semanticType: 'boutons'),
    ]),
    'thermal_profile': '{"modelVersion":"thermal-v1"}',
    'style_analysis': '{"modelVersion":"style-v1"}',
    'created_at': '2026-01-01', 'updated_at': '2026-01-01',
  }],
  'outfits': [{'id': 'o1', 'name': 'Bureau'}],
  'outfitItems': [{'outfit_id': 'o1', 'garment_id': 'g1'}],
  'plannedOutfits': [{'id': 'p1', 'outfit_id': 'o1'}],
  'styleProfiles': [{'id': 'default'}],
};


class _DelayedBackupDestinationPicker extends _FakeBackupDestinationPicker {
  final _completer = Completer<void>();

  _DelayedBackupDestinationPicker({required super.destination});

  void complete() => _completer.complete();

  @override
  Future<BackupSaveDestination?> saveZip({required String fileName, required Uint8List bytes}) async {
    await _completer.future;
    return super.saveZip(fileName: fileName, bytes: bytes);
  }
}

class _MemoryRepository implements BackupRepository {
  Map<String, List<Map<String, Object?>>> data;
  int restoreCalls = 0;
  _MemoryRepository(this.data);
  @override
  Future<Map<String, List<Map<String, Object?>>>> exportData() async => data;
  @override
  Future<void> restoreData(Map<String, List<Map<String, Object?>>> restored) async {
    restoreCalls++;
    data = restored;
  }
}

class _FakeBackupDestinationPicker implements BackupDestinationPicker {
  BackupSaveDestination? destination;
  Object? error;
  int calls = 0;
  String? requestedName;
  List<int>? writtenBytes;

  _FakeBackupDestinationPicker({this.destination, this.error});

  @override
  Future<BackupSaveDestination?> saveZip({required String fileName, required Uint8List bytes}) async {
    calls++;
    requestedName = fileName;
    writtenBytes = List<int>.from(bytes);
    final thrown = error;
    if (thrown != null) throw thrown;
    return destination;
  }
}
