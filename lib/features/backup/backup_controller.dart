import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'backup_service.dart';
import 'restore_service.dart';

class BackupController extends ChangeNotifier {
  final BackupService backupService;
  final RestoreService restoreService;
  bool busy = false;
  DateTime? lastBackupAt;
  String? result;

  BackupController({required this.backupService, required this.restoreService});

  Future<void> createBackup() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer la sauvegarde WardrobeOS',
      fileName: 'wardrobeos-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return;
    await _run(() async {
      final backup = await backupService.createBackup();
      await backupService.writeBackup(backup, path);
      lastBackupAt = backup.createdAt;
      result = 'Sauvegarde créée avec succès.';
    });
  }

  Future<void> restoreBackup() async {
    final selection = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choisir une sauvegarde WardrobeOS',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = selection?.files.single.path;
    if (path == null) return;
    await _run(() async {
      await restoreService.restoreFile(path);
      result = 'Sauvegarde restaurée avec succès.';
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    busy = true;
    result = null;
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      result = 'Échec de l’opération : $error';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
