import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'backup_file.dart';
import 'backup_service.dart';
import 'restore_service.dart';

enum BackupSaveFailure { invalidDestination, archiveCreation, export }

class BackupSaveException implements Exception {
  final BackupSaveFailure failure;
  final Object? cause;
  const BackupSaveException(this.failure, [this.cause]);
  @override
  String toString() => 'BackupSaveException($failure, $cause)';
}

class BackupSaveDestination {
  final String name;
  final String? location;
  final bool confirmed;
  const BackupSaveDestination({required this.name, this.location, required this.confirmed});
}

abstract interface class BackupDestinationPicker {
  Future<BackupSaveDestination?> saveZip({required String fileName, required Uint8List bytes});
}

class FilePickerBackupDestinationPicker implements BackupDestinationPicker {
  @override
  Future<BackupSaveDestination?> saveZip({required String fileName, required Uint8List bytes}) async {
    final selected = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer la sauvegarde WardrobeOS',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: bytes,
    );
    if (selected == null) return null;
    if (selected.trim().isEmpty) throw const BackupSaveException(BackupSaveFailure.invalidDestination);

    final displayName = _displayName(selected, fileName);
    if (_isFilePath(selected)) {
      final path = _withZipExtension(selected);
      final file = File(path);
      if (!await file.exists()) {
        await file.writeAsBytes(bytes, flush: true);
      }
      if (!await file.exists() || await file.length() == 0) {
        throw const BackupSaveException(BackupSaveFailure.export);
      }
      return BackupSaveDestination(name: p.basename(path), location: path, confirmed: true);
    }

    return BackupSaveDestination(name: displayName, location: selected, confirmed: true);
  }

  static bool _isFilePath(String value) {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) return false;
    if (value.startsWith('content://') || value.startsWith('file://')) return false;
    return true;
  }

  static String _withZipExtension(String value) => value.toLowerCase().endsWith('.zip') ? value : '$value.zip';

  static String _displayName(String selected, String fallback) {
    final raw = Uri.tryParse(selected)?.pathSegments.lastOrNull ?? p.basename(selected);
    final name = raw.isEmpty ? fallback : raw;
    return name.toLowerCase().endsWith('.zip') ? name : '$name.zip';
  }
}

class BackupController extends ChangeNotifier {
  final BackupService backupService; final RestoreService restoreService;
  final BackupDestinationPicker destinationPicker;
  final Future<void> Function()? afterRestore;
  bool busy = false; bool resultIsError = false; BackupManifest? lastBackup; String? lastLocation; String? result;
  String? pendingPath; BackupArchive? pendingRestore;
  BackupController({required this.backupService, required this.restoreService,
    BackupDestinationPicker? destinationPicker, this.afterRestore})
      : destinationPicker = destinationPicker ?? FilePickerBackupDestinationPicker();

  static String defaultFileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'WardrobeOS_backup_${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}-${two(now.minute)}.zip';
  }
  Future<void> createBackup() async {
    if (busy) return;
    await _run(() async {
      final BackupArchive archive;
      final Uint8List bytes;
      try {
        archive = await backupService.createBackup();
        bytes = Uint8List.fromList(backupService.encodeBackup(archive));
      } catch (error) {
        throw BackupSaveException(BackupSaveFailure.archiveCreation, error);
      }
      final destination = await destinationPicker.saveZip(
        fileName: defaultFileName(DateTime.now()),
        bytes: bytes,
      );
      if (destination == null) {
        result = 'Sauvegarde annulée.';
        return;
      }
      if (!destination.confirmed) {
        throw const BackupSaveException(BackupSaveFailure.export);
      }
      lastBackup = archive.manifest;
      lastLocation = destination.location;
      final warningText = archive.warnings.isEmpty ? '' : '\n${archive.warnings.join(' ')}';
      result = destination.location == null
        ? 'Sauvegarde créée : ${destination.name}$warningText'
        : 'Sauvegarde créée : ${destination.name}\nEmplacement : ${destination.location}$warningText';
    }, failurePrefix: 'Impossible de créer la sauvegarde');
  }
  Future<bool> selectRestore() async {
    final selection = await FilePicker.platform.pickFiles(dialogTitle: 'Choisir une sauvegarde WardrobeOS',
      type: FileType.custom, allowedExtensions: const ['zip']);
    final path = selection?.files.single.path; if (path == null) return false;
    var ready = false; await _run(() async { pendingRestore = await restoreService.inspectFile(path); pendingPath = path; ready = true; }); return ready;
  }
  Future<void> confirmRestore() async { final archive = pendingRestore; if (archive == null) return;
    await _run(() async { final report = await restoreService.restore(archive);
      await afterRestore?.call();
      final total = report.restored.values.fold<int>(0, (a, b) => a + b);
      result = '$total éléments restaurés (${report.manifest.garmentCount} vêtements, ${report.manifest.photoCount} photos).'
        '${report.warnings.isEmpty ? '' : ' Avertissements : ${report.warnings.join(' ')}'}'; pendingRestore = null; pendingPath = null; }); }
  Future<void> _run(Future<void> Function() operation, {String failurePrefix = 'Échec'}) async { busy = true; result = null; resultIsError = false; notifyListeners();
    try { await operation(); } catch (error) { debugPrint('$failurePrefix: $error'); resultIsError = true; result = _friendlyError(error); } finally { busy = false; notifyListeners(); } }

  String _friendlyError(Object error) {
    if (error is BackupSaveException) {
      return switch (error.failure) {
        BackupSaveFailure.invalidDestination => 'Impossible d’utiliser l’emplacement sélectionné. Choisis un autre emplacement.',
        BackupSaveFailure.archiveCreation => error.cause is BackupFormatException
          ? (error.cause as BackupFormatException).message
          : 'Impossible de créer l’archive de sauvegarde.',
        BackupSaveFailure.export => 'L’archive a été préparée, mais n’a pas pu être enregistrée à l’emplacement choisi.',
      };
    }
    if (error is BackupFormatException) return error.message;
    final text = error.toString().toLowerCase();
    if (text.contains('cancel')) return 'Sauvegarde annulée.';
    if (text.contains('permission') || text.contains('denied')) {
      return 'Impossible d’utiliser l’emplacement sélectionné. Choisis un autre emplacement.';
    }
    return 'Impossible de créer l’archive de sauvegarde.';
  }
}
